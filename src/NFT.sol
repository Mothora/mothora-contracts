// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/LibUtils.sol";

contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // _blueprint = SHA256 part of the IPFS CID (meaning without f01701220 prefix - see Readme)
    // Complete Base16 v1 CID = "f01701220c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a"
    // _blueprint = 01701220c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a
    // blueprint32 = c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a

    string internal constant BASE_URI = "ipfs://";

    string private constant CID_PREFIX = "f01701220";

    mapping(uint256 => string) private _metadata;

    constructor() ERC721("NFTStorage", "mothora") {}

    function awardItem(address player, string memory tokenURI) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function mint(bytes calldata _blueprint) external {
        require(balanceOf(msg.sender) < 1, "CANNOT_MINT_MORE_THAN_1");
        _tokenIds.increment();
        uint256 currentId = _tokenIds.current();

        uint256 blueprintOffset = _blueprint.length - 32;
        bytes32 blueprint32 = LibUtils.bytesToBytes32Left(_blueprint, blueprintOffset);
        string memory blueprintAsString = LibUtils.toHex(blueprint32);
        _metadata[currentId] = blueprintAsString;

        _mint(msg.sender, currentId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view override(ERC721Enumerable) returns (uint256) {
        return super.tokenOfOwnerByIndex(owner, index);
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

    function getPrefix() private pure returns (string memory) {
        return CID_PREFIX;
    }

    function getBase16CIDV1withPrefix(uint256 _tokenId) public view returns (string memory) {
        return string(abi.encodePacked(CID_PREFIX, _metadata[_tokenId]));
    }

    // For OpenSea to retrieve metadata
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        string memory baseUri = _baseURI();
        string memory coreCID = getBase16CIDV1withPrefix(tokenId);
        return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, coreCID)) : "";
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) external {
        _setTokenURI(tokenId, tokenURI);
    }

    // function setBaseURI(string memory _baseURI) external {
    //     BASE_URI = _baseURI;
    // }

    function _baseURI() internal pure override returns (string memory) {
        return BASE_URI;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
