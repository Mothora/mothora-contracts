// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../../../interfaces/IArtifactMetadataStore.sol";

import "./StakingRulesBase.sol";

contract ArtifactStakingRules is StakingRulesBase {
    uint256 public staked;
    uint256 public maxStakeableTotal;
    uint256 public maxArtifactWeight;
    uint256 public totalRank;
    uint256 public powerFactor;

    uint256[][] public artifactPowerMatrix;
    uint256[][] public artifactWeightMatrix;
    uint256[][] public artifactRankMatrix;

    IArtifactMetadataStore public artifactMetadataStore;

    /// @dev maps user wallet to current staked weight. For weight values, see getWeight
    mapping(address => uint256) public weightStaked;

    event MaxWeight(uint256 maxArtifactWeight);
    event ArtifactMetadataStore(IArtifactMetadataStore artifactMetadataStore);
    event MaxStakeableTotal(uint256 maxStakeableTotal);
    event PowerFactor(uint256 powerFactor);

    error MaxWeightReached();

    function init(
        address _admin,
        address _harvesterFactory,
        IArtifactMetadataStore _artifactMetadataStore,
        uint256 _maxArtifactWeight,
        uint256 _maxStakeableTotal,
        uint256 _powerFactor
    ) external initializer {
        _initStakingRulesBase(_admin, _harvesterFactory);

        artifactMetadataStore = _artifactMetadataStore;

        _setMaxWeight(_maxArtifactWeight);
        _setMaxStakeableTotal(_maxStakeableTotal);
        _setPowerFactor(_powerFactor);

        // array follows values from IArtifactMetadataStore.ArtifactGeneration and IArtifactMetadataStore.ArtifactRarity
        artifactPowerMatrix = [
            // GENESIS
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [uint256(6e18), uint256(2e18), uint256(0.75e18), uint256(1e18), uint256(0.5e18), uint256(0)],
            // AUXILIARY
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [uint256(0), uint256(0.25e18), uint256(0), uint256(0.1e18), uint256(0.05e18), uint256(0)],
            // RECRUIT
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]
        ];

        uint256 illegalWeight = _maxArtifactWeight * 1e18;

        artifactWeightMatrix = [
            // GENESIS
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [uint256(120e18), uint256(40e18), uint256(16e18), uint256(21e18), uint256(11e18), illegalWeight],
            // AUXILIARY
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [illegalWeight, uint256(5.5e18), illegalWeight, uint256(4e18), uint256(2.5e18), illegalWeight],
            // RECRUIT
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [illegalWeight, illegalWeight, illegalWeight, illegalWeight, illegalWeight, illegalWeight]
        ];

        uint256 illegalRank = 1e18;

        artifactRankMatrix = [
            // GENESIS
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [uint256(4e18), uint256(4e18), uint256(2e18), uint256(3e18), uint256(1.5e18), illegalRank],
            // AUXILIARY
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [illegalRank, uint256(1.2e18), illegalRank, uint256(1.1e18), uint256(1e18), illegalRank],
            // RECRUIT
            // LEGENDARY,RARE,SPECIAL,UNCOMMON,COMMON,RECRUIT
            [illegalRank, illegalRank, illegalRank, illegalRank, illegalRank, illegalRank]
        ];
    }

    function getArtifactPowerMatrix() public view returns (uint256[][] memory) {
        return artifactPowerMatrix;
    }

    function getArtifactWeightMatrix() public view returns (uint256[][] memory) {
        return artifactWeightMatrix;
    }

    function getArtifactRankMatrix() public view returns (uint256[][] memory) {
        return artifactRankMatrix;
    }

    /// @inheritdoc IStakingRules
    function getUserPower(
        address,
        address,
        uint256 _tokenId,
        uint256
    ) external view override returns (uint256) {
        IArtifactMetadataStore.ArtifactMetadata memory metadata = artifactMetadataStore.metadataForArtifact(_tokenId);

        return getArtifactPower(uint256(metadata.artifactGeneration), uint256(metadata.artifactRarity));
    }

    /// @inheritdoc IStakingRules
    function getAbsorberPower() external view returns (uint256) {
        // quadratic function in the interval: [1, (1 + power_factor)] based on number of parts staked.
        // exhibits diminishing returns on power as more artifacts are added
        // num: number of artifacts staked on harvester
        // max: number of artifacts where you achieve max power
        // avg_artifact_rank: avg artifact rank on your harvester
        // power_factor: the amount of power you want to apply to parts
        // default is 1 = 50% power (1.5x) if num = max

        uint256 n = (staked > maxStakeableTotal ? maxStakeableTotal : staked) * Constant.ONE;
        uint256 maxArtifacts = maxStakeableTotal * Constant.ONE;
        if (maxArtifacts == 0) return Constant.ONE;
        uint256 avgArtifactRank = staked == 0 ? 0 : totalRank / staked;
        uint256 artifactRankModifier = 0.9e18 + avgArtifactRank / 10;

        return
            Constant.ONE +
            ((((2 * n - n**2 / maxArtifacts) * artifactRankModifier) / Constant.ONE) * powerFactor) /
            maxArtifacts;
    }

    function getArtifactPower(uint256 _artifactGeneration, uint256 _artifactRarity) public view returns (uint256) {
        if (
            _artifactGeneration < artifactPowerMatrix.length &&
            _artifactRarity < artifactPowerMatrix[_artifactGeneration].length
        ) {
            return artifactPowerMatrix[_artifactGeneration][_artifactRarity];
        }

        return 0;
    }

    function getRank(uint256 _tokenId) public view returns (uint256) {
        IArtifactMetadataStore.ArtifactMetadata memory metadata = artifactMetadataStore.metadataForArtifact(_tokenId);
        uint256 _artifactGeneration = uint256(metadata.artifactGeneration);
        uint256 _artifactRarity = uint256(metadata.artifactRarity);

        if (
            _artifactGeneration < artifactRankMatrix.length &&
            _artifactRarity < artifactRankMatrix[_artifactGeneration].length
        ) {
            return artifactRankMatrix[_artifactGeneration][_artifactRarity];
        }

        return 0;
    }

    function getWeight(uint256 _tokenId) public view returns (uint256) {
        IArtifactMetadataStore.ArtifactMetadata memory metadata = artifactMetadataStore.metadataForArtifact(_tokenId);
        uint256 _artifactGeneration = uint256(metadata.artifactGeneration);
        uint256 _artifactRarity = uint256(metadata.artifactRarity);

        if (
            _artifactGeneration < artifactWeightMatrix.length &&
            _artifactRarity < artifactWeightMatrix[_artifactGeneration].length
        ) {
            return artifactWeightMatrix[_artifactGeneration][_artifactRarity];
        }

        return 0;
    }

    function _processStake(
        address _user,
        address,
        uint256 _tokenId,
        uint256
    ) internal override {
        staked++;
        totalRank += getRank(_tokenId);
        weightStaked[_user] += getWeight(_tokenId);

        if (weightStaked[_user] > maxArtifactWeight) revert MaxWeightReached();
    }

    function _processUnstake(
        address _user,
        address,
        uint256 _tokenId,
        uint256
    ) internal override {
        staked--;
        totalRank -= getRank(_tokenId);
        weightStaked[_user] -= getWeight(_tokenId);
    }

    // ADMIN

    function setArtifactMetadataStore(IArtifactMetadataStore _artifactMetadataStore) external onlyRole(SR_ADMIN) {
        artifactMetadataStore = _artifactMetadataStore;
        emit ArtifactMetadataStore(_artifactMetadataStore);
    }

    function setMaxWeight(uint256 _maxArtifactWeight) external onlyRole(SR_ADMIN) {
        _setMaxWeight(_maxArtifactWeight);
    }

    function setMaxStakeableTotal(uint256 _maxStakeableTotal) external onlyRole(SR_ADMIN) {
        _setMaxStakeableTotal(_maxStakeableTotal);
    }

    function setPowerFactor(uint256 _powerFactor) external onlyRole(SR_ADMIN) {
        nftHandler.absorber().callUpdateRewards();

        _setPowerFactor(_powerFactor);
    }

    function _setMaxWeight(uint256 _maxArtifactWeight) internal {
        maxArtifactWeight = _maxArtifactWeight;
        emit MaxWeight(_maxArtifactWeight);
    }

    function _setMaxStakeableTotal(uint256 _maxStakeableTotal) internal {
        maxStakeableTotal = _maxStakeableTotal;
        emit MaxStakeableTotal(_maxStakeableTotal);
    }

    function _setPowerFactor(uint256 _powerFactor) internal {
        powerFactor = _powerFactor;
        emit PowerFactor(_powerFactor);
    }
}
