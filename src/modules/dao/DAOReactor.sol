// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {IDAOReactor} from "../../interfaces/IDAOReactor.sol";
import {IDAOReactorFactory} from "../../interfaces/IDAOReactorFactory.sol";
import {Constant} from "../../libraries/Constant.sol";

contract DAOReactor is IDAOReactor, Initializable, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    bytes32 public constant DAO_REACTOR_ADMIN = keccak256("DAO_REACTOR_ADMIN");

    IDAOReactorFactory public factory;

    bool public disabled;
    uint256 public totalRewardsEarned;
    uint256 public accRewardPerShare;
    uint256 public totalSRepToken;
    uint256 public essenceTotalDeposits;
    uint256 public constant sRepRatio = 1.8e18;

    /// @notice user => depositId => UserInfo
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;
    /// @notice user => GlobalUserDeposit
    mapping(address => GlobalUserDeposit) public getUserGlobalDeposit;
    /// @notice user => depositId[]
    mapping(address => EnumerableSet.UintSet) private allUserDepositIds;
    /// @notice user => deposit index
    mapping(address => uint256) public currentId;

    modifier updateRewards() {
        uint256 sRepSupply = totalSRepToken;
        if (sRepSupply > 0) {
            uint256 distributedRewards = factory.rewardsPipeline().requestRewards();
            if (distributedRewards > 0) {
                totalRewardsEarned += distributedRewards;
                accRewardPerShare += (distributedRewards * Constant.ONE) / sRepSupply;
                emit LogUpdateRewards(distributedRewards, sRepSupply, accRewardPerShare);
            }
        }

        _;
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

    function initialize(address _admin) external initializer {
        __AccessControlEnumerable_init();

        factory = IDAOReactorFactory(msg.sender);

        _setRoleAdmin(DAO_REACTOR_ADMIN, DAO_REACTOR_ADMIN);
        _grantRole(DAO_REACTOR_ADMIN, _admin);
    }

    /*///////////////////////////////////////////////////////////////
                    Get deposit and reward logic
    //////////////////////////////////////////////////////////////*/

    function getAllUserDepositIds(address _user) external view override returns (uint256[] memory) {
        return allUserDepositIds[_user].values();
    }

    function getAllUserDepositIdsLength(address _user) external view override returns (uint256) {
        return allUserDepositIds[_user].length();
    }

    function pendingRewardsAll(address _user) external view override returns (uint256 pending) {
        GlobalUserDeposit storage userGlobalDeposit = getUserGlobalDeposit[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        uint256 sRepSupply = totalSRepToken;

        if (sRepSupply > 0) {
            uint256 pendingRewards = factory.rewardsPipeline().getPendingRewards(address(this));
            _accRewardPerShare += (pendingRewards * Constant.ONE) / sRepSupply;
        }

        int256 rewardDebt = userGlobalDeposit.globalRewardDebt;
        int256 accumulatedRewards = ((userGlobalDeposit.globalSRepAmount * _accRewardPerShare) / Constant.ONE)
            .toInt256();

        if (accumulatedRewards >= rewardDebt) {
            pending = (accumulatedRewards - rewardDebt).toUint256();
        }
    }

    function callUpdateRewards() public override updateRewards returns (bool) {
        return true;
    }

    /*///////////////////////////////////////////////////////////////
                    Deposit logic
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 _amount) external override updateRewards whenEnabled {
        (UserInfo storage user, uint256 depositId) = _addDeposit(msg.sender);

        uint256 sRepAmount = _amount + (_amount * sRepRatio) / Constant.ONE;
        essenceTotalDeposits += _amount;

        user.originalDepositAmount = _amount;
        user.depositAmount = _amount;
        user.sRepAmount = sRepAmount;

        _recalculateGlobalSRep(msg.sender, _amount.toInt256(), sRepAmount.toInt256());

        factory.essence().safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, depositId, _amount);
    }

    /*///////////////////////////////////////////////////////////////
                    Management
    //////////////////////////////////////////////////////////////*/

    function enable() external onlyFactory {
        disabled = false;
        emit Enable();
    }

    function disable() external onlyFactory {
        disabled = true;
        emit Disable();
    }

    /*///////////////////////////////////////////////////////////////
                    Internal / Helper functions
    //////////////////////////////////////////////////////////////*/

    function _recalculateGlobalSRep(
        address _user,
        int256 _essenceAmount,
        int256 _sRepAmount
    ) internal returns (uint256 pendingRewards) {
        GlobalUserDeposit storage userGlobalDeposit = getUserGlobalDeposit[_user];
        uint256 newGlobalSRepAmount = (userGlobalDeposit.globalSRepAmount.toInt256() + _sRepAmount).toUint256();
        int256 globalSRepDiff = newGlobalSRepAmount.toInt256() - userGlobalDeposit.globalSRepAmount.toInt256();

        userGlobalDeposit.globalEssenceAmount = (userGlobalDeposit.globalEssenceAmount.toInt256() + _essenceAmount)
            .toUint256();
        userGlobalDeposit.globalSRepAmount = newGlobalSRepAmount;
        userGlobalDeposit.globalRewardDebt += (globalSRepDiff * accRewardPerShare.toInt256()) / Constant.ONE.toInt256();

        totalSRepToken = (totalSRepToken.toInt256() + globalSRepDiff).toUint256();

        int256 accumulatedRewards = ((newGlobalSRepAmount * accRewardPerShare) / Constant.ONE).toInt256();
        pendingRewards = (accumulatedRewards - userGlobalDeposit.globalRewardDebt).toUint256();
    }

    function _addDeposit(address _user) internal returns (UserInfo storage user, uint256 newDepositId) {
        // start depositId from 1
        newDepositId = ++currentId[_user];
        allUserDepositIds[_user].add(newDepositId);
        user = userInfo[_user][newDepositId];
    }
}
