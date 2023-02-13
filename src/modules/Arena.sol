// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IArena} from "../interfaces/IArena.sol";

contract Arena is IArena, Ownable {
    mapping(uint256 => bytes32) private matchToMerkleRoot;

    string public endpointURI;

    constructor(string memory _endpointURI) Ownable() {
        endpointURI = _endpointURI;
    }

    /*///////////////////////////////////////////////////////////////
                    Proof verification
    //////////////////////////////////////////////////////////////*/

    function checkValidityOfPlayerData(
        uint256 matchId,
        address player,
        uint256 K,
        uint256 D,
        uint256 A,
        uint256 essenceEarned,
        bytes32[] calldata merkleProof
    ) external view override returns (bool valid) {
        bytes32 merkleRoot = matchToMerkleRoot[matchId];
        if (merkleRoot.length == 0) revert INVALID_MATCH_ID();

        bytes32 node = keccak256(abi.encodePacked(player, K, D, A, essenceEarned));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert INVALID_PROOF();

        valid = true;
    }

    /*///////////////////////////////////////////////////////////////
                    Admin logic
    //////////////////////////////////////////////////////////////*/

    function endMatch(uint256 matchId, bytes32 merkleRoot) external override onlyOwner {
        if (matchToMerkleRoot[matchId] != 0) revert MATCH_ALREADY_POSTED();
        if (merkleRoot == 0) revert NULL_MERKLE_ROOT();

        matchToMerkleRoot[matchId] = merkleRoot;

        emit ArenaSessionPostgame(matchId, merkleRoot);
    }

    function setEndpointURI(string memory _endpointURI) external override onlyOwner {
        endpointURI = _endpointURI;

        emit EndpointURIChanged(_endpointURI);
    }
}
