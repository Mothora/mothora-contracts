// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {Artifacts} from "./Artifacts.sol";

contract Arena is VRFConsumerBaseV2, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public arenaSessionsCounter;
    //===============Events================
    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);
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
    }

    // arena session id to arena data
    mapping(uint256 => ArenaData) internal arenaSessionData;

    // Reverse Mapping ± player => arena session id = 0 if in no session
    mapping(address => uint256) internal playerInSession;

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

    mapping(uint256 => address) randomIdToTerminator;

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

    struct ArenaSessionLocalVars {
        bool tempFrozenStatus;
        address player;
        uint256 playerNumber;
        uint256 arenaId;
        uint256 tempPlayerId;
        uint256 tempFaction;
        uint256[4] factionMembers;
    }

    /**
     * @dev Starts an arena session
     * @param players The addresses of players that will participate in the arena
     **/
    function startArenaSession(address[] memory players) external activeAccounts {
        ArenaSessionLocalVars memory vars;

        vars.playerNumber = players.length;

        require(vars.playerNumber < sessionMaxSize, "INVALID_SESSION_SIZE");

        arenaSessionsCounter.increment();

        vars.arenaId = arenaSessionsCounter.current();

        for (uint256 i = 0; i < vars.playerNumber; i = unsafeInc(i)) {
            vars.player = players[i];

            vars.tempPlayerId = mothoraGameContract.getPlayerId(vars.player);
            vars.tempFrozenStatus = mothoraGameContract.getPlayerStatus(vars.player);
            vars.tempFaction = mothoraGameContract.getPlayerFaction(vars.player);

            require(vars.tempPlayerId != 0 && !vars.tempFrozenStatus, "ACCOUNT_NOT_ACTIVE");
            // If a player is marked to be in a session already and is repeated, it will be flagged here as a duplicate
            require(playerInSession[vars.player] == 0, "PLAYER_IN_SESSION_OR_DUPLICATE");

            vars.factionMembers[vars.tempFaction] += 1;
            arenaSessionData[vars.arenaId].players.push(vars.player);
            playerInSession[vars.player] = vars.arenaId;
        }
        require(playerInSession[msg.sender] == vars.arenaId, "CREATOR_NOT_IN_SESSION");

        for (uint256 i = 1; i <= 3; i = unsafeInc(i)) {
            require(vars.factionMembers[i] > 0, "NOT_ENOUGH_FACTION_MEMBERS");
        }

        arenaSessionData[vars.arenaId].status = Status.INGAME;

        emit ArenaSessionCreated(vars.arenaId, msg.sender);
    }

    /**
     * @dev Finishes sessions that can be "terminated"
     * @dev This function could fetch off-chain information such as winning players through a chainlink adapter
     * @dev For the current purpose will only determine rewards randomly and give a guaranteed extra reward to the callee of this function
     * @param arenaId The id of the arena
     **/
    function terminateArenaSession(uint256 arenaId) external activeAccounts {
        require(playerInSession[msg.sender] == arenaId, "TERMINATOR_NOT_IN_SESSION");
        require(arenaSessionData[arenaId].status == Status.INGAME, "SESSION_NOT_INGAME");
        arenaSessionData[arenaId].status = Status.POSTGAME;

        uint256 playerNumber = arenaSessionData[arenaId].players.length;

        // TODO check for suficient link tokens
        uint256 s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(playerNumber)
        );
        randomIdToTerminator[s_requestId] = msg.sender;
        emit ArenaSessionPostgame(arenaId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        address terminator = randomIdToTerminator[requestId];

        uint256 arenaId = playerInSession[terminator];

        require(arenaId != 0, "SESSION_MUST_EXIST");
        require(arenaSessionData[arenaId].status == Status.POSTGAME, "SESSION_ALREADY_REWARDED");

        arenaSessionData[arenaId].status = Status.REWARDED;

        uint256 playerNumber = arenaSessionData[arenaId].players.length;
        uint256 artifactsToMint;
        uint256 random;
        address player;
        Artifacts artifactsContract = Artifacts(mothoraGameContract.getArtifacts());

        for (uint256 i = 0; i < playerNumber; i = unsafeInc(i)) {
            artifactsToMint = 0;
            player = arenaSessionData[arenaId].players[i];
            random = (randomWords[i] % 1000) + 1;

            if (player == terminator) {
                // give an extra artifact to the game terminator as an incentive
                artifactsToMint = 1;
            }
            if (random >= 800) {
                artifactsToMint += 4;
                artifactsContract.mintArtifacts(player, artifactsToMint);
            } else if (random < 800 && random >= 600) {
                artifactsToMint += 3;
                artifactsContract.mintArtifacts(player, artifactsToMint);
            } else if (random < 600 && random >= 400) {
                artifactsToMint += 2;
                artifactsContract.mintArtifacts(player, artifactsToMint);
            } else if (random < 400 && random >= 200) {
                artifactsToMint += 1;
                artifactsContract.mintArtifacts(player, artifactsToMint);
            } else if (random < 200) {
                artifactsContract.mintArtifacts(player, artifactsToMint);
            }
            // reset session for player to be able to join a new game
            playerInSession[player] = 0;
        }

        emit ArenaSessionRewarded(arenaId);
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /**
     * @dev Returns the address of the Mothora Game Hub Contract
     **/
    function getArenaSessionData(uint256 arenaId) public view returns (uint256 status, address[] memory players) {
        ArenaData memory tempData = arenaSessionData[arenaId];

        status = uint256(tempData.status);
        players = tempData.players;
    }

    /**
     * @dev Returns the id of the arena the player is in, 0 if not playing
     **/
    function getPlayerInSession(address player) public view returns (uint256 arenaId) {
        arenaId = playerInSession[player];
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
