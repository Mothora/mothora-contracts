// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./StakingRulesBase.sol";

contract ShardStakingRules is StakingRulesBase {
    uint256 public maxStakeablePerUser;

    mapping(address => uint256) public getAmountShardsStaked;

    event MaxStakeablePerUser(uint256 maxStakeablePerUser);

    error ZeroAddress();
    error ZeroAmount();
    error MaxStakeablePerUserReached();

    modifier validateInput(address _user, uint256 _amount) {
        if (_user == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        _;
    }

    function init(
        address _admin,
        address _absorberFactory,
        uint256 _maxStakeablePerUser
    ) external initializer {
        _initStakingRulesBase(_admin, _absorberFactory);

        _setMaxStakeablePerUser(_maxStakeablePerUser);
    }

    /// @inheritdoc IStakingRules
    function getUserPower(
        address,
        address,
        uint256 _tokenId,
        uint256 _amount
    ) external pure override returns (uint256) {
        return getShardPower(_tokenId, _amount);
    }

    /// @inheritdoc IStakingRules
    function getAbsorberPower() external pure returns (uint256) {
        // Shard staking only boosts userPower, not absorberPower
        return Constant.ONE;
    }

    function getShardPower(uint256 _tokenId, uint256 _amount) public pure returns (uint256 power) {
        // boosts are base e16, so %1 is represented as 1e16
        // Same as Atlas Mine Shard staking
        if (_tokenId == 39) {
            // Ancient Relic 7.5%
            power = 75e15;
        } else if (_tokenId == 46) {
            // Bag of Rare Mushrooms 6.2%
            power = 62e15;
        } else if (_tokenId == 47) {
            // Bait for Monsters 7.3%
            power = 73e15;
        } else if (_tokenId == 48) {
            // Beetle-wing 0.8%
            power = 8e15;
        } else if (_tokenId == 49) {
            // Blue Rupee 1.5%
            power = 15e15;
        } else if (_tokenId == 51) {
            // Bottomless Elixir 7.6%
            power = 76e15;
        } else if (_tokenId == 52) {
            // Cap of Invisibility 7.6%
            power = 76e15;
        } else if (_tokenId == 53) {
            // Carriage 6.1%
            power = 61e15;
        } else if (_tokenId == 54) {
            // Castle 7.1%
            power = 71e15;
        } else if (_tokenId == 68) {
            // Common Bead 5.6%
            power = 56e15;
        } else if (_tokenId == 69) {
            // Common Feather 3.4%
            power = 34e15;
        } else if (_tokenId == 71) {
            // Common Relic 2.2%
            power = 22e15;
        } else if (_tokenId == 72) {
            // Cow 5.8%
            power = 58e15;
        } else if (_tokenId == 73) {
            // Diamond 0.8%
            power = 8e15;
        } else if (_tokenId == 74) {
            // Divine Hourglass 6.3%
            power = 63e15;
        } else if (_tokenId == 75) {
            // Divine Mask 5.7%
            power = 57e15;
        } else if (_tokenId == 76) {
            // Donkey 1.2%
            power = 12e15;
        } else if (_tokenId == 77) {
            // Dragon Tail 0.8%
            power = 8e15;
        } else if (_tokenId == 79) {
            // Emerald 0.8%
            power = 8e15;
        } else if (_tokenId == 82) {
            // Favor from the Gods 5.6%
            power = 56e15;
        } else if (_tokenId == 91) {
            // Framed Butterfly 5.8%
            power = 58e15;
        } else if (_tokenId == 92) {
            // Gold Coin 0.8%
            power = 8e15;
        } else if (_tokenId == 93) {
            // Grain 3.2%
            power = 32e15;
        } else if (_tokenId == 94) {
            // Green Rupee 3.3%
            power = 33e15;
        } else if (_tokenId == 95) {
            // Grin 15.7%
            power = 157e15;
        } else if (_tokenId == 96) {
            // Half-Penny 0.8%
            power = 8e15;
        } else if (_tokenId == 97) {
            // Honeycomb 15.8%
            power = 158e15;
        } else if (_tokenId == 98) {
            // Immovable Stone 7.2%
            power = 72e15;
        } else if (_tokenId == 99) {
            // Ivory Breastpin 6.4%
            power = 64e15;
        } else if (_tokenId == 100) {
            // Jar of Fairies 5.3%
            power = 53e15;
        } else if (_tokenId == 103) {
            // Lumber 3%
            power = 30e15;
        } else if (_tokenId == 104) {
            // Military Stipend 6.2%
            power = 62e15;
        } else if (_tokenId == 105) {
            // Mollusk Shell 6.7%
            power = 67e15;
        } else if (_tokenId == 114) {
            // Ox 1.6%
            power = 16e15;
        } else if (_tokenId == 115) {
            // Pearl 0.8%
            power = 8e15;
        } else if (_tokenId == 116) {
            // Pot of Gold 5.8%
            power = 58e15;
        } else if (_tokenId == 117) {
            // Quarter-Penny 0.8%
            power = 8e15;
        } else if (_tokenId == 132) {
            // Red Feather 6.4%
            power = 64e15;
        } else if (_tokenId == 133) {
            // Red Rupee 0.8%
            power = 8e15;
        } else if (_tokenId == 141) {
            // Score of Ivory 6%
            power = 60e15;
        } else if (_tokenId == 151) {
            // Silver Coin 0.8%
            power = 8e15;
        } else if (_tokenId == 152) {
            // Small Bird 6%
            power = 60e15;
        } else if (_tokenId == 153) {
            // Snow White Feather 6.4%
            power = 64e15;
        } else if (_tokenId == 161) {
            // Thread of Divine Silk 7.3%
            power = 73e15;
        } else if (_tokenId == 162) {
            // Unbreakable Pocketwatch 5.9%
            power = 59e15;
        } else if (_tokenId == 164) {
            // Witches Broom 5.1%
            power = 51e15;
        }

        power = power * _amount;
    }

    function _processStake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override validateInput(_user, _amount) {
        // There is only a address-specific limit on number of staked Shards
        uint256 amountStakedCache = getAmountShardsStaked[_user];
        if (amountStakedCache + _amount > maxStakeablePerUser) revert MaxStakeablePerUserReached();
        getAmountShardsStaked[_user] = amountStakedCache + _amount;
    }

    function _processUnstake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override validateInput(_user, _amount) {
        getAmountShardsStaked[_user] -= _amount;
    }

    // ADMIN

    function setMaxStakeablePerUser(uint256 _maxStakeablePerUser) external onlyRole(SR_ADMIN) {
        _setMaxStakeablePerUser(_maxStakeablePerUser);
    }

    function _setMaxStakeablePerUser(uint256 _maxStakeablePerUser) internal {
        maxStakeablePerUser = _maxStakeablePerUser;
        emit MaxStakeablePerUser(_maxStakeablePerUser);
    }
}
