// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./INftHandler.sol";

interface IAbsorber {
    struct UserInfo {
        uint256 originalDepositAmount;
        uint256 depositAmount;
        uint256 lockEpAmount;
        uint256 lockedUntil;
        uint256 lock;
    }

    struct CapConfig {
        address parts;
        uint256 partsTokenId;
        uint256 capPerPart;
    }

    struct GlobalUserDeposit {
        uint256 globalDepositAmount;
        uint256 globalLockEpAmount;
        uint256 globalEpAmount;
        int256 globalRewardDebt;
    }

    struct Timelock {
        uint256 power;
        uint256 timelock;
        uint256 vesting;
        bool enabled;
    }

    function init(
        address _admin,
        INftHandler _nftHandler,
        CapConfig memory _depositCapPerWallet
    ) external;

    function disabled() external view returns (bool);

    function enable() external;

    function disable() external;

    function callUpdateRewards() external returns (bool);

    function isUserExceedingDepositCap(address _user) external view returns (bool);

    function updateNftPower(address user) external returns (bool);

    function nftHandler() external view returns (INftHandler);

    function essenceTotalDeposits() external view returns (uint256);

    function totalDepositCap() external view returns (uint256);
}
