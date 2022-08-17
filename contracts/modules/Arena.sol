// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {GameItems} from "./GameItems.sol";

contract Arena is VRFConsumerBaseV2, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public arenaSessionsCounter;
    //===============Events================

    event ArenaSessionCreated(uint256 indexed arenaId, address indexed creator);
    event ArenaSessionPostgame(uint256 indexed arenaId);
    event ArenaSessionRewarded(uint256 indexed arenaId);

    //===============Storage===============
    //        bool arenaIsLocked = playerAccounts[player].timelock > block.timestamp ? true : false;

    enum Status {
        NONE,
        INGAME,
        POSTGAME,
        REWARDED
    }

    struct ArenaData {
        Status status;
        address[] players;
        address creator;
    }

    // arena session id to arena data
    mapping(uint256 => ArenaData) arenaSessionData;

    // Reverse Mapping ± player => arena session id = 0 if in no session
    mapping(address => uint256) playerInSession;

    MothoraGame mothoraGameContract;

    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint256 constant sessionMaxSize = 24;

    //===============Chainlink Storage===============
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    uint64 s_subscriptionId;
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 500000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    mapping(uint256 => uint256) randomIdToArena;

    modifier activeAccounts() {
        uint256 id = mothoraGameContract.getPlayerId(msg.sender);
        bool frozen = mothoraGameContract.getPlayerStatus(msg.sender);
        require(id != 0 && !frozen, "ACCOUNT_NOT_ACTIVE");
        _;
    }

    //===============Functions=============
    constructor(uint64 subscriptionId, MothoraGame mothoraGame) VRFConsumerBaseV2(vrfCoordinator) {
        // Chainlink VRF
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_subscriptionId = subscriptionId;
        mothoraGameContract = mothoraGame;
    }

    /**
     * @dev Starts an arena session
     * @param players The addresses of players that will participate in the arena
     **/
    function startArenaSession(address[] memory players) external activeAccounts {
        uint256 playerNumber = players.length;

        require(playerNumber < sessionMaxSize, "INVALID_SESSION_SIZE");

        arenaSessionsCounter.increment();

        uint256 arenaId = arenaSessionsCounter.current();
        uint256 tempPlayerId;
        uint256 tempFaction;
        bool tempFrozenStatus;
        address player;
        uint256[4] memory factionMembers;

        for (uint256 i = 1; i <= playerNumber; i = unsafeInc(i)) {
            player = players[i];
            tempPlayerId = mothoraGameContract.getPlayerId(player);
            tempFrozenStatus = mothoraGameContract.getPlayerStatus(player);
            tempFaction = mothoraGameContract.getPlayerFaction(player);
            factionMembers[tempFaction] += 1;

            require(tempPlayerId != 0 && !tempFrozenStatus, "ACCOUNT_NOT_ACTIVE");
            require(playerInSession[player] == 0, "PLAYER_IN_A_SESSION");

            arenaSessionData[arenaId].players.push(player);
            playerInSession[player] = arenaId;
        }

        for (uint256 i = 1; i <= 3; i = unsafeInc(i)) {
            require(factionMembers[i] > 0, "NOT_ENOUGH_FACTION_MEMBERS");
        }

        arenaSessionData[arenaId].status = Status.INGAME;
        arenaSessionData[arenaId].creator = msg.sender;

        emit ArenaSessionCreated(arenaId, msg.sender);
    }

    /**
     * @dev Finishes sessions that can be "ended"
     * @dev This function could fetch off-chain information such as winning players through a chainlink adapter
     * @dev It will only determine winners randomly and give a guaranteed reward to the callee of this function
     * @param arenaId The id of the arena
     **/
    function endArenaSession(uint256 arenaId) external {
        uint256 playerNumber = arenaSessionData[arenaId].players.length;

        // TODO check for suficient link tokens
        uint256 s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(playerNumber)
        );
        randomIdToArena[s_requestId] = arenaId;
        arenaSessionData[arenaId].status = Status.POSTGAME;
        emit ArenaSessionPostgame(arenaId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        uint256 arenaId = randomIdToArena[requestId];

        // we would need to request a number of random words equal to the number of players in this case

        uint256 playerNumber = arenaSessionData[arenaId].players.length;

        address player;

        GameItems gameItemsContract = GameItems(mothoraGameContract.getGameItems());

        //gameItemsContract.mintVaultParts(arenaSessionData[arenaId].creator, 5);

        for (uint256 i = 1; i <= playerNumber; i = unsafeInc(i)) {
            player = arenaSessionData[arenaId].players[i];

            uint256 random = (randomWords[i] % 1000) + 1;

            if (random >= 800) {
                gameItemsContract.mintVaultParts(player, 5);
            } else if (random < 800 && random >= 600) {
                gameItemsContract.mintVaultParts(player, 4);
            } else if (random < 600 && random >= 400) {
                gameItemsContract.mintVaultParts(player, 3);
            } else if (random < 400 && random >= 200) {
                gameItemsContract.mintVaultParts(player, 2);
            } else if (random < 200) {
                gameItemsContract.mintVaultParts(player, 1);
            }
            playerInSession[player] = 0;
        }
        arenaSessionData[arenaId].status = Status.REWARDED;

        emit ArenaSessionRewarded(arenaId);
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }
}
