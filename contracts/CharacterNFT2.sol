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

    string internal constant BASE_URI = "ipfs://";
    string private constant CID_PREFIX = "f01701220";

    mapping(uint256 => string) private _metadata;

    //===============Functions=============
    constructor() ERC721("Characters", "CHAs") {}

    function mintNFT(bytes calldata _blueprint) external onlyOwner {
        _tokenIds.increment();
        uint256 currentId = _tokenIds.current();
        
        uint256 blueprintOffset = _blueprint.length - 32;
        bytes32 blueprint32 = LibUtils.bytesToBytes32Left(_blueprint, blueprintOffset);
        string memory blueprintAsString = LibUtils.toHex(blueprint32);
        _metadata[currentId] = blueprintAsString;

        _mint(msg.sender, currentId);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory baseUri = BASE_URI;
        string memory coreCID = string(abi.encodePacked(CID_PREFIX, _metadata[_tokenId]));
        return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, coreCID)) : "";
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
}