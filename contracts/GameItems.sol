// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameItems is ERC1155, Ownable {

    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping (uint256 => string) private _uris;

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeif257x7rsniq477knwmrl7cx57zqu2jmo2tjm7re5mb4hlxrypjki.ipfs.dweb.link/{id}.json") {}

    constructor() ERC1155("https://bafybeihul6zsmbzyrgmjth3ynkmchepyvyhcwecn2yxc57ppqgpvr35zsq.ipfs.dweb.link/{id}.json") {
    }

    function mint(uint256 id, uint256 amount) public {
        _mint(msg.sender, id, amount, "");
    }

    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }
    
    function setTokenUri(uint256 tokenId, string memory NFTuri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice"); 
        _uris[tokenId] = NFTuri; 
    }

}