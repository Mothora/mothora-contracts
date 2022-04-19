// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {CharacterNFT2} from "./CharacterNFT2.sol";
contract PlayerContract is CharacterNFT2 {
    //===============Storage===============

    //===============Events================

    //===============Variables=============


    struct Player {
        string faction;
        uint256 nrVaultParts;
        uint256 timelock;
        bool characterFullofRewards;
        bool playerHasMintedCharacter; // Placeholder - ideally we check wallet to see if NFT is there
        uint256 multiplier;
    }
    
    mapping (address => Player) players;


    //===============Functions=============


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

    function MintCharacter(uint _blueprintindex) external {
        require(keccak256(abi.encodePacked(players[msg.sender].faction)) != keccak256(abi.encodePacked("")), "This Player has no faction yet.");
        CharacterNFT2.mintNFT(_blueprintindex);
        players[msg.sender].playerHasMintedCharacter = true;
    }

    function GoOnQuest() external {
        require(players[msg.sender].playerHasMintedCharacter = true, "You need to mint a Character first.");
        require(players[msg.sender].timelock < block.timestamp, "The Player is already on a quest.");
        players[msg.sender].timelock = block.timestamp + 10 minutes;
        players[msg.sender].characterFullofRewards = true;
    }

    function ClaimQuestRewards() external {
        require(players[msg.sender].timelock < block.timestamp, "The Player is still on a quest.");
        require(players[msg.sender].characterFullofRewards = true, "The Player has to go on a quest first to claim its rewards.");

        uint random = pseudorandom();
        if (random >=800) {
            players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts + 5;
            players[msg.sender].multiplier = players[msg.sender].multiplier + 5;
        } else if (random <800 && random >=600) {
            players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts + 4;
            players[msg.sender].multiplier = players[msg.sender].multiplier + 4;
        } else if (random <600 && random >=400) {
            players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts + 3;
            players[msg.sender].multiplier = players[msg.sender].multiplier + 3;
        } else if (random <400 && random >=200) {
            players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts + 2;
            players[msg.sender].multiplier = players[msg.sender].multiplier + 2;
        } else if (random <200) {
            players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts + 1;
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