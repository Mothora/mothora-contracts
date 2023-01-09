// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {EssenceToken} from "./EssenceToken.sol";

contract Arena is Ownable {
    event ArenaSessionPostgame();
    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);

    MothoraGame mothoraGameContract;

    constructor(address mothoraGame) {
        mothoraGameContract = MothoraGame(mothoraGame);
        emit MothoraGameAddressUpdated(mothoraGame);
    }

    /**
     * @dev Ends a match by writting an onchain merkle tree proof. The emited event is used by the Mothora Game to allow the generation of signatures to mint essence
     * @param proof The end of the match proof to write on-chain
     * @param winners The addresses of the winners
     * @param rewardAmounts The reward amounts
     **/
    function postgame(
        bytes32 proof,
        address[] calldata winners,
        uint256[] calldata rewardAmounts
    ) public onlyOwner {
        // todo - do something here with the proof
        emit ArenaSessionPostgame();
    }

    /**
     * @dev Returns the address of the Mothora Game Hub Contract
     * @return The Mothora Game address
     **/
    function getMothoraGame() public view returns (address) {
        return address(mothoraGameContract);
    }

    /**
     * @dev Updates the address of the Mothora Game
     * @param mothoraGameContractAddress The new Mothora Game address
     **/
    function setMothoraGame(address mothoraGameContractAddress) external onlyOwner {
        mothoraGameContract = MothoraGame(mothoraGameContractAddress);
        emit MothoraGameAddressUpdated(mothoraGameContractAddress);
    }
}
