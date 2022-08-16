// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

import "../interfaces/IEssenceField.sol";
import "../interfaces/IArtifactMetadataStore.sol";

/// @notice Contract is using an admin role to manage its configuration. Admin role is assigned to a multi-sig
/// wallet controlled by trusted team members. Admin role aka FACTION_ABSORBER_ADMIN_ROLE, as initialized during init()
/// to msg.sender can:
/// • Add/Remove addresses to excludedAddresses, which impacts the utilization calculation, by calling
///   addExcludedAddress() and removeExcludedAddress(), respectively.
/// • Set/Unset an arbitrary override value for the value returned by utilization(), by calling
///   setUtilizationOverride().
/// • Change at any time the essence token address, which is set during init(), to an arbitrary one, by calling
///   setEssenceToken().
/// • Set absorberRods to an arbitrary address (including address(0), in which case absorberRods staking/unstaking is
///   disabled), by calling setAbsorberRods().
/// • Set artifact to an arbitrary address (including address(0), in which case artifact staking/unstaking is disabled),
///   by calling setArtifact().
/// • Set artifactMetadataStore to an arbitrary address (used for artifact 1:1 checking and artifact nft power computation),
///   by calling setArtifactMetadataStore().
/// • Re-set the artifactPowerTable array to arbitrary values, by calling setArtifactPowerTable().
/// • Set/Unset the emergency unlockAll state, by calling toggleUnlockAll().
/// • Withdraw all undistributed rewards to an arbitrary address, by calling withdrawUndistributedRewards().
contract EssenceAbsorberV2 is Initializable, AccessControlEnumerableUpgradeable, ERC1155HolderUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;

    enum Lock {
        twoWeeks,
        oneMonth,
        threeMonths,
        sixMonths,
        twelveMonths
    }

    struct UserInfo {
        uint256 originalDepositAmount;
        uint256 depositAmount; //current deposit amount
        uint256 epAmount;
        uint256 lockedUntil;
        uint256 vestingLastUpdate;
        int256 rewardDebt;
        Lock lock;
    }

    bytes32 public constant FACTION_ABSORBER_ADMIN_ROLE = keccak256("FACTION_ABSORBER_ADMIN_ROLE");

    uint256 public constant DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 public constant TWO_WEEKS = ONE_WEEK * 2;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant THREE_MONTHS = ONE_MONTH * 3;
    uint256 public constant SIX_MONTHS = ONE_MONTH * 6;
    uint256 public constant TWELVE_MONTHS = 365 days;
    uint256 public constant ONE = 1e18;

    // Essence token addr
    IERC20Upgradeable public essence;
    IEssenceField public essenceField;

    bool public unlockAll;

    uint256 public totalRewardsEarned;
    uint256 public totalUndistributedRewards;

    /// EP stands for ESSENCE POWER, representing the multiplier over the ESSENCE a user has, and thus their share of emissions
    /// this represents the amount of essence per ESSENCE POWER token shares that exist
    /// Having high EP enables a user to gain a greater share of emissions but does not increase the rate of ESSENCE emissions for the game.
    uint256 public accEssencePerEpShare;

    /// this represents the total amount of EP Shares that exist
    uint256 public totalEpToken;
    uint256 public essenceTotalDeposits;

    uint256 public utilizationOverride;
    EnumerableSetUpgradeable.AddressSet private excludedAddresses;

    address public artifactMetadataStore;
    address public absorberRods;
    address public artifact;

    // user => staked 1/1
    mapping(address => bool) public isArtifact1_1Staked;
    uint256[][] public artifactPowerTable;

    /// @notice user => depositId => UserInfo
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;
    /// @notice user => depositId[]
    mapping(address => EnumerableSetUpgradeable.UintSet) private allUserDepositIds;
    /// @notice user => deposit index
    mapping(address => uint256) public currentId;

    // user => tokenIds
    mapping(address => EnumerableSetUpgradeable.UintSet) private artifactStaked;
    // user => tokenId => amount
    mapping(address => mapping(uint256 => uint256)) public absorberRodsStaked;
    // user => total amount staked
    mapping(address => uint256) public absorberRodsStakedAmount;
    // user => power
    mapping(address => uint256) public powers;

    event Staked(address nft, uint256 tokenId, uint256 amount, uint256 currentPower);
    event Unstaked(address nft, uint256 tokenId, uint256 amount, uint256 currentPower);

    event Deposit(address indexed user, uint256 indexed index, uint256 amount, Lock lock);
    event Withdraw(address indexed user, uint256 indexed index, uint256 amount);
    event UndistributedRewardsWithdraw(address indexed to, uint256 amount);
    event Harvest(address indexed user, uint256 indexed index, uint256 amount);
    event LogUpdateRewards(
        uint256 distributedRewards,
        uint256 undistributedRewards,
        uint256 epSupply,
        uint256 accEssencePerEpShare
    );
    event UtilizationRate(uint256 util);

    /// @notice what is the total epToken
    /// get distributed and undistributed rewards, accumulates them and calculates the amount of Essence per share
    /// This is called on every function
    modifier updateRewards() {
        uint256 epSupply = totalEpToken;
        if (epSupply > 0) {
            (uint256 distributedRewards, uint256 undistributedRewards) = getRealEssenceReward(
                essenceField.requestRewards()
            );
            totalRewardsEarned += distributedRewards;
            totalUndistributedRewards += undistributedRewards;
            accEssencePerEpShare += (distributedRewards * ONE) / epSupply;
            emit LogUpdateRewards(distributedRewards, undistributedRewards, epSupply, accEssencePerEpShare);
        }

        uint256 util = utilization();
        emit UtilizationRate(util);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(address _essence, address _essenceField) external initializer {
        essence = IERC20Upgradeable(_essence);
        essenceField = IEssenceField(_essenceField);

        _setRoleAdmin(FACTION_ABSORBER_ADMIN_ROLE, FACTION_ABSORBER_ADMIN_ROLE);
        _grantRole(FACTION_ABSORBER_ADMIN_ROLE, msg.sender);

        // array follows values from IArtifactMetadataStore.ArtifactGeneration and IArtifactMetadataStore.ArtifactRarity
        artifactPowerTable = [
            // PRIMAL
            // LEGENDARY,EXOTIC,RARE,UNCOMMON,COMMON
            [uint256(600e16), uint256(200e16), uint256(75e16), uint256(100e16), uint256(50e16)],
            // SECONDARY
            // LEGENDARY,EXOTIC,RARE,UNCOMMON,COMMON
            [uint256(40e16), uint256(25e16), uint256(15e16), uint256(10e16), uint256(5e16)]
        ];

        __AccessControlEnumerable_init();
        __ERC1155Holder_init();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ReceiverUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getStakedArtifacts(address _user) external view virtual returns (uint256[] memory) {
        return artifactStaked[_user].values();
    }

    function getUserPower(address _user) external view virtual returns (uint256) {
        return powers[_user];
    }

    function getArtifactPowerTable() external view virtual returns (uint256[][] memory) {
        return artifactPowerTable;
    }

    function getArtifactPower(uint256 _artifactGeneration, uint256 _artifactRarity)
        public
        view
        virtual
        returns (uint256)
    {
        if (
            _artifactGeneration < artifactPowerTable.length &&
            _artifactRarity < artifactPowerTable[_artifactGeneration].length
        ) {
            return artifactPowerTable[_artifactGeneration][_artifactRarity];
        }
        return 0;
    }

    /// @notice how this function calculates the utilization % of this absorber
    function utilization() public view virtual returns (uint256 util) {
        if (utilizationOverride > 0) return utilizationOverride;

        uint256 circulatingSupply = essence.totalSupply();
        uint256 len = excludedAddresses.length();
        for (uint256 i = 0; i < len; i++) {
            circulatingSupply -= essence.balanceOf(excludedAddresses.at(i));
        }
        uint256 rewardsAmount = essence.balanceOf(address(this)) - essenceTotalDeposits;
        circulatingSupply -= rewardsAmount;
        if (circulatingSupply != 0) {
            util = (essenceTotalDeposits * ONE) / circulatingSupply;
        }
    }

    function getRealEssenceReward(uint256 _essenceReward)
        public
        view
        virtual
        returns (uint256 distributedRewards, uint256 undistributedRewards)
    {
        uint256 util = utilization();

        if (util < 3e17) {
            distributedRewards = 0;
        } else if (util < 4e17) {
            // >30%
            // 50%
            distributedRewards = (_essenceReward * 5) / 10;
        } else if (util < 5e17) {
            // >40%
            // 60%
            distributedRewards = (_essenceReward * 6) / 10;
        } else if (util < 6e17) {
            // >50%
            // 80%
            distributedRewards = (_essenceReward * 8) / 10;
        } else {
            // >60%
            // 100%
            distributedRewards = _essenceReward;
        }

        undistributedRewards = _essenceReward - distributedRewards;
    }

    function getAllUserDepositIds(address _user) public view virtual returns (uint256[] memory) {
        return allUserDepositIds[_user].values();
    }

    function getExcludedAddresses() public view virtual returns (address[] memory) {
        return excludedAddresses.values();
    }

    function getLockPower(Lock _lock) public pure virtual returns (uint256 power, uint256 timelock) {
        if (_lock == Lock.twoWeeks) {
            // 10%
            return (10e16, TWO_WEEKS);
        } else if (_lock == Lock.oneMonth) {
            // 25%
            return (25e16, ONE_MONTH);
        } else if (_lock == Lock.threeMonths) {
            // 80%
            return (80e16, THREE_MONTHS);
        } else if (_lock == Lock.sixMonths) {
            // 180%
            return (180e16, SIX_MONTHS);
        } else if (_lock == Lock.twelveMonths) {
            // 400%
            return (400e16, TWELVE_MONTHS);
        } else {
            revert("Invalid lock value");
        }
    }

    function getVestingTime(Lock _lock) public pure virtual returns (uint256 vestingTime) {
        if (_lock == Lock.twoWeeks) {
            vestingTime = 0;
        } else if (_lock == Lock.oneMonth) {
            vestingTime = 7 days;
        } else if (_lock == Lock.threeMonths) {
            vestingTime = 14 days;
        } else if (_lock == Lock.sixMonths) {
            vestingTime = 30 days;
        } else if (_lock == Lock.twelveMonths) {
            vestingTime = 45 days;
        }
    }

    function calcualteVestedPrincipal(address _user, uint256 _depositId) public view virtual returns (uint256 amount) {
        UserInfo storage user = userInfo[_user][_depositId];
        Lock _lock = user.lock;
        uint256 originalDepositAmount = user.originalDepositAmount;

        uint256 vestingEnd = user.lockedUntil + getVestingTime(_lock);
        uint256 vestingBegin = user.lockedUntil;

        if (block.timestamp >= vestingEnd || unlockAll) {
            amount = user.depositAmount;
        } else if (block.timestamp > vestingBegin) {
            uint256 amountVested = (originalDepositAmount * (block.timestamp - vestingBegin)) /
                (vestingEnd - vestingBegin);
            uint256 amountWithdrawn = originalDepositAmount - user.depositAmount;
            if (amountWithdrawn < amountVested) {
                amount = amountVested - amountWithdrawn;
            }
        }
    }

    /// @notice essenceField.getPendingRewards: calculates the rewards still available to this absorber from the stream that was enabled
    /// getRealEssenceRewards, strangulates the stream by a % according to the utilization of this absorber
    function pendingRewardsPosition(address _user, uint256 _depositId) public view virtual returns (uint256 pending) {
        UserInfo storage user = userInfo[_user][_depositId];
        uint256 _accEssencePerEpShare = accEssencePerEpShare;
        uint256 epSupply = totalEpToken;

        (uint256 distributedRewards, ) = getRealEssenceReward(essenceField.getPendingRewards(address(this)));
        _accEssencePerEpShare += (distributedRewards * ONE) / epSupply;

        int256 rewardDebt = user.rewardDebt;
        int256 accumulatedEssence = ((user.epAmount * _accEssencePerEpShare) / ONE).toInt256();

        if (accumulatedEssence >= rewardDebt) {
            pending = (accumulatedEssence - rewardDebt).toUint256();
        }
    }

    function pendingRewardsAll(address _user) external view virtual returns (uint256 pending) {
        uint256 len = allUserDepositIds[_user].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_user].at(i);
            pending += pendingRewardsPosition(_user, depositId);
        }
    }

    function deposit(uint256 _amount, Lock _lock) public virtual updateRewards {
        require(allUserDepositIds[msg.sender].length() < 3000, "Max deposits number reached");

        (UserInfo storage user, uint256 depositId) = _addDeposit(msg.sender);
        (uint256 lockPower, uint256 timelock) = getLockPower(_lock);
        uint256 nftPower = powers[msg.sender];

        /// deposit amount * (1 + additive % boosts)
        uint256 epAmount = _amount + (_amount * (lockPower + nftPower)) / ONE;
        essenceTotalDeposits += _amount;
        totalEpToken += epAmount;

        user.originalDepositAmount = _amount;
        user.depositAmount = _amount;
        user.epAmount = epAmount;
        user.lockedUntil = block.timestamp + timelock;
        user.vestingLastUpdate = user.lockedUntil;

        /// amount of essence in debt to the user according to his Essence power
        /// It's like calculating a staker total rewards since block 0,
        /// but removing the rewards they already harvested or the rewards their were not eligibly to claim because they weren't staking yet.
        user.rewardDebt = ((epAmount * accEssencePerEpShare) / ONE).toInt256();
        user.lock = _lock;

        essence.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, depositId, _amount, _lock);
    }

    function withdrawPosition(uint256 _depositId, uint256 _amount) public virtual updateRewards returns (bool) {
        UserInfo storage user = userInfo[msg.sender][_depositId];
        uint256 depositAmount = user.depositAmount;
        if (depositAmount == 0) return false;

        if (_amount > depositAmount) {
            _amount = depositAmount;
        }

        // anyone can withdraw if kill swith was used
        if (!unlockAll) {
            require(block.timestamp >= user.lockedUntil, "Position is still locked");
            uint256 vestedAmount = _vestedPrincipal(msg.sender, _depositId);
            if (_amount > vestedAmount) {
                _amount = vestedAmount;
            }
        }

        // Effects

        /// @notice how this calculates the % of total deposited being withdrawn and reduces the same % in the user EP amount/total EP
        uint256 ratio = (_amount * ONE) / depositAmount;
        uint256 epAmount = (user.epAmount * ratio) / ONE;

        totalEpToken -= epAmount;
        essenceTotalDeposits -= _amount;

        user.depositAmount -= _amount;
        user.epAmount -= epAmount;

        /// reduces the debt to the user with the reduced EP amount
        /// It's interesting to note how no check is being made to the users' reward debt, could cause underflows?
        /// perhaps when a full withdraw is done this function could be improved
        user.rewardDebt -= ((epAmount * accEssencePerEpShare) / ONE).toInt256();

        // Interactions
        essence.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _depositId, _amount);

        return true;
    }

    function withdrawAll() public virtual {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            withdrawPosition(depositIds[i], type(uint256).max);
        }
    }

    function harvestPosition(uint256 _depositId) public virtual updateRewards {
        UserInfo storage user = userInfo[msg.sender][_depositId];

        uint256 _pendingEssence = 0;
        /// user current reward debt
        int256 rewardDebt = user.rewardDebt;

        /// user new reward debt based on new accEssencePerEpShare
        int256 newRewardDebt = ((user.epAmount * accEssencePerEpShare) / ONE).toInt256();

        if (newRewardDebt >= rewardDebt) {
            _pendingEssence = (newRewardDebt - rewardDebt).toUint256();
        }

        // Effects
        user.rewardDebt = newRewardDebt;

        if (user.depositAmount == 0 && user.epAmount == 0) {
            _removeDeposit(msg.sender, _depositId);
        }

        // Interactions
        if (_pendingEssence != 0) {
            essence.safeTransfer(msg.sender, _pendingEssence);
        }

        emit Harvest(msg.sender, _depositId, _pendingEssence);

        require(essence.balanceOf(address(this)) >= essenceTotalDeposits, "Run on banks");
    }

    function harvestAll() public virtual {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            harvestPosition(depositIds[i]);
        }
    }

    function withdrawAndHarvestPosition(uint256 _depositId, uint256 _amount) public virtual {
        withdrawPosition(_depositId, _amount);
        harvestPosition(_depositId);
    }

    function withdrawAndHarvestAll() public virtual {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            withdrawAndHarvestPosition(depositIds[i], type(uint256).max);
        }
    }

    function stakeAbsorberRods(uint256 _tokenId, uint256 _amount) external virtual updateRewards {
        require(absorberRods != address(0), "Cannot stake AbsorberRods");
        require(_amount > 0, "Amount is 0");

        absorberRodsStaked[msg.sender][_tokenId] += _amount;
        absorberRodsStakedAmount[msg.sender] += _amount;

        require(absorberRodsStakedAmount[msg.sender] <= 20, "Max 20 absorberRods per wallet");

        uint256 power = getNftPower(absorberRods, _tokenId, _amount);
        powers[msg.sender] += power;

        _recalculateEpAmount(msg.sender);

        IERC1155Upgradeable(absorberRods).safeTransferFrom(msg.sender, address(this), _tokenId, _amount, bytes(""));

        emit Staked(absorberRods, _tokenId, _amount, powers[msg.sender]);
    }

    function unstakeAbsorberRods(uint256 _tokenId, uint256 _amount) external virtual updateRewards {
        require(absorberRods != address(0), "Cannot stake AbsorberRods");
        require(_amount > 0, "Amount is 0");
        require(absorberRodsStaked[msg.sender][_tokenId] >= _amount, "Withdraw amount too big");

        absorberRodsStaked[msg.sender][_tokenId] -= _amount;
        absorberRodsStakedAmount[msg.sender] -= _amount;

        uint256 power = getNftPower(absorberRods, _tokenId, _amount);
        powers[msg.sender] -= power;

        _recalculateEpAmount(msg.sender);

        IERC1155Upgradeable(absorberRods).safeTransferFrom(address(this), msg.sender, _tokenId, _amount, bytes(""));

        emit Unstaked(absorberRods, _tokenId, _amount, powers[msg.sender]);
    }

    /// This function could do a chainlink request to obtain the person's social score from off-chain
    /// The score enters in the power equation of the user to calculate new EP (_recalculateEPAmount)
    /// If the update is done in a pull fashion, it is up to the user to call the function whenever he
    /// sees a surplus in reward from doing it (frontend could compute cost of update).
    /// It could also be called whenever the user deposits/harvests/withdraws/stakesNFTs
    /// If done in push fashion, system has to provide an ordered array of user addresses and Ids to update the power
    /// and _recalculate the EP amount. This involves a lot of gas costs and storage updates, but in a rollup could be doable.
    function performanceBoost() external {}

    function stakeArtifact(uint256 _tokenId) external virtual updateRewards {
        require(artifact != address(0), "Cannot stake Artifact");
        require(artifactStaked[msg.sender].add(_tokenId), "NFT already staked");
        require(artifactStaked[msg.sender].length() <= 3, "Max 3 artifacts per wallet");

        /// if it is a top tier artifact (primal legendary) only one is allowed to be staked per wallet
        if (isArtifact1_1(_tokenId)) {
            require(!isArtifact1_1Staked[msg.sender], "Max 1 1/1 artifact per wallet");
            isArtifact1_1Staked[msg.sender] = true;
        }

        uint256 power = getNftPower(artifact, _tokenId, 1);
        powers[msg.sender] += power;

        /// could be reused to change a users' EP based on a changed player performance
        _recalculateEpAmount(msg.sender);

        IERC721Upgradeable(artifact).transferFrom(msg.sender, address(this), _tokenId);

        emit Staked(artifact, _tokenId, 1, powers[msg.sender]);
    }

    function unstakeArtifact(uint256 _tokenId) external virtual updateRewards {
        require(artifactStaked[msg.sender].remove(_tokenId), "NFT is not staked");

        if (isArtifact1_1(_tokenId)) {
            isArtifact1_1Staked[msg.sender] = false;
        }

        uint256 power = getNftPower(artifact, _tokenId, 1);
        powers[msg.sender] -= power;

        _recalculateEpAmount(msg.sender);

        IERC721Upgradeable(artifact).transferFrom(address(this), msg.sender, _tokenId);

        emit Unstaked(artifact, _tokenId, 1, powers[msg.sender]);
    }

    function isArtifact1_1(uint256 _tokenId) public view virtual returns (bool) {
        try IArtifactMetadataStore(artifactMetadataStore).metadataForArtifact(_tokenId) returns (
            IArtifactMetadataStore.ArtifactMetadata memory metadata
        ) {
            return
                metadata.artifactGeneration == IArtifactMetadataStore.ArtifactGeneration.PRIMAL &&
                metadata.artifactRarity == IArtifactMetadataStore.ArtifactRarity.LEGENDARY;
        } catch Error(
            string memory /*reason*/
        ) {
            return false;
        } catch Panic(uint256) {
            return false;
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            return false;
        }
    }

    function getNftPower(
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) public view virtual returns (uint256) {
        if (_nft == absorberRods) {
            return getAbsorberRodsPower(_amount);
        } else if (_nft == artifact) {
            try IArtifactMetadataStore(artifactMetadataStore).metadataForArtifact(_tokenId) returns (
                IArtifactMetadataStore.ArtifactMetadata memory metadata
            ) {
                return getArtifactPower(uint256(metadata.artifactGeneration), uint256(metadata.artifactRarity));
            } catch Error(
                string memory /*reason*/
            ) {
                return 0;
            } catch Panic(uint256) {
                return 0;
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                return 0;
            }
        }

        return 0;
    }

    /// @notice this function could be used to change the user Essence power if his performance in game changes
    function _recalculateEpAmount(address _user) internal virtual {
        uint256 nftPower = powers[_user];

        uint256[] memory depositIds = allUserDepositIds[_user].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            uint256 depositId = depositIds[i];
            UserInfo storage user = userInfo[_user][depositId];

            (uint256 lockPower, ) = getLockPower(user.lock);
            uint256 _amount = user.depositAmount;
            uint256 newEpAmount = _amount + (_amount * (lockPower + nftPower)) / ONE;
            uint256 oldEpAmount = user.epAmount;

            if (newEpAmount > oldEpAmount) {
                uint256 epDiff = newEpAmount - oldEpAmount;
                user.rewardDebt += ((epDiff * accEssencePerEpShare) / ONE).toInt256();
                totalEpToken += epDiff;
                user.epAmount += epDiff;
            } else if (newEpAmount < oldEpAmount) {
                uint256 epDiff = oldEpAmount - newEpAmount;
                user.rewardDebt -= ((epDiff * accEssencePerEpShare) / ONE).toInt256();
                totalEpToken -= epDiff;
                user.epAmount -= epDiff;
            }
        }
    }

    function addExcludedAddress(address _exclude) external virtual onlyRole(FACTION_ABSORBER_ADMIN_ROLE) updateRewards {
        require(excludedAddresses.add(_exclude), "Address already excluded");
    }

    function removeExcludedAddress(address _excluded)
        external
        virtual
        onlyRole(FACTION_ABSORBER_ADMIN_ROLE)
        updateRewards
    {
        require(excludedAddresses.remove(_excluded), "Address is not excluded");
    }

    function setUtilizationOverride(uint256 _utilizationOverride)
        external
        virtual
        onlyRole(FACTION_ABSORBER_ADMIN_ROLE)
        updateRewards
    {
        utilizationOverride = _utilizationOverride;
    }

    function setEssenceToken(address _essence) external virtual onlyRole(FACTION_ABSORBER_ADMIN_ROLE) {
        essence = IERC20Upgradeable(_essence);
    }

    function setAbsorberRods(address _absorberRods) external virtual onlyRole(FACTION_ABSORBER_ADMIN_ROLE) {
        absorberRods = _absorberRods;
    }

    function setArtifact(address _artifact) external virtual onlyRole(FACTION_ABSORBER_ADMIN_ROLE) {
        artifact = _artifact;
    }

    function setArtifactMetadataStore(address _artifactMetadataStore)
        external
        virtual
        onlyRole(FACTION_ABSORBER_ADMIN_ROLE)
    {
        artifactMetadataStore = _artifactMetadataStore;
    }

    function setArtifactPowerTable(uint256[][] memory _artifactPowerTable)
        external
        virtual
        onlyRole(FACTION_ABSORBER_ADMIN_ROLE)
    {
        artifactPowerTable = _artifactPowerTable;
    }

    /// @notice EMERGENCY ONLY
    function toggleUnlockAll() external virtual onlyRole(FACTION_ABSORBER_ADMIN_ROLE) updateRewards {
        unlockAll = unlockAll ? false : true;
    }

    function withdrawUndistributedRewards(address _to)
        external
        virtual
        onlyRole(FACTION_ABSORBER_ADMIN_ROLE)
        updateRewards
    {
        uint256 _totalUndistributedRewards = totalUndistributedRewards;
        totalUndistributedRewards = 0;

        essence.safeTransfer(_to, _totalUndistributedRewards);
        emit UndistributedRewardsWithdraw(_to, _totalUndistributedRewards);
    }

    function getAbsorberRodsPower(uint256 _amount) public pure virtual returns (uint256 power) {
        power = 10e15 * _amount;
    }

    function _vestedPrincipal(address _user, uint256 _depositId) internal virtual returns (uint256 amount) {
        amount = calcualteVestedPrincipal(_user, _depositId);
        UserInfo storage user = userInfo[_user][_depositId];
        user.vestingLastUpdate = block.timestamp;
    }

    function _addDeposit(address _user) internal virtual returns (UserInfo storage user, uint256 newDepositId) {
        // start depositId from 1
        newDepositId = ++currentId[_user];
        allUserDepositIds[_user].add(newDepositId);
        user = userInfo[_user][newDepositId];
    }

    function _removeDeposit(address _user, uint256 _depositId) internal virtual {
        require(allUserDepositIds[_user].remove(_depositId), "depositId !exists");
    }
}
