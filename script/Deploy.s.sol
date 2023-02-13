// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {MothoraGame} from "src/MothoraGame.sol";
import {Arena} from "src/modules/Arena.sol";

import {EssenceToken} from "src/modules/EssenceToken.sol";
import {MockUSDC} from "src/modules/MockUSDC.sol";
import {RewardsPipeline} from "src/modules/RewardsPipeline.sol";
import {DAOReactorFactory} from "src/modules/dao/DAOReactorFactory.sol";
import {DAOReactor} from "src/modules/dao/DAOReactor.sol";
import {StreamSystem} from "src/modules/StreamSystem.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    UUPSProxy proxy;

    /// @notice The main script entrypoint
    /// @return mothoraGame The MothoraGame contract
    /// @return arena The Arena contract
    /// @return essenceToken The EssenceToken contract
    /// @return streamSystem The StreamSystem contract
    /// @return usdc The MockUSDC contract
    /// @return daoReactorFactory The DAOReactorFactory contract
    /// @return rewards The RewardsPipeline contract
    function run()
        external
        returns (
            MothoraGame mothoraGame,
            Arena arena,
            EssenceToken essenceToken,
            StreamSystem streamSystem,
            MockUSDC usdc,
            DAOReactorFactory daoReactorFactory,
            RewardsPipeline rewards
        )
    {
        vm.startBroadcast();

        /// @dev mothora game
        MothoraGame mothoraGameImplementation = new MothoraGame();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(mothoraGameImplementation), "");

        // wrap in ABI to support easier calls
        mothoraGame = MothoraGame(address(proxy));

        mothoraGame.initialize();

        /// @dev Arena contract (non upgradeable)

        arena = new Arena("https://");

        /// @dev Essence token (non upgradeable)

        essenceToken = new EssenceToken(address(arena));

        /// @dev Stream system

        StreamSystem streamSystemImplementation = new StreamSystem();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(streamSystemImplementation), "");

        // wrap in ABI to support easier calls
        streamSystem = StreamSystem(address(proxy));

        // Mock USDC as a reward token (localhost deployment)
        usdc = new MockUSDC("USDC", "USDC");

        streamSystem.initialize(address(usdc));

        /// @dev DAO reactor factory

        DAOReactorFactory daoReactorFactoryImplementation = new DAOReactorFactory();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(daoReactorFactoryImplementation), "");

        // wrap in ABI to support easier calls
        daoReactorFactory = DAOReactorFactory(address(proxy));

        // DaoReactor Implementation for factor intialization
        DAOReactor daoReactorImplementation = new DAOReactor();

        /// Rewards pipeline deployment for Dao Reactor Factory initialization
        /// @dev WARNING: todo analyze this for security issues
        RewardsPipeline rewardsImplementation = new RewardsPipeline();

        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(rewardsImplementation), "");

        daoReactorFactory.initialize(msg.sender, usdc, essenceToken, rewards, address(daoReactorImplementation));

        // Initialization of rewards right after the factory initialize
        rewards = RewardsPipeline(address(proxy));

        rewards.initialize(msg.sender, streamSystem, daoReactorFactory);

        // Deploy three DAO reactors
        daoReactorFactory.deployDAOReactor(msg.sender);
        daoReactorFactory.deployDAOReactor(msg.sender);
        daoReactorFactory.deployDAOReactor(msg.sender);

        vm.stopBroadcast();
    }
}
