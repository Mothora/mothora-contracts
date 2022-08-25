// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./EssenceFieldV1.sol";

contract EssenceField is EssenceFieldV1 {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    uint256 public constant PRECISION = 1e18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _fundFlow(address _flow, uint256 _amount) internal virtual override {
        EssenceFlow storage flow = flowConfig[_flow];

        uint256 secondsToEnd = flow.endTimestamp - flow.lastRewardTimestamp;
        uint256 rewardsLeft = secondsToEnd * flow.ratePerSecond;
        flow.ratePerSecond = ((rewardsLeft + _amount) * PRECISION) / secondsToEnd / PRECISION;
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
    ) external virtual override onlyRole(ESSENCE_FIELD_CREATOR_ROLE) {
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

    function defundFlow(address _flow, uint256 _amount)
        external
        virtual
        override
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
    ) external virtual override onlyRole(ESSENCE_FIELD_CREATOR_ROLE) flowExists(_flow) callbackFlow(_flow) {
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
}
