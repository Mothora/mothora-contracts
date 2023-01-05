// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMothoraGame {
    /******************
    /  EVENTS
    /******************/

    event AccountCreated(address indexed player, uint256 dao);
    event AccountStatusChanged(address indexed player, bool freezeStatus);
    event Defect(address indexed player, uint256 newDAO);
    event ArenaModuleUpdated(address indexed arenaModule);
    event DAOModuleUpdated(address indexed daoModule);
    event EssenceModuleUpdated(address indexed essenceModule);

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

    /******************
    /  FUNCTIONS
    /******************/

    /**
     * @dev Creates an account for a player
     * @param dao The selected dao id
     */
    function createAccount(uint256 dao) external;

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
    function defect(uint256 newDAO) external;

    /**
     * @dev Returns a player's DAO and freeze status
     * @param _player The address of the player
     */
    function getAccount(address _player) external view returns (uint256 dao, bool frozen);

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
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(bytes32 id) external view returns (address);

    /**
     * @dev Returns the address of the ARENA module
     * @return The ARENA address
     */
    function getArenaModule() external view returns (address);

    /**
     * @dev Updates the address of the ARENA module
     * @param arenaModule The new ARENA address
     */
    function setArenaModule(address arenaModule) external;

    /**
     * @dev Returns the address of the DAO Module
     * @return The DAO address
     */
    function getDAOModule() external view returns (address);

    /**
     * @dev Updates the address of the DAO module
     * @param daoModule The new DAO module address
     */
    function setDAOModule(address daoModule) external;

    /**
     * @dev Returns the address of the ESSENCE module
     * @return The ESSENCE address
     */
    function getEssenceModule() external view returns (address);

    /**
     * @dev Updates the address of the ESSENCE
     * @param essenceModule The new ESSENCE address
     */
    function setEssenceModule(address essenceModule) external;
}
