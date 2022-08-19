// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {Cosmetics} from "./modules/Cosmetics.sol";

contract MothoraGame is Initializable, AccessControlEnumerableUpgradeable {
    using Counters for Counters.Counter;

    Counters.Counter public accountsCounter;

    enum Faction {
        NONE,
        THOROKS,
        CONGLOMERATE,
        DOC
    }
    uint256[4] public totalFactionMembers;

    struct Account {
        uint256 id;
        bool frozen;
        Faction faction;
    }
    bytes32 public constant MOTHORA_GAME_MASTER = keccak256("MOTHORA_GAME_MASTER");

    address[] private accountAddresses;

    // Player address => Struct Account
    mapping(address => Account) private playerAccounts;

    // Bytes32 id => contract Address
    mapping(bytes32 => address) private gameProtocolAddresses;

    bytes32 private constant ARENA = "ARENA";
    bytes32 private constant ARTIFACTS = "ARTIFACTS";
    bytes32 private constant COSMETICS = "COSMETICS";
    bytes32 private constant CRAFTING = "CRAFTING";
    bytes32 private constant ESSENCE = "ESSENCE";
    bytes32 private constant ESSENCE_FIELD = "ESSENCE_FIELD";
    bytes32 private constant ESSENCE_ABSORBER = "ESSENCE_ABSORBER";

    event AccountCreated(address indexed player, uint256 id);
    event AccountStatusChanged(address indexed player, bool freezeStatus);
    event ArenaModuleUpdated(address indexed arenaModule);
    event EssenceFieldUpdated(address indexed essenceField);
    event EssenceAbsorberUpdated(address indexed essenceAbsorber);
    event EssenceUpdated(address indexed essence);
    event CraftingModuleUpdated(address indexed craftingModule);
    event CosmeticsModuleUpdated(address indexed cosmetics);
    event ArtifactsModuleUpdated(address indexed artifacts);

    modifier activeAccounts() {
        uint256 id = getPlayerId(msg.sender);
        bool frozen = getPlayerStatus(msg.sender);
        require(id != 0 && !frozen, "ACCOUNT_NOT_ACTIVE");
        _;
    }

    function init() external initializer {
        _setRoleAdmin(MOTHORA_GAME_MASTER, MOTHORA_GAME_MASTER);
        _grantRole(MOTHORA_GAME_MASTER, msg.sender);
        __AccessControlEnumerable_init();
    }

    /**
     * @dev Creates an account for a player
     * @param faction The selected faction id
     **/
    function createAccount(uint256 faction) external {
        _joinFaction(faction);

        // currently using a contract id system
        // would be changed to Unreal Engine id system
        accountsCounter.increment();

        uint256 playerId = accountsCounter.current();
        playerAccounts[msg.sender].id = playerId;
        accountAddresses.push(msg.sender);

        _mintCharacterCosmeticSkin();

        emit AccountCreated(msg.sender, playerId);
    }

    /**
     * @dev Freezes an account for a player
     * @param player The address of the player whose account is being frozen
     * @param freezeStatus Whether to freeze or unfreeze the account
     **/
    function changeFreezeStatus(address player, bool freezeStatus) public onlyRole(MOTHORA_GAME_MASTER) {
        require(playerAccounts[player].id != 0, "ACCOUNT_DOES_NOT_EXIST");

        playerAccounts[player].frozen = freezeStatus;
        emit AccountStatusChanged(player, freezeStatus);
    }

    function defect(uint256 newFaction) external activeAccounts {
        require(newFaction == 1 || newFaction == 2 || newFaction == 3, "INVALID_FACTION_SELECTED");
        uint256 currentfaction = getPlayerFaction(msg.sender);
        require(newFaction != currentfaction, "CANNOT_DEFECT_TO_SAME_FACTION");

        totalFactionMembers[currentfaction] -= 1;

        if (newFaction == 1 && currentfaction != 1) {
            playerAccounts[msg.sender].faction = Faction.THOROKS;
            totalFactionMembers[1] += 1;
        } else if (newFaction == 2 && currentfaction != 2) {
            playerAccounts[msg.sender].faction = Faction.CONGLOMERATE;
            totalFactionMembers[2] += 1;
        } else if (newFaction == 3 && currentfaction != 3) {
            playerAccounts[msg.sender].faction = Faction.DOC;
            totalFactionMembers[3] += 1;
        }
        // TODO restake or unstake Artifacts according to what the player desires
    }

    /**
     * @dev Returns a player's id
     * @return Players'id
     */
    function getPlayerId(address player) public view returns (uint256) {
        return (playerAccounts[player].id);
    }

    /**
     * @dev Returns a player's faction
     * @return Faction code
     */
    function getPlayerFaction(address player) public view returns (uint256) {
        return (uint256(playerAccounts[player].faction));
    }

    /**
     * @dev Returns a player's status
     * @return Frozen status
     */
    function getPlayerStatus(address player) public view returns (bool) {
        return playerAccounts[player].frozen;
    }

    /**
     * @dev Returns all active players
     * @return Frozen status
     */
    function getAllActivePlayers() public view returns (address[] memory) {
        return accountAddresses;
    }

    /**
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(bytes32 id) public view returns (address) {
        return gameProtocolAddresses[id];
    }

    /**
     * @dev Returns the address of the ARENA
     * @return The ARENA address
     **/
    function getArena() public view returns (address) {
        return getAddress(ARENA);
    }

    /**
     * @dev Updates the address of the ARENA
     * @param arenaModule The new ARENA address
     **/
    function setArena(address arenaModule) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ARENA] = arenaModule;
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
    function setEssenceField(address essenceField) external onlyRole(MOTHORA_GAME_MASTER) {
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
    function setEssenceAbsorber(address essenceAbsorber) external onlyRole(MOTHORA_GAME_MASTER) {
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
     * @dev Returns the address of the CRAFTING
     * @return The CRAFTING address
     **/
    function getCrafting() public view returns (address) {
        return getAddress(CRAFTING);
    }

    /**
     * @dev Updates the address of the CRAFTING
     * @param crafting The new CRAFTING address
     **/
    function setCrafting(address crafting) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[CRAFTING] = crafting;
        emit CraftingModuleUpdated(crafting);
    }

    /**
     * @dev Returns the address of the COSMETICS
     * @return The COSMETICS address
     **/
    function getCosmetics() public view returns (address) {
        return getAddress(COSMETICS);
    }

    /**
     * @dev Updates the address of the COSMETICS
     * @param cosmetics The new COSMETICS address
     **/
    function setCosmetics(address cosmetics) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[COSMETICS] = cosmetics;
        emit CosmeticsModuleUpdated(cosmetics);
    }

    /**
     * @dev Returns the address of the ARTIFACTS
     * @return The ARTIFACTS address
     **/
    function getArtifacts() public view returns (address) {
        return getAddress(ARTIFACTS);
    }

    /**
     * @dev Updates the address of the ARTIFACTS
     * @param artifacts The new ARTIFACTS address
     **/
    function setArtifacts(address artifacts) external onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ARTIFACTS] = artifacts;
        emit ArtifactsModuleUpdated(artifacts);
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /**
     * @dev Assigns a faction id to an account
     **/
    function _joinFaction(uint256 faction) internal {
        require(playerAccounts[msg.sender].faction == Faction.NONE, "PLAYER_ALREADY_HAS_FACTION");
        require(faction == 1 || faction == 2 || faction == 3, "INVALID_FACTION");
        if (faction == 1) {
            playerAccounts[msg.sender].faction = Faction.THOROKS;
            totalFactionMembers[1] += 1;
        } else if (faction == 2) {
            playerAccounts[msg.sender].faction = Faction.CONGLOMERATE;
            totalFactionMembers[2] += 1;
        } else if (faction == 3) {
            playerAccounts[msg.sender].faction = Faction.DOC;
            totalFactionMembers[3] += 1;
        }
    }

    /**
     * @dev Mints a faction related cosmetic skin
     **/
    function _mintCharacterCosmeticSkin() internal {
        require(playerAccounts[msg.sender].faction != Faction.NONE, "PLAYER_HAS_NO_FACTION");
        uint256 faction = uint256(playerAccounts[msg.sender].faction);
        require(Cosmetics(getCosmetics()).balanceOf(msg.sender, faction) == 0, "ONLY_ONE_SKIN_PER_FACTION");
        Cosmetics(getCosmetics()).mintCharacter(msg.sender, faction);
    }
}
