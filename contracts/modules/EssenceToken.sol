// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {IEssenceToken} from "../interfaces/IEssenceToken.sol";

contract EssenceToken is IEssenceToken, AccessControlEnumerable, ERC20Permit {
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

    function allowTransfers() external override {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert PAUSER_ROLE_REQUIRED();
        if (mutex == 2) revert ALREADY_UNPAUSED();

        mutex = 2;
    }

    function mint(address account, uint256 amount) external override {
        if (!hasRole(TRANSFER_GOVERNOR, _msgSender())) revert TRANSFER_GOVERNOR_REQUIRED();
        if (account == _msgSender()) revert MINT_TO_SELF();

        _mint(account, amount);
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
