// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IArena} from "../interfaces/IArena.sol";

contract Arena is IArena, Ownable {
    mapping(uint256 => bytes32) private matchToMerkleRoot;

    // string = 'https://api.mothra.gg/arena/v1/matches/{matchId}/postgame'
    string public metadata;

    constructor(string memory _metadata) Ownable() {
        metadata = _metadata;
    }

    function endMatch(uint256 matchId, bytes32 merkleRoot) external onlyOwner {
        if (matchToMerkleRoot[matchId] != 0) revert MATCH_ALREADY_POSTED();
        if (merkleRoot == 0) revert NULL_MERKLE_ROOT();

        matchToMerkleRoot[matchId] = merkleRoot;

        emit ArenaSessionPostgame(matchId, merkleRoot);
    }

    function checkValidityOfPlayerData(
        uint256 matchId,
        address player,
        uint256 K,
        uint256 D,
        uint256 A,
        bytes32[] calldata merkleProof
    ) external view returns (bool valid) {
        bytes32 merkleRoot = matchToMerkleRoot[matchId];
        if (merkleRoot.length == 0) revert INVALID_MATCH_ID();

        bytes32 node = keccak256(abi.encodePacked(player, K, D, A));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert INVALID_PROOF();

        valid = true;
    }
}
