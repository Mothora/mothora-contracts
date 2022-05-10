// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import {GameItems} from "./GameItems.sol";

contract Player is Ownable {
    //===============Storage===============

    enum Faction {
        NONE,
        VAHNU,
        CONGLOMERATE,
        DOC
    }
    uint256[4] public totalFactionMembers;

    uint256 public random;

    struct PlayerData {
        bool characterFullofRewards;
        Faction faction;
        uint256 timelock;
    }

    mapping(address => PlayerData) players;

    GameItems gameItemsContract;

    //===============Functions=============

    function setGameItems(address _gameItemsAddress) external onlyOwner {
        gameItemsContract = GameItems(_gameItemsAddress);
    }

    function joinFaction(uint256 _faction) public {
        require(uint256(players[msg.sender].faction) == 0, "This player already has a faction.");
        require(_faction == 1 || _faction == 2 || _faction == 3, "Please select a valid faction.");
        if (_faction == 1) {
            players[msg.sender].faction = Faction.VAHNU;
            totalFactionMembers[1] += 1;
        } else if (_faction == 2) {
            players[msg.sender].faction = Faction.CONGLOMERATE;
            totalFactionMembers[2] += 1;
        } else if (_faction == 3) {
            players[msg.sender].faction = Faction.DOC;
            totalFactionMembers[3] += 1;
        }
    }

    function defect(uint256 _newFaction) external {
        require(_newFaction == 1 || _newFaction == 2 || _newFaction == 3, "Please select a valid faction.");
        uint256 currentfaction = getFaction(msg.sender);
        totalFactionMembers[currentfaction] -= 1;
        if (_newFaction == 1 && players[msg.sender].faction != Faction.VAHNU) {
            players[msg.sender].faction = Faction.VAHNU;
            totalFactionMembers[1] += 1;
        } else if (_newFaction == 2 && players[msg.sender].faction != Faction.CONGLOMERATE) {
            players[msg.sender].faction = Faction.CONGLOMERATE;
            totalFactionMembers[2] += 1;
        } else if (_newFaction == 3 && players[msg.sender].faction != Faction.DOC) {
            players[msg.sender].faction = Faction.DOC;
            totalFactionMembers[3] += 1;
        }
        // TODO burn all vault part NFTs this wallet has on it.
        // Joao: instead of burning they could be given away to their current faction
    }

    function mintCharacter() public {
        require(players[msg.sender].faction != Faction.NONE, "This Player has no faction yet.");
        require(
            gameItemsContract.balanceOf(msg.sender, getFaction(msg.sender)) == 0,
            "The Player can only mint 1 Character of each type."
        );
        gameItemsContract.mintCharacter(msg.sender, getFaction(msg.sender));
    }

    function joinAndMint(uint256 _faction) external {
        joinFaction(_faction);
        mintCharacter();
    }

    function goOnQuest() external {
        require(
            gameItemsContract.balanceOf(msg.sender, getFaction(msg.sender)) == 1,
            "The Player does not own a character of this faction."
        );
        require(players[msg.sender].timelock < block.timestamp, "The Player is already on a quest.");
        require(players[msg.sender].characterFullofRewards == false, "The Player has not claimed its rewards.");
        players[msg.sender].timelock = block.timestamp + 60;
        players[msg.sender].characterFullofRewards = true;
    }

    function claimQuestRewards() external {
        require(
            players[msg.sender].characterFullofRewards == true,
            "The Player has to go on a quest first to claim its rewards."
        );
        require(players[msg.sender].timelock < block.timestamp, "The Player is still on a quest.");

        // TODO: Careful -> block.difficulty probably not available on L2s
        random = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 1000;
        if (random >= 800) {
            gameItemsContract.mintVaultParts(msg.sender, 1);
        } else if (random < 800 && random >= 600) {
            gameItemsContract.mintVaultParts(msg.sender, 1);
        } else if (random < 600 && random >= 400) {
            gameItemsContract.mintVaultParts(msg.sender, 1);
        } else if (random < 400 && random >= 200) {
            gameItemsContract.mintVaultParts(msg.sender, 1);
        } else if (random < 200) {
            gameItemsContract.mintVaultParts(msg.sender, 1);
        }

        players[msg.sender].characterFullofRewards = false;
    }

    function getFaction(address _recipient) public view returns (uint256) {
        return uint256(players[_recipient].faction);
    }

    function getQuestIsLocked(address _recipient) external view returns (bool) {
        if (players[_recipient].timelock > block.timestamp) {
            return true;
        }
        return false;
    }
}
