// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract PlayerContract is ERC721 {
    //===============Storage===============

    //===============Events================

    //===============Variables=============

    struct Player {
        address playerAddress;
        string faction;
        uint256 nrVaultParts;
        uint256 CharacterTokenID;
    }

    //===============Functions=============
    constructor() ERC721("Characters", "CHAs") {}
}   