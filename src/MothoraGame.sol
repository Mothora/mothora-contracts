// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMothoraGame} from "./interfaces/IMothoraGame.sol";
import {CoreErrors} from "./libraries/CoreErrors.sol";

contract MothoraGame is
    Initializable,
    IMothoraGame,
    EIP712Upgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    bytes32 private constant TYPEHASH =
        keccak256(
            "NewAccountRequest(address targetAddress,uint256 dao,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );

    // RBAC
    bytes32 public constant MOTHORA_GAME_MASTER = keccak256("MOTHORA_GAME_MASTER");

    address[] private accountAddresses;

    /*
     * Player address => uint256 packed (dao 8bits, frozen 8bits)
     * Dao 1 - Shadow Council
     * Dao 2 - Eclipse Horizon
     * Dao 3 - The Federation
     *
     * DAO and frozen status are packed into one uint256 to save gas
     */
    mapping(address => uint256) private playerAccounts;

    // Bytes32 id => contract module address
    mapping(bytes32 => address) private gameProtocolModules;

    // Defect fee is 0 in the begining
    uint256 public defectFee;

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
        __EIP712_init("MothoraGame", "1");
        __AccessControlEnumerable_init();
        _setRoleAdmin(MOTHORA_GAME_MASTER, MOTHORA_GAME_MASTER);
        _grantRole(MOTHORA_GAME_MASTER, msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyRole(MOTHORA_GAME_MASTER) {}

    /*///////////////////////////////////////////////////////////////
                    Account Management Logic
    //////////////////////////////////////////////////////////////*/
    function createAccount(NewAccountRequest calldata _req, bytes calldata _signature) external override {
        (uint256 currentDAO, ) = getAccount(msg.sender);
        if (currentDAO != 0) revert PLAYER_ALREADY_HAS_DAO();
        _verifyRequest(_req, _signature);

        _setAccount(msg.sender, _req.dao, 0);

        accountAddresses.push(msg.sender);

        emit AccountCreated(msg.sender, _req.dao);
    }

    function changeFreezeStatus(address _player, bool _freezeStatus) public override onlyRole(MOTHORA_GAME_MASTER) {
        (uint256 DAO, ) = getAccount(_player);

        if (DAO == 0) revert ACCOUNT_DOES_NOT_EXIST();

        _setAccount(_player, DAO, _freezeStatus ? 1 : 0);

        emit AccountStatusChanged(_player, _freezeStatus);
    }

    function defect(uint256 _newDAO) external payable override activeAccounts {
        if (_newDAO == 0 || _newDAO > 3) revert INVALID_DAO();
        if (msg.value < defectFee) revert INVALID_DEFECT_FEE();

        (uint256 currentdao, ) = getAccount(msg.sender);

        if (_newDAO == currentdao) revert CANNOT_DEFECT_TO_SAME_DAO();

        _setAccount(msg.sender, _newDAO, 0);

        emit Defect(msg.sender, _newDAO);
    }

    function getAccount(address _player) public view override returns (uint256 dao, bool frozen) {
        uint256 account = playerAccounts[_player];
        dao = uint256(uint8(account));
        frozen = uint8(account >> 8) == 1 ? true : false;
    }

    function getAllPlayers() external view override returns (address[] memory) {
        return accountAddresses;
    }

    function getAllActivePlayersByDao(uint256 _dao) external view override returns (address[] memory) {
        uint256 accountsNumber = accountAddresses.length;
        address[] memory playersByDao = new address[](accountsNumber);
        uint256 count = 0;

        for (uint256 i = 0; i < accountsNumber; ++i) {
            address account = accountAddresses[i];
            (uint256 currentdao, bool frozen) = getAccount(account);
            if (currentdao == _dao && !frozen) {
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

    /*///////////////////////////////////////////////////////////////
                    Account creation verification logic
    //////////////////////////////////////////////////////////////*/

    function verify(NewAccountRequest calldata _req, bytes calldata _signature)
        public
        view
        override
        returns (bool, address)
    {
        address signer = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _req.targetAddress,
                    _req.dao,
                    _req.validityStartTimestamp,
                    _req.validityEndTimestamp,
                    _req.uid
                )
            )
        ).recover(_signature);
        return (hasRole(MOTHORA_GAME_MASTER, signer), signer);
    }

    /// @dev Verifies that a mint request is valid.
    function _verifyRequest(NewAccountRequest calldata _req, bytes calldata _signature)
        internal
        view
        returns (address)
    {
        (bool success, address signer) = verify(_req, _signature);
        if (!success) revert CoreErrors.INVALID_SIGNATURE();
        if (_req.validityStartTimestamp > block.timestamp || _req.validityEndTimestamp < block.timestamp)
            revert CoreErrors.REQUEST_EXPIRED();
        if (_req.targetAddress == address(0)) revert CoreErrors.RECIPIENT_UNDEFINED();
        if (_req.dao == 0 || _req.dao > 3) revert INVALID_DAO();

        return signer;
    }

    /*///////////////////////////////////////////////////////////////
                    Module Management Logic
    //////////////////////////////////////////////////////////////*/

    function getModule(bytes32 _id) public view override returns (address) {
        return gameProtocolModules[_id];
    }

    function setModule(bytes32 _id, address _module) external override onlyRole(MOTHORA_GAME_MASTER) {
        gameProtocolModules[_id] = _module;
        emit ModuleUpdated(_id, _module);
    }

    /*///////////////////////////////////////////////////////////////
                    Fee collection logic
    //////////////////////////////////////////////////////////////*/
    function setDefectFee(uint256 _defectFee) external override onlyRole(MOTHORA_GAME_MASTER) {
        defectFee = _defectFee;
        emit DefectFeeUpdated(_defectFee);
    }

    // TODO - add fee collector contract address logic?

    function withdrawCollectedFees() external override onlyRole(MOTHORA_GAME_MASTER) {
        //slither-disable-next-line arbitrary-send-eth
        (bool success, ) = msg.sender.call{value: address(this).balance}(new bytes(0));
        if (!success) revert ETH_TRANSFER_FAILED();

        emit FeesWithdrawn();
    }

    /*///////////////////////////////////////////////////////////////
                    Internal/ Helper functions
    //////////////////////////////////////////////////////////////*/
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
