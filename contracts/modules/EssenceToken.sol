// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {IEssenceToken} from "../interfaces/IEssenceToken.sol";

contract EssenceToken is IEssenceToken, AccessControlEnumerable, ERC20Permit {
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
    constructor(address _arena, address _essenceReactor)
        ERC20("Essence Token", "ESSENCE")
        ERC20Permit("Essence Token")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Arena and Essence Reactor are both transfer governors (can mint and burn)
        _setupRole(TRANSFER_GOVERNOR, _arena);
        _setupRole(TRANSFER_GOVERNOR, _essenceReactor);

        // Pauser will be the deployer of this contract (the Admin)
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /*///////////////////////////////////////////////////////////////
                        External functions
    //////////////////////////////////////////////////////////////*/

    function allowTransfers() external override {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert PAUSER_ROLE_REQUIRED();
        if (mutex == 2) revert ALREADY_UNPAUSED();

        mutex = 2;
    }

    function mint(MintRequest calldata _req, bytes calldata _signature) external override {
        _verifyRequest(_req, _signature);
        // todo - check if needed to save uuid to prevent replay
        _mint(_msgSender(), _req.quantity);
    }

    /*///////////////////////////////////////////////////////////////
                        Public functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies that a mint request is signed by an account holding TRANSFER_GOVERNOR (at the time of the function call).
    function verify(MintRequest calldata _req, bytes calldata _signature) public view override returns (bool, address) {
        address signer = _recoverAddress(_req, _signature);
        return (hasRole(TRANSFER_GOVERNOR, signer), signer);
    }

    /*///////////////////////////////////////////////////////////////
                        Internal functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies that a mint request is valid.
    function _verifyRequest(MintRequest calldata _req, bytes calldata _signature) internal view returns (address) {
        (bool success, address signer) = verify(_req, _signature);
        if (!success) revert INVALID_SIGNATURE();
        if (_req.validityStartTimestamp > block.timestamp || _req.validityEndTimestamp < block.timestamp)
            revert REQUEST_EXPIRED();
        if (_req.minter == address(0)) revert RECIPIENT_UNDEFINED();
        if (_req.quantity == 0) revert ZERO_QUANTITY();

        return signer;
    }

    /// @dev Returns the address of the signer of the mint request.
    function _recoverAddress(MintRequest calldata _req, bytes calldata _signature) internal view returns (address) {
        return _hashTypedDataV4(keccak256(_encodeRequest(_req))).recover(_signature);
    }

    /// @dev Resolves 'stack too deep' error in `recoverAddress`.
    function _encodeRequest(MintRequest calldata _req) internal pure returns (bytes memory) {
        return
            abi.encode(
                TYPEHASH,
                _req.minter,
                _req.quantity,
                _req.validityStartTimestamp,
                _req.validityEndTimestamp,
                _req.uid
            );
    }

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
