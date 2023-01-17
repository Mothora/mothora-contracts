// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IArena {
    /**
     * @dev Emited when merkleRoot is posted
     * @param matchId The id of the match (generated by the database)
     * @param merkleRoot The merkle root to write on-chain
     */
    event ArenaSessionPostgame(uint256 indexed matchId, bytes32 indexed merkleRoot);

    /**
     * @dev Emited when endpoint URI is updated
     * @param endpointURI The URI of the Arena
     */
    event EndpointURIChanged(string endpointURI);

    /**
     * @dev Error thrown when match has already been posted
     */
    error MATCH_ALREADY_POSTED();

    /**
     * @dev Error thrown when merkle root is null
     */
    error NULL_MERKLE_ROOT();

    /**
     * @dev Error thrown when match id is invalid
     */
    error INVALID_MATCH_ID();

    /**
     * @dev Error thrown when merkle proof is invalid
     */
    error INVALID_PROOF();

    /**
     * @dev Checks validity of a node of player data
     * @dev If the function does not revert it means the node is valid. Otherwise, the data submitted has been tampered with
     * @param matchId The id of the match (generated by the database)
     * @param player The address of the player in the node
     * @param K The number of Kills of the player
     * @param D The number of Deaths of the player
     * @param A The number of Assists of the player
     * @param essenceEarned The number of essence earned by the player
     * @param merkleProof The merkle proof of the node
     **/
    function checkValidityOfPlayerData(
        uint256 matchId,
        address player,
        uint256 K,
        uint256 D,
        uint256 A,
        uint256 essenceEarned,
        bytes32[] calldata merkleProof
    ) external view returns (bool valid);

    /**
     * @dev Ends a match by writting its id and merkle root.
     * @dev The emited event is used by the Mothora Game to trigger the generation of signatures to mint essence
     * @param matchId The id of the match (generated by the database)
     * @param merkleRoot The merkle root to write on-chain
     **/
    function endMatch(uint256 matchId, bytes32 merkleRoot) external;

    /**
     * @dev Sets the endpoint URI of the Arena
     * @param _endpointURI The URI of the Arena
     **/
    function setEndpointURI(string memory _endpointURI) external;
}