// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Contracts
import {Arena} from "src/modules/Arena.sol";
import {IArena} from "src/interfaces/IArena.sol";
// Libs
import {Merkle} from "@murky/Merkle.sol";
// Test Utils
import {MockERC20} from "./mocks/MockERC20.sol";
import {Wallet} from "./utils/Wallet.sol";
import "./utils/BaseTest.sol";

contract ArenaTest is BaseTest {
    Merkle merkle = new Merkle();

    Arena internal arena;
    Wallet internal tokenOwner;

    address internal alice = address(0x1);
    address internal bob = address(0x2);
    address internal carol = address(0x3);

    struct PlayerData {
        address player;
        uint256 K;
        uint256 D;
        uint256 A;
        uint256 essenceEarned;
    }
    PlayerData[] internal playerData;

    function setUp() public override {
        super.setUp();

        arena = Arena(payable(getContract("Arena")));

        tokenOwner = getWallet();

        playerData.push(PlayerData({player: alice, K: 10, D: 4, A: 2, essenceEarned: 100}));
        playerData.push(PlayerData({player: bob, K: 20, D: 3, A: 6, essenceEarned: 250}));
        playerData.push(PlayerData({player: carol, K: 5, D: 6, A: 1, essenceEarned: 30}));
    }

    function createLeaves(PlayerData[] memory _playerData) public pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](_playerData.length);
        for (uint256 i; i < _playerData.length; ++i) {
            PlayerData memory playerData_ = _playerData[i];

            leaves[i] = keccak256(
                abi.encodePacked(
                    playerData_.player,
                    playerData_.K,
                    playerData_.D,
                    playerData_.A,
                    playerData_.essenceEarned
                )
            );
        }

        return leaves;
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Postgame posting
    //////////////////////////////////////////////////////////////*/

    function test_revert_end_match_invalid_root() public {
        bytes32 root;

        uint256 matchId_1 = 1;
        vm.prank(deployer);
        vm.expectRevert(IArena.NULL_MERKLE_ROOT.selector);
        arena.endMatch(matchId_1, root);
    }

    function test_end_match() public {
        PlayerData[] memory _playerData = playerData;
        bytes32[] memory leaves = createLeaves(_playerData);
        bytes32 root;

        root = merkle.getRoot(leaves);

        uint256 matchId_1 = 1;
        vm.prank(deployer);
        arena.endMatch(matchId_1, root);
    }

    function test_revert_end_match_same_id() public {
        PlayerData[] memory _playerData = playerData;

        bytes32[] memory leaves = createLeaves(_playerData);
        bytes32 root;

        root = merkle.getRoot(leaves);

        uint256 matchId_1 = 1;
        vm.prank(deployer);
        arena.endMatch(matchId_1, root);

        vm.prank(deployer);
        vm.expectRevert(IArena.MATCH_ALREADY_POSTED.selector);
        arena.endMatch(matchId_1, root);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Merkle proof verification
    //////////////////////////////////////////////////////////////*/

    function test_revert_invalid_proof() public {
        PlayerData[] memory _playerData = playerData;

        bytes32[] memory leaves = createLeaves(_playerData);
        bytes32 root;

        root = merkle.getRoot(leaves);

        uint256 matchId_1 = 1;
        vm.prank(deployer);
        arena.endMatch(matchId_1, root);
        bytes32[] memory proof = merkle.getProof(leaves, 1); // bob is node 1

        PlayerData memory playerDataWrong = PlayerData({player: bob, K: 21, D: 3, A: 6, essenceEarned: 250});

        vm.expectRevert(IArena.INVALID_PROOF.selector);
        arena.checkValidityOfPlayerData(
            matchId_1,
            playerDataWrong.player,
            playerDataWrong.K,
            playerDataWrong.D,
            playerDataWrong.A,
            playerDataWrong.essenceEarned,
            proof
        );
    }

    function test_correct_proof() public {
        PlayerData[] memory _playerData = playerData;

        bytes32[] memory leaves = createLeaves(_playerData);
        bytes32 root;

        root = merkle.getRoot(leaves);

        uint256 matchId_1 = 1;
        vm.prank(deployer);
        arena.endMatch(matchId_1, root);
        bytes32[] memory proof = merkle.getProof(leaves, 1); // bob is node 1

        PlayerData memory playerDataCorrect = PlayerData({player: bob, K: 20, D: 3, A: 6, essenceEarned: 250});

        bool result = arena.checkValidityOfPlayerData(
            matchId_1,
            playerDataCorrect.player,
            playerDataCorrect.K,
            playerDataCorrect.D,
            playerDataCorrect.A,
            playerDataCorrect.essenceEarned,
            proof
        );

        assertTrue(result);
    }
}
