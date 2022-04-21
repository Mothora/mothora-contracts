// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PlayerContract} from "./Player.sol";

contract PlayerVault is Ownable, PlayerContract {

    //===============Storage===============

    //===============Events================

    //===============Variables=============

    mapping(address => uint256) public stakingESSBalance;

    mapping(address => uint256) public stakingPartsBalance;

    IERC20 public EssenceAddress;

    //===============Functions=============

    constructor(address _tokenAddress) public {
        EssenceAddress = IERC20(_tokenAddress);
    }

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        IERC20(EssenceAddress).transferFrom(msg.sender, address(this), _amount);
        stakingESSBalance[msg.sender] = stakingESSBalance[msg.sender] + _amount;
    }

    function unstakeTokens(uint256 _amount) public {
        require(stakingESSBalance[msg.sender] > 0, "Staking balance cannot be 0");
        require(_amount <= stakingESSBalance[msg.sender], "Cannot unstake more than your staked balance");
        IERC20(EssenceAddress).transfer(msg.sender, _amount);
        stakingESSBalance[msg.sender] = stakingESSBalance[msg.sender] - _amount;
    }

    // change to NFT 1155
    function stakeVaultParts(uint256 _amount) public {
        require(_amount > 0, "Amount must be more than 0");
        require(_amount <= players[msg.sender].nrVaultParts, "The Player does not have enough vault parts.");
        players[msg.sender].nrVaultParts = players[msg.sender].nrVaultParts - _amount;
        stakingPartsBalance[msg.sender] = stakingPartsBalance[msg.sender] + _amount;

    }

    // claimrewards -> implies definicao funcao de reward bastante superior a 20% APR
    // Vault parts ERC1155 - imagem qualet
}