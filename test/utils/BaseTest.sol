// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@std/Test.sol";
import "@ds-test/test.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Wallet.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockERC721.sol";
import "../mocks/MockERC1155.sol";
import {MothoraGame} from "src/MothoraGame.sol";
import {Arena} from "src/modules/Arena.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";

abstract contract BaseTest is DSTest, Test {
    string public constant NAME = "NAME";
    string public constant SYMBOL = "SYMBOL";
    string public constant CONTRACT_URI = "CONTRACT_URI";

    MockERC20 public erc20;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    UUPSProxy proxy;

    address public deployer = address(0x8fb52e325C3145A2A7Cd4A04A6F4146017ADD6c0);
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public royaltyRecipient = address(0x30001);
    uint128 public royaltyBps = 500; // 5%

    address public signer;

    mapping(bytes32 => address) public contracts;

    function setUp() public virtual {
        /// setup main contracts
        vm.startPrank(deployer);

        signer = vm.addr(privateKey);

        // erc20 = new MockERC20();
        // erc721 = new MockERC721();
        // erc1155 = new MockERC1155();
        vm.stopPrank();

        address mothoraGameImplementation = address(new MothoraGame());
        deployUUPSProxy("MothoraGame", mothoraGameImplementation, abi.encodeCall(MothoraGame.initialize, ()));

        vm.prank(deployer);
        address arena = address(new Arena("ipfs://"));
        contracts[bytes32(bytes("Arena"))] = arena;
    }

    function deployUUPSProxy(
        string memory _contractType,
        address _implementation,
        bytes memory _initializer
    ) public returns (address proxyAddress) {
        vm.startPrank(deployer);

        proxy = new UUPSProxy(_implementation, "");
        proxyAddress = address(proxy);
        if (_initializer.length > 0) {
            Address.functionCall(proxyAddress, _initializer);
        }

        contracts[bytes32(bytes(_contractType))] = proxyAddress;
        vm.stopPrank();
    }

    function getContract(string memory _name) public view returns (address) {
        return contracts[bytes32(bytes(_name))];
    }

    function getActor(uint160 _index) public pure returns (address) {
        return address(uint160(0x50000 + _index));
    }

    function getWallet() public returns (Wallet wallet) {
        wallet = new Wallet();
    }

    function assertIsOwnerERC721(
        address _token,
        address _owner,
        uint256[] memory _tokenIds
    ) internal {
        for (uint256 i = 0; i < _tokenIds.length; i += 1) {
            bool isOwnerOfToken = MockERC721(_token).ownerOf(_tokenIds[i]) == _owner;
            assertTrue(isOwnerOfToken);
        }
    }

    function assertIsNotOwnerERC721(
        address _token,
        address _owner,
        uint256[] memory _tokenIds
    ) internal {
        for (uint256 i = 0; i < _tokenIds.length; i += 1) {
            bool isOwnerOfToken = MockERC721(_token).ownerOf(_tokenIds[i]) == _owner;
            assertTrue(!isOwnerOfToken);
        }
    }

    function assertBalERC1155Eq(
        address _token,
        address _owner,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) internal {
        require(_tokenIds.length == _amounts.length, "unequal lengths");

        for (uint256 i = 0; i < _tokenIds.length; i += 1) {
            assertEq(MockERC1155(_token).balanceOf(_owner, _tokenIds[i]), _amounts[i]);
        }
    }

    function assertBalERC1155Gte(
        address _token,
        address _owner,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) internal {
        require(_tokenIds.length == _amounts.length, "unequal lengths");

        for (uint256 i = 0; i < _tokenIds.length; i += 1) {
            assertTrue(MockERC1155(_token).balanceOf(_owner, _tokenIds[i]) >= _amounts[i]);
        }
    }

    function assertBalERC20Eq(
        address _token,
        address _owner,
        uint256 _amount
    ) internal {
        assertEq(MockERC20(_token).balanceOf(_owner), _amount);
    }

    function assertBalERC20Gte(
        address _token,
        address _owner,
        uint256 _amount
    ) internal {
        assertTrue(MockERC20(_token).balanceOf(_owner) >= _amount);
    }
}
