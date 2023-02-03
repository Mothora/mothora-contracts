// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {MothoraGame} from "src/MothoraGame.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    UUPSProxy proxy;

    /// @notice The main script entrypoint
    /// @return wrappedProxyV1 The MothoraGame contract
    function run() external returns (MothoraGame wrappedProxyV1) {
        vm.startBroadcast();
        MothoraGame mothoraGameImplementation = new MothoraGame();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(mothoraGameImplementation), "");

        // wrap in ABI to support easier calls
        wrappedProxyV1 = MothoraGame(address(proxy));

        wrappedProxyV1.initialize();

        vm.stopBroadcast();
    }
}
