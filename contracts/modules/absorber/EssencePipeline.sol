// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IAbsorberFactory.sol";
import "./interfaces/IAbsorber.sol";
import "../interfaces/IEssenceField.sol";

import "./lib/Constant.sol";

/// TODO -> understand what the corruption is for
contract EssencePipeline is AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    struct RewardsBalance {
        uint256 unpaid;
        uint256 paid;
    }

    bytes32 public constant ESSENCE_PIPELINE_ADMIN = keccak256("ESSENCE_PIPELINE_ADMIN");

    /// @dev Essence token addr
    IERC20 public corruptionToken;
    IAbsorberFactory public absorberFactory;
    IEssenceField public essenceField;

    uint256 public lastRewardTimestamp;

    mapping(address => RewardsBalance) public rewardsBalance;

    uint256[][] public corruptionNegativeBoostMatrix;

    event RewardsPaid(address indexed stream, uint256 rewardsPaid, uint256 rewardsPaidInTotal);
    event CorruptionToken(IERC20 corruptionToken);
    event AbsorberFactory(IAbsorberFactory absorberFactory);
    event EssenceField(IEssenceField essenceField);
    event CorruptionNegativeBoostMatrix(uint256[][] _corruptionNegativeBoostMatrix);
    event AtlasMineBoost(uint256 atlasMineBoost);

    modifier runIfNeeded() {
        if (block.timestamp > lastRewardTimestamp) {
            lastRewardTimestamp = block.timestamp;
            _;
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(
        address _admin,
        IEssenceField _essenceField,
        IAbsorberFactory _absorberFactory,
        IERC20 _corruptionToken
    ) external initializer {
        __AccessControlEnumerable_init();

        _setRoleAdmin(ESSENCE_PIPELINE_ADMIN, ESSENCE_PIPELINE_ADMIN);
        _grantRole(ESSENCE_PIPELINE_ADMIN, _admin);

        essenceField = _essenceField;
        emit EssenceField(_essenceField);

        absorberFactory = _absorberFactory;
        emit AbsorberFactory(_absorberFactory);

        corruptionToken = _corruptionToken;
        emit CorruptionToken(_corruptionToken);

        corruptionNegativeBoostMatrix = [
            [600_000e18, 0.4e18],
            [500_000e18, 0.5e18],
            [400_000e18, 0.6e18],
            [300_000e18, 0.7e18],
            [200_000e18, 0.8e18],
            [100_000e18, 0.9e18]
        ];
        emit CorruptionNegativeBoostMatrix(corruptionNegativeBoostMatrix);
    }

    /// @dev Returns share in mining power for all absorbers. To get percentage of mining power
    ///      for given absorber do:
    ///      `absorberShare[i] / totalShare`, where `i` is index of absorber address in `allActiveAbsorbers`
    ///      array.
    /// @param _targetAbsorber optional parameter, you can safely use `address(0)`. If you are looking
    ///        for specific absorber, provide its address as param and `targetIndex` will return index
    ///        of absorber in question in `allActiveAbsorbers` array.
    /// @return allActiveAbsorbers array of all absorbers
    /// @return absorberShare share in mining power for each absorber in `allActiveAbsorbers` array
    /// @return totalShare sum of all shares
    /// @return targetIndex index of `_targetAbsorber` in `allActiveAbsorbers` array
    function getAbsorberShares(address _targetAbsorber)
        public
        view
        returns (
            address[] memory allActiveAbsorbers,
            uint256[] memory absorberShare,
            uint256 totalShare,
            uint256 targetIndex
        )
    {
        address[] memory absorbers = absorberFactory.getAllAbsorbers();
        uint256 len = absorbers.length;

        allActiveAbsorbers = new address[](len);
        absorberShare = new uint256[](len);

        for (uint256 i = 0; i < allActiveAbsorbers.length; i++) {
            allActiveAbsorbers[i] = absorbers[i];
            absorberShare[i] = getAbsorberEmissionsBoost(allActiveAbsorbers[i]);
            totalShare += absorberShare[i];

            if (allActiveAbsorbers[i] == _targetAbsorber) {
                targetIndex = i;
            }
        }
    }

    function getPendingRewards(address _absorber) public view returns (uint256) {
        uint256 pendingRewards = essenceField.getPendingRewards(address(this));

        (
            address[] memory allActiveAbsorbers,
            uint256[] memory absorberShare,
            uint256 totalShare,
            uint256 targetIndex
        ) = getAbsorberShares(_absorber);

        uint256 unpaidRewards = rewardsBalance[allActiveAbsorbers[targetIndex]].unpaid;
        return unpaidRewards + (pendingRewards * absorberShare[targetIndex]) / totalShare;
    }

    function getAbsorberEmissionsBoost(address _absorber) public view returns (uint256) {
        uint256 absorberTotalBoost = IAbsorber(_absorber).nftHandler().getAbsorberTotalBoost();
        uint256 utilBoost = getUtilizationBoost(_absorber);
        uint256 corruptionNegativeBoost = getCorruptionNegativeBoost(_absorber);

        return (((absorberTotalBoost * utilBoost) / Constant.ONE) * corruptionNegativeBoost) / Constant.ONE;
    }

    function getCorruptionNegativeBoost(address _absorber) public view returns (uint256 negBoost) {
        negBoost = Constant.ONE;

        uint256 balance = corruptionToken.balanceOf(_absorber);

        for (uint256 i = 0; i < corruptionNegativeBoostMatrix.length; i++) {
            uint256 balanceThreshold = corruptionNegativeBoostMatrix[i][0];

            if (balance > balanceThreshold) {
                negBoost = corruptionNegativeBoostMatrix[i][1];
                break;
            }
        }
    }

    /// @dev this is the old getRealEssenceReward
    function getUtilizationBoost(address _absorber) public view returns (uint256 utilBoost) {
        uint256 util = getUtilization(_absorber);

        if (util < 0.3e18) {
            // if utilization < 30%, no emissions
            utilBoost = 0;
        } else if (util < 0.4e18) {
            // if 30% < utilization < 40%, 50% emissions
            utilBoost = 0.5e18;
        } else if (util < 0.5e18) {
            // if 40% < utilization < 50%, 60% emissions
            utilBoost = 0.6e18;
        } else if (util < 0.6e18) {
            // if 50% < utilization < 60%, 70% emissions
            utilBoost = 0.7e18;
        } else if (util < 0.7e18) {
            // if 60% < utilization < 70%, 80% emissions
            utilBoost = 0.8e18;
        } else if (util < 0.8e18) {
            // if 70% < utilization < 80%, 90% emissions
            utilBoost = 0.9e18;
        } else {
            // 100% emissions above 80% utilization
            utilBoost = 1e18;
        }
    }

    function getUtilization(address _absorber) public view returns (uint256 util) {
        uint256 totalDepositCap = IAbsorber(_absorber).totalDepositCap();

        if (totalDepositCap != 0) {
            uint256 essenceTotalDeposits = IAbsorber(_absorber).essenceTotalDeposits();
            util = (essenceTotalDeposits * Constant.ONE) / totalDepositCap;
        }
    }

    function getCorruptionNegativeBoostMatrix() public view returns (uint256[][] memory) {
        return corruptionNegativeBoostMatrix;
    }

    function distributeRewards() public runIfNeeded {
        uint256 distributedRewards = essenceField.requestRewards();

        (address[] memory allActiveAbsorbers, uint256[] memory absorberShare, uint256 totalShare, ) = getAbsorberShares(
            address(0)
        );

        for (uint256 i = 0; i < absorberShare.length; i++) {
            rewardsBalance[allActiveAbsorbers[i]].unpaid += (distributedRewards * absorberShare[i]) / totalShare;
        }
    }

    /// @dev The essence field has a flow into the Essence Pipeline
    /// the essence pipeline receives the rewards when requestRewards is called by an absorber
    /// these rewards are then diverted to the apropriate absorber from where the call originated (msg.sender)
    function requestRewards() public returns (uint256 rewardsPaid) {
        distributeRewards();

        address absorber = msg.sender;

        rewardsPaid = rewardsBalance[absorber].unpaid;

        if (rewardsPaid == 0) {
            return 0;
        }

        rewardsBalance[absorber].unpaid = 0;
        rewardsBalance[absorber].paid += rewardsPaid;

        absorberFactory.essence().safeTransfer(absorber, rewardsPaid);
        emit RewardsPaid(absorber, rewardsPaid, rewardsBalance[absorber].paid);
    }

    // ADMIN
    function setAbsorberFactory(IAbsorberFactory _absorberFactory) external onlyRole(ESSENCE_PIPELINE_ADMIN) {
        absorberFactory = _absorberFactory;
        emit AbsorberFactory(_absorberFactory);
    }

    function setEssenceField(IEssenceField _essenceField) external onlyRole(ESSENCE_PIPELINE_ADMIN) {
        essenceField = _essenceField;
        emit EssenceField(_essenceField);
    }

    function setCorruptionNegativeBoostMatrix(uint256[][] memory _corruptionNegativeBoostMatrix)
        external
        onlyRole(ESSENCE_PIPELINE_ADMIN)
    {
        corruptionNegativeBoostMatrix = _corruptionNegativeBoostMatrix;
        emit CorruptionNegativeBoostMatrix(_corruptionNegativeBoostMatrix);
    }
}
