// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract CharacterNFT is ERC721URIStorage, Ownable {
    //===============Storage===============

    //===============Events================

    //===============Variables=============
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _NFTsAllowed;

    string[] AllowedNFTs;

    //===============Functions=============
    constructor() ERC721("CharacterNFT", "NFT") {}

    function addAllowedNFT(string memory exampletokenURI) external onlyOwner {
        _NFTsAllowed.increment();
        AllowedNFTs[_NFTsAllowed.current()] = exampletokenURI;
    }

    function removeAllowedNFT(uint indexposition) external onlyOwner {
        AllowedNFTs[indexposition] = "";
    }

    function mintNFT(string memory exampletokenURI) internal returns (uint256) {
            _tokenIds.increment();

            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, exampletokenURI);

            return newItemId;
    }
}
