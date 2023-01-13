// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IDAOReactor {
    struct UserInfo {
        uint256 originalDepositAmount;
        uint256 depositAmount;
        uint256 sRepAmount;
    }

    struct GlobalUserDeposit {
        uint256 globalEssenceAmount;
        uint256 globalSRepAmount;
        int256 globalRewardDebt;
    }

    function init(address _admin) external;

    function disabled() external view returns (bool);

    function enable() external;

    function disable() external;

    function callUpdateRewards() external returns (bool);

    function essenceTotalDeposits() external view returns (uint256);

    function totalSRepToken() external view returns (uint256);
}
