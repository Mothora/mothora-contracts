// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import {GameItems} from "./GameItems.sol";
contract PlayerContract is Ownable {    
    //===============Storage===============

    //===============Events================

    //===============Variables=============


    struct Player {
        string faction;
        uint256 timelock;
        bool characterFullofRewards;
        uint256 multiplier;
    }
    
    mapping (address => Player) players;

    GameItems GameItemsContract;  

    //===============Functions=============

    function setGameItems(address _gameitemsaddress) external onlyOwner {
        GameItemsContract = GameItems(_gameitemsaddress);
    }

    function JoinFaction(string memory _faction) external {
        require(keccak256(abi.encodePacked(_faction)) == keccak256(abi.encodePacked("VAHNU"))|| keccak256(abi.encodePacked(_faction)) == keccak256(abi.encodePacked("CONGLOMERATE")) || keccak256(abi.encodePacked(_faction)) == keccak256(abi.encodePacked("DISCIPLESOFCHAOS")), "Please select a valid faction.");
        players[msg.sender].faction = _faction;
    }

    function Defect(string memory _newfaction) external {
        require(keccak256(abi.encodePacked(_newfaction)) == keccak256(abi.encodePacked("VAHNU"))|| keccak256(abi.encodePacked(_newfaction)) == keccak256(abi.encodePacked("CONGLOMERATE")) || keccak256(abi.encodePacked(_newfaction)) == keccak256(abi.encodePacked("DISCIPLESOFCHAOS")), "Please select a valid faction.");
        require(keccak256(abi.encodePacked(_newfaction)) != keccak256(abi.encodePacked(players[msg.sender].faction)), "The Player cannot defect to the same faction.");
        players[msg.sender].faction = _newfaction;
        players[msg.sender].nrVaultParts = 0;
        players[msg.sender].multiplier = 0;
    }

    function MintCharacter(uint256 _id) external {
        require(keccak256(abi.encodePacked(players[msg.sender].faction)) != keccak256(abi.encodePacked("")), "This Player has no faction yet.");
        require(GameItemsContract.balanceOf(msg.sender, _id) == 0, "The Player can only mint 1 Character of each type");
        GameItemsContract.mintCharacter(msg.sender,_id);
    }

    function GoOnQuest() external {
        require(players[msg.sender].playerHasMintedCharacter = true, "You need to mint a Character first.");
        require(players[msg.sender].timelock < block.timestamp, "The Player is already on a quest.");
        players[msg.sender].timelock = block.timestamp + 2 minutes;
        players[msg.sender].characterFullofRewards = true;
    }

    function ClaimQuestRewards() external {
        require(players[msg.sender].timelock < block.timestamp, "The Player is still on a quest.");
        require(players[msg.sender].characterFullofRewards = true, "The Player has to go on a quest first to claim its rewards.");

        uint random = pseudorandom();
        if (random >=800) {
            GameItemsContract.mintVaultParts(msg.sender,5);
            players[msg.sender].multiplier = players[msg.sender].multiplier + 5;
        } else if (random <800 && random >=600) {
            GameItemsContract.mintVaultParts(msg.sender,4);
            players[msg.sender].multiplier = players[msg.sender].multiplier + 4;
        } else if (random <600 && random >=400) {
            GameItemsContract.mintVaultParts(msg.sender,3);
            players[msg.sender].multiplier = players[msg.sender].multiplier + 3;
        } else if (random <400 && random >=200) {
            GameItemsContract.mintVaultParts(msg.sender,2);
            players[msg.sender].multiplier = players[msg.sender].multiplier + 2;
        } else if (random <200) {
            GameItemsContract.mintVaultParts(msg.sender,1);
            players[msg.sender].multiplier = players[msg.sender].multiplier + 1;
        }

        players[msg.sender].characterFullofRewards = false;
    
    }

    function pseudorandom() private view returns (uint) {
        uint randomHash = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        return randomHash % 1000;
    } 

    function getFaction() external view returns (string memory) {
        return players[msg.sender].faction;
    }

    function getMultiplier() external view returns (uint) {
        return players[msg.sender].multiplier;
    }
}   