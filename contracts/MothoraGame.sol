// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMothoraGame} from "./interfaces/IMothoraGame.sol";

contract MothoraGame is Initializable, IMothoraGame, AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    bytes32 public constant MOTHORA_GAME_MASTER = keccak256("MOTHORA_GAME_MASTER");

    address[] private accountAddresses;

    // Player address => uint256 packed (dao 8bits, frozen 8bits)
    mapping(address => uint256) private playerAccounts;

    // Bytes32 id => contract Address
    mapping(bytes32 => address) private gameProtocolAddresses;

    bytes32 private constant ARENA_MODULE = "ARENA_MODULE"; // Manages the postmatch results representation and reward distribution to players
    bytes32 private constant DAO_MODULE = "DAO_MODULE"; // DAO representation and staking module
    bytes32 private constant ESSENCE_MODULE = "ESSENCE_MODULE"; // Fungible non-tradeable in-game currency

    modifier activeAccounts() {
        _checkAccount();
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

    // TODO add signature mechanism that controls account creation
    function createAccount(uint256 dao) external override {
        (uint256 currentDAO, ) = getAccount(msg.sender);
        if (currentDAO != 0) revert PLAYER_ALREADY_HAS_DAO();
        if (dao == 0 || dao > 3) revert INVALID_DAO();

        _setAccount(msg.sender, dao, 0);

        accountAddresses.push(msg.sender);

        emit AccountCreated(msg.sender, dao);
    }

    function changeFreezeStatus(address player, bool freezeStatus) public override onlyRole(MOTHORA_GAME_MASTER) {
        (uint256 DAO, ) = getAccount(player);

        if (DAO == 0) revert ACCOUNT_DOES_NOT_EXIST();

        _setAccount(player, DAO, freezeStatus ? 1 : 0);

        emit AccountStatusChanged(player, freezeStatus);
    }

    // todo add mechanic to pay a variable fee to defect
    // payment is in
    function defect(uint256 newDAO) external override activeAccounts {
        if (newDAO == 0 || newDAO > 3) revert INVALID_DAO();
        (uint256 currentdao, ) = getAccount(msg.sender);

        if (newDAO == currentdao) revert CANNOT_DEFECT_TO_SAME_DAO();

        _setAccount(msg.sender, newDAO, 0);

        emit Defect(msg.sender, newDAO);
    }

    function getAccount(address _player) public view override returns (uint256 dao, bool frozen) {
        uint256 account = playerAccounts[_player];
        dao = uint256(uint8(account));
        frozen = uint256(uint8(account >> 8)) == 1 ? true : false;
    }

    function getAllPlayers() external view override returns (address[] memory) {
        return accountAddresses;
    }

    function getAllActivePlayersByDao(uint256 dao) external view override returns (address[] memory) {
        uint256 accountsNumber = accountAddresses.length;
        address[] memory playersByDao = new address[](accountsNumber);
        uint256 count = 0;

        for (uint256 i = 0; i < accountsNumber; ++i) {
            address account = accountAddresses[i];
            (uint256 currentdao, bool frozen) = getAccount(account);
            if (currentdao == dao && !frozen) {
                playersByDao[count] = account;
                unchecked {
                    count++;
                }
            }
        }
        if (count != accountsNumber) {
            //slither-disable-next-line assembly
            assembly {
                mstore(playersByDao, count)
            }
        }

        return playersByDao;
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

    function _setAccount(
        address _player,
        uint256 _dao,
        uint256 frozen
    ) internal {
        uint256 account = _dao;
        account |= frozen << 8;
        playerAccounts[_player] = account;
    }

    function _checkAccount() internal view {
        (uint256 DAO, bool frozen) = getAccount(msg.sender);

        if (DAO == 0 || frozen) revert ACCOUNT_NOT_ACTIVE();
    }
}
