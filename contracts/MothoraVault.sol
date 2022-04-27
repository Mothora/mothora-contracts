// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PlayerContract} from "./Player.sol";
import {GameItems} from "./GameItems.sol";
import {Essence} from "./Essence.sol";

contract PlayerVault is Ownable {

    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping(address => uint256) public stakedESSBalance;

    mapping(address => uint256) public stakedTime;

    mapping(address => uint256) public lastClaimTime;

    mapping(address => uint256) public playerStakedPartsBalance;
    mapping(uint256 => uint256) public factionPartsBalance;

    // Creating instances of other contracts here
    IERC20 public EssenceAddress;
    address tokenAddress;
    GameItems GameItemsContract;
    PlayerContract PlayerContract1;
    
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

    //===============Functions=============

    constructor(address _tokenAddress, address _gameitemsaddress, address _playercontractaddress, uint _epochRewards, uint _epochDuration) public {
        tokenAddress = _tokenAddress;
        EssenceAddress = IERC20(_tokenAddress);
        GameItemsContract = GameItems(_gameitemsaddress);
        PlayerContract1 = PlayerContract(_playercontractaddress);
        epochRewards = _epochRewards;
        epochDuration = _epochDuration;
        epochStartTime = block.timestamp;

    }

    function pullFunds(uint _amount) external onlyOwner {
        EssenceAddress.transferFrom(tokenAddress, address(this), _amount);
    }

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        uint initialStakedAmount = stakedESSBalance[msg.sender];
        EssenceAddress.transferFrom(msg.sender, address(this), _amount); // TODO move this to safeTransferFrom - error is happening

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 37 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] + _amount;
        if (initialStakedAmount == 0) {
            stakedTime[msg.sender] = block.timestamp;
        } else {
            stakedTime[msg.sender] = stakedTime[msg.sender] * (initialStakedAmount/stakedESSBalance[msg.sender]); //weighted average of balance & time staked
        }

        totalStakedTime = totalStakedTime * (totalStakedBalance/(totalStakedBalance+_amount));
        totalStakedBalance = totalStakedBalance + _amount;
        lastTimeUpdate = block.timestamp;
    }

    function unstakeTokens(uint256 _amount) public {
        require(stakedESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakedESSBalance[msg.sender], "Cannot unstake more than your staked balance");
        EssenceAddress.transferFrom(address(this), msg.sender, _amount); // TODO move this to safeTransferFrom - error is happening

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 54 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] - _amount;
        totalStakedBalance = totalStakedBalance - _amount;
    }

    function ContributeVaultParts(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        require(GameItemsContract.balanceOf(msg.sender, GameItemsContract.VAULTPARTS()) >= _amount, "The Player does not have enough Vault Parts");

        // Transfer from player to Staking Contract
        GameItemsContract.safeTransferFrom(msg.sender, address(this), 1, _amount,"");

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 72 reverts
        playerStakedPartsBalance[msg.sender] = playerStakedPartsBalance[msg.sender] + _amount;
        uint256 faction = PlayerContract1.getFaction(msg.sender);
        factionPartsBalance[faction] = factionPartsBalance[faction] + _amount;
        totalVaultPartsContributed = totalVaultPartsContributed + _amount;
    }


    function ClaimEpochRewards() external{
        lastEpochTime = epochStartTime + epochDuration*(((block.timestamp - epochStartTime)/epochDuration) % 1); //TODO confirm if this is giving you the number rounded (1,3 = 1)
        require(lastClaimTime[msg.sender] < lastEpochTime, "The player has already claimed in this epoch.");

        // player factor1 calculation
        totalStakedTime = totalStakedTime + (block.timestamp - lastTimeUpdate);
        totalStakedTimeAmountValue = totalStakedTime * totalStakedBalance;
        uint256 factor1 = stakedESSBalance[msg.sender] * stakedTime[msg.sender] / totalStakedTimeAmountValue;
        
        // player factor2 and factor3 calculation
        uint256 factor2 = playerStakedPartsBalance[msg.sender] / totalVaultPartsContributed;
        uint256 factor3 = factionPartsBalance[PlayerContract1.getFaction(msg.sender)] / totalVaultPartsContributed;

        // World level factor calculation
        uint256 maxedfactor1 = totalStakedTimeAmountValue;
        uint256 maxedfactor2 = totalVaultPartsContributed;
        uint256 maxedfactor3 = PlayerContract1.totalFactionMembers(1)*factionPartsBalance[1]+PlayerContract1.totalFactionMembers(2)*factionPartsBalance[2]+PlayerContract1.totalFactionMembers(3)*factionPartsBalance[3];
        
        // Calculation of player rewards (players' share of world)
        uint256 playerRewards = (epochRewards*90/100)*(factor1/maxedfactor1)+(epochRewards*7/100)*(factor2/maxedfactor2)+(epochRewards*3/100)*(factor3/maxedfactor3);

        EssenceAddress.transferFrom(address(this), msg.sender, _amount); // TODO move this to safeTransferFrom - error is happening
        lastClaimTime[msg.sender] = block.timestamp;
    }   
    
}