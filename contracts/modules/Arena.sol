// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {EssenceToken} from "./EssenceToken.sol";

contract Arena is Ownable {
    event ArenaSessionPostgame();
    event RewardsDisbursed();
    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);

    MothoraGame mothoraGameContract;

    constructor(address mothoraGame) {
        mothoraGameContract = MothoraGame(mothoraGame);
        emit MothoraGameAddressUpdated(mothoraGame);
    }

    /**
     * @dev Ends a match by writting an onchain merkle tree proof and disbursing rewards to winners
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
        disburseRewards(winners, rewardAmounts);
        emit ArenaSessionPostgame();
    }

    /**
     * @dev Distributes rewards to the winners (general function)
     * @dev If this is not a good approach, then do a pull based mint (with signature (performed by the backend))
     * @param winners The addresses of the winners
     * @param rewardAmounts The reward amounts
     **/
    function disburseRewards(address[] calldata winners, uint256[] calldata rewardAmounts) public onlyOwner {
        // must take into account gas limits
        for (uint256 i; i < winners.length; ++i) {
            EssenceToken(mothoraGameContract.getEssenceModule()).mint(winners[i], rewardAmounts[i]);
        }
        emit RewardsDisbursed();
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
