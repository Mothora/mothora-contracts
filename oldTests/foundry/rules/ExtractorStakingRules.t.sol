pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/Mock.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/interfaces/INftHandler.sol";
import "contracts/modules/absorber/interfaces/IAbsorber.sol";
import "contracts/modules/absorber/lib/Constant.sol";
import "contracts/modules/absorber/rules/ExtractorStakingRules.sol";

contract ExtractorStakingRulesTest is TestUtils {
    ExtractorStakingRules public extractorRules;

    IAbsorber public absorber = IAbsorber(address(8888));

    address public admin = address(111);
    address public absorberFactory = address(222);
    address public extractorAddress = address(333);
    uint256 public maxStakeable = 10;
    uint256 public lifetime = 3600;
    uint256 public extractorPower = 1e18;

    event MaxStakeable(uint256 maxStakeable);
    event ExtractorPower(uint256 tokenId, uint256 power);
    event ExtractorStaked(address user, uint256 tokenId, uint256 spotId, uint256 amount);
    event ExtractorReplaced(address user, uint256 tokenId, uint256 replacedSpotId);
    event Lifetime(uint256 lifetime);
    event ExtractorAddress(address extractorAddress);

    function setUp() public {
        vm.label(admin, "admin");
        vm.label(absorberFactory, "absorberFactory");
        vm.label(extractorAddress, "extractorAddress");

        address impl = address(new ExtractorStakingRules());

        extractorRules = ExtractorStakingRules(address(new ERC1967Proxy(impl, bytes(""))));
        extractorRules.init(admin, absorberFactory, extractorAddress, maxStakeable, lifetime);

        vm.mockCall(address(absorber), abi.encodeCall(IAbsorber.callUpdateRewards, ()), abi.encode(true));
    }

    function stakeExtractor(
        address _user,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        if (!extractorRules.hasRole(extractorRules.SR_NFT_HANDLER(), address(this))) {
            vm.prank(absorberFactory);
            extractorRules.setNftHandler(address(this));
        }

        vm.prank(admin);
        extractorRules.setExtractorPower(_tokenId, extractorPower);

        extractorRules.processStake(_user, extractorAddress, _tokenId, _amount);
    }

    function test_processStake(
        address _user,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        vm.assume(0 < _amount && _amount < maxStakeable);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_NFT_HANDLER());
        vm.expectRevert(errorMsg);
        extractorRules.processStake(_user, extractorAddress, _tokenId, _amount);

        vm.prank(absorberFactory);
        extractorRules.setNftHandler(address(this));

        vm.expectRevert(ExtractorStakingRules.InvalidAddress.selector);
        extractorRules.processStake(_user, address(999), _tokenId, _amount);

        vm.expectRevert(ExtractorStakingRules.ZeroAmount.selector);
        extractorRules.processStake(_user, extractorAddress, _tokenId, 0);

        vm.expectRevert(ExtractorStakingRules.ZeroPower.selector);
        extractorRules.processStake(_user, extractorAddress, _tokenId, _amount);

        vm.prank(admin);
        extractorRules.setExtractorPower(_tokenId, extractorPower);

        vm.expectRevert(ExtractorStakingRules.MaxStakeableReached.selector);
        extractorRules.processStake(_user, extractorAddress, _tokenId, maxStakeable + 1);

        assertEq(extractorRules.getExtractorCount(), 0);

        uint256 spotId = extractorRules.getExtractorCount() + _amount - 1;

        vm.expectEmit(true, true, true, true);
        emit ExtractorStaked(_user, _tokenId, spotId, _amount);
        extractorRules.processStake(_user, extractorAddress, _tokenId, _amount);

        assertEq(extractorRules.getExtractorCount(), _amount);

        ExtractorStakingRules.ExtractorData[] memory extractors = extractorRules.getExtractors();

        for (uint256 i = 0; i < _amount; i++) {
            (address user, uint256 tokenId, uint256 stakedTimestamp) = extractorRules.stakedExtractor(i);
            assertEq(user, _user);
            assertEq(tokenId, _tokenId);
            assertEq(extractors[i].tokenId, _tokenId);
            assertEq(stakedTimestamp, block.timestamp);
            assertEq(extractors[i].stakedTimestamp, block.timestamp);
        }

        assertEq(extractorRules.getExtractorsTotalPower(), _amount * extractorPower);
        assertEq(extractorRules.getAbsorberPower(), 1e18 + _amount * extractorPower);

        assertEq(extractorRules.getUserPower(_user, extractorAddress, _tokenId, _amount), 0);
    }

    function test_processUnstake(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_NFT_HANDLER());
        vm.expectRevert(errorMsg);
        extractorRules.processUnstake(_user, _nft, _tokenId, _amount);

        vm.prank(absorberFactory);
        extractorRules.setNftHandler(address(this));

        vm.expectRevert(ExtractorStakingRules.CannotUnstake.selector);
        extractorRules.processUnstake(_user, _nft, _tokenId, _amount);
    }

    struct LocalVars {
        uint256 power1;
        uint256 power2;
        uint256 newTokenId;
        uint256 spotId;
        uint256 timestamp;
    }

    function test_canReplace(
        address _user,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        vm.assume(0 < _amount && _amount < maxStakeable);
        vm.assume(_tokenId < type(uint256).max);

        LocalVars memory localVars = LocalVars({
            power1: 5e17,
            power2: 6e17,
            newTokenId: _tokenId + 1,
            spotId: 0,
            timestamp: block.timestamp
        });

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_NFT_HANDLER());
        vm.expectRevert(errorMsg);
        extractorRules.canReplace(_user, extractorAddress, _tokenId, _amount, localVars.spotId);

        stakeExtractor(_user, _tokenId, _amount);
        vm.prank(admin);
        extractorRules.setExtractorPower(_tokenId, localVars.power1);
        vm.prank(admin);
        extractorRules.setExtractorPower(localVars.newTokenId, localVars.power2);

        vm.expectRevert(ExtractorStakingRules.InvalidAddress.selector);
        extractorRules.canReplace(_user, address(999), _tokenId, 1, localVars.spotId);

        vm.expectRevert(ExtractorStakingRules.ZeroAmount.selector);
        extractorRules.canReplace(_user, extractorAddress, _tokenId, 0, localVars.spotId);

        vm.expectRevert(ExtractorStakingRules.MustReplaceOne.selector);
        extractorRules.canReplace(_user, extractorAddress, localVars.newTokenId, 2, localVars.spotId);

        vm.expectRevert(ExtractorStakingRules.InvalidSpotId.selector);
        extractorRules.canReplace(_user, extractorAddress, localVars.newTokenId, 1, maxStakeable);

        vm.expectRevert(ExtractorStakingRules.MustReplaceWithHigherPower.selector);
        extractorRules.canReplace(_user, extractorAddress, _tokenId, 1, localVars.spotId);

        (address user, uint256 stakedTokenId, uint256 stakedTimestamp) = extractorRules.stakedExtractor(
            localVars.spotId
        );
        assertEq(user, _user);
        assertEq(stakedTokenId, _tokenId);
        assertEq(stakedTimestamp, localVars.timestamp);

        vm.warp(localVars.timestamp + 10);

        vm.expectEmit(true, true, true, true);
        emit ExtractorReplaced(_user, localVars.newTokenId, localVars.spotId);
        extractorRules.canReplace(_user, extractorAddress, localVars.newTokenId, 1, localVars.spotId);

        (address user2, uint256 stakedTokenId2, uint256 stakedTimestamp2) = extractorRules.stakedExtractor(
            localVars.spotId
        );
        assertEq(user2, _user);
        assertEq(stakedTokenId2, localVars.newTokenId);
        assertEq(stakedTimestamp2, localVars.timestamp + 10);
    }

    function test_isExtractorActive(
        address _user,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        vm.assume(0 < _amount && _amount < maxStakeable);
        assertEq(extractorRules.getExtractorCount(), 0);

        stakeExtractor(_user, _tokenId, _amount);

        for (uint256 i = 0; i < _amount; i++) {
            assertEq(extractorRules.isExtractorActive(i), true);
        }

        vm.warp(block.timestamp + lifetime);

        for (uint256 i = 0; i < _amount; i++) {
            assertEq(extractorRules.isExtractorActive(i), true);
        }

        vm.warp(block.timestamp + 1);

        for (uint256 i = 0; i < _amount; i++) {
            assertEq(extractorRules.isExtractorActive(i), false);
        }
    }

    function test_getExtractorCount(uint256 _amount) public {
        vm.assume(0 < _amount && _amount < maxStakeable);

        address user = address(999);
        uint256 tokenId = 9;

        assertEq(extractorRules.getExtractorCount(), 0);
        stakeExtractor(user, tokenId, _amount);
        assertEq(extractorRules.getExtractorCount(), _amount);

        stakeExtractor(user, tokenId, maxStakeable - _amount);
        assertEq(extractorRules.getExtractorCount(), maxStakeable);

        vm.expectRevert(ExtractorStakingRules.MaxStakeableReached.selector);
        extractorRules.processStake(user, extractorAddress, tokenId, 1);

        assertEq(extractorRules.getExtractorCount(), maxStakeable);
    }

    function test_getExtractors(uint256 _amount) public {
        vm.assume(0 < _amount && _amount < maxStakeable);

        address user = address(999);
        uint256 tokenId = 9;

        stakeExtractor(user, tokenId, _amount);

        ExtractorStakingRules.ExtractorData[] memory extractors = extractorRules.getExtractors();

        for (uint256 i = 0; i < _amount; i++) {
            assertEq(extractors[i].tokenId, tokenId);
            assertEq(extractors[i].stakedTimestamp, block.timestamp);
        }

        vm.warp(block.timestamp + 100);

        stakeExtractor(user, tokenId, maxStakeable - _amount);

        extractors = extractorRules.getExtractors();

        for (uint256 i = 0; i < _amount; i++) {
            assertEq(extractors[i].tokenId, tokenId);
            assertEq(extractors[i].stakedTimestamp, block.timestamp - 100);
        }

        for (uint256 i = _amount; i < maxStakeable; i++) {
            assertEq(extractors[i].tokenId, tokenId);
            assertEq(extractors[i].stakedTimestamp, block.timestamp);
        }
    }

    function test_getExtractorsTotalPower(uint256 _amount) public {
        vm.assume(0 < _amount && _amount < maxStakeable - 1);

        address user = address(999);
        uint256 tokenId = 9;
        uint256 power = 5e17;

        assertEq(extractorRules.getExtractorsTotalPower(), 0);

        stakeExtractor(user, tokenId, _amount);
        vm.prank(admin);
        extractorRules.setExtractorPower(tokenId, power);

        assertEq(extractorRules.getExtractorsTotalPower(), _amount * power);

        vm.warp(block.timestamp + lifetime);

        stakeExtractor(user, tokenId, maxStakeable - _amount);
        vm.prank(admin);
        extractorRules.setExtractorPower(tokenId, power);

        assertEq(extractorRules.getExtractorsTotalPower(), maxStakeable * power);

        vm.warp(block.timestamp + 1);

        assertEq(extractorRules.getExtractorsTotalPower(), (maxStakeable - _amount) * power);
    }

    function test_getUserPower(
        address _user,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        assertEq(extractorRules.getUserPower(_user, extractorAddress, _tokenId, _amount), 0);
    }

    function test_getAbsorberPower(uint256 _amount) public {
        vm.prank(absorberFactory);
        extractorRules.setNftHandler(address(this));

        vm.assume(0 < _amount && _amount < maxStakeable - 1);

        address user = address(999);
        uint256 tokenId = 9;
        uint256 power = 5e17;

        assertEq(extractorRules.getAbsorberPower(), Constant.ONE);
        vm.prank(admin);
        extractorRules.setExtractorPower(tokenId, power);

        stakeExtractor(user, tokenId, _amount);

        assertEq(extractorRules.getAbsorberPower(), Constant.ONE + extractorRules.getExtractorsTotalPower());

        vm.warp(block.timestamp + lifetime);

        stakeExtractor(user, tokenId, maxStakeable - _amount);

        assertEq(extractorRules.getAbsorberPower(), Constant.ONE + extractorRules.getExtractorsTotalPower());

        vm.warp(block.timestamp + 1);

        assertEq(extractorRules.getAbsorberPower(), Constant.ONE + extractorRules.getExtractorsTotalPower());
    }

    function test_setMaxStakeable() public {
        assertEq(extractorRules.maxStakeable(), maxStakeable);

        uint256 newMaxStakeable = 15;

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        extractorRules.setMaxStakeable(newMaxStakeable);

        uint256 MAX_SPOTS = extractorRules.MAX_SPOTS();
        vm.prank(admin);
        vm.expectRevert(ExtractorStakingRules.TooManyStakeableSpots.selector);
        extractorRules.setMaxStakeable(MAX_SPOTS + 1);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit MaxStakeable(newMaxStakeable);
        extractorRules.setMaxStakeable(newMaxStakeable);

        assertEq(extractorRules.maxStakeable(), newMaxStakeable);
    }

    function test_setExtractorPower(uint256 _power) public {
        vm.prank(absorberFactory);
        extractorRules.setNftHandler(address(this));

        uint256 tokenId = 9;

        assertEq(extractorRules.extractorPower(tokenId), 0);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        extractorRules.setExtractorPower(tokenId, _power);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit ExtractorPower(tokenId, _power);
        extractorRules.setExtractorPower(tokenId, _power);

        assertEq(extractorRules.extractorPower(tokenId), _power);
    }

    function test_setExtractorLifetime(uint256 _lifetime) public {
        vm.prank(absorberFactory);
        extractorRules.setNftHandler(address(this));

        vm.assume(_lifetime != lifetime);

        assertEq(extractorRules.lifetime(), lifetime);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), extractorRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        extractorRules.setExtractorLifetime(_lifetime);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Lifetime(_lifetime);
        extractorRules.setExtractorLifetime(_lifetime);

        assertEq(extractorRules.lifetime(), _lifetime);
    }

    function test_supportsInterface() public {
        assertFalse(extractorRules.supportsInterface(bytes4("123")));
        assertTrue(extractorRules.supportsInterface(type(IExtractorStakingRules).interfaceId));
    }
}
