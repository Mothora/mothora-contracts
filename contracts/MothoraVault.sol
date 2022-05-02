// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Player} from "./Player.sol";
import {GameItems} from "./GameItems.sol";
import {Essence} from "./Essence.sol";

contract MothoraVault is Ownable {
    using SafeERC20 for IERC20;

    //===============Storage===============

    mapping(address => uint256) public stakedESSBalance;

    mapping(address => uint256) public stakedTime;

    mapping(address => uint256) public lastClaimTime;

    mapping(address => uint256) public playerStakedPartsBalance;
    mapping(uint256 => uint256) public factionPartsBalance;

    // Creating instances of other contracts here
    IERC20 public essenceAddress;
    address tokenAddress;
    GameItems gameItemsContract;
    Player playerContract;

    // Rewards Function variables
    uint256 totalStakedTime;
    uint256 totalStakedBalance;
    uint256 totalStakedTimeAmountValue;
    uint256 totalVaultPartsContributed;
    uint256 lastTimeUpdate;
    uint256 epochRewards;
    uint256 epochDuration;
    uint256 epochStartTime;
    uint256 lastEpochTime;
    uint256 factor1;
    uint256 factor2;
    uint256 factor3;
    uint256 maxedFactor1;
    uint256 maxedFactor2;
    uint256 maxedFactor3;

    //===============Functions=============

    constructor(
        address _tokenAddress,
        address _gameItemsAddress,
        address _playerContractAddress,
        uint256 _epochRewardsAPR,
        uint256 _epochDuration
    ) {
        tokenAddress = _tokenAddress;
        essenceAddress = IERC20(_tokenAddress);
        gameItemsContract = GameItems(_gameItemsAddress);
        playerContract = Player(_playerContractAddress);
        epochRewards = ((1000000 * 10**18) * _epochRewardsAPR) / 100;
        epochDuration = _epochDuration;
        epochStartTime = block.timestamp;
    }

    function pullFunds(uint256 _amount) external onlyOwner {
        essenceAddress.safeTransferFrom(tokenAddress, address(this), _amount);
    }

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        uint256 initialStakedAmount = stakedESSBalance[msg.sender];
        essenceAddress.safeTransferFrom(msg.sender, address(this), _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 37 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] + _amount;
        if (initialStakedAmount == 0) {
            stakedTime[msg.sender] = block.timestamp;
        } else {
            stakedTime[msg.sender] = stakedTime[msg.sender] * (initialStakedAmount / stakedESSBalance[msg.sender]); //weighted average of balance & time staked
        }

        totalStakedTime = totalStakedTime * (totalStakedBalance / (totalStakedBalance + _amount));
        totalStakedBalance = totalStakedBalance + _amount;
        lastTimeUpdate = block.timestamp;
    }

    function unstakeTokens(uint256 _amount) public {
        require(stakedESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakedESSBalance[msg.sender], "Cannot unstake more than your staked balance");
        essenceAddress.safeTransferFrom(address(this), msg.sender, _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 54 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] - _amount;
        totalStakedBalance = totalStakedBalance - _amount;
    }

    function contributeVaultParts(uint256 _amount) public {
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

    function claimEpochRewards() external {
        //TODO confirm if this is giving you the number rounded (1,3 = 1)
        // CAREFUL - block.timestamp may not work as expected in Layer 2s (where tx speed is high). May need a time oracle.
        lastEpochTime = epochStartTime + epochDuration * (((block.timestamp - epochStartTime) / epochDuration) % 1);
        require(lastClaimTime[msg.sender] < lastEpochTime, "The player has already claimed in this epoch.");

        // player factor1 calculation
        totalStakedTime = totalStakedTime + (block.timestamp - lastTimeUpdate);
        totalStakedTimeAmountValue = totalStakedTime * totalStakedBalance;
        factor1 = (stakedESSBalance[msg.sender] * stakedTime[msg.sender]) / totalStakedTimeAmountValue;

        // player factor2 and factor3 calculation
        factor2 = playerStakedPartsBalance[msg.sender] / totalVaultPartsContributed;
        factor3 = factionPartsBalance[playerContract.getFaction(msg.sender)] / totalVaultPartsContributed;

        // World level factor calculation
        maxedFactor1 = totalStakedTimeAmountValue;
        maxedFactor2 = totalVaultPartsContributed;
        maxedFactor3 =
            playerContract.totalFactionMembers(1) *
            factionPartsBalance[1] +
            playerContract.totalFactionMembers(2) *
            factionPartsBalance[2] +
            playerContract.totalFactionMembers(3) *
            factionPartsBalance[3];

        // Calculation of player rewards (players' share of world)
        uint256 playerRewards = ((epochRewards * 90) / 100) *
            (factor1 / maxedFactor1) +
            ((epochRewards * 7) / 100) *
            (factor2 / maxedFactor2) +
            ((epochRewards * 3) / 100) *
            (factor3 / maxedFactor3);

        essenceAddress.safeTransferFrom(address(this), msg.sender, playerRewards);
        lastClaimTime[msg.sender] = block.timestamp;
    }
}
