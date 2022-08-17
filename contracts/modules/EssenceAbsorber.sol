// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {GameItems} from "./GameItems.sol";

contract EssenceAbsorber is Ownable, ReentrancyGuard, ERC1155Holder {
    //=========== DEPENDENCIES ============

    using SafeERC20 for IERC20;

    //============== STORAGE ==============

    mapping(address => uint256) public stakedESSBalance;
    mapping(address => uint256) public RewardsBalance;
    mapping(address => uint256) public playerIds;

    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public timeTier;

    mapping(address => uint256) public playerStakedPartsBalance;
    mapping(uint256 => uint256) public factionPartsBalance;

    MothoraGame mothoraGameContract;

    // Rewards Function variables
    uint256 public totalStakedBalance;
    uint256 public epochRewards;
    uint256 public totalVaultPartsContributed;
    uint256 public lastDistributionTime;
    uint256 public epochRewardsPercentage;
    uint256 public epochDuration;
    uint256 public epochStartTime;
    address[] public playerAddresses;
    uint256 public playerId;

    //============== CONSTRUCTOR ============

    constructor(
        MothoraGame _mothoraGame,
        uint256 _epochRewardsPercentage,
        uint256 _epochDuration
    ) {
        mothoraGameContract = _mothoraGame;
        epochRewardsPercentage = _epochRewardsPercentage;
        epochDuration = _epochDuration;
        epochStartTime = block.timestamp;
    }

    modifier activeAccounts() {
        uint256 id = mothoraGameContract.getPlayerId(msg.sender);
        bool frozen = mothoraGameContract.getPlayerStatus(msg.sender);
        require(id != 0 && !frozen, "ACCOUNT_NOT_ACTIVE");
        _;
    }

    //============== FUNCTIONS =============

    function stakeTokens(uint256 _amount) public nonReentrant activeAccounts {
        require(_amount > 0, "Amount must be more than 0.");
        IERC20(mothoraGameContract.getEssence()).safeTransferFrom(msg.sender, address(this), _amount);

        _stakeTokens(_amount);
    }

    function unstakeTokens(uint256 _amount) external nonReentrant activeAccounts {
        require(_amount > 0, "Amount must be more than 0.");
        require(stakedESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakedESSBalance[msg.sender], "Cannot unstake more than your staked balance");

        stakedESSBalance[msg.sender] -= _amount;
        totalStakedBalance -= _amount;
    }

    function contributeArtifacts(uint256 _amount) external nonReentrant activeAccounts {
        require(_amount > 0, "Amount must be more than 0");
        GameItems gameItemsContract = GameItems(mothoraGameContract.getGameItems());
        require(
            gameItemsContract.balanceOf(msg.sender, gameItemsContract.ARTIFACTS()) >= _amount,
            "The Player does not have enough Artifacts"
        );

        playerStakedPartsBalance[msg.sender] += _amount;
        uint256 faction = mothoraGameContract.getPlayerFaction(msg.sender);

        factionPartsBalance[faction] += _amount;
        totalVaultPartsContributed += _amount;

        // Transfer from player to Staking Contract
        gameItemsContract.safeTransferFrom(msg.sender, address(this), 0, _amount, "");
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    function distributeRewards() external onlyOwner {
        require(totalStakedBalance > 0, "There are no tokens staked");
        uint256 lastEpochTime = epochStartTime + epochDuration * (((block.timestamp - epochStartTime) / epochDuration));
        require(lastDistributionTime < lastEpochTime, "The player has already claimed in this epoch");
        // total staked balance * APR percentage * 10min/1 year -> rewards in a given epoch of 10 minute
        epochRewards = divider(totalStakedBalance * epochRewardsPercentage * 600, 31536000 * 100, 0);

        address[] memory _playerAddresses = playerAddresses;
        uint256 _playerId = playerId;
        uint256 _epochRewards = epochRewards;
        uint256 maxedFactor1 = 0;
        uint256 maxedFactor2 = 0;
        uint256 maxedFactor3 = 0;
        uint256 factor1 = 0;
        uint256 factor2 = 0;
        uint256 factor3 = 0;

        for (uint256 i = 1; i <= _playerId; i = unsafeInc(i)) {
            if (stakedESSBalance[_playerAddresses[i - 1]] > 0) {
                maxedFactor1 += stakedESSBalance[_playerAddresses[i - 1]] * _calculateTimeTier(_playerAddresses[i - 1]);
            }
        }

        maxedFactor2 = totalVaultPartsContributed;
        maxedFactor3 =
            mothoraGameContract.totalFactionMembers(1) *
            factionPartsBalance[1] +
            mothoraGameContract.totalFactionMembers(2) *
            factionPartsBalance[2] +
            mothoraGameContract.totalFactionMembers(3) *
            factionPartsBalance[3];

        if (maxedFactor2 != 0) {
            uint256 faction;
            // Distributes the rewards
            for (uint256 i = 1; i <= playerId; i = unsafeInc(i)) {
                factor1 = (stakedESSBalance[playerAddresses[i - 1]] * _calculateTimeTier(_playerAddresses[i - 1]));
                factor2 = playerStakedPartsBalance[_playerAddresses[i - 1]];
                faction = mothoraGameContract.getPlayerFaction(_playerAddresses[i - 1]);

                factor3 = factionPartsBalance[faction];

                RewardsBalance[_playerAddresses[i - 1]] +=
                    divider(factor1 * 70 * _epochRewards, maxedFactor1 * 100, 0) +
                    divider(factor2 * 25 * _epochRewards, maxedFactor2 * 100, 0) +
                    divider(factor3 * 5 * _epochRewards, maxedFactor3 * 100, 0);
            }
        } else {
            // Distributes the rewards
            for (uint256 i = 1; i <= playerId; i = unsafeInc(i)) {
                factor1 = (stakedESSBalance[playerAddresses[i - 1]] * _calculateTimeTier(playerAddresses[i - 1]));

                RewardsBalance[playerAddresses[i - 1]] += divider(factor1 * epochRewards, maxedFactor1, 0);
            }
        }
        lastDistributionTime = block.timestamp;
    }

    function claimEpochRewards(bool autocompound) external activeAccounts {
        uint256 transferValue = RewardsBalance[msg.sender];
        RewardsBalance[msg.sender] = 0;

        if (autocompound) {
            _stakeTokens(transferValue);
        } else {
            IERC20(mothoraGameContract.getEssence()).safeTransfer(msg.sender, transferValue);
        }
    }

    function divider(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) public pure returns (uint256) {
        return ((numerator * (uint256(10)**uint256(precision + 1))) / denominator + 5) / uint256(10);
    }

    function getTotalBalance(address _player)
        external
        view
        returns (
            uint256 balance,
            uint256 stakedBalance,
            uint256 pendingRewards
        )
    {
        balance = IERC20(mothoraGameContract.getEssence()).balanceOf(_player);
        stakedBalance = stakedESSBalance[_player];
        pendingRewards = RewardsBalance[_player];

        return (balance, stakedBalance, pendingRewards);
    }

    function getPlayerVaultPartsBalance(address _player) external view returns (uint256 playerVaultPartsBalance) {
        playerVaultPartsBalance = playerStakedPartsBalance[_player];

        return playerVaultPartsBalance;
    }

    function getFactionVaultPartsBalance(uint256 _faction) external view returns (uint256 factionVaultPartsBalance) {
        factionVaultPartsBalance = factionPartsBalance[_faction];

        return factionVaultPartsBalance;
    }

    function _stakeTokens(uint256 _amount) internal {
        uint256 initialStakedAmount = stakedESSBalance[msg.sender];

        if (initialStakedAmount == 0) {
            if (playerIds[msg.sender] == 0) {
                playerId++;
                playerIds[msg.sender] = playerId;
                playerAddresses.push(msg.sender);
            }
            lastUpdate[msg.sender] = block.timestamp;
        } else {
            stakedDuration[msg.sender] =
                (block.timestamp - lastUpdate[msg.sender]) *
                (initialStakedAmount / stakedESSBalance[msg.sender]); //weighted average of balance & time staked
        }

        stakedESSBalance[msg.sender] += _amount;
        totalStakedBalance += _amount;
    }

    function _calculateTimeTier(address _recipient) private returns (uint256) {
        stakedDuration[_recipient] += (block.timestamp - lastUpdate[_recipient]);
        lastUpdate[_recipient] = block.timestamp;
        uint256 stakedDurationLocal = stakedDuration[_recipient];
        if (stakedDurationLocal <= 600) {
            timeTier[_recipient] = 10;
        } else if (stakedDurationLocal > 600 && stakedDurationLocal <= 1200) {
            timeTier[_recipient] = 13;
        } else if (stakedDurationLocal > 1200 && stakedDurationLocal <= 3000) {
            timeTier[_recipient] = 16;
        } else if (stakedDurationLocal > 3000) {
            timeTier[_recipient] = 20;
        }
        return timeTier[_recipient];
    }
}
