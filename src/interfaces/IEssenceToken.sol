// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEssenceToken is IERC20 {
    /**
     *  @notice The body of a request to mint Essence
     *
     *  @param minter The minter of essence
     *  @param quantity The quantity of essence to mint
     *  @param validityStartTimestamp The unix timestamp after which the request is valid.
     *  @param validityEndTimestamp The unix timestamp after which the request expires.
     *  @param uid A unique identifier for the request.
     */
    struct MintRequest {
        address minter;
        uint256 quantity;
        uint128 validityStartTimestamp;
        uint128 validityEndTimestamp;
        bytes32 uid;
    }

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
     * @dev Essence tokens to mint is 0
     */
    error ZERO_QUANTITY();

    /**
     * @dev Unpauses all token transfers.
     */
    function allowTransfers() external;

    /**
     * @dev Players are minted Essence when Performance is displayed in the game (winning matches, for e.g)
     * @dev The backend will generate a signature which a player can take to reward himself with Essence
     * @param _req       The struct with the data to mint Essence
     * @param _signature The signature to verify the request.
     */
    function mint(MintRequest calldata _req, bytes calldata _signature) external;

    /**
     * @dev Verifies that a mint request is signed by an account holding TRANSFER_GOVERNOR (at the time of the function call).
     * @param _req       The struct with the data to mint Essence
     * @param _signature The signature to verify the request.
     */
    function verify(MintRequest calldata _req, bytes calldata _signature) external view returns (bool, address);
}
