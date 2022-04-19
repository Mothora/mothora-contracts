// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Essence is ERC20 {

    constructor() ERC20("Essence", "ESSE"){
        _mint(msg.sender,1000000000*10**18); // 1bi tokens // msg.sender should be the main vault
    }

}