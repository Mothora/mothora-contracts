// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IAbsorber.sol";
import "./IStakingRules.sol";

interface INftHandler {
    enum Interfaces {
        Unsupported,
        ERC721,
        ERC1155
    }

    struct NftConfig {
        Interfaces supportedInterface;
        /// @dev contract address which calculates power for this NFT
        IStakingRules stakingRules;
    }

    /// @notice Initialize contract
    /// @param _admin wallet address to be set as contract's admin
    /// @param _absorber absorber address for which INftHandler is deployed
    /// @param _nfts array of NFTs allowed to be staked
    /// @param _tokenIds array of tokenIds allowed to be staked, it should correspond to `_nfts`
    /// @param _nftConfigs array of configs for each NFT
    function init(
        address _admin,
        address _absorber,
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        INftHandler.NftConfig[] memory _nftConfigs
    ) external;

    /// @notice Gets absorber address linked to this contract
    /// @return Absorber interface
    function absorber() external view returns (IAbsorber);

    /// @notice Gets staking rules contract address
    /// @param _nft NFT contract address for which to read staking rules contract address
    /// @param _tokenId token id for which to read staking rules contract address
    /// @return staking rules contract address
    function getStakingRules(address _nft, uint256 _tokenId) external view returns (IStakingRules);

    /// @notice Gets cached user power
    /// @dev Cached power is re-calculated on the fly on stake and unstake NFT by user
    /// @param _user user's wallet address
    /// @return cached user power as percentage, 1e18 == 100%
    function getUserPower(address _user) external view returns (uint256);

    /// @notice Gets given NFT power for user
    /// @param _user user's wallet address
    /// @param _nft address of NFT contract
    /// @param _tokenId token Id of NFT for which to calculate the power
    /// @param _amount amount of tokens for which to calculate power, must be 1 for ERC721
    /// @return calculated power for given NFT for given user as percentage, 1e18 == 100%
    function getNftPower(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) external view returns (uint256);

    /// @notice Gets absorber power to calculate rewards allocation
    /// @return power calculated absorber power to calculate rewards allocation
    function getAbsorberTotalPower() external view returns (uint256 power);
}
