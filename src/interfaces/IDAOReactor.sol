// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDAOReactor {
    /******************
    /  STRUCTS
    /******************/
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

    /******************
    /  EVENTS
    /******************/

    /**
     * @dev Emitted when `user` deposits `amount` of essence.
     * @param user The address of the user
     * @param index The index of the deposit
     * @param amount The amount of essence deposited
     */
    event Deposit(address indexed user, uint256 indexed index, uint256 amount);

    /**
     * @dev Emitted when rewards are updated
     * @param distributedRewards The amount of rewards distributed
     * @param sRepSupply The amount of sRep tokens in circulation
     * @param accRewardPerShare The accumulated reward per share
     */
    event LogUpdateRewards(uint256 distributedRewards, uint256 sRepSupply, uint256 accRewardPerShare);

    /**
     * @dev Emitted Reactor is enabled
     */
    event Enable();

    /**
     * @dev Emitted Reactor is disabled
     */
    event Disable();

    /******************
    /  ERRORS
    /******************/

    /**
     * @dev Error when the caller is not the factory
     */
    error OnlyFactory();

    /**
     * @dev Error when the deposit does not exist
     */
    error DepositDoesNotExists();

    /**
     * @dev Error when the contract is disabled
     */
    error Disabled();

    /******************
    /  FUNCTIONS
    /******************/

    /**
     * @dev Initiatlizes the contract
     * @param _admin The admin of the contract
     */
    function initialize(address _admin) external;

    /**
     * @dev Gets all user deposit ids
     * @param _user The user address
     */
    function getAllUserDepositIds(address _user) external view returns (uint256[] memory);

    /**
     * @dev Gets the number of user deposits
     * @param _user The user address
     */
    function getAllUserDepositIdsLength(address _user) external view returns (uint256);

    /**
     * @dev Gets the pending rewards for a user
     * @param _user The user address
     */
    function pendingRewardsAll(address _user) external view returns (uint256 pending);

    /**
     * @dev utility function to invoke updateRewards modifier
     */
    function callUpdateRewards() external returns (bool);

    /**
     * @dev Deposits essence into the DAO
     * @param _amount The amount of essence to deposit
     */
    function deposit(uint256 _amount) external;

    /**
     * @dev Enables the contract
     */
    function enable() external;

    /**
     * @dev Disables the contract
     */
    function disable() external;

    /**
     * @dev Views total amount of deposited essence in the DAO Reactor
     */
    function essenceTotalDeposits() external view returns (uint256);

    /**
     * @dev Views thetotal amount of Srep tokens that exist in the DAO Reactor
     */
    function totalSRepToken() external view returns (uint256);
}
