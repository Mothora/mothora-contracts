pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/Mock.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/interfaces/INftHandler.sol";
import "contracts/modules/absorber/interfaces/IAbsorber.sol";
import "contracts/modules/absorber/rules/PartsStakingRules.sol";

contract StakingRulesBaseImpl is StakingRulesBase {
    function init(address _admin, address _absorberFactory) external initializer {
        _initStakingRulesBase(_admin, _absorberFactory);
    }

    // implement abstract methods so it's deployable
    function _processStake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override {}

    function _processUnstake(
        address _user,
        address,
        uint256,
        uint256 _amount
    ) internal override {}

    function getUserPower(
        address,
        address,
        uint256,
        uint256
    ) external pure override returns (uint256) {}

    function getAbsorberPower() external view returns (uint256) {}
}

contract StakingRulesBaseTest is TestUtils {
    StakingRulesBase public stakingRules;

    address public admin;
    address public absorberFactory;

    function setUp() public {
        admin = address(111);
        vm.label(admin, "admin");
        absorberFactory = address(222);
        vm.label(absorberFactory, "absorberFactory");

        address impl = address(new StakingRulesBaseImpl());

        stakingRules = StakingRulesBaseImpl(address(new ERC1967Proxy(impl, bytes(""))));
        StakingRulesBaseImpl(address(stakingRules)).init(admin, absorberFactory);
    }

    function test_constants() public {
        assertEq(stakingRules.SR_ADMIN(), keccak256("SR_ADMIN"));
        assertEq(stakingRules.SR_NFT_HANDLER(), keccak256("SR_NFT_HANDLER"));
        assertEq(stakingRules.SR_NFT_HANDLER(), keccak256("SR_NFT_HANDLER"));
    }

    function test_setNftHandler() public {
        assertEq(stakingRules.getRoleAdmin(stakingRules.SR_ADMIN()), stakingRules.SR_ADMIN());
        assertEq(stakingRules.getRoleAdmin(stakingRules.SR_NFT_HANDLER()), stakingRules.SR_ADMIN());
        assertEq(stakingRules.getRoleAdmin(stakingRules.SR_ABSORBER_FACTORY()), stakingRules.SR_ADMIN());

        assertTrue(stakingRules.hasRole(stakingRules.SR_ADMIN(), admin));

        address nftHandler = address(1234);

        assertFalse(stakingRules.hasRole(stakingRules.SR_NFT_HANDLER(), nftHandler));
        assertTrue(stakingRules.hasRole(stakingRules.SR_ABSORBER_FACTORY(), absorberFactory));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), stakingRules.SR_ABSORBER_FACTORY());
        vm.expectRevert(errorMsg);
        stakingRules.setNftHandler(nftHandler);

        assertFalse(stakingRules.hasRole(stakingRules.SR_NFT_HANDLER(), nftHandler));
        assertTrue(stakingRules.hasRole(stakingRules.SR_ABSORBER_FACTORY(), absorberFactory));

        vm.prank(absorberFactory);
        stakingRules.setNftHandler(nftHandler);

        assertTrue(stakingRules.hasRole(stakingRules.SR_NFT_HANDLER(), nftHandler));
        assertFalse(stakingRules.hasRole(stakingRules.SR_ABSORBER_FACTORY(), absorberFactory));
    }

    function test_processStake() public {
        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), stakingRules.SR_NFT_HANDLER());
        vm.expectRevert(errorMsg);
        stakingRules.processStake(address(1), address(1), 1, 1);

        vm.prank(absorberFactory);
        stakingRules.setNftHandler(address(this));

        stakingRules.processStake(address(1), address(1), 1, 1);
    }

    function test_processUnstake() public {
        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), stakingRules.SR_NFT_HANDLER());
        vm.expectRevert(errorMsg);
        stakingRules.processUnstake(address(1), address(1), 1, 1);

        vm.prank(absorberFactory);
        stakingRules.setNftHandler(address(this));

        stakingRules.processUnstake(address(1), address(1), 1, 1);
    }
}
