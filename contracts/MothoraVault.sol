// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Player} from "./Player.sol";
import {GameItems} from "./GameItems.sol";
import {Essence} from "./Essence.sol";


contract MothoraVault is Ownable, ReentrancyGuard {
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

    // Creating instances of other contracts here
    IERC20 public essenceAddress;
    address tokenAddress;
    GameItems gameItemsContract;
    Player playerContract;

    // Rewards Function variables
    uint256 totalStakedBalance;
    uint256 totalVaultPartsContributed;
    uint256 lastDistributionTime;
    uint256 epochRewards;
    uint256 epochDuration;
    uint256 epochStartTime;
    uint256 lastEpochTime;
    uint256 maxedFactor1;
    uint256 maxedFactor2;
    uint256 maxedFactor3;
    address[] playerAddresses;
    uint256 playerId;
    address public a;

    //===============Functions=============

    constructor(
        address _tokenAddress,
        address _gameItemsAddress,
        address _playerContractAddress,
        uint256 _epochRewardsPercentage,
        uint256 _epochDuration
    ) {
        essenceAddress = IERC20(_tokenAddress);
        gameItemsContract = GameItems(_gameItemsAddress);
        playerContract = Player(_playerContractAddress);
        epochRewards = ((1000000 * 10**18) * _epochRewardsPercentage) / 100;
        epochDuration = _epochDuration;
        epochStartTime = block.timestamp;
    }

    function stakeTokens(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be more than 0.");
        uint256 initialStakedAmount = stakedESSBalance[msg.sender];
        essenceAddress.safeTransferFrom(msg.sender, address(this), _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 37 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] + _amount;
        if (initialStakedAmount == 0) {

            if (playerIds[msg.sender] == 0) {
                playerId++;
                playerIds[msg.sender] = playerId;
                playerAddresses.push(msg.sender);
            }
        } else {
            stakedDuration[msg.sender] =
                (block.timestamp - lastUpdate[msg.sender]) *
                (initialStakedAmount / stakedESSBalance[msg.sender]); //weighted average of balance & time staked
        }

        totalStakedBalance = totalStakedBalance + _amount;
    }

    function unstakeTokens(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be more than 0.");
        require(stakedESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakedESSBalance[msg.sender], "Cannot unstake more than your staked balance");
        essenceAddress.safeTransfer(msg.sender, _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 54 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] - _amount;
        totalStakedBalance = totalStakedBalance - _amount;
    }

    function contributeVaultParts(uint256 _amount) external {
        require(_amount > 0, "Amount must be more than 0");
        require(
            gameItemsContract.balanceOf(msg.sender, gameItemsContract.VAULTPARTS()) >= _amount,
            "The Player does not have enough Vault Parts"
        );

        // Transfer from player to Staking Contract
        gameItemsContract.safeTransferFrom(msg.sender, address(this), 1, _amount, "");

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 72 reverts
        playerStakedPartsBalance[msg.sender] = playerStakedPartsBalance[msg.sender] + _amount;
        uint256 faction = playerContract.getFaction(msg.sender);
        factionPartsBalance[faction] = factionPartsBalance[faction] + _amount;
        totalVaultPartsContributed = totalVaultPartsContributed + _amount;
    }

    function distributeRewards() external {
        // TODO add restriction of only distributing rewards once per epoch
        lastEpochTime = epochStartTime + epochDuration * (((block.timestamp - epochStartTime) / epochDuration) % 1); //TODO confirm if this is giving you the number rounded (eg 1.3 = 1)
        require(lastDistributionTime < lastEpochTime, "The player has already claimed in this epoch.");

        // World level maxedfactors calculation
        for (uint256 i = 1; i <= playerId; i++) {
            maxedFactor1 = maxedFactor1 + stakedESSBalance[playerAddresses[i]] * _calculateTimeTier(playerAddresses[i]);
        }
        maxedFactor2 = totalVaultPartsContributed;
        maxedFactor3 =
            playerContract.totalFactionMembers(1) *
            factionPartsBalance[1] +
            playerContract.totalFactionMembers(2) *
            factionPartsBalance[2] +
            playerContract.totalFactionMembers(3) *
            factionPartsBalance[3];

        // Distributes the rewards
        for (uint256 i = 1; i <= playerId; i++) {
            RewardsBalance[playerAddresses[i]] =
                RewardsBalance[playerAddresses[i]] +
                ((((stakedESSBalance[playerAddresses[i]] * _calculateTimeTier(playerAddresses[i])) / maxedFactor1) * 70) / 100) +
                (((playerStakedPartsBalance[playerAddresses[i]] / maxedFactor2) * 25) / 100) +
                (((factionPartsBalance[playerContract.getFaction(playerAddresses[i])] / maxedFactor3) * 5) / 100);
        }

        lastDistributionTime = block.timestamp;

    }

    function claimEpochRewards() external {
        essenceAddress.safeTransferFrom(address(this), msg.sender, RewardsBalance[msg.sender]);

        //QUESTION: these lines below should not run if transaction on line 151 reverts
        RewardsBalance[msg.sender] = 0;
    }

    function _calculateTimeTier(address _recipient) private returns (uint256) {
        stakedDuration[_recipient] = stakedDuration[_recipient] + (block.timestamp - lastUpdate[_recipient]);
        lastUpdate[_recipient] = block.timestamp;
        if (stakedDuration[_recipient] <= 86400) {
            timeTier[_recipient] = 1;
        } else if (stakedDuration[_recipient] > 86400 && stakedDuration[_recipient] <= 172800) {
            timeTier[_recipient] = uint256(13) / uint256(10);
        } else if (stakedDuration[_recipient] > 172800 && stakedDuration[_recipient] <= 432000) {
            timeTier[_recipient] = uint256(16) / uint256(10);
        } else if (stakedDuration[_recipient] > 432000) {
            timeTier[_recipient] = 2;
        }
        return timeTier[_recipient];
    }
}
