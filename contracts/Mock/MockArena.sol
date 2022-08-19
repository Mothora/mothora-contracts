// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../modules/Arena.sol";

contract MockArena is Arena {
    constructor(uint64 subscriptionId, MothoraGame mothoraGame) Arena(subscriptionId, mothoraGame) {}

    function mockTerminateArenaSession(uint256 arenaId, uint256 requestId) external activeAccounts {
        require(playerInSession[msg.sender] == arenaId, "TERMINATOR_NOT_IN_SESSION");
        require(arenaSessionData[arenaId].status == Status.INGAME, "SESSION_NOT_INGAME");
        arenaSessionData[arenaId].status = Status.POSTGAME;

        randomIdToTerminator[requestId] = msg.sender;
        emit ArenaSessionPostgame(arenaId);
    }

    function mockRandomnessFulfillment(uint256 requestId, uint256[] memory randomWords) external {
        super.fulfillRandomWords(requestId, randomWords);
    }
}
