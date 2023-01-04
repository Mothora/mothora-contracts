// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IEssenceField.sol";
import "./interfaces/IFlow.sol";

/// wallet controlled by trusted team members. Admin role aka ESSENCE_FIELD_CREATOR_ROLE, as initialized during init()
/// to msg.sender can:
/// • ESSENCE_FIELD_CREATOR_ROLE, as initialized during init() to msg.sender:
/// • Add or remove flows, by calling addFlow() and removeFlow(), respectively.
/// • Increasing an active flow's ratePerSecond and totalRewards, by calling fundFlow().
/// • Decrease an active flow's ratePerSecond and totalRewards, by calling defundFlow().
/// • Modify a flow's startTimestamp, lastRewardTimestamp, endTimestamp and indirectly ratePerSecond, by calling
///   updateFlowTime().
/// • Enable/Disable registered flow addresses as callbacks, by calling setCallback().
/// • Withdraw an arbitrary essence token amount to an arbitrary address, by calling withdrawEssence().
/// • Set the essence token address to an arbitrary address, by calling setEssenceToken().
contract EssenceField is IEssenceField, Initializable, AccessControlEnumerableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant PRECISION = 1e18;
    bytes32 public constant ESSENCE_FIELD_CREATOR_ROLE = keccak256("ESSENCE_FIELD_CREATOR_ROLE");

    IERC20Upgradeable public essence;

    /// @notice flow address => EssenceFlow
    mapping(address => EssenceFlow) public flowConfig;

    /// @notice flow ID => flow address
    EnumerableSetUpgradeable.AddressSet internal flows;

    /// @notice flow address => bool
    mapping(address => bool) public callbackRegistry;

    modifier flowExists(address _flow) {
        require(flows.contains(_flow), "Flow does not exist");
        _;
    }

    modifier flowActive(address _flow) {
        require(flowConfig[_flow].endTimestamp > block.timestamp, "Flow ended");
        _;
    }

    modifier callbackFlow(address _flow) {
        if (callbackRegistry[_flow]) IFlow(_flow).preRateUpdate();
        _;
        if (callbackRegistry[_flow]) IFlow(_flow).postRateUpdate();
    }

    event FlowAdded(address indexed flow, uint256 amount, uint256 startTimestamp, uint256 endTimestamp);
    event FlowTimeUpdated(address indexed flow, uint256 startTimestamp, uint256 endTimestamp);

    event FlowGrant(address indexed flow, address from, uint256 amount);
    event FlowFunded(address indexed flow, uint256 amount);
    event FlowDefunded(address indexed flow, uint256 amount);
    event FlowRemoved(address indexed flow);

    event RewardsPaid(address indexed flow, uint256 rewardsPaid, uint256 rewardsPaidInTotal);
    event Withdraw(address to, uint256 amount);
    event CallbackSet(address flow, bool value);

    function init(address _essence) external initializer {
        essence = IERC20Upgradeable(_essence);

        _setRoleAdmin(ESSENCE_FIELD_CREATOR_ROLE, ESSENCE_FIELD_CREATOR_ROLE);
        _grantRole(ESSENCE_FIELD_CREATOR_ROLE, msg.sender);

        __AccessControlEnumerable_init();
    }

    /// @notice how anyone can call this function but only flows that exist have amounts.
    function requestRewards() public virtual returns (uint256 rewardsPaid) {
        EssenceFlow storage flow = flowConfig[msg.sender];

        rewardsPaid = getPendingRewards(msg.sender);

        if (rewardsPaid == 0 || essence.balanceOf(address(this)) < rewardsPaid) {
            return 0;
        }

        flow.paid += rewardsPaid;
        flow.lastRewardTimestamp = block.timestamp;

        // this should never happen but better safe than sorry
        require(flow.paid <= flow.totalRewards, "Rewards overflow");

        essence.safeTransfer(msg.sender, rewardsPaid);
        emit RewardsPaid(msg.sender, rewardsPaid, flow.paid);
    }

    function grantTokenToFlow(address _flow, uint256 _amount)
        public
        virtual
        flowExists(_flow)
        flowActive(_flow)
        callbackFlow(_flow)
    {
        _fundFlow(_flow, _amount);

        essence.safeTransferFrom(msg.sender, address(this), _amount);
        emit FlowGrant(_flow, msg.sender, _amount);
    }

    function getFlows() external view virtual returns (address[] memory) {
        return flows.values();
    }

    function getFlowConfig(address _flow) external view virtual returns (EssenceFlow memory) {
        return flowConfig[_flow];
    }

    function getGlobalRatePerSecond() external view virtual returns (uint256 globalRatePerSecond) {
        uint256 len = flows.length();
        for (uint256 i = 0; i < len; i++) {
            globalRatePerSecond += getRatePerSecond(flows.at(i));
        }
    }

    function getRatePerSecond(address _flow) public view virtual returns (uint256 ratePerSecond) {
        EssenceFlow storage flow = flowConfig[_flow];

        if (flow.startTimestamp < block.timestamp && block.timestamp < flow.endTimestamp) {
            ratePerSecond = flow.ratePerSecond;
        }
    }

    function getPendingRewards(address _flow) public view virtual returns (uint256 pendingRewards) {
        EssenceFlow storage flow = flowConfig[_flow];

        uint256 paid = flow.paid;
        uint256 totalRewards = flow.totalRewards;
        uint256 lastRewardTimestamp = flow.lastRewardTimestamp;

        if (block.timestamp >= flow.endTimestamp) {
            // flow ended
            pendingRewards = totalRewards - paid;
        } else if (block.timestamp > lastRewardTimestamp) {
            // flow active
            uint256 secondsFromLastPull = block.timestamp - lastRewardTimestamp;
            pendingRewards = secondsFromLastPull * flow.ratePerSecond;

            // in case of rounding error, make sure that paid + pending rewards is never more than totalRewards
            if (paid + pendingRewards > totalRewards) {
                pendingRewards = totalRewards - paid;
            }
        }
    }

    function _fundFlow(address _flow, uint256 _amount) internal virtual {
        EssenceFlow storage flow = flowConfig[_flow];

        uint256 secondsToEnd = flow.endTimestamp - flow.lastRewardTimestamp;
        uint256 rewardsLeft = secondsToEnd * flow.ratePerSecond;
        flow.ratePerSecond = (rewardsLeft + _amount) / secondsToEnd;
        flow.totalRewards += _amount;
    }

    // ADMIN

    /// @param _flow address of the contract that gets rewards
    /// @param _totalRewards amount of ESSENCE that should be distributed in total
    /// @param _startTimestamp when ESSENCE flow should start
    /// @param _endTimestamp when ESSENCE flow should end
    /// @param _callback should callback be used (if you don't know, set false)
    function addFlow(
        address _flow,
        uint256 _totalRewards,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _callback
    ) external virtual onlyRole(ESSENCE_FIELD_CREATOR_ROLE) {
        require(_endTimestamp > _startTimestamp, "Rewards must last > 1 sec");
        require(!flows.contains(_flow), "Flow for address already exists");

        if (flows.add(_flow)) {
            flowConfig[_flow] = EssenceFlow({
                totalRewards: _totalRewards,
                startTimestamp: _startTimestamp,
                endTimestamp: _endTimestamp,
                lastRewardTimestamp: _startTimestamp,
                ratePerSecond: (_totalRewards * PRECISION) / (_endTimestamp - _startTimestamp) / PRECISION,
                paid: 0
            });
            emit FlowAdded(_flow, _totalRewards, _startTimestamp, _endTimestamp);

            setCallback(_flow, _callback);
        }
    }

    function fundFlow(address _flow, uint256 _amount)
        external
        virtual
        onlyRole(ESSENCE_FIELD_CREATOR_ROLE)
        flowExists(_flow)
        flowActive(_flow)
        callbackFlow(_flow)
    {
        _fundFlow(_flow, _amount);
        emit FlowFunded(_flow, _amount);
    }

    function defundFlow(address _flow, uint256 _amount)
        external
        virtual
        onlyRole(ESSENCE_FIELD_CREATOR_ROLE)
        flowExists(_flow)
        flowActive(_flow)
        callbackFlow(_flow)
    {
        EssenceFlow storage flow = flowConfig[_flow];

        uint256 secondsToEnd = flow.endTimestamp - flow.lastRewardTimestamp;
        uint256 rewardsLeft = flow.totalRewards - flow.paid;

        require(_amount <= rewardsLeft, "Reduce amount too large, rewards already paid");

        flow.ratePerSecond = ((rewardsLeft - _amount) * PRECISION) / secondsToEnd / PRECISION;
        flow.totalRewards -= _amount;

        emit FlowDefunded(_flow, _amount);
    }

    function updateFlowTime(
        address _flow,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external virtual onlyRole(ESSENCE_FIELD_CREATOR_ROLE) flowExists(_flow) callbackFlow(_flow) {
        EssenceFlow storage flow = flowConfig[_flow];

        if (_startTimestamp > 0) {
            require(_startTimestamp > block.timestamp, "startTimestamp cannot be in the past");

            flow.startTimestamp = _startTimestamp;
            flow.lastRewardTimestamp = _startTimestamp;
        }

        if (_endTimestamp > 0) {
            require(_endTimestamp > _startTimestamp, "Rewards must last > 1 sec");
            require(_endTimestamp > block.timestamp, "Cannot end rewards in the past");

            flow.endTimestamp = _endTimestamp;
        }

        flow.ratePerSecond =
            ((flow.totalRewards - flow.paid) * PRECISION) /
            (flow.endTimestamp - flow.lastRewardTimestamp) /
            PRECISION;

        emit FlowTimeUpdated(_flow, _startTimestamp, _endTimestamp);
    }

    function removeFlow(address _flow)
        external
        virtual
        onlyRole(ESSENCE_FIELD_CREATOR_ROLE)
        flowExists(_flow)
        callbackFlow(_flow)
    {
        if (flows.remove(_flow)) {
            delete flowConfig[_flow];
            emit FlowRemoved(_flow);
        }
    }

    function setCallback(address _flow, bool _value)
        public
        virtual
        onlyRole(ESSENCE_FIELD_CREATOR_ROLE)
        flowExists(_flow)
        callbackFlow(_flow)
    {
        callbackRegistry[_flow] = _value;
        emit CallbackSet(_flow, _value);
    }

    function withdrawEssence(address _to, uint256 _amount) external virtual onlyRole(ESSENCE_FIELD_CREATOR_ROLE) {
        essence.safeTransfer(_to, _amount);
        emit Withdraw(_to, _amount);
    }

    function setEssenceToken(address _essence) external virtual onlyRole(ESSENCE_FIELD_CREATOR_ROLE) {
        essence = IERC20Upgradeable(_essence);
    }
}
