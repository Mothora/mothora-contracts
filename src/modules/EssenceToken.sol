// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IEssenceToken} from "../interfaces/IEssenceToken.sol";
import {CoreErrors} from "../libraries/CoreErrors.sol";

contract EssenceToken is IEssenceToken, AccessControlEnumerable, EIP712, ERC20 {
    using ECDSA for bytes32;

    bytes32 private constant TYPEHASH =
        keccak256(
            "MintRequest(address minter,uint256 quantity,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );
    bytes32 public constant TRANSFER_GOVERNOR = keccak256("TRANSFER_GOVERNOR");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 private mutex = 1; // Used to prevent transfers; 1 = paused, 2 = unpaused

    /**
     * @dev Will mint 100 million tokens and transfer ownership to the owner (which should be the Essence Reactor)
     */
    constructor(address _arena) ERC20("Essence Token", "ESSENCE") EIP712("Essence Token", "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Arena and Essence Reactor are both transfer governors (can mint and burn)
        _setupRole(TRANSFER_GOVERNOR, _arena);

        /// @dev TODO set this role later in its own setter, perhaps the 3 Dao Reactors addresses directly
        /// _setupRole(TRANSFER_GOVERNOR, _daoReactorFactory);

        // Pauser will be the deployer of this contract (the Admin)
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /*///////////////////////////////////////////////////////////////
                    Mutex and mint logic
    //////////////////////////////////////////////////////////////*/

    function allowTransfers() external override {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert PAUSER_ROLE_REQUIRED();
        if (mutex == 2) revert ALREADY_UNPAUSED();

        mutex = 2;
    }

    function mint(MintRequest calldata _req, bytes calldata _signature) external override {
        _verifyRequest(_req, _signature);
        // todo - check if needed to save uuid to prevent replay
        // todo - validate user node from Arena.sol?
        _mint(_msgSender(), _req.quantity);
    }

    /*///////////////////////////////////////////////////////////////
                    Mint verification logic Management Logic
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies that a mint request is signed by an account holding TRANSFER_GOVERNOR (at the time of the function call).
    function verify(MintRequest calldata _req, bytes calldata _signature) public view override returns (bool, address) {
        address signer = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _req.minter,
                    _req.quantity,
                    _req.validityStartTimestamp,
                    _req.validityEndTimestamp,
                    _req.uid
                )
            )
        ).recover(_signature);
        return (hasRole(TRANSFER_GOVERNOR, signer), signer);
    }

    /// @dev Verifies that a mint request is valid.
    function _verifyRequest(MintRequest calldata _req, bytes calldata _signature) internal view returns (address) {
        (bool success, address signer) = verify(_req, _signature);
        if (!success) revert CoreErrors.INVALID_SIGNATURE();
        if (_req.validityStartTimestamp > block.timestamp || _req.validityEndTimestamp < block.timestamp)
            revert CoreErrors.REQUEST_EXPIRED();
        if (_req.minter == address(0)) revert CoreErrors.RECIPIENT_UNDEFINED();
        if (_req.quantity == 0) revert ZERO_QUANTITY();

        return signer;
    }

    /*///////////////////////////////////////////////////////////////
                        Hooks
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev See {ERC20-_beforeTokenTransfer}
     * Requirements: the contract must not be paused OR transfer must be initiated by owner
     * @param from The account that is sending the tokens
     * @param to The account that should receive the tokens
     * @param amount Amount of tokens that should be transferred
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (to == address(this)) revert TRANSFER_TO_THIS();

        // Token transfers are only possible if the contract is not paused
        // OR if triggered by an address with TRANSFER_GOVERNOR role
        if (mutex == 1 && !hasRole(TRANSFER_GOVERNOR, _msgSender())) revert TRANSFER_DISALLOWED();
    }
}
