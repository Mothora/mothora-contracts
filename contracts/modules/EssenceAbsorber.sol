// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MothoraGame} from "../MothoraGame.sol";
import {Artifacts} from "./Artifacts.sol";

contract EssenceAbsorber is Ownable, ReentrancyGuard, ERC1155Holder {
    using SafeERC20 for IERC20;

    event MothoraGameAddressUpdated(address indexed mothoraGameContractAddress);

    //============== STORAGE ==============

    mapping(address => uint256) public stakedESSBalance;
    mapping(address => uint256) public RewardsBalance;
    mapping(address => uint256) public playerIds;

    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public timeTier;

    mapping(address => uint256) public playerStakedArtifactsBalance;
    mapping(uint256 => uint256) public factionArtifactsBalance;

    MothoraGame mothoraGameContract;

    // Rewards Function variables
    uint256 public totalStakedBalance;
    uint256 public epochRewards;
    uint256 public totalArtifactsContributed;
    uint256 public lastDistributionTime;
    uint256 public epochRewardsPercentage;
    uint256 public epochDuration;
    uint256 public epochStartTime;
    // keeps a registry of all active players who staked
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

    modifier existingAccounts() {
        uint256 id = mothoraGameContract.getPlayerId(msg.sender);
        require(id != 0, "ACCOUNT_DOES_NOT_EXIST");
        _;
    }

    //============== FUNCTIONS =============
    /**
     * @dev Allows active accounts only to stake tokens
     * @param amount amount to be staked
     */
    function stakeTokens(uint256 amount) public nonReentrant activeAccounts {
        require(amount > 0, "AMOUNT_NOT_HIGHER_THAN_0");
        _stakeTokens(amount);

        IERC20(mothoraGameContract.getEssence()).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Allows any existing account to unstake (including frozen accounts, which cannot stake anymore)
     * @param amount amount to be staked
     */
    function unstakeTokens(uint256 amount) external nonReentrant existingAccounts {
        require(amount > 0, "AMOUNT_IS_0");
        require(stakedESSBalance[msg.sender] > 0, "STAKED_BALANCE_IS_0");
        require(amount <= stakedESSBalance[msg.sender], "INVALID_UNSTAKE_OPERATION");

        stakedESSBalance[msg.sender] -= amount;
        totalStakedBalance -= amount;

        // transfer from contract to player
        IERC20(mothoraGameContract.getEssence()).safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Stakes artifacts in the absorber, only active accounts can stake
     * @param amount amount to be staked
     */
    function stakeArtifacts(uint256 amount) external nonReentrant activeAccounts {
        require(amount > 0, "AMOUNT_IS_0");
        Artifacts artifactsContract = Artifacts(mothoraGameContract.getArtifacts());
        require(artifactsContract.balanceOf(msg.sender, artifactsContract.ARTIFACTS()) >= amount, "NOT_ENOUGH_BALANCE");

        playerStakedArtifactsBalance[msg.sender] += amount;
        uint256 faction = mothoraGameContract.getPlayerFaction(msg.sender);

        factionArtifactsBalance[faction] += amount;
        totalArtifactsContributed += amount;

        // Transfer from player to Staking Contract
        artifactsContract.safeTransferFrom(msg.sender, address(this), 0, amount, "");
    }

    /**
     * @dev Unstakes artifacts from the absorber. Any existing account can unstake
     * @param amount amount to be unstaked
     */
    function unstakeArtifacts(uint256 amount) external nonReentrant existingAccounts {
        require(amount > 0, "AMOUNT_IS_0");
        require(playerStakedArtifactsBalance[msg.sender] > 0, "STAKED_BALANCE_IS_0");
        require(amount <= playerStakedArtifactsBalance[msg.sender], "INVALID_UNSTAKE_OPERATION");

        playerStakedArtifactsBalance[msg.sender] -= amount;
        uint256 faction = mothoraGameContract.getPlayerFaction(msg.sender);

        factionArtifactsBalance[faction] -= amount;
        totalArtifactsContributed -= amount;

        Artifacts artifactsContract = Artifacts(mothoraGameContract.getArtifacts());
        // Transfer from contract to player
        artifactsContract.safeTransferFrom(address(this), msg.sender, 0, amount, "");
    }

    /**
     * @dev Admin function to distribute rewards after a given epoch. It operates in a push basis
     * @dev Given this operation mode it has serious limitations given the loops. A better implementation is to create a pull based system
     **/
    function distributeRewards() external onlyOwner {
        require(totalStakedBalance > 0, "NO_TOKENS_STAKED");
        uint256 lastEpochTime = epochStartTime + epochDuration * (((block.timestamp - epochStartTime) / epochDuration));
        require(lastDistributionTime < lastEpochTime, "DISTRIBUTION_ALREADY_HAPPENED");
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

        maxedFactor2 = totalArtifactsContributed;
        maxedFactor3 =
            mothoraGameContract.totalFactionMembers(1) *
            factionArtifactsBalance[1] +
            mothoraGameContract.totalFactionMembers(2) *
            factionArtifactsBalance[2] +
            mothoraGameContract.totalFactionMembers(3) *
            factionArtifactsBalance[3];

        if (maxedFactor2 != 0) {
            uint256 faction;
            // Distributes the rewards
            for (uint256 i = 1; i <= playerId; i = unsafeInc(i)) {
                factor1 = (stakedESSBalance[playerAddresses[i - 1]] * _calculateTimeTier(_playerAddresses[i - 1]));
                factor2 = playerStakedArtifactsBalance[_playerAddresses[i - 1]];
                faction = mothoraGameContract.getPlayerFaction(_playerAddresses[i - 1]);

                factor3 = factionArtifactsBalance[faction];

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

    /**
     * @dev Claims the rewards of a given epoch. If autocompound is true it re-stakes the tokens harvested, otherwise withdraws them
     * @param autocompound true or false
     **/
    function claimEpochRewards(bool autocompound) external existingAccounts {
        uint256 transferValue = RewardsBalance[msg.sender];
        RewardsBalance[msg.sender] = 0;

        if (autocompound) {
            _stakeTokens(transferValue);
        } else {
            IERC20(mothoraGameContract.getEssence()).safeTransfer(msg.sender, transferValue);
        }
    }

    /**
     * @dev Returns the players' balances
     **/
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

    /**
     * @dev Returns the current number of staked artifacts
     * @return The number of staked artifacts
     **/
    function getPlayerArtifactsBalance(address _player) external view returns (uint256) {
        return playerStakedArtifactsBalance[_player];
    }

    /**
     * @dev Returns the current number of staked artifacts per faction
     * @return The number of staked artifacts
     **/
    function getFactionArtifactsBalance(uint256 _faction) external view returns (uint256) {
        return factionArtifactsBalance[_faction];
    }

    /**
     * @dev Returns the address of the Mothora Game Hub Contract
     * @return The Mothora Game address
     **/
    function getMothoraGame() public view returns (address) {
        return address(mothoraGameContract);
    }

    /**
     * @dev Updates the address of the Mothora Game
     * @param mothoraGameContractAddress The new Mothora Game address
     **/
    function setMothoraGame(address mothoraGameContractAddress) external onlyOwner {
        mothoraGameContract = MothoraGame(mothoraGameContractAddress);
        emit MothoraGameAddressUpdated(mothoraGameContractAddress);
    }

    /**
     * @dev Performs internal operations of staking, including adding the active account to the registry
     */
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

    /**
     * @dev Determines boost for the time locked up until now
     */
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

    function divider(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) public pure returns (uint256) {
        return ((numerator * (uint256(10)**uint256(precision + 1))) / denominator + 5) / uint256(10);
    }

    function unsafeInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }
}
