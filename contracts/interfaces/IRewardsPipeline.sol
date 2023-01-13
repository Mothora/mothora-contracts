// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IRewardsPipeline {
    function requestRewards() external returns (uint256 rewardsPaid);

    function getPendingRewards(address _stream) external view returns (uint256 pendingRewards);
}
