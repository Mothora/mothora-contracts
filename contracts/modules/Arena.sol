// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {GameItems} from "./GameItems.sol";

contract Arena is VRFConsumerBaseV2, Ownable {
    //===============Storage===============

    struct PlayerData {
        bool characterFullofRewards;
        uint256 timelock;
    }

    mapping(address => PlayerData) players;

    GameItems gameItemsContract;

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

    // Retrieve 1 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 maxValues = 2;

    address s_owner;

    mapping(uint256 => address) randomIdToRequestor;

    //===============Functions=============
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        // Chainlink VRF
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function setGameItems(address _gameItemsAddress) external onlyOwner {
        gameItemsContract = GameItems(_gameItemsAddress);
    }

    function startArenaSession() external {}

    function endArenaSession() external {
        uint256 s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            maxValues
        );
        randomIdToRequestor[s_requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        address player = randomIdToRequestor[requestId];

        uint256 random = (randomWords[0] % 1000) + 1;
        players[player].characterFullofRewards = false;

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
    }

    function getQuestIsLocked(address _recipient) external view returns (bool) {
        if (players[_recipient].timelock > block.timestamp) {
            return true;
        }
        return false;
    }

    function getHasRewards(address _recipient) external view returns (bool) {
        return players[_recipient].characterFullofRewards;
    }
}
