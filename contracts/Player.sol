// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {CharacterNFT2} from "./CharacterNFT2.sol";
contract PlayerContract is CharacterNFT2 {
    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping (address => Player) players;
    struct Player {
        string faction;
        uint256 nrVaultParts;
        bytes characterNFTData; //CharacterNFTId
    }
    
    //===============Functions=============

    function JoinFaction(string memory _faction) external {
        players[msg.sender].faction = _faction;
    }

    function Defect(string memory _newfaction) external {
        players[msg.sender].faction = _newfaction;
        players[msg.sender].nrVaultParts = 0;
    }

    function SelectCharacter(bytes memory _blueprint) external {
        CharacterNFT2.mintNFT(_blueprint);
        players[msg.sender].characterNFTData = tokenURI(CharacterNFT2._tokenIds.current());
    }


}   