// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// TODO changes
interface IArtifactMetadataStore {
    struct ArtifactMetadata {
        ArtifactGeneration artifactGeneration;
        ArtifactRarity artifactRarity;
    }

    enum ArtifactRarity {
        LEGENDARY,
        EXOTIC,
        RARE,
        UNCOMMON,
        COMMON
    }

    enum ArtifactGeneration {
        PRIMAL,
        SECONDARY
    }

    // Sets the intial metadata for a token id.
    // Admin only.
    function setInitialMetadataForArtifact(
        address _owner,
        uint256 _tokenId,
        ArtifactGeneration _generation,
        ArtifactRarity _rarity
    ) external;

    // Returns the metadata for the given artifact.
    function metadataForArtifact(uint256 _tokenId) external view returns (ArtifactMetadata memory);
}
