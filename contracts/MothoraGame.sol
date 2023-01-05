// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMothoraGame} from "./interfaces/IMothoraGame.sol";

contract MothoraGame is Initializable, IMothoraGame, AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter public accountsCounter;

    // this can be optmized to a single bytes element
    uint256[4] public totalDAOMembers;

    bytes32 public constant MOTHORA_GAME_MASTER = keccak256("MOTHORA_GAME_MASTER");

    address[] private accountAddresses;

    // Player address => Struct Account
    mapping(address => Account) private playerAccounts;

    // Bytes32 id => contract Address
    mapping(bytes32 => address) private gameProtocolAddresses;

    bytes32 private constant ARENA_MODULE = "ARENA_MODULE"; // Manages the postmatch results representation and reward distribution to players
    bytes32 private constant DAO_MODULE = "DAO_MODULE"; // DAO representation and staking module
    bytes32 private constant ESSENCE_MODULE = "ESSENCE_MODULE"; // Fungible non-tradeable in-game currency

    modifier activeAccounts() {
        uint256 id = getPlayerId(msg.sender);
        bool frozen = getPlayerStatus(msg.sender);
        if (id == 0 || frozen) revert ACCOUNT_NOT_ACTIVE();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        _setRoleAdmin(MOTHORA_GAME_MASTER, MOTHORA_GAME_MASTER);
        _grantRole(MOTHORA_GAME_MASTER, msg.sender);
        __AccessControlEnumerable_init();
    }

    function _authorizeUpgrade(address) internal override onlyRole(MOTHORA_GAME_MASTER) {}

    function createAccount(uint256 dao) external override {
        _joinDAO(dao);

        // currently using a contract id system
        // Could be changed to an Unreal Engine id system? Check with Ivo
        accountsCounter.increment();

        uint256 playerId = accountsCounter.current();

        playerAccounts[msg.sender].id = playerId;
        accountAddresses.push(msg.sender);

        emit AccountCreated(msg.sender, playerId);
    }

    function changeFreezeStatus(address player, bool freezeStatus) public override onlyRole(MOTHORA_GAME_MASTER) {
        Account storage playerAccount = playerAccounts[player];
        if (playerAccount.id == 0) revert ACCOUNT_DOES_NOT_EXIST();

        playerAccounts[player].frozen = freezeStatus;
        emit AccountStatusChanged(player, freezeStatus);
    }

    function defect(uint256 newDAO) external override activeAccounts {
        if (newDAO == 0 || newDAO > 3) revert INVALID_DAO();
        uint256 currentdao = getPlayerDAO(msg.sender);
        if (newDAO == currentdao) revert CANNOT_DEFECT_TO_SAME_DAO();

        Account storage playerAccount = playerAccounts[msg.sender];

        totalDAOMembers[currentdao] -= 1;

        if (newDAO == 1 && currentdao != 1) {
            playerAccount.dao = DAO.SC;
            totalDAOMembers[1] += 1;
        } else if (newDAO == 2 && currentdao != 2) {
            playerAccount.dao = DAO.EH;
            totalDAOMembers[2] += 1;
        } else if (newDAO == 3 && currentdao != 3) {
            playerAccount.dao = DAO.TF;
            totalDAOMembers[3] += 1;
        }

        emit Defect(msg.sender, newDAO);
    }

    function getPlayerId(address player) public view override returns (uint256) {
        return (playerAccounts[player].id);
    }

    function getPlayerDAO(address player) public view override returns (uint256) {
        return (uint256(playerAccounts[player].dao));
    }

    function getPlayerStatus(address player) public view override returns (bool) {
        return playerAccounts[player].frozen;
    }

    function getAllActivePlayers() public view override returns (address[] memory) {
        return accountAddresses;
    }

    function getAddress(bytes32 id) public view override returns (address) {
        return gameProtocolAddresses[id];
    }

    function getArenaModule() public view override returns (address) {
        return getAddress(ARENA_MODULE);
    }

    function setArenaModule(address arenaModule) external override onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ARENA_MODULE] = arenaModule;
        emit ArenaModuleUpdated(arenaModule);
    }

    function getDAOModule() public view override returns (address) {
        return getAddress(DAO_MODULE);
    }

    function setDAOModule(address daoModule) external override onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[DAO_MODULE] = daoModule;
        emit DAOModuleUpdated(daoModule);
    }

    function getEssenceModule() public view override returns (address) {
        return getAddress(ESSENCE_MODULE);
    }

    function setEssenceModule(address essenceModule) external override onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolAddresses[ESSENCE_MODULE] = essenceModule;
        emit EssenceModuleUpdated(essenceModule);
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /**
     * @dev Assigns a dao id to an account
     **/
    function _joinDAO(uint256 dao) internal {
        Account storage playerAccount = playerAccounts[msg.sender];
        if (playerAccount.dao != DAO.NONE) revert PLAYER_ALREADY_HAS_DAO();
        if (dao == 0 || dao > 3) revert INVALID_DAO();

        if (dao == 1) {
            playerAccount.dao = DAO.SC;
            totalDAOMembers[1] += 1;
        } else if (dao == 2) {
            playerAccount.dao = DAO.EH;
            totalDAOMembers[2] += 1;
        } else if (dao == 3) {
            playerAccount.dao = DAO.TF;
            totalDAOMembers[3] += 1;
        }
    }
}
