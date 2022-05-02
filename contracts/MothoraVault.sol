// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Player} from "./Player.sol";
import {GameItems} from "./GameItems.sol";
import {Essence} from "./Essence.sol";

contract MothoraVault is Ownable {

    //=========== DEPENDENCIES ============
    
    using SafeERC20 for IERC20;

    //============== STORAGE ==============

    //============== EVENTS ===============

    //============== VARIABLES ============

    mapping(address => uint256) public stakedESSBalance;

    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public timeTier;

    mapping(address => uint256) public lastClaimTime;

    mapping(address => uint256) public playerStakedPartsBalance;
    mapping(uint256 => uint256) public factionPartsBalance;

    // Creating instances of other contracts here
    IERC20 public EssenceAddress;
    address tokenAddress;
    GameItems GameItemsContract;
    Player PlayerContract;
    
    // Rewards Function variables
    uint256 totalStakedTime;
    uint256 totalStakedBalance;
    uint256 totalVaultPartsContributed;
    uint256 lastTimeUpdate;
    uint256 epochRewards;
    uint256 epochDuration;
    uint256 epochStartTime; 
    uint256 lastEpochTime;
    uint256 factor1;
    uint256 factor2;
    uint256 factor3;
    uint256 maxedfactor1;
    uint256 maxedfactor2;
    uint256 maxedfactor3;

    //===============Functions=============

    constructor(address _tokenAddress, address _gameitemsaddress, address _playercontractaddress,uint256 _epochRewardsPercentage, uint256 _epochDuration) {
        EssenceAddress = IERC20(_tokenAddress);
        GameItemsContract = GameItems(_gameitemsaddress);
        PlayerContract = Player(_playercontractaddress);
        epochRewards = (1000000*10**18)*_epochRewardsPercentage/100;
        epochDuration = _epochDuration;
        epochStartTime = block.timestamp;


    }

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0.");
        uint initialStakedAmount = stakedESSBalance[msg.sender];
        EssenceAddress.safeTransferFrom(msg.sender, address(this), _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 37 reverts
        stakedESSBalance[msg.sender] = stakedESSBalance[msg.sender] + _amount;
        if (initialStakedAmount == 0) {
            lastUpdate[msg.sender] = block.timestamp;
        } else {
            stakedDuration[msg.sender] = (block.timestamp - lastUpdate[msg.sender]) * (initialStakedAmount/stakedESSBalance[msg.sender]); //weighted average of balance & time staked
            lastUpdate[msg.sender] = block.timestamp;
        }

        totalStakedTime = totalStakedTime * (totalStakedBalance/(totalStakedBalance+_amount));
        totalStakedBalance = totalStakedBalance + _amount;
        lastTimeUpdate = block.timestamp;
    }

    function unstakeTokens(uint256 _amount) public {
        require(stakedESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakedESSBalance[msg.sender], "Cannot unstake more than your staked balance");
        EssenceAddress.safeTransferFrom(address(this), msg.sender, _amount);

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
        uint256 faction = PlayerContract.getFaction(msg.sender);
        factionPartsBalance[faction] = factionPartsBalance[faction] + _amount;
        totalVaultPartsContributed = totalVaultPartsContributed + _amount;
    }

    function CalculateTimeTier(address _playeraddress) private returns (uint256) {
        stakedDuration[msg.sender] = stakedDuration[msg.sender] + (block.timestamp - lastUpdate[msg.sender]);
        lastUpdate[msg.sender] = block.timestamp;
        if (stakedDuration[msg.sender] <= 86400) {
            timeTier[msg.sender] = 1;
        } else if (stakedDuration[msg.sender] >86400 && stakedDuration[msg.sender] <=172800) {
            timeTier[msg.sender] = uint256(13)/uint256(10);
        } else if (stakedDuration[msg.sender] >172800 && stakedDuration[msg.sender] <=432000) {
            timeTier[msg.sender] = uint256(16)/uint256(10);
        } else if (stakedDuration[msg.sender] >432000) {
            timeTier[msg.sender] = 2;
        }
        return timeTier[msg.sender];
    }

    function ClaimEpochRewards() external{
        lastEpochTime = epochStartTime + epochDuration*(((block.timestamp - epochStartTime)/epochDuration) % 1); //TODO confirm if this is giving you the number rounded (1,3 = 1)
        require(lastClaimTime[msg.sender] < lastEpochTime, "The player has already claimed in this epoch.");

        // World level factor calculation
        totalStakedTime = totalStakedTime + (block.timestamp - lastTimeUpdate);
        maxedfactor1 = totalStakedTime * totalStakedBalance;
        maxedfactor2 = totalVaultPartsContributed;
        maxedfactor3 = PlayerContract.totalFactionMembers(1)*factionPartsBalance[1]+PlayerContract.totalFactionMembers(2)*factionPartsBalance[2]+PlayerContract.totalFactionMembers(3)*factionPartsBalance[3];

        // player factor1 calculation
        factor1 = stakedESSBalance[msg.sender] * stakedDuration[msg.sender] / maxedfactor1;
        
        // player factor2 and factor3 calculation
        factor2 = playerStakedPartsBalance[msg.sender] / totalVaultPartsContributed;
        factor3 = factionPartsBalance[PlayerContract.getFaction(msg.sender)] / totalVaultPartsContributed;    

        // Calculation of player rewards (players' share of world)
        uint256 playerRewards = (epochRewards*90/100)*(factor1/maxedfactor1)+(epochRewards*7/100)*(factor2/maxedfactor2)+(epochRewards*3/100)*(factor3/maxedfactor3);

        EssenceAddress.safeTransferFrom(address(this), msg.sender, playerRewards);
        lastClaimTime[msg.sender] = block.timestamp;
    }   
    
}