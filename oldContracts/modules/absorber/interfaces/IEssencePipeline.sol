// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IEssencePipeline {
    function requestRewards() external returns (uint256 rewardsPaid);

    function getPendingRewards(address _stream) external view returns (uint256 pendingRewards);
}