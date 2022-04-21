// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./lib/LibUtils.sol";
contract CharacterNFT2 is ERC721, Ownable {
    //===============Storage===============

    //===============Events================

    //===============Variables=============
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _NFTsAllowed;

    string internal constant BASE_URI = "ipfs://";
    string private constant CID_PREFIX = "f01701220";

    mapping(uint256 => string) private _metadata;

    bytes[] AllowedNFTids;

    //===============Functions=============
    constructor() ERC721("Characters", "CHAs") {}

    function addAllowedNFT(bytes calldata _blueprint) external onlyOwner {
        _NFTsAllowed.increment();
        AllowedNFTids[_NFTsAllowed.current()] = _blueprint;
    }

    function removeAllowedNFT(uint _blueprintindex) external onlyOwner {
        AllowedNFTids[_blueprintindex] = "";
    }

    function mintNFT(uint _blueprintindex) internal {
        _tokenIds.increment();
        uint256 currentId = _tokenIds.current();
        
        uint256 blueprintOffset = AllowedNFTids[_blueprintindex].length - 32;
        bytes32 blueprint32 = LibUtils.bytesToBytes32Left(AllowedNFTids[_blueprintindex], blueprintOffset);
        string memory blueprintAsString = LibUtils.toHex(blueprint32);
        _metadata[currentId] = blueprintAsString;

        _mint(msg.sender, currentId);
    }

    function updateNFTMetadata(uint256 _tokenId, bytes calldata _blueprint) external {
        uint256 blueprintOffset = _blueprint.length - 32;
        bytes32 blueprint32 = LibUtils.bytesToBytes32Left(_blueprint, blueprintOffset);
        string memory blueprintAsString = LibUtils.toHex(blueprint32);
        _metadata[_tokenId] = blueprintAsString;
    }

    function getNFTMetadata(uint256 tokenId) external view returns (string memory) {
        return (_metadata[tokenId]);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory baseUri = BASE_URI;
        string memory coreCID = string(abi.encodePacked(CID_PREFIX, _metadata[_tokenId]));
        return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, coreCID)) : "";
    }
}