// tests/NFT.test.sol
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../src/NFT.sol";
import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";

contract NFTest is DSTest, Test {
    NFT nft;
    bytes cid;

    function setUp() public {
        nft = new NFT();
        string[] memory cmds = new string[](2);
        // Build ffi command string
        cmds[0] = "ts-node";
        cmds[1] = "./ts/main.ts";
        bytes memory result = vm.ffi(cmds);
        cid = abi.decode(result, (bytes));
        console.log("CID: %s", string(abi.encodePacked(cid)));
    }

    function testMint() public {
        bytes memory blueprint = (cid);
        nft.mint(blueprint);

        // Check that the NFT was minted
        assertEq(nft.totalSupply(), 1);

        // Check that the metadata was stored correctly

        // how do i know what to expect?
        // string memory expectedMetadata = "c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a";
        // assertEq(nft.getNFTMetadata(1), expectedMetadata);
        console.log("Metadata: %s", nft.getNFTMetadata(1));
    }
}

// contract NFTTest is DSTest {
//     NFT nft;
//     address public owner;
//     bytes32 constant BLUEPRINT = hex"5d5c6a5c6e5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a";
//     bytes32 constant CID_PREFIX = hex"f017012200";

//     function setUp() public {
//         nft = new NFT();
//         owner = address(this);
//     }

//     function testMint() public {
//         // Check that initial balance is zero
//         assertEq(nft.balanceOf(owner), 0);

//         // Mint a new NFT
//         bytes memory blueprint = abi.encodePacked(BLUEPRINT);
//         nft.mint(blueprint);

//         // Check that the balance is now 1
//         assertEq(nft.balanceOf(owner), 1);

//         // Check that the NFT metadata matches the expected value
//         assertEq(nft.getNFTMetadata(1), string(BLUEPRINT));
//     }

//     // function testSetBaseURI() public {
//     //     // Set the base URI
//     //     string memory newBaseURI = "ipfs://new/";
//     //     nft.setBaseURI(newBaseURI);

//     //     // Check that the base URI was set correctly
//     //     assertEq(nft.baseURI, newBaseURI);
//     // }

//     // function testTokenURI() public {
//     //     // Set the base URI
//     //     string memory newBaseURI = "ipfs://new/";
//     //     nft.setBaseURI(newBaseURI);

//     //     // Mint a new NFT
//     //     nft.mint(BLUEPRINT);

//     //     // Check that the token URI matches the expected value
//     //     string memory expectedURI = string(abi.encodePacked(newBaseURI, bytes32ToString(BLUEPRINT)));
//     //     assertEq(nft.tokenURI(1), expectedURI);
//     // }

//     // function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
//     //     bytes memory bytesArray = new bytes(64);
//     //     for (uint256 i; i < 32; i++) {
//     //         bytesArray[i * 2] = bytes(hex"30");
//     //         bytesArray[i * 2 + 1] = bytes((uint8(_bytes32[i]) / 16) + hex"30");
//     //         bytesArray[i * 2 + 2] = bytes(
//     //             ((uint8(_bytes32[i]) % 16) < 10)
//     //                 ? ((uint8(_bytes32[i]) % 16) + hex"30")
//     //                 : ((uint8(_bytes32[i]) % 16) + hex"57")
//     //         );
//     //     }
//     //     return string(bytesArray);
//     // }

//     function testGetPrefix() public {
//         // Check that the CID prefix matches the expected value
//         assertEq(nft.getPrefix(), bytes32(CID_PREFIX));
//     }
// }
