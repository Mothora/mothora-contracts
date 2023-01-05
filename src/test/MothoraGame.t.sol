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

        uint256 dao = mothoraGame.getPlayerDAO(player);
        assertEq(dao, 1);

        uint256 totalDAOMembers = mothoraGame.totalDAOMembers(dao);
        assertEq(totalDAOMembers, 1);
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

        uint256 dao = mothoraGame.getPlayerDAO(player);
        assertEq(dao, 2);

        uint256 totalDAOMembers = mothoraGame.totalDAOMembers(1);
        assertEq(totalDAOMembers, 0);

        totalDAOMembers = mothoraGame.totalDAOMembers(2);
        assertEq(totalDAOMembers, 1);
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

        bool freezeStatus = mothoraGame.getPlayerStatus(player);

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
        bool freezeStatus = mothoraGame.getPlayerStatus(player);

        assert(!freezeStatus);
    }
}
