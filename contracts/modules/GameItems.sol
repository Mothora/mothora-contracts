// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameItems is ERC1155, Ownable {
    //===============Storage===============

    mapping(uint256 => string) private _uris;

    uint256 public constant ARTIFACTS = 0;
    uint256 public constant THOROKS = 1;
    uint256 public constant CONGLOMERATE = 2;
    uint256 public constant DOC = 3;

    address public mothoraGameAddress;

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/{id}.json") {}

    constructor(string memory _initialFolder, address _mothoraGameAddress)
        ERC1155(string(abi.encodePacked(_initialFolder, "{id}.json")))
    {
        setTokenUri(ARTIFACTS, string(abi.encodePacked(_initialFolder, "0", ".json")));
        setTokenUri(THOROKS, string(abi.encodePacked(_initialFolder, "1", ".json")));
        setTokenUri(CONGLOMERATE, string(abi.encodePacked(_initialFolder, "2", ".json")));
        setTokenUri(DOC, string(abi.encodePacked(_initialFolder, "3", ".json")));
        mothoraGameAddress = _mothoraGameAddress;
    }

    modifier onlyMothoraGame() {
        require(msg.sender == mothoraGameAddress, "Not player contract address.");
        _;
    }

    function mintCharacter(address _recipient, uint256 _id) external onlyMothoraGame {
        require(_id == THOROKS || _id == CONGLOMERATE || _id == DOC, "ONLY_CHARACTERS_ALLOWED");
        _mint(_recipient, _id, 1, "");
    }

    function mintArtifacts(address recipient, uint256 amount) external onlyMothoraGame {
        _mint(recipient, ARTIFACTS, amount, "");
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return (_uris[tokenId]);
    }

    function setTokenUri(uint256 tokenId, string memory NFTuri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "CANNOT_SET_URI_TWICE");
        _uris[tokenId] = NFTuri;
    }

    function approveStakeVaultParts(address operator) external {
        _setApprovalForAll(_msgSender(), operator, true);
    }
}
