// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;
// import {MothoraGame} from "src/MothoraGame.sol";
// import {IMothoraGame} from "src/interfaces/IMothoraGame.sol";

// // Test imports
// import {MockERC20} from "./mocks/MockERC20.sol";
// import {Wallet} from "./utils/Wallet.sol";
// import "./utils/BaseTest.sol";

// contract MothoraGameTest is BaseTest {
//     MothoraGame internal mothoraGame;
//     Wallet internal tokenOwner;

//     // signature state
//     bytes32 internal TYPEHASH;
//     bytes32 internal nameHash;
//     bytes32 internal versionHash;
//     bytes32 internal typehashEip712;
//     bytes32 internal domainSeparator;

//     function setUp() public override {
//         super.setUp();

//         mothoraGame = MothoraGame(payable(getContract("MothoraGame")));

//         tokenOwner = getWallet();

//         // create account signature preparation steps

//         TYPEHASH = keccak256(
//             "NewAccountRequest(address targetAddress,uint256 dao,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
//         );
//         nameHash = keccak256(bytes("MothoraGame"));
//         versionHash = keccak256(bytes("1"));
//         typehashEip712 = keccak256(
//             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
//         );
//         domainSeparator = keccak256(
//             abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(mothoraGame))
//         );
//     }

//     function signOpenRequest(
//         IMothoraGame.NewAccountRequest memory _request,
//         uint256 _privateKey
//     ) internal view returns (bytes memory) {
//         bytes memory encodedRequest = abi.encode(
//             TYPEHASH,
//             _request.targetAddress,
//             _request.dao,
//             _request.validityStartTimestamp,
//             _request.validityEndTimestamp,
//             _request.uid
//         );
//         bytes32 structHash = keccak256(encodedRequest);
//         bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
//         bytes memory sig = abi.encodePacked(r, s, v);

//         return sig;
//     }

//     /*///////////////////////////////////////////////////////////////
//                         Unit tests: Account creation
//     //////////////////////////////////////////////////////////////*/

//     function test_revert_account_creation_invalid_dao() public {
//         address player = address(0x123);
//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 4,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         vm.expectRevert(IMothoraGame.INVALID_DAO.selector);
//         mothoraGame.createAccount(newAccountRequest, signature);
//     }

//     function test_account_creation_shadow_council() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         (uint256 dao, ) = mothoraGame.getAccount(player);
//         assertEq(dao, 1);

//         address[] memory allDAOMembers = mothoraGame.getAllActivePlayersByDao(dao);
//         assertEq(allDAOMembers.length, 1);
//     }

//     function test_revert_already_has_faction() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(player);
//         vm.expectRevert(IMothoraGame.PLAYER_ALREADY_HAS_DAO.selector);
//         mothoraGame.createAccount(newAccountRequest, signature);
//     }

//     /*///////////////////////////////////////////////////////////////
//                         Unit tests: Defection
//     //////////////////////////////////////////////////////////////*/

//     function test_defect() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(player);
//         mothoraGame.defect(2);

//         (uint256 dao, ) = mothoraGame.getAccount(player);

//         assertEq(dao, 2);

//         address[] memory allDAOMembers = mothoraGame.getAllActivePlayersByDao(1);

//         assertEq(allDAOMembers.length, 0);

//         allDAOMembers = mothoraGame.getAllActivePlayersByDao(2);

//         assertEq(allDAOMembers.length, 1);
//     }

//     function test_revert_defect_twice_same_dao() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);
//         vm.startPrank(player);

//         mothoraGame.createAccount(newAccountRequest, signature);

//         mothoraGame.defect(2);

//         vm.expectRevert(IMothoraGame.CANNOT_DEFECT_TO_SAME_DAO.selector);
//         mothoraGame.defect(2);

//         vm.stopPrank();
//     }

//     /*///////////////////////////////////////////////////////////////
//                         Unit tests: Freezing accounts
//     //////////////////////////////////////////////////////////////*/

//     function test_freezing_account() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(deployer);
//         mothoraGame.changeFreezeStatus(player, true);

//         (, bool freezeStatus) = mothoraGame.getAccount(player);

//         assert(freezeStatus);
//     }

//     function test_revert_defect_while_frozen() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(deployer);
//         mothoraGame.changeFreezeStatus(player, true);

//         vm.prank(player);
//         vm.expectRevert(IMothoraGame.ACCOUNT_NOT_ACTIVE.selector);
//         mothoraGame.defect(2);
//     }

//     function test_unfreezing_account() public {
//         address player = address(0x123);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(deployer);
//         mothoraGame.changeFreezeStatus(player, true);

//         vm.prank(deployer);
//         mothoraGame.changeFreezeStatus(player, false);
//         (, bool freezeStatus) = mothoraGame.getAccount(player);

//         assert(!freezeStatus);
//     }

//     /*///////////////////////////////////////////////////////////////
//                         Unit tests: Getters
//     //////////////////////////////////////////////////////////////*/

//     function test_return_all_accounts_in_dao() public {
//         address player1 = address(0x1231);
//         address player2 = address(0x1232);
//         address player3 = address(0x1233);
//         address player4 = address(0x1234);

//         IMothoraGame.NewAccountRequest memory newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player1,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });

//         // request must be signed with private key of deployer
//         bytes memory signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player1);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player2,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });
//         signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player2);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player3,
//             dao: 1,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });
//         signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player3);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         newAccountRequest = IMothoraGame.NewAccountRequest({
//             targetAddress: player4,
//             dao: 2,
//             validityStartTimestamp: 0,
//             validityEndTimestamp: 2000,
//             uid: bytes32(0)
//         });
//         signature = signOpenRequest(newAccountRequest, privateKey);

//         vm.prank(player4);
//         mothoraGame.createAccount(newAccountRequest, signature);

//         vm.prank(deployer);
//         mothoraGame.changeFreezeStatus(player2, true);

//         address[] memory players = mothoraGame.getAllActivePlayersByDao(1);

//         for (uint256 i = 0; i < players.length; i++) {
//             if (players[i] == player1) {
//                 assert(true);
//             } else if (players[i] == player3) {
//                 assert(true);
//             } else {
//                 assert(false);
//             }
//         }
//         assertEq(players.length, 2);
//     }
// }
