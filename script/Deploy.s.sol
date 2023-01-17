// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {Arena} from "src/modules/Arena.sol";
import {MothoraGame} from "src/MothoraGame.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    UUPSProxy proxy;
    MothoraGame wrappedProxyV1;

    /// @notice The main script entrypoint
    /// @return arena The arena contract
    function run() external returns (Arena arena) {
        vm.startBroadcast();
        arena = new Arena("https://api.mothora.xyz/endpoint");

        MothoraGame mothoraGameImplementation = new MothoraGame();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(mothoraGameImplementation), "");

        // wrap in ABI to support easier calls
        wrappedProxyV1 = MothoraGame(address(proxy));

        wrappedProxyV1.initialize();

        vm.stopBroadcast();
    }
}
