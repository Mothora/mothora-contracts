// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IEssenceField {
    struct EssenceFlow {
        uint256 totalRewards;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 lastRewardTimestamp;
        uint256 ratePerSecond;
        uint256 paid;
    }

    function requestRewards() external returns (uint256 rewardsPaid);

    function grantTokenToFlow(address _flow, uint256 _amount) external;

    function getFlows() external view returns (address[] memory);

    function getFlowConfig(address _flow) external view returns (EssenceFlow memory);

    function getGlobalRatePerSecond() external view returns (uint256 globalRatePerSecond);

    function getRatePerSecond(address _flow) external view returns (uint256 ratePerSecond);

    function getPendingRewards(address _flow) external view returns (uint256 pendingRewards);
}
