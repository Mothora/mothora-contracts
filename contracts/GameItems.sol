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

    address public playerContractAddress;

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeif257x7rsniq477knwmrl7cx57zqu2jmo2tjm7re5mb4hlxrypjki.ipfs.dweb.link/{id}.json") {}

    constructor(string memory _initialfolder, address _playerContractAddress) ERC1155(string(abi.encodePacked(_initialfolder, "{id}.json"))) {
        setTokenUri(BLACKSOLDIER, string(abi.encodePacked(_initialfolder, "0", ".json")));
        setTokenUri(VAULTPARTS, string(abi.encodePacked(_initialfolder, "1", ".json")));
        playerContractAddress = _playerContractAddress;
    }

    modifier onlyPlayer() {
        require(msg.sender == playerContractAddress, "Not player contract address.");
        _;
    }

    function mintCharacter(address _recipient, uint256 _id) external onlyPlayer {
        require(_id != VAULTPARTS, "The Player cannot mint VaultParts on MintCharacter function.");
        // QUESTION require that _uris[].length>= id
        _mint(_recipient, _id, 1, "");
    }

    // TODO block the transfer of vault parts to any address except the MothoraVault.
    function mintVaultParts(address recipient, uint256 amount) external onlyPlayer {
        _mint(recipient, VAULTPARTS, amount, "");
    }

    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }
    
    function setTokenUri(uint256 tokenId, string memory NFTuri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice"); 
        _uris[tokenId] = NFTuri; 
    }

}