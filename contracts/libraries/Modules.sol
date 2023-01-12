// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library Modules {
    //Core modules
    bytes32 private constant ARENA_MODULE = "ARENA_MODULE"; // Manages the postmatch results representation and reward distribution to players
    bytes32 private constant DAO_MODULE = "DAO_MODULE"; // DAO representation and staking module
    bytes32 private constant ESSENCE_MODULE = "ESSENCE_MODULE"; // Fungible non-tradeable in-game currency
}
