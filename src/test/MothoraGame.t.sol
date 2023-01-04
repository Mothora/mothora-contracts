// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";
import {Booster, IERC2981Upgradeable} from "contracts/Booster.sol";
import {IBooster} from "contracts/interfaces/IBooster.sol";
import {ITokenBundle} from "contracts/extension/interfaces/ITokenBundle.sol";

// Test imports
import {MockERC20} from "./mocks/MockERC20.sol";
import {Wallet} from "./utils/Wallet.sol";
import "./utils/BaseTest.sol";

contract MothoraGameTest is BaseTest {
    /// @notice Emitted when a set of boosters is created.
    event BoosterCreated(uint256 indexed boosterId, address recipient, uint256 totalBoostersCreated);

    /// @notice Emitted when a booster is opened.
    event BoosterOpened(
        uint256 indexed boosterId,
        address indexed opener,
        uint256 numOfBoostersOpened,
        ITokenBundle.Token[] rewardUnitsDistributed
    );

    Booster internal booster;

    Wallet internal tokenOwner;
    string internal boosterUri;
    ITokenBundle.Token[] internal boosterContents;
    ITokenBundle.Token[] internal additionalContents;
    uint256[] internal numOfRewardUnits;
    uint256[] internal additionalContentsRewardUnits;

    // signature state
    bytes32 internal typehashOpenRequest;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    function setUp() public override {
        super.setUp();

        booster = Booster(payable(getContract("Booster")));
        //console2.log("Minter : ", booster.hasRole(booster.MINTER_ROLE(), deployer));

        tokenOwner = getWallet();
        boosterUri = "ipfs://";

        boosterContents.push(
            ITokenBundle.Token({
                assetContract: address(erc1155),
                tokenType: ITokenBundle.TokenType.ERC1155,
                tokenId: 0,
                totalAmount: 100
            })
        );
        numOfRewardUnits.push(20);

        boosterContents.push(
            ITokenBundle.Token({
                assetContract: address(erc1155),
                tokenType: ITokenBundle.TokenType.ERC1155,
                tokenId: 1,
                totalAmount: 500
            })
        );
        numOfRewardUnits.push(50);

        erc1155.mint(address(tokenOwner), 0, 100);
        erc1155.mint(address(tokenOwner), 1, 500);

        // additional contents, to check `addBoosterContents`
        additionalContents.push(
            ITokenBundle.Token({
                assetContract: address(erc1155),
                tokenType: ITokenBundle.TokenType.ERC1155,
                tokenId: 2,
                totalAmount: 200
            })
        );
        additionalContentsRewardUnits.push(50);

        tokenOwner.setApprovalForAllERC1155(address(erc1155), address(booster), true);

        vm.prank(deployer);
        booster.grantRole(keccak256("MINTER_ROLE"), address(tokenOwner));

        // open booster signature preparation steps

        typehashOpenRequest = keccak256(
            "OpenRequest(address opener,uint256 boosterId,uint256 quantity,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );
        nameHash = keccak256(bytes("Booster"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(booster)));
    }

    function signOpenRequest(IBooster.OpenRequest memory _request, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashOpenRequest,
            _request.opener,
            _request.boosterId,
            _request.quantity,
            _request.validityStartTimestamp,
            _request.validityEndTimestamp,
            _request.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: Miscellaneous
    //////////////////////////////////////////////////////////////*/

    function test_revert_addBoosterContents_RandomAccountGrief() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        // random address tries to transfer zero amount
        address randomAccount = address(0x123);

        vm.prank(randomAccount);
        booster.safeTransferFrom(randomAccount, address(567), boosterId, 0, ""); // zero transfer

        // canUpdateBooster should remain true, since no boosters were transferred
        assertTrue(booster.canUpdateBooster(boosterId));

        erc1155.mint(address(tokenOwner), 2, 200);

        vm.prank(address(tokenOwner));
        // Should not revert
        booster.addBoosterContents(boosterId, additionalContents, additionalContentsRewardUnits, recipient);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `createBooster`
    //////////////////////////////////////////////////////////////*/

    function test_interface() public view {
        console2.logBytes4(type(IERC1155).interfaceId);
    }

    function test_supportsInterface() public {
        assertEq(booster.supportsInterface(type(IERC2981Upgradeable).interfaceId), true);
        assertEq(booster.supportsInterface(type(IERC1155Receiver).interfaceId), true);
        assertEq(booster.supportsInterface(type(IERC1155Upgradeable).interfaceId), true);
    }

    /**
     *  note: Testing state changes; token owner calls `createBooster` to booster owned tokens.
     */
    function test_state_createBooster() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        assertEq(boosterId + 1, booster.nextTokenIdToMint());

        (ITokenBundle.Token[] memory packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, boosterContents.length);
        for (uint256 i = 0; i < packed.length; i += 1) {
            assertEq(packed[i].assetContract, boosterContents[i].assetContract);
            assertEq(uint256(packed[i].tokenType), uint256(boosterContents[i].tokenType));
            assertEq(packed[i].tokenId, boosterContents[i].tokenId);
            assertEq(packed[i].totalAmount, boosterContents[i].totalAmount);
        }

        assertEq(boosterUri, booster.uri(boosterId));
    }

    /**
     *  note: Testing state changes; token owner calls `createBooster` to booster owned tokens.
     *        Only assets with ASSET_ROLE can be packed (first ASSET ROLE must be disabled for address(0))
     */
    function test_state_createBooster_withAssetRoleRestriction() public {
        vm.startPrank(deployer);
        booster.revokeRole(keccak256("ASSET_ROLE"), address(0));
        for (uint256 i = 0; i < boosterContents.length; i += 1) {
            if (!booster.hasRole(keccak256("ASSET_ROLE"), boosterContents[i].assetContract)) {
                booster.grantRole(keccak256("ASSET_ROLE"), boosterContents[i].assetContract);
            }
        }
        vm.stopPrank();

        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        assertEq(boosterId + 1, booster.nextTokenIdToMint());

        (ITokenBundle.Token[] memory packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, boosterContents.length);
        for (uint256 i = 0; i < packed.length; i += 1) {
            assertEq(packed[i].assetContract, boosterContents[i].assetContract);
            assertEq(uint256(packed[i].tokenType), uint256(boosterContents[i].tokenType));
            assertEq(packed[i].tokenId, boosterContents[i].tokenId);
            assertEq(packed[i].totalAmount, boosterContents[i].totalAmount);
        }

        assertEq(boosterUri, booster.uri(boosterId));
    }

    /**
     *  note: Testing event emission; token owner calls `createBooster` to booster owned tokens.
     */
    function test_event_createBooster_BoosterCreated() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);

        vm.startPrank(address(tokenOwner));

        // test for event emission
        vm.expectEmit(true, true, true, true);
        emit BoosterCreated(boosterId, recipient, 70);

        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        vm.stopPrank();
    }

    /**
     *  note: Testing token balances; token owner calls `createBooster` to booster owned tokens.
     */
    function test_balances_createBooster() public {
        // ERC1155 balance
        assertEq(erc1155.balanceOf(address(tokenOwner), 0), 100);
        assertEq(erc1155.balanceOf(address(booster), 0), 0);

        assertEq(erc1155.balanceOf(address(tokenOwner), 1), 500);
        assertEq(erc1155.balanceOf(address(booster), 1), 0);

        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        (, uint256 totalSupply) = booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        // ERC1155 balance
        assertEq(erc1155.balanceOf(address(tokenOwner), 0), 0);
        assertEq(erc1155.balanceOf(address(booster), 0), 100);

        assertEq(erc1155.balanceOf(address(tokenOwner), 1), 0);
        assertEq(erc1155.balanceOf(address(booster), 1), 500);

        // Booster wrapped token balance
        assertEq(booster.balanceOf(address(recipient), boosterId), totalSupply);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` to booster owned tokens.
     *        Only assets with ASSET_ROLE can be packed, but assets being packed don't have that role.
     */
    function test_revert_createBooster_access_ASSET_ROLE() public {
        vm.prank(deployer);
        booster.revokeRole(keccak256("ASSET_ROLE"), address(0));

        address recipient = address(0x123);

        string memory errorMsg = string(
            abi.encodePacked(
                "Permissions: account ",
                Strings.toHexString(uint160(boosterContents[0].assetContract), 20),
                " is missing role ",
                Strings.toHexString(uint256(keccak256("ASSET_ROLE")), 32)
            )
        );

        vm.prank(address(tokenOwner));
        vm.expectRevert(bytes(errorMsg));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` to booster owned tokens, without MINTER_ROLE.
     */
    function test_revert_createBooster_access_MINTER_ROLE() public {
        vm.prank(address(tokenOwner));
        booster.renounceRole(keccak256("MINTER_ROLE"), address(tokenOwner));

        address recipient = address(0x123);

        string memory errorMsg = string(
            abi.encodePacked(
                "Permissions: account ",
                Strings.toHexString(uint160(address(tokenOwner)), 20),
                " is missing role ",
                Strings.toHexString(uint256(keccak256("MINTER_ROLE")), 32)
            )
        );

        vm.prank(address(tokenOwner));
        vm.expectRevert(bytes(errorMsg));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` to pack un-owned ERC1155 tokens.
     */
    function test_revert_createBooster_notOwner_ERC1155() public {
        tokenOwner.transferERC1155(address(erc1155), address(0x12), 0, 100, "");

        address recipient = address(0x123);

        vm.startPrank(address(tokenOwner));
        vm.expectRevert("ERC1155: insufficient balance for transfer");
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` to pack un-approved ERC1155 tokens.
     */
    function test_revert_createBooster_notApprovedTransfer_ERC1155() public {
        tokenOwner.setApprovalForAllERC1155(address(erc1155), address(booster), false);

        address recipient = address(0x123);

        vm.startPrank(address(tokenOwner));
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` with total-amount as 0.
     */
    function test_revert_createPack_zeroTotalAmount() public {
        ITokenBundle.Token[] memory invalidContent = new ITokenBundle.Token[](1);
        uint256[] memory rewardUnits = new uint256[](1);

        invalidContent[0] = ITokenBundle.Token({
            assetContract: address(erc20),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 0,
            totalAmount: 0
        });
        rewardUnits[0] = 10;

        address recipient = address(0x123);

        vm.startPrank(address(tokenOwner));
        vm.expectRevert("0 amt");
        booster.createBooster(invalidContent, rewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` with no tokens to booster.
     */
    function test_revert_createBooster_noTokensToBooster() public {
        ITokenBundle.Token[] memory emptyContent;
        uint256[] memory rewardUnits;

        address recipient = address(0x123);

        bytes memory err = "!Len";
        vm.startPrank(address(tokenOwner));
        vm.expectRevert(err);
        booster.createBooster(emptyContent, rewardUnits, boosterUri, 0, 1, recipient);
    }

    /**
     *  note: Testing revert condition; token owner calls `createBooster` with unequal length of contents and rewardUnits.
     */
    function test_revert_createBooster_invalidRewardUnits() public {
        uint256[] memory rewardUnits;

        address recipient = address(0x123);

        bytes memory err = "!Len";
        vm.startPrank(address(tokenOwner));
        vm.expectRevert(err);
        booster.createBooster(boosterContents, rewardUnits, boosterUri, 0, 1, recipient);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `addBoosterContents`
    //////////////////////////////////////////////////////////////*/

    /**
     *  note: Testing state changes; token owner calls `addBoosterContents` to booster more tokens.
     */
    function test_state_addBoosterContents() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        (ITokenBundle.Token[] memory packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, boosterContents.length);
        for (uint256 i = 0; i < packed.length; i += 1) {
            assertEq(packed[i].assetContract, boosterContents[i].assetContract);
            assertEq(uint256(packed[i].tokenType), uint256(boosterContents[i].tokenType));
            assertEq(packed[i].tokenId, boosterContents[i].tokenId);
            assertEq(packed[i].totalAmount, boosterContents[i].totalAmount);
        }

        erc1155.mint(address(tokenOwner), 2, 200);

        vm.prank(address(tokenOwner));
        booster.addBoosterContents(boosterId, additionalContents, additionalContentsRewardUnits, recipient);

        (packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, boosterContents.length + additionalContents.length);
        for (uint256 i = boosterContents.length; i < packed.length; i += 1) {
            assertEq(packed[i].assetContract, additionalContents[i - boosterContents.length].assetContract);
            assertEq(uint256(packed[i].tokenType), uint256(additionalContents[i - boosterContents.length].tokenType));
            assertEq(packed[i].tokenId, additionalContents[i - boosterContents.length].tokenId);
            assertEq(packed[i].totalAmount, additionalContents[i - boosterContents.length].totalAmount);
        }
    }

    /**
     *  note: Testing token balances; token owner calls `addBoosterContents` to booster more tokens
     *        in an already existing booster.
     */
    function test_balances_addBoosterContents() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        (, uint256 totalSupply) = booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        // ERC1155 balance
        assertEq(erc1155.balanceOf(address(tokenOwner), 0), 0);
        assertEq(erc1155.balanceOf(address(booster), 0), 100);

        assertEq(erc1155.balanceOf(address(tokenOwner), 1), 0);
        assertEq(erc1155.balanceOf(address(booster), 1), 500);

        // Booster wrapped token balance
        assertEq(booster.balanceOf(address(recipient), boosterId), totalSupply);

        erc1155.mint(address(tokenOwner), 2, 200);

        vm.prank(address(tokenOwner));
        (uint256 newTotalSupply, uint256 additionalSupply) = booster.addBoosterContents(
            boosterId,
            additionalContents,
            additionalContentsRewardUnits,
            recipient
        );

        // ERC1155 balance after adding more tokens
        assertEq(erc1155.balanceOf(address(tokenOwner), 2), 0);
        assertEq(erc1155.balanceOf(address(booster), 2), 200);

        // Booster wrapped token balance
        assertEq(booster.balanceOf(address(recipient), boosterId), newTotalSupply);
        assertEq(totalSupply + additionalSupply, newTotalSupply);
    }

    /**
     *  note: Testing revert condition; non-creator calls `addBoosterContents`.
     */
    function test_revert_addBoosterContents_NotMinterRole() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        address randomAccount = address(0x123);

        string memory errorMsg = string(
            abi.encodePacked(
                "Permissions: account ",
                Strings.toHexString(uint160(address(randomAccount)), 20),
                " is missing role ",
                Strings.toHexString(uint256(keccak256("MINTER_ROLE")), 32)
            )
        );

        vm.prank(randomAccount);
        vm.expectRevert(bytes(errorMsg));
        booster.addBoosterContents(boosterId, additionalContents, additionalContentsRewardUnits, recipient);
    }

    /**
     *  note: Testing revert condition; adding tokens to non-existent booster.
     */
    function test_revert_addBoosterContents_BoosterNonExistent() public {
        vm.prank(address(tokenOwner));
        vm.expectRevert("!Allowed");
        booster.addBoosterContents(0, boosterContents, numOfRewardUnits, address(1));
    }

    /**
     *  note: Testing revert condition; adding tokens after boosters have been distributed.
     *  booster cannot be updated after transfer to non zero address
     */
    function test_revert_addBoosterContents_CantUpdateAnymore() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        vm.prank(recipient);
        booster.safeTransferFrom(recipient, address(567), boosterId, 1, "");

        vm.prank(address(tokenOwner));
        vm.expectRevert("!Allowed");
        booster.addBoosterContents(boosterId, additionalContents, additionalContentsRewardUnits, recipient);
    }

    /**
     *  note: Testing revert condition; adding tokens with a different recipient.
     */
    function test_revert_addBoosterContents_NotRecipient() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        address randomRecipient = address(0x12345);

        bytes memory err = "!Bal";
        vm.expectRevert(err);
        vm.prank(address(tokenOwner));
        booster.addBoosterContents(boosterId, additionalContents, additionalContentsRewardUnits, randomRecipient);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `openBooster`
    //////////////////////////////////////////////////////////////*/

    /**
     *  note: Testing state changes; booster owner calls `openBooster` to redeem underlying rewards.
     */
    function test_state_openBooster() public {
        vm.warp(1000);
        uint256 boosterId = booster.nextTokenIdToMint();
        uint256 boostersToOpen = 3;
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        (, uint256 totalSupply) = booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 2, recipient);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: boosterId,
            quantity: boostersToOpen,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        vm.prank(recipient);
        ITokenBundle.Token[] memory rewardUnits = booster.openBooster(openRequest, signature);
        //console2.log("total reward units: ", rewardUnits.length);

        for (uint256 i = 0; i < rewardUnits.length; i++) {
            //console2.log("----- reward unit number: ", i, "------");
            //console2.log("asset contract: ", rewardUnits[i].assetContract);
            //console2.log("token type: ", uint256(rewardUnits[i].tokenType));
            //console2.log("tokenId: ", rewardUnits[i].tokenId);
            //console2.log("total amount: ", rewardUnits[i].totalAmount);
            //console2.log("");
        }

        assertEq(boosterUri, booster.uri(boosterId));
        assertEq(booster.totalSupply(boosterId), totalSupply - boostersToOpen);

        (ITokenBundle.Token[] memory packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, boosterContents.length);
    }

    /**
     *  note: Testing event emission; booster owner calls `openBooster` to open owned boosters.
     */
    function test_event_openBooster_BoosterOpened() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);

        ITokenBundle.Token[] memory emptyRewardUnitsForTestingEvent;

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        vm.expectEmit(true, true, false, false);
        emit BoosterOpened(boosterId, recipient, 1, emptyRewardUnitsForTestingEvent);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: boosterId,
            quantity: 1,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        vm.prank(recipient, recipient);
        booster.openBooster(openRequest, signature);
    }

    function test_balances_openBooster() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        uint256 boostersToOpen = 3;
        address recipient = address(1);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 2, recipient);

        // ERC1155 balance
        assertEq(erc1155.balanceOf(address(recipient), 0), 0);
        assertEq(erc1155.balanceOf(address(booster), 0), 100);

        assertEq(erc1155.balanceOf(address(recipient), 1), 0);
        assertEq(erc1155.balanceOf(address(booster), 1), 500);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: boosterId,
            quantity: boostersToOpen,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        vm.prank(recipient, recipient);
        ITokenBundle.Token[] memory rewardUnits = booster.openBooster(openRequest, signature);
        console2.log("total reward units: ", rewardUnits.length);

        uint256[] memory erc1155Amounts = new uint256[](2);

        for (uint256 i = 0; i < rewardUnits.length; i++) {
            console2.log("----- reward unit number: ", i, "------");
            console2.log("asset contract: ", rewardUnits[i].assetContract);
            console2.log("token type: ", uint256(rewardUnits[i].tokenType));
            console2.log("tokenId: ", rewardUnits[i].tokenId);
            if (rewardUnits[i].tokenType == ITokenBundle.TokenType.ERC1155) {
                console2.log("total amount: ", rewardUnits[i].totalAmount);
                console.log("balance of recipient: ", erc1155.balanceOf(address(recipient), rewardUnits[i].tokenId));
                erc1155Amounts[rewardUnits[i].tokenId] += rewardUnits[i].totalAmount;
            }
            console2.log("");
        }

        for (uint256 i = 0; i < erc1155Amounts.length; i += 1) {
            assertEq(erc1155.balanceOf(address(recipient), i), erc1155Amounts[i]);
        }
    }

    /**
     *  note: Testing revert condition; booster owner calls `openBooster` to open more than owned boosters.
     */
    function test_revert_openBooster_openMoreThanOwned() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);

        vm.prank(address(tokenOwner));
        (, uint256 totalSupply) = booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: boosterId,
            quantity: totalSupply + 1,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        bytes memory err = "!Bal";
        vm.prank(recipient);
        vm.expectRevert(err);
        booster.openBooster(openRequest, signature);
    }

    /**
     *  note: Testing revert condition; booster owner calls `openBooster` before start timestamp.
     */
    function test_revert_openBooster_openBeforeStart() public {
        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);
        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 1000, 1, recipient);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: boosterId,
            quantity: 1,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        vm.prank(recipient);
        vm.expectRevert("cant open");
        booster.openBooster(openRequest, signature);
    }

    /**
     *  note: Testing revert condition; booster owner calls `openBooster` with booster-id non-existent or not owned.
     */
    function test_revert_openBooster_invalidBoosterId() public {
        address recipient = address(0x123);

        vm.prank(address(tokenOwner));
        booster.createBooster(boosterContents, numOfRewardUnits, boosterUri, 0, 1, recipient);

        IBooster.OpenRequest memory openRequest = IBooster.OpenRequest({
            opener: recipient,
            boosterId: 2,
            quantity: 1,
            validityStartTimestamp: 0,
            validityEndTimestamp: 2000,
            uid: bytes32(0)
        });

        // request must be signed with private key of deployer

        bytes memory signature = signOpenRequest(openRequest, privateKey);

        bytes memory err = "!Bal";
        vm.prank(recipient);
        vm.expectRevert(err);
        booster.openBooster(openRequest, signature);
    }

    /*///////////////////////////////////////////////////////////////
                            Fuzz testing
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_TOKENS = 2000;

    function getTokensToBooster(uint256 len)
        internal
        returns (ITokenBundle.Token[] memory tokensToPack, uint256[] memory rewardUnits)
    {
        vm.assume(len < MAX_TOKENS);
        tokensToPack = new ITokenBundle.Token[](len);
        rewardUnits = new uint256[](len);

        for (uint256 i = 0; i < len; i += 1) {
            uint256 random = uint256(keccak256(abi.encodePacked(len + i))) % MAX_TOKENS;

            tokensToPack[i] = ITokenBundle.Token({
                assetContract: address(erc1155),
                tokenType: ITokenBundle.TokenType.ERC1155,
                tokenId: random,
                totalAmount: (random + 1) * 10
            });
            rewardUnits[i] = random + 1;

            erc1155.mint(address(tokenOwner), tokensToPack[i].tokenId, tokensToPack[i].totalAmount);
        }
    }

    function checkBalances(ITokenBundle.Token[] memory rewardUnits, address)
        internal
        pure
        returns (uint256[] memory erc1155Amounts)
    {
        erc1155Amounts = new uint256[](MAX_TOKENS);

        for (uint256 i = 0; i < rewardUnits.length; i++) {
            // console2.log("----- reward unit number: ", i, "------");
            // console2.log("asset contract: ", rewardUnits[i].assetContract);
            // console2.log("token type: ", uint256(rewardUnits[i].tokenType));
            // console2.log("tokenId: ", rewardUnits[i].tokenId);
            if (rewardUnits[i].tokenType == ITokenBundle.TokenType.ERC1155) {
                // console2.log("total amount: ", rewardUnits[i].totalAmount);
                // console.log("balance of recipient: ", erc1155.balanceOf(address(recipient), rewardUnits[i].tokenId));
                erc1155Amounts[rewardUnits[i].tokenId] += rewardUnits[i].totalAmount;
            }
            // console2.log("");
        }
    }

    /*
    function test_fuzz_state_createBooster(uint256 x, uint128 y) public {
        (ITokenBundle.Token[] memory tokensToPack, uint256[] memory rewardUnits) = getTokensToBooster(x);
        if (tokensToPack.length == 0) {
            return;
        }

        uint256 boosterId = booster.nextTokenIdToMint();
        address recipient = address(0x123);
        uint256 totalRewardUnits;

        for (uint256 i = 0; i < tokensToPack.length; i += 1) {
            totalRewardUnits += rewardUnits[i];
        }
        vm.assume(y > 0 && totalRewardUnits % y == 0);

        vm.prank(address(tokenOwner));
        (, uint256 totalSupply) = booster.createBooster(tokensToPack, rewardUnits, boosterUri, 0, y, recipient);
        console2.log("total supply: ", totalSupply);
        console2.log("total reward units: ", totalRewardUnits);

        assertEq(boosterId + 1, booster.nextTokenIdToMint());

        (ITokenBundle.Token[] memory packed, ) = booster.getBoosterContents(boosterId);
        assertEq(packed.length, tokensToPack.length);
        for (uint256 i = 0; i < packed.length; i += 1) {
            assertEq(packed[i].assetContract, tokensToPack[i].assetContract);
            assertEq(uint256(packed[i].tokenType), uint256(tokensToPack[i].tokenType));
            assertEq(packed[i].tokenId, tokensToPack[i].tokenId);
            assertEq(packed[i].totalAmount, tokensToPack[i].totalAmount);
        }

        assertEq(boosterUri, booster.uri(boosterId));
    }
    */
}
