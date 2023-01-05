// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {MothoraGame} from "contracts/MothoraGame.sol";
import {IMothoraGame} from "contracts/interfaces/IMothoraGame.sol";

// Test imports
import {MockERC20} from "./mocks/MockERC20.sol";
import {Wallet} from "./utils/Wallet.sol";
import "./utils/BaseTest.sol";

contract MothoraGameTest is BaseTest {
    MothoraGame internal mothoraGame;
    Wallet internal tokenOwner;

    function setUp() public override {
        super.setUp();

        mothoraGame = MothoraGame(payable(getContract("MothoraGame")));

        tokenOwner = getWallet();
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Account creation
    //////////////////////////////////////////////////////////////*/

    function test_revert_account_creation_invalid_dao() public {
        address player = address(0x123);

        vm.prank(player);
        vm.expectRevert(IMothoraGame.INVALID_DAO.selector);
        mothoraGame.createAccount(4);
    }

    function test_account_creation_shadow_council() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);

        (uint256 dao, ) = mothoraGame.getAccount(player);
        assertEq(dao, 1);

        address[] memory allDAOMembers = mothoraGame.getAllActivePlayersByDao(dao);
        assertEq(allDAOMembers.length, 1);
    }

    function test_revert_already_has_faction() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);
        vm.prank(player);

        vm.expectRevert(IMothoraGame.PLAYER_ALREADY_HAS_DAO.selector);
        mothoraGame.createAccount(1);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Defection
    //////////////////////////////////////////////////////////////*/

    function test_defect() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);

        vm.prank(player);
        mothoraGame.defect(2);

        (uint256 dao, ) = mothoraGame.getAccount(player);

        assertEq(dao, 2);

        address[] memory allDAOMembers = mothoraGame.getAllActivePlayersByDao(1);

        assertEq(allDAOMembers.length, 0);

        allDAOMembers = mothoraGame.getAllActivePlayersByDao(2);

        assertEq(allDAOMembers.length, 1);
    }

    function test_revert_defect_twice_same_dao() public {
        address player = address(0x123);

        vm.startPrank(player);
        mothoraGame.createAccount(1);

        mothoraGame.defect(2);

        vm.expectRevert(IMothoraGame.CANNOT_DEFECT_TO_SAME_DAO.selector);
        mothoraGame.defect(2);

        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Freezing accounts
    //////////////////////////////////////////////////////////////*/

    function test_freezing_account() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);

        vm.prank(deployer);
        mothoraGame.changeFreezeStatus(player, true);

        (, bool freezeStatus) = mothoraGame.getAccount(player);

        assert(freezeStatus);
    }

    function test_revert_defect_while_frozen() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);

        vm.prank(deployer);
        mothoraGame.changeFreezeStatus(player, true);

        vm.prank(player);
        vm.expectRevert(IMothoraGame.ACCOUNT_NOT_ACTIVE.selector);
        mothoraGame.defect(2);
    }

    function test_unfreezing_account() public {
        address player = address(0x123);

        vm.prank(player);
        mothoraGame.createAccount(1);

        vm.prank(deployer);
        mothoraGame.changeFreezeStatus(player, true);

        vm.prank(deployer);
        mothoraGame.changeFreezeStatus(player, false);
        (, bool freezeStatus) = mothoraGame.getAccount(player);

        assert(!freezeStatus);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Getters
    //////////////////////////////////////////////////////////////*/

    function test_return_all_accounts_in_dao() public {
        address player1 = address(0x1231);
        address player2 = address(0x1232);
        address player3 = address(0x1233);
        address player4 = address(0x1234);

        vm.prank(player1);
        mothoraGame.createAccount(1);
        vm.prank(player2);
        mothoraGame.createAccount(1);
        vm.prank(player3);
        mothoraGame.createAccount(1);
        vm.prank(player4);
        mothoraGame.createAccount(2);

        vm.prank(deployer);
        mothoraGame.changeFreezeStatus(player2, true);

        address[] memory players = mothoraGame.getAllActivePlayersByDao(1);

        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player1) {
                assert(true);
            } else if (players[i] == player3) {
                assert(true);
            } else {
                assert(false);
            }
        }
        assertEq(players.length, 2);
    }
}
