// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

interface IEssenceToken is IERC20, IERC20Permit {
    /**
     * @dev Tokens can only be minted addresses other than those with TRANSFER_GOVERNOR role
     */
    error MINT_TO_SELF();

    /**
     * @dev Transfer governor role required for action
     */
    error TRANSFER_GOVERNOR_REQUIRED();

    /**
     * @dev Pauser role required for action
     */
    error PAUSER_ROLE_REQUIRED();

    /**
     * @dev Mutex has already been unlocked
     */
    error ALREADY_UNPAUSED();

    /**
     * @dev Token cannot be transfered to Essence Token contract
     */
    error TRANSFER_TO_THIS();

    /**
     * @dev Token can only be transfered if contract is unpaused OR transfer is initiated by contract with ability to transfer
     */
    error TRANSFER_DISALLOWED();

    /**
     * @dev Unpauses all token transfers.
     */
    function allowTransfers() external;

    /**
     * @dev Players are minted essence when Performance is displayed in the game (winning matches, for e.g)
     * @dev Arena contract will typically be the one to call this function
     * @param account The owner of the tokens to burn
     * @param amount The amount of tokens to burn
     */
    function mint(address account, uint256 amount) external;
}
