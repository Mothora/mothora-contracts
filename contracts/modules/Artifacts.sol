// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {MothoraGame} from "../MothoraGame.sol";

contract Artifacts is ERC1155, Ownable {
    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);
    //===============Storage===============

    mapping(uint256 => string) private _uris;

    uint256 public constant ARTIFACTS = 0;

    MothoraGame mothoraGameContract;

    modifier onlyArena() {
        require(msg.sender == mothoraGameContract.getArena(), "NOT_ARENA");
        _;
    }
    modifier onlyCrafting() {
        require(msg.sender == mothoraGameContract.getCrafting(), "NOT_CRAFTING");
        _;
    }

    modifier onlyArenaOrCrafting() {
        require(
            msg.sender == mothoraGameContract.getCrafting() || msg.sender == mothoraGameContract.getArena(),
            "NOT_CRAFTING_OR_ARENA"
        );
        _;
    }

    //===============Functions=============

    // To translate CIDv0 (Qm) to CIDv1 (ba) use this website: https://cid.ipfs.io/
    // constructor() ERC1155("https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/{id}.json") {}

    constructor(string memory _initialFolder, address _mothoraGameAddress)
        ERC1155(string(abi.encodePacked(_initialFolder, "{id}.json")))
    {
        setTokenUri(ARTIFACTS, string(abi.encodePacked(_initialFolder, "0", ".json")));
        mothoraGameContract = MothoraGame(_mothoraGameAddress);
    }

    function mintArtifacts(address recipient, uint256 amount) external onlyArenaOrCrafting {
        _mint(recipient, ARTIFACTS, amount, "");
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
