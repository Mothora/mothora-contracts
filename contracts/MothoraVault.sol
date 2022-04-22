// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PlayerContract} from "./Player.sol";
import {GameItems} from "./GameItems.sol";

contract PlayerVault is Ownable {

    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping(address => uint256) public stakedESSBalance;

    mapping(address => uint256) public stakedTime;

    mapping(string => uint256) public stakedPartsBalance;

    IERC20 public EssenceAddress;

    GameItems GameItemsContract;  
    Player PlayerContract;

    //===============Functions=============

    constructor(address _tokenAddress, address _gameitemsaddress, address _playercontractaddress) public {
        EssenceAddress = IERC20(_tokenAddress);
        GameItemsContract = GameItems(_gameitemsaddress);
        PlayerContract = Player(_playercontractaddress);
    }

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");

        // Get Initial State
        uint memory initialStakedAmount = stakingESSBalance[msg.sender];

        // Transfer from player to Staking Contract
        IERC20(EssenceAddress).safeTransferFrom(msg.sender, address(this), _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 37 reverts
        stakingESSBalance[msg.sender] = stakingESSBalance[msg.sender] + _amount;
        if (initialStakedAmount = 0) {
            stakedTime[msg.sender] = block.timestamp;
        } else {
            stakedTime[msg.sender] = stakedTime[msg.sender] * (initialStakedAmount/stakingESSBalance[msg.sender]); //weighted average of balance & time staked
        }
        
    }

    function unstakeTokens(uint256 _amount) public {
        require(stakingESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakingESSBalance[msg.sender], "Cannot unstake more than your staked balance");

        // Transfer from Staking Contract to player
        IERC20(EssenceAddress).safeTransfer(msg.sender, _amount);

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 54 reverts
        stakingESSBalance[msg.sender] = stakingESSBalance[msg.sender] - _amount;
    }

    // change to NFT 1155
    function ContributeVaultParts(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        require(GameItemsContract.balanceOf(msg.sender, 1) >= _amount, "The Player does not have enough Vault Parts");

        // Transfer from player to Staking Contract
        GameItemsContract.safeTransferFrom(msg.sender, address(this), 1, _amount,"");

        // Calculate Final State - QUESTION: these lines below should not run if transaction on line 72 reverts
        string memory faction = PlayerContract.getFaction(msg.sender);
        stakingPartsBalance[faction] = stakingPartsBalance[faction] + _amount;

    }


    uint256 APR = 0.15;
    uint256 totalStakedBalance;
    uint256 totalStakedTime;
    uint256 totalVaultPartsContributed;

    // claimrewards -> implies definicao funcao de reward bastante superior a 15% APR
    function ClaimRewards() external{
        
    }
    
}