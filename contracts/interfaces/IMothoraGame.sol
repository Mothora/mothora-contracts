// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMothoraGame {
    /**
     *  @notice The body of a request to create an Account
     *  @param targetAddress The target creator of an account
     *  @param dao The selected dao id
     *  @param validityStartTimestamp The unix timestamp after which the request is valid.
     *  @param validityEndTimestamp The unix timestamp after which the request expires.
     *  @param uid A unique identifier for the request.
     */
    struct NewAccountRequest {
        address targetAddress;
        uint256 dao;
        uint128 validityStartTimestamp;
        uint128 validityEndTimestamp;
        bytes32 uid;
    }

    /******************
    /  EVENTS
    /******************/
    /**
     * @dev Emitted when an account is created
     */
    event AccountCreated(address indexed player, uint256 dao);

    /**
     * @dev Emitted when an account is frozen or unfrozen
     */
    event AccountStatusChanged(address indexed player, bool freezeStatus);

    /**
     * @dev Emitted when a player defects to a new DAO
     */
    event Defect(address indexed player, uint256 newDAO);

    /**
     * @dev Emitted when a module is updated
     */
    event ModuleUpdated(bytes32 indexed id, address indexed module);

    /**
     * @dev Emitted when the defect fee is updated
     */
    event DefectFeeUpdated(uint256 indexed defectFee);

    /**
     * @dev Emitted when the collected fees are withdrawn
     */
    event FeesWithdrawn();

    /******************
    /  ERRORS
    /******************/

    /**
     * @dev If account id is null or account is frozen
     */
    error ACCOUNT_NOT_ACTIVE();

    /**
     * @dev If account id is null
     */
    error ACCOUNT_DOES_NOT_EXIST();

    /**
     * @dev If dao ID is invalid
     */
    error INVALID_DAO();

    /**
     * @dev If player is already in the same DAO that is trying to defect to
     */
    error CANNOT_DEFECT_TO_SAME_DAO();

    /**
     * @dev If player already has a DAO attributed
     */
    error PLAYER_ALREADY_HAS_DAO();

    /**
     * @dev If the defect fee is invalid
     */
    error INVALID_DEFECT_FEE();

    /**
     * @dev If the defect fee withdrawal fails
     */
    error ETH_TRANSFER_FAILED();

    /******************
    /  FUNCTIONS
    /******************/

    /**
     * @dev Creates an account for a player
     * @param _req       The struct with the data to create an account
     * @param _signature The signature to verify the request.
     */
    function createAccount(NewAccountRequest calldata _req, bytes calldata _signature) external;

    /**
     * @dev Freezes an account for a player
     * @param player The address of the player whose account is being frozen
     * @param freezeStatus Whether to freeze or unfreeze the account
     */
    function changeFreezeStatus(address player, bool freezeStatus) external;

    /**
     * @dev A player can defect from a specific DAO to another
     * @param newDAO The DAO to defect to
     */
    function defect(uint256 newDAO) external payable;

    /**
     * @dev Returns a player's DAO and freeze status
     * @param player The address of the player
     */
    function getAccount(address player) external view returns (uint256 dao, bool frozen);

    /**
     * @dev Returns all players
     * @return All player addresses
     */
    function getAllPlayers() external view returns (address[] memory);

    /**
     * @dev Returns all active players by dao
     * @param dao the dao to filter by
     * @return Frozen status
     */
    function getAllActivePlayersByDao(uint256 dao) external view returns (address[] memory);

    /**
     * @dev Returns a module by id
     * @return The address
     */
    function getModule(bytes32 id) external view returns (address);

    /**
     * @dev Updates a module by id
     * @param id The id of the address
     * @param module The new address
     */
    function setModule(bytes32 id, address module) external;

    /**
     * @dev Sets the defect fee
     * @param defectFee The defect fee
     */
    function setDefectFee(uint256 defectFee) external;

    /**
     * @dev Withdraws the collected fees
     */
    function withdrawCollectedFees() external;

    /**
     * @dev Verifies that an account creation request is signed by an account holding MOTHORA_GAME_MASTER (at the time of the function call).
     * @param _req       The struct with the data to create an account
     * @param _signature The signature to verify the request.
     */
    function verify(NewAccountRequest calldata _req, bytes calldata _signature) external view returns (bool, address);
}
