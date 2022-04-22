// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract GameItems is ERC1155, Ownable {

    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping (uint256 => string) private _uris;

    uint256 public constant BLACKSOLDIER = 0;
    uint256 public constant VAULTPARTS = 1;

    address immutable PlayerContract;

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeif257x7rsniq477knwmrl7cx57zqu2jmo2tjm7re5mb4hlxrypjki.ipfs.dweb.link/{id}.json") {}

    constructor(string memory _initialfolder, address _playerContract) ERC1155(string(abi.encodePacked(_initialfolder, "{id}.json"))) {
        setTokenUri(BLACKSOLDIER, string(abi.encodePacked(_initialfolder, "0", ".json")));
        setTokenUri(VAULTPARTS, string(abi.encodePacked(_initialfolder, "1", ".json")));
        PlayerContract = _playerContract;
    }

    modifier onlyPlayer() {
        require(msg.sender == PlayerContract, "Not player contract"); // == é para assertions
        _;
    }

    function mintCharacter(address recipient, uint256 id) external onlyPlayer {
        require(_id != 1, "The Player cannot mint VaultParts on MintCharacter function.");
        // require that _uris[].length>= id
        _mint(recipient, id, amount, "");
    }

    function mintVaultParts(address recipient, uint256 amount) external onlyPlayer {
        _mint(recipient, 1, amount, "");
    }

    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }
    
    function setTokenUri(uint256 tokenId, string memory NFTuri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice"); 
        _uris[tokenId] = NFTuri; 
    }

}