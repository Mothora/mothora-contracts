// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interfaces/INftHandler.sol";

import "./StakingRulesBase.sol";

contract PartsStakingRules is StakingRulesBase {
    uint256 public staked;
    uint256 public maxStakeableTotal;
    uint256 public maxStakeablePerUser;
    uint256 public powerFactor;

    mapping(address => uint256) public getAmountStaked;

    event MaxStakeableTotal(uint256 maxStakeableTotal);
    event MaxStakeablePerUser(uint256 maxStakeablePerUser);
    event PowerFactor(uint256 powerFactor);

    error ZeroAddress();
    error ZeroAmount();
    error MaxStakeable();
    error MaxStakeablePerUserReached();
    error MinUserGlobalDeposit();

    modifier validateInput(address _user, uint256 _amount) {
        if (_user == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        _;
    }

    function init(
        address _admin,
        address _absorberFactory,
        uint256 _maxStakeableTotal,
        uint256 _maxStakeablePerUser,
        uint256 _powerFactor
    ) external initializer {
        _initStakingRulesBase(_admin, _absorberFactory);

        _setMaxStakeableTotal(_maxStakeableTotal);
        _setMaxStakeablePerUser(_maxStakeablePerUser);
        _setPowerFactor(_powerFactor);
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
        // quadratic function in the interval: [1, (1 + power_factor)] based on number of parts staked.
        // exhibits diminishing returns on powers as more parts are added
        // num_parts: number of absorber parts
        // max_parts: number of parts to achieve max power
        // power_factor: the amount of power you want to apply to parts
        // default is 1 = 100% power (2x) if num_parts = max_parts
        // # weight for additional parts has  diminishing gains
        // n = num_parts
        // return 1 + (2*n - n**2/max_parts) / max_parts * power_factor

        uint256 n = staked * Constant.ONE;
        uint256 maxParts = maxStakeableTotal * Constant.ONE;
        if (maxParts == 0) return Constant.ONE;
        uint256 power = powerFactor;
        return Constant.ONE + ((2 * n - n**2 / maxParts) * power) / maxParts;
    }

    function _processStake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override validateInput(_user, _amount) {
        uint256 stakedCache = staked;
        if (stakedCache + _amount > maxStakeableTotal) revert MaxStakeable();
        staked = stakedCache + _amount;

        uint256 amountStakedCache = getAmountStaked[_user];
        if (amountStakedCache + _amount > maxStakeablePerUser) revert MaxStakeablePerUserReached();
        getAmountStaked[_user] = amountStakedCache + _amount;
    }

    function _processUnstake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override validateInput(_user, _amount) {
        staked -= _amount;
        getAmountStaked[_user] -= _amount;

        // require that user cap is above MAGIC deposit amount after unstake
        if (INftHandler(msg.sender).absorber().isUserExceedingDepositCap(_user)) {
            revert MinUserGlobalDeposit();
        }
    }

    // ADMIN

    function setMaxStakeableTotal(uint256 _maxStakeableTotal) external onlyRole(SR_ADMIN) {
        _setMaxStakeableTotal(_maxStakeableTotal);
    }

    function setMaxStakeablePerUser(uint256 _maxStakeablePerUser) external onlyRole(SR_ADMIN) {
        _setMaxStakeablePerUser(_maxStakeablePerUser);
    }

    function setPowerFactor(uint256 _powerFactor) external onlyRole(SR_ADMIN) {
        nftHandler.absorber().callUpdateRewards();

        _setPowerFactor(_powerFactor);
    }

    function _setMaxStakeableTotal(uint256 _maxStakeableTotal) internal {
        maxStakeableTotal = _maxStakeableTotal;
        emit MaxStakeableTotal(_maxStakeableTotal);
    }

    function _setMaxStakeablePerUser(uint256 _maxStakeablePerUser) internal {
        maxStakeablePerUser = _maxStakeablePerUser;
        emit MaxStakeablePerUser(_maxStakeablePerUser);
    }

    function _setPowerFactor(uint256 _powerFactor) internal {
        powerFactor = _powerFactor;
        emit PowerFactor(_powerFactor);
    }
}
