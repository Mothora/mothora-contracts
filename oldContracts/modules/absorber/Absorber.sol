// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "./interfaces/INftHandler.sol";
import "./interfaces/IPartsStakingRules.sol";
import "./interfaces/IAbsorberFactory.sol";

contract Absorber is IAbsorber, Initializable, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    bytes32 public constant ABSORBER_ADMIN = keccak256("ABSORBER_ADMIN");

    uint256 public constant DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 public constant TWO_WEEKS = ONE_WEEK * 2;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant THREE_MONTHS = ONE_MONTH * 3;
    uint256 public constant SIX_MONTHS = ONE_MONTH * 6;
    uint256 public constant TWELVE_MONTHS = 365 days;
    uint256 public constant ONE = 1e18;

    IAbsorberFactory public factory;

    INftHandler public nftHandler;

    bool public unlockAll;
    bool public disabled;

    uint256 public totalRewardsEarned;
    uint256 public accEssencePerShare;
    uint256 public totalEpToken;
    uint256 public essenceTotalDeposits;

    /// @notice amount of ESSENCE that can be deposited
    uint256 public totalDepositCap;

    CapConfig public depositCapPerWallet;

    /// @notice user => depositId => UserInfo
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;
    /// @notice user => GlobalUserDeposit
    mapping(address => GlobalUserDeposit) public getUserGlobalDeposit;
    /// @notice user => depositId[]
    mapping(address => EnumerableSet.UintSet) private allUserDepositIds;
    /// @notice user => deposit index
    mapping(address => uint256) public currentId;
    /// @notice id => Timelock
    mapping(uint256 => Timelock) public timelockOptions;
    /// @notice set of timelockOptions IDs
    EnumerableSet.UintSet private timelockIds;

    event Deposit(address indexed user, uint256 indexed index, uint256 amount, uint256 lock);
    event Withdraw(address indexed user, uint256 indexed index, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event LogUpdateRewards(uint256 distributedRewards, uint256 epSupply, uint256 accEssencePerShare);
    event Enable();
    event Disable();
    event NftHandler(INftHandler nftHandler);
    event DepositCapPerWallet(CapConfig depositCapPerWallet);
    event TotalDepositCap(uint256 totalDepositCap);
    event UnlockAll(bool value);
    event TimelockOption(Timelock timelock, uint256 id);
    event TimelockOptionEnabled(Timelock timelock, uint256 id);
    event TimelockOptionDisabled(Timelock timelock, uint256 id);

    error MaxUserGlobalDeposit();
    error MaxTotalDeposit();
    error Disabled();
    error OnlyFactory();
    error InvalidValueOrDisabledTimelock();
    error ZeroAmount();
    error StillLocked();
    error AmountTooBig();
    error RunOnBank();
    error DepositDoesNotExists();

    modifier updateRewards() {
        uint256 epSupply = totalEpToken;
        if (epSupply > 0) {
            uint256 distributedRewards = factory.essencePipeline().requestRewards();
            if (distributedRewards > 0) {
                totalRewardsEarned += distributedRewards;
                accEssencePerShare += (distributedRewards * ONE) / epSupply;
                emit LogUpdateRewards(distributedRewards, epSupply, accEssencePerShare);
            }
        }

        _;
    }

    modifier checkDepositCaps() {
        _;

        if (isUserExceedingDepositCap(msg.sender)) {
            revert MaxUserGlobalDeposit();
        }

        if (essenceTotalDeposits > totalDepositCap) revert MaxTotalDeposit();
    }

    modifier whenEnabled() {
        if (disabled) revert Disabled();

        _;
    }

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert OnlyFactory();

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(
        address _admin,
        INftHandler _nftHandler,
        CapConfig memory _depositCapPerWallet
    ) external initializer {
        __AccessControlEnumerable_init();

        totalDepositCap = 10_000_000e18;
        emit TotalDepositCap(totalDepositCap);

        factory = IAbsorberFactory(msg.sender);

        _setRoleAdmin(ABSORBER_ADMIN, ABSORBER_ADMIN);
        _grantRole(ABSORBER_ADMIN, _admin);

        nftHandler = _nftHandler;
        emit NftHandler(_nftHandler);

        depositCapPerWallet = _depositCapPerWallet;
        emit DepositCapPerWallet(_depositCapPerWallet);

        // add default timelock
        _addTimelockOption(Timelock(0, 0, 0, true));
    }

    function getTimelockOptionsIds() external view returns (uint256[] memory) {
        return timelockIds.values();
    }

    function getUserPower(address _user) external view returns (uint256) {
        return nftHandler.getUserPower(_user);
    }

    function getDepositTotalPower(address _user, uint256 _depositId) external view returns (uint256) {
        (uint256 lockPower, ) = getLockPower(userInfo[_user][_depositId].lock);
        uint256 userNftPower = nftHandler.getUserPower(_user);
        // see: `_recalculateGlobalEp`.
        return ((ONE + lockPower) * (ONE + userNftPower)) / ONE;
    }

    function getNftPower(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) external view returns (uint256) {
        return nftHandler.getNftPower(_user, _nft, _tokenId, _amount);
    }

    function getAllUserDepositIds(address _user) external view returns (uint256[] memory) {
        return allUserDepositIds[_user].values();
    }

    function getAllUserDepositIdsLength(address _user) external view returns (uint256) {
        return allUserDepositIds[_user].length();
    }

    /// @notice Gets amount of ESSENCE that a single wallet can deposit
    function getUserDepositCap(address _user) public view returns (uint256 cap) {
        address stakingRules = address(
            nftHandler.getStakingRules(depositCapPerWallet.parts, depositCapPerWallet.partsTokenId)
        );

        if (stakingRules != address(0)) {
            uint256 amountStaked = IPartsStakingRules(stakingRules).getAmountStaked(_user);
            cap = amountStaked * depositCapPerWallet.capPerPart;
        }
    }

    function getLockPower(uint256 _timelockId) public view returns (uint256 power, uint256 timelock) {
        power = timelockOptions[_timelockId].power;
        timelock = timelockOptions[_timelockId].timelock;
    }

    function getVestingTime(uint256 _timelockId) public view returns (uint256 vestingTime) {
        vestingTime = timelockOptions[_timelockId].vesting;
    }

    function calculateVestedPrincipal(address _user, uint256 _depositId) public view returns (uint256 amount) {
        UserInfo storage user = userInfo[_user][_depositId];
        uint256 _timelockId = user.lock;
        uint256 originalDepositAmount = user.originalDepositAmount;

        uint256 vestingEnd = user.lockedUntil + getVestingTime(_timelockId);
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

    function isUserExceedingDepositCap(address _user) public view returns (bool) {
        return getUserGlobalDeposit[_user].globalDepositAmount > getUserDepositCap(_user);
    }

    function pendingRewardsAll(address _user) external view returns (uint256 pending) {
        GlobalUserDeposit storage userGlobalDeposit = getUserGlobalDeposit[_user];
        uint256 _accEssencePerShare = accEssencePerShare;
        uint256 epSupply = totalEpToken;

        if (epSupply > 0) {
            uint256 pendingRewards = factory.essencePipeline().getPendingRewards(address(this));
            _accEssencePerShare += (pendingRewards * ONE) / epSupply;
        }

        int256 rewardDebt = userGlobalDeposit.globalRewardDebt;
        int256 accumulatedEssence = ((userGlobalDeposit.globalEpAmount * _accEssencePerShare) / ONE).toInt256();

        if (accumulatedEssence >= rewardDebt) {
            pending = (accumulatedEssence - rewardDebt).toUint256();
        }
    }

    function getMaxWithdrawableAmount(address _user) public view returns (uint256 withdrawable) {
        uint256[] memory depositIds = allUserDepositIds[_user].values();

        for (uint256 i = 0; i < depositIds.length; i++) {
            uint256 depositId = depositIds[i];

            withdrawable += calculateVestedPrincipal(_user, depositId);
        }
    }

    /// @dev utility function to invoke updateRewards modifier
    function callUpdateRewards() public updateRewards returns (bool) {
        return true;
    }

    function updateNftPower(address _user) external updateRewards returns (bool) {
        _recalculateGlobalEp(_user, 0, 0);

        return true;
    }

    function enable() external onlyFactory {
        disabled = false;
        emit Enable();
    }

    function disable() external onlyFactory {
        disabled = true;
        emit Disable();
    }

    function deposit(uint256 _amount, uint256 _timelockId) external updateRewards checkDepositCaps whenEnabled {
        (UserInfo storage user, uint256 depositId) = _addDeposit(msg.sender);

        if (!timelockOptions[_timelockId].enabled) {
            revert InvalidValueOrDisabledTimelock();
        }

        (uint256 lockPower, uint256 timelock) = getLockPower(_timelockId);
        uint256 lockEpAmount = _amount + (_amount * lockPower) / ONE;
        essenceTotalDeposits += _amount;

        user.originalDepositAmount = _amount;
        user.depositAmount = _amount;
        user.lockEpAmount = lockEpAmount;
        user.lockedUntil = block.timestamp + timelock;
        user.lock = _timelockId;

        _recalculateGlobalEp(msg.sender, _amount.toInt256(), lockEpAmount.toInt256());

        factory.essence().safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, depositId, _amount, _timelockId);
    }

    function withdrawPosition(uint256 _depositId, uint256 _amount) public updateRewards returns (bool) {
        if (_amount == 0) revert ZeroAmount();

        UserInfo storage user = userInfo[msg.sender][_depositId];
        uint256 depositAmount = user.depositAmount;
        if (depositAmount == 0) return false;

        if (_amount > depositAmount) {
            _amount = depositAmount;
        }

        // anyone can withdraw if kill switch was used
        if (!unlockAll) {
            if (block.timestamp < user.lockedUntil) revert StillLocked();

            uint256 vestedAmount = calculateVestedPrincipal(msg.sender, _depositId);
            if (_amount > vestedAmount) {
                _amount = vestedAmount;
            }
        }

        // Effects
        uint256 ratio = (_amount * ONE) / depositAmount;
        uint256 lockEpAmount = (user.lockEpAmount * ratio) / ONE;

        essenceTotalDeposits -= _amount;

        user.depositAmount -= _amount;
        user.lockEpAmount -= lockEpAmount;

        int256 amountInt = _amount.toInt256();
        int256 lockEpAmountInt = lockEpAmount.toInt256();
        _recalculateGlobalEp(msg.sender, -amountInt, -lockEpAmountInt);

        if (user.depositAmount == 0 && user.lockEpAmount == 0) {
            _removeDeposit(msg.sender, _depositId);
        }

        // Interactions
        factory.essence().safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _depositId, _amount);

        return true;
    }

    function withdrawAmountFromAll(uint256 _amount) public {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();

        for (uint256 i = 0; i < depositIds.length; i++) {
            UserInfo storage user = userInfo[msg.sender][depositIds[i]];
            uint256 depositAmount = user.depositAmount;
            if (depositAmount == 0) continue;

            uint256 amountToWithdrawFromDeposit = _amount >= depositAmount ? depositAmount : _amount;

            _amount -= amountToWithdrawFromDeposit;

            withdrawPosition(depositIds[i], amountToWithdrawFromDeposit);

            if (_amount == 0) return;
        }

        if (_amount > 0) revert AmountTooBig();
    }

    function withdrawAll() public {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            withdrawPosition(depositIds[i], type(uint256).max);
        }
    }

    function harvestAll() public updateRewards {
        GlobalUserDeposit storage userGlobalDeposit = getUserGlobalDeposit[msg.sender];

        uint256 _pendingEssence = 0;
        int256 rewardDebt = userGlobalDeposit.globalRewardDebt;
        int256 accumulatedEssence = ((userGlobalDeposit.globalEpAmount * accEssencePerShare) / ONE).toInt256();

        if (accumulatedEssence >= rewardDebt) {
            _pendingEssence = (accumulatedEssence - rewardDebt).toUint256();
        }

        // Effects
        userGlobalDeposit.globalRewardDebt = accumulatedEssence;

        IERC20 essence = factory.essence();

        // Interactions
        if (_pendingEssence != 0) {
            essence.safeTransfer(msg.sender, _pendingEssence);
        }

        emit Harvest(msg.sender, _pendingEssence);

        if (essence.balanceOf(address(this)) < essenceTotalDeposits) revert RunOnBank();
    }

    function withdrawAndHarvestPosition(uint256 _depositId, uint256 _amount) public {
        harvestAll();
        withdrawPosition(_depositId, _amount);
    }

    function withdrawAndHarvestAll() public {
        harvestAll();
        withdrawAll();
    }

    function _recalculateGlobalEp(
        address _user,
        int256 _amount,
        int256 _lockEpAmount
    ) internal returns (uint256 pendingRewards) {
        GlobalUserDeposit storage userGlobalDeposit = getUserGlobalDeposit[_user];
        uint256 nftPower = nftHandler.getUserPower(_user);
        uint256 newGlobalLockEpAmount = (userGlobalDeposit.globalLockEpAmount.toInt256() + _lockEpAmount).toUint256();
        uint256 newGlobalEpAmount = newGlobalLockEpAmount + (newGlobalLockEpAmount * nftPower) / ONE;
        int256 globalEpDiff = newGlobalEpAmount.toInt256() - userGlobalDeposit.globalEpAmount.toInt256();

        userGlobalDeposit.globalDepositAmount = (userGlobalDeposit.globalDepositAmount.toInt256() + _amount)
            .toUint256();
        userGlobalDeposit.globalLockEpAmount = newGlobalLockEpAmount;
        userGlobalDeposit.globalEpAmount = newGlobalEpAmount;
        userGlobalDeposit.globalRewardDebt += (globalEpDiff * accEssencePerShare.toInt256()) / ONE.toInt256();

        totalEpToken = (totalEpToken.toInt256() + globalEpDiff).toUint256();

        int256 accumulatedEssence = ((newGlobalEpAmount * accEssencePerShare) / ONE).toInt256();
        pendingRewards = (accumulatedEssence - userGlobalDeposit.globalRewardDebt).toUint256();
    }

    function _addDeposit(address _user) internal returns (UserInfo storage user, uint256 newDepositId) {
        // start depositId from 1
        newDepositId = ++currentId[_user];
        allUserDepositIds[_user].add(newDepositId);
        user = userInfo[_user][newDepositId];
    }

    function _removeDeposit(address _user, uint256 _depositId) internal {
        if (!allUserDepositIds[_user].remove(_depositId)) revert DepositDoesNotExists();
    }

    // ADMIN

    function setNftHandler(INftHandler _nftHandler) external onlyRole(ABSORBER_ADMIN) {
        nftHandler = _nftHandler;
        emit NftHandler(_nftHandler);
    }

    function setDepositCapPerWallet(CapConfig memory _depositCapPerWallet) external onlyRole(ABSORBER_ADMIN) {
        depositCapPerWallet = _depositCapPerWallet;
        emit DepositCapPerWallet(_depositCapPerWallet);
    }

    function setTotalDepositCap(uint256 _totalDepositCap) external onlyRole(ABSORBER_ADMIN) {
        totalDepositCap = _totalDepositCap;
        emit TotalDepositCap(_totalDepositCap);
    }

    function addTimelockOption(Timelock memory _timelock) external onlyRole(ABSORBER_ADMIN) {
        _addTimelockOption(_timelock);
    }

    function enableTimelockOption(uint256 _id) external onlyRole(ABSORBER_ADMIN) {
        Timelock storage t = timelockOptions[_id];
        t.enabled = true;
        emit TimelockOptionEnabled(t, _id);
    }

    function disableTimelockOption(uint256 _id) external onlyRole(ABSORBER_ADMIN) {
        Timelock storage t = timelockOptions[_id];
        t.enabled = false;
        emit TimelockOptionDisabled(t, _id);
    }

    function _addTimelockOption(Timelock memory _timelock) internal {
        uint256 id = timelockIds.length();
        timelockIds.add(id);

        timelockOptions[id] = _timelock;
        emit TimelockOption(_timelock, id);
    }

    /// @notice EMERGENCY ONLY
    function setUnlockAll(bool _value) external onlyRole(ABSORBER_ADMIN) {
        unlockAll = _value;
        emit UnlockAll(_value);
    }
}