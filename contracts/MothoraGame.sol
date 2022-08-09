// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MothoraGame is Initializable, AccessControlEnumerableUpgradeable {
    using Counters for Counters.Counter;

    Counters.Counter public accountsCounter;

    struct Account {
        uint256 id;
        bool frozen;
    }
    bytes32 public constant MOTHORA_GAME_MASTER = keccak256("MOTHORA_GAME_MASTER");

    // address => Account
    mapping(address => Account) private playerAccounts;

    mapping(bytes32 => address) private gameProtocolAddresses;

    bytes32 private constant ARENA_MODULE = "ARENA_MODULE";
    bytes32 private constant ESSENCE_FIELD = "ESSENCE_FIELD";
    bytes32 private constant ESSENCE_ABSORBER = "ESSENCE_ABSORBER";
    bytes32 private constant ESSENCE = "ESSENCE";
    bytes32 private constant CRAFTING_MODULE = "CRAFTING_MODULE";

    event AccountCreated(address indexed player, uint256 id);
    event AccountFrozen(address indexed player);
    event ArenaModuleUpdated(address indexed arenaModule);
    event EssenceFieldUpdated(address indexed essenceField);
    event EssenceAbsorberUpdated(address indexed essenceAbsorber);
    event EssenceUpdated(address indexed essence);
    event CraftingModuleUpdated(address indexed craftingModule);

    function init() external initializer {
        _setRoleAdmin(MOTHORA_GAME_MASTER, MOTHORA_GAME_MASTER);
        _grantRole(MOTHORA_GAME_MASTER, msg.sender);
        __AccessControlEnumerable_init();
    }

    /**
     * @dev Creates an account for a player
     * @param player The address of the player whose account is being created
     **/
    function createAccount(address player) external {
        require(playerAccounts[player].id == 0, "ACCOUNT_ALREADY_EXISTS");

        accountsCounter.increment();

        uint256 tempId = accountsCounter.current();
        playerAccounts[player].id = tempId;

        emit AccountCreated(player, tempId);
    }

    /**
     * @dev Freezes an account for a player
     * @param player The address of the player whose account is being frozen
     **/
    function freezeAccount(address player) public onlyRole(MOTHORA_GAME_MASTER) {
        require(playerAccounts[player].id != 0, "ACCOUNT_DOES_NOT_EXIST");
        require(!playerAccounts[player].frozen, "ACCOUNT_ALREADY_FROZEN");

        playerAccounts[player].frozen = true;
        emit AccountFrozen(player);
    }

    /**
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(bytes32 id) public view returns (address) {
        return gameProtocolAddresses[id];
    }

    /**
     * @dev Returns the address of the ARENA_MODULE
     * @return The ARENA_MODULE address
     **/
    function getArena() external view returns (address) {
        return getAddress(ARENA_MODULE);
    }

    /**
     * @dev Updates the address of the ARENA_MODULE
     * @param arenaModule The new ARENA_MODULE address
     **/
    function setArenaModuleAddress(address arenaModule) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ARENA_MODULE] = arenaModule;
        emit ArenaModuleUpdated(arenaModule);
    }

    /**
     * @dev Returns the address of the ESSENCE_FIELD
     * @return The ESSENCE_FIELD address
     **/
    function getEssenceField() external view returns (address) {
        return getAddress(ESSENCE_FIELD);
    }

    /**
     * @dev Updates the address of the ESSENCE_FIELD
     * @param essenceField The new ESSENCE_FIELD address
     **/
    function setEsssenceField(address essenceField) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ESSENCE_FIELD] = essenceField;
        emit EssenceFieldUpdated(essenceField);
    }

    /**
     * @dev Returns the address of the ESSENCE_ABSORBER
     * @return The ESSENCE_ABSORBER address
     **/
    function getEssenceAbsorber() external view returns (address) {
        return getAddress(ESSENCE_ABSORBER);
    }

    /**
     * @dev Updates the address of the ESSENCE_ABSORBER
     * @param essenceAbsorber The new ESSENCE_ABSORBER address
     **/
    function setEsssenceAbsorber(address essenceAbsorber) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ESSENCE_ABSORBER] = essenceAbsorber;
        emit EssenceAbsorberUpdated(essenceAbsorber);
    }

    /**
     * @dev Returns the address of the ESSENCE
     * @return The ESSENCE address
     **/
    function getEssence() external view returns (address) {
        return getAddress(ESSENCE);
    }

    /**
     * @dev Updates the address of the ESSENCE
     * @param essence The new ESSENCE address
     **/
    function setEssence(address essence) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ESSENCE] = essence;
        emit EssenceUpdated(essence);
    }

    /**
     * @dev Returns the address of the CRAFTING_MODULE
     * @return The CRAFTING_MODULE address
     **/
    function getCrafting() external view returns (address) {
        return getAddress(CRAFTING_MODULE);
    }

    /**
     * @dev Updates the address of the CRAFTING_MODULE
     * @param craftingModule The new CRAFTING_MODULE address
     **/
    function setCraftingModule(address craftingModule) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[CRAFTING_MODULE] = craftingModule;
        emit CraftingModuleUpdated(craftingModule);
    }
}
