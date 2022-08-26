// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "../interfaces/IExtractorStakingRules.sol";

import "./StakingRulesBase.sol";

contract ExtractorStakingRules is IExtractorStakingRules, ERC165Upgradeable, StakingRulesBase {
    using Counters for Counters.Counter;

    struct ExtractorData {
        address user;
        uint256 tokenId;
        uint256 stakedTimestamp;
    }

    uint256 public constant MAX_SPOTS = 75;

    uint256 public maxStakeable;

    /// @dev time in seconds during which extractor is live
    uint256 public lifetime;

    /// @dev address of NFT extractor token
    address public extractorAddress;

    /// @dev latest spot Id
    Counters.Counter public extractorCount;
    /// @dev maps spot Id to ExtractorData
    mapping(uint256 => ExtractorData) public stakedExtractor;

    /// @dev maps token Id => power value
    mapping(uint256 => uint256) public extractorPower;

    event MaxStakeable(uint256 maxStakeable);
    event ExtractorPower(uint256 tokenId, uint256 power);
    event ExtractorStaked(address user, uint256 tokenId, uint256 spotId, uint256 amount);
    event ExtractorReplaced(address user, uint256 tokenId, uint256 replacedSpotId);
    event Lifetime(uint256 lifetime);
    event ExtractorAddress(address extractorAddress);

    error InvalidAddress();
    error ZeroAmount();
    error MustReplaceOne();
    error InvalidSpotId();
    error MustReplaceWithHigherPower();
    error ZeroPower();
    error MaxStakeableReached();
    error CannotUnstake();
    error TooManyStakeableSpots();

    modifier validateInput(address _nft, uint256 _amount) {
        if (_nft != extractorAddress) revert InvalidAddress();
        if (_amount == 0) revert ZeroAmount();

        _;
    }

    function init(
        address _admin,
        address _absorberFactory,
        address _extractorAddress,
        uint256 _maxStakeable,
        uint256 _lifetime
    ) external initializer {
        __ERC165_init();

        _initStakingRulesBase(_admin, _absorberFactory);

        _setExtractorAddress(_extractorAddress);
        _setMaxStakeable(_maxStakeable);
        _setExtractorLifetime(_lifetime);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IExtractorStakingRules).interfaceId ||
            interfaceId == type(IERC165Upgradeable).interfaceId ||
            interfaceId == type(IAccessControlUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function isExtractorActive(uint256 _spotId) public view returns (bool) {
        return block.timestamp <= stakedExtractor[_spotId].stakedTimestamp + lifetime;
    }

    function getExtractorCount() public view returns (uint256) {
        return extractorCount.current();
    }

    /// @return extractors array of all staked extractors
    function getExtractors() external view returns (ExtractorData[] memory extractors) {
        extractors = new ExtractorData[](extractorCount.current());

        for (uint256 i = 0; i < extractors.length; i++) {
            extractors[i] = stakedExtractor[i];
        }
    }

    /// @return totalPower power sum of all active extractors
    function getExtractorsTotalPower() public view returns (uint256 totalPower) {
        for (uint256 i = 0; i < extractorCount.current(); i++) {
            if (isExtractorActive(i)) {
                totalPower += extractorPower[stakedExtractor[i].tokenId];
            }
        }
    }

    /// @inheritdoc IStakingRules
    function getUserPower(
        address,
        address,
        uint256,
        uint256
    ) external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IStakingRules
    function getAbsorberPower() external view returns (uint256) {
        return Constant.ONE + getExtractorsTotalPower();
    }

    /// @inheritdoc IExtractorStakingRules
    function canReplace(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _replacedSpotId
    )
        external
        override
        onlyRole(SR_NFT_HANDLER)
        validateInput(_nft, _amount)
        returns (
            address user,
            uint256 replacedTokenId,
            uint256 replacedAmount
        )
    {
        if (_amount != 1) revert MustReplaceOne();
        if (_replacedSpotId >= maxStakeable) revert InvalidSpotId();

        user = stakedExtractor[_replacedSpotId].user;
        replacedTokenId = stakedExtractor[_replacedSpotId].tokenId;
        replacedAmount = _amount;

        if (isExtractorActive(_replacedSpotId)) {
            uint256 oldPower = extractorPower[replacedTokenId];
            uint256 newPower = extractorPower[_tokenId];
            if (oldPower >= newPower) revert MustReplaceWithHigherPower();
        }

        stakedExtractor[_replacedSpotId] = ExtractorData(_user, _tokenId, block.timestamp);
        emit ExtractorReplaced(_user, _tokenId, _replacedSpotId);
    }

    function _processStake(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) internal override validateInput(_nft, _amount) {
        if (extractorPower[_tokenId] == 0) revert ZeroPower();
        if (extractorCount.current() + _amount > maxStakeable) revert MaxStakeableReached();

        uint256 spotId;

        for (uint256 i = 0; i < _amount; i++) {
            spotId = extractorCount.current();

            stakedExtractor[spotId] = ExtractorData(_user, _tokenId, block.timestamp);
            extractorCount.increment();
        }

        emit ExtractorStaked(_user, _tokenId, spotId, _amount);
    }

    function _processUnstake(
        address,
        address,
        uint256,
        uint256
    ) internal pure override {
        revert CannotUnstake();
    }

    // ADMIN

    function setMaxStakeable(uint256 _maxStakeable) external onlyRole(SR_ADMIN) {
        _setMaxStakeable(_maxStakeable);
    }

    function setExtractorPower(uint256 _tokenId, uint256 _power) external onlyRole(SR_ADMIN) {
        nftHandler.absorber().callUpdateRewards();

        extractorPower[_tokenId] = _power;
        emit ExtractorPower(_tokenId, _power);
    }

    function setExtractorLifetime(uint256 _lifetime) external onlyRole(SR_ADMIN) {
        nftHandler.absorber().callUpdateRewards();

        _setExtractorLifetime(_lifetime);
    }

    function _setMaxStakeable(uint256 _maxStakeable) internal {
        // disallow number higher than MAX_SPOTS because of loops
        if (_maxStakeable > MAX_SPOTS) revert TooManyStakeableSpots();

        maxStakeable = _maxStakeable;
        emit MaxStakeable(_maxStakeable);
    }

    function _setExtractorAddress(address _extractorAddress) internal {
        extractorAddress = _extractorAddress;
        emit ExtractorAddress(_extractorAddress);
    }

    function _setExtractorLifetime(uint256 _lifetime) internal {
        lifetime = _lifetime;
        emit Lifetime(_lifetime);
    }
}
