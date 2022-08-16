// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./modules/GameItems.sol";

contract MothoraGame is Initializable, AccessControlEnumerableUpgradeable {
    using Counters for Counters.Counter;

    Counters.Counter public accountsCounter;

    enum Faction {
        NONE,
        VAHNU,
        CONGLOMERATE,
        DOC
    }
    uint256[4] public totalFactionMembers;

    struct Account {
        uint256 timelock;
        uint256 id;
        bool frozen;
        bool characterFullofRewards;
        Faction faction;
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
    bytes32 private constant GAME_ITEMS = "GAME_ITEMS";

    event AccountCreated(address indexed player, uint256 id);
    event AccountFrozen(address indexed player);
    event ArenaModuleUpdated(address indexed arenaModule);
    event EssenceFieldUpdated(address indexed essenceField);
    event EssenceAbsorberUpdated(address indexed essenceAbsorber);
    event EssenceUpdated(address indexed essence);
    event CraftingModuleUpdated(address indexed craftingModule);
    event GameItemsModuleUpdated(address indexed gameItems);

    function init() external initializer {
        _setRoleAdmin(MOTHORA_GAME_MASTER, MOTHORA_GAME_MASTER);
        _grantRole(MOTHORA_GAME_MASTER, msg.sender);
        __AccessControlEnumerable_init();
    }

    /**
     * @dev Creates an account for a player
     * @param player The address of the player whose account is being created
     **/
    function createAccount(address player, uint256 faction) external {
        require(playerAccounts[player].id == 0, "ACCOUNT_ALREADY_EXISTS");

        accountsCounter.increment();

        uint256 tempId = accountsCounter.current();
        playerAccounts[player].id = tempId;

        _joinFaction(faction);
        _mintCharacter();

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
     * @dev Returns a player's account
     * @return Returns an account's data ID/FACTION/TIMELOCK/ARENAISLOCKED/FROZEN/HASREWARDS
     */
    function getAccount(address player)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            bool
        )
    {
        bool arenaIsLocked = playerAccounts[player].timelock > block.timestamp ? true : false;

        return (
            playerAccounts[player].id,
            uint256(playerAccounts[player].faction),
            playerAccounts[player].timelock,
            arenaIsLocked,
            playerAccounts[player].frozen,
            playerAccounts[player].characterFullofRewards
        );
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
    function getArena() public view returns (address) {
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
    function getEssenceField() public view returns (address) {
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
    function getEssenceAbsorber() public view returns (address) {
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
    function getEssence() public view returns (address) {
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
    function getCrafting() public view returns (address) {
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

    /**
     * @dev Returns the address of the GAME_ITEMS
     * @return The GAME_ITEMS address
     **/
    function getGameItems() public view returns (address) {
        return getAddress(GAME_ITEMS);
    }

    /**
     * @dev Updates the address of the GAME_ITEMS
     * @param gameItems The new GAME_ITEMS address
     **/
    function setGameItems(address gameItems) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[GAME_ITEMS] = gameItems;
        emit GameItemsModuleUpdated(gameItems);
    }

    function _joinFaction(uint256 faction) internal {
        require(uint256(playerAccounts[msg.sender].faction) == 0, "This player already has a faction.");
        require(faction == 1 || faction == 2 || faction == 3, "Please select a valid faction.");
        if (faction == 1) {
            playerAccounts[msg.sender].faction = Faction.VAHNU;
            totalFactionMembers[1] += 1;
        } else if (faction == 2) {
            playerAccounts[msg.sender].faction = Faction.CONGLOMERATE;
            totalFactionMembers[2] += 1;
        } else if (faction == 3) {
            playerAccounts[msg.sender].faction = Faction.DOC;
            totalFactionMembers[3] += 1;
        }
    }

    function _mintCharacter() internal {
        require(playerAccounts[msg.sender].faction != Faction.NONE, "This Player has no faction yet.");
        uint256 faction = uint256(playerAccounts[msg.sender].faction);
        require(
            GameItems(getGameItems()).balanceOf(msg.sender, faction) == 0,
            "The Player can only mint 1 Character of each type."
        );
        GameItems(getGameItems()).mintCharacter(msg.sender, faction);
    }
}
