// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {MothoraGame} from "../MothoraGame.sol";

contract Cosmetics is ERC1155, Ownable {
    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);

    //===============Storage===============

    mapping(uint256 => string) private _uris;

    uint256 public constant THOROKS = 1;
    uint256 public constant CONGLOMERATE = 2;
    uint256 public constant DOC = 3;

    MothoraGame mothoraGameContract;

    modifier onlyMothoraGame() {
        require(msg.sender == address(mothoraGameContract), "NOT_MOTHORA_GAME");
        _;
    }

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/{id}.json") {}
    // currently all characters of the same faction have the same skin

    constructor(string memory _initialFolder, address _mothoraGameAddress)
        ERC1155(string(abi.encodePacked(_initialFolder, "{id}.json")))
    {
        setTokenUri(THOROKS, string(abi.encodePacked(_initialFolder, "1", ".json")));
        setTokenUri(CONGLOMERATE, string(abi.encodePacked(_initialFolder, "2", ".json")));
        setTokenUri(DOC, string(abi.encodePacked(_initialFolder, "3", ".json")));
        mothoraGameContract = MothoraGame(_mothoraGameAddress);
    }

    function mintCharacter(address _recipient, uint256 _id) external onlyMothoraGame {
        require(_id == THOROKS || _id == CONGLOMERATE || _id == DOC, "WRONG_ID");
        _mint(_recipient, _id, 1, "");
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return (_uris[tokenId]);
    }

    function setTokenUri(uint256 tokenId, string memory NFTuri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "CANNOT_SET_URI_TWICE");
        _uris[tokenId] = NFTuri;
    }

    /**
     * @dev Returns the address of the Mothora Game Hub Contract
     * @return The Mothora Game address
     **/
    function getMothoraGame() public view returns (address) {
        return address(mothoraGameContract);
    }

    /**
     * @dev Updates the address of the Mothora Game
     * @param mothoraGameContractAddress The new Mothora Game address
     **/
    function setMothoraGame(address mothoraGameContractAddress) external onlyOwner {
        mothoraGameContract = MothoraGame(mothoraGameContractAddress);
        emit MothoraGameAddressUpdated(mothoraGameContractAddress);
    }
}
