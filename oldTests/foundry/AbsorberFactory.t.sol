pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/ERC721Mintable.sol";
import "foundry/lib/ERC1155Mintable.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/AbsorberFactory.sol";
import "contracts/modules/absorber/Absorber.sol";
import "contracts/modules/absorber/NftHandler.sol";
import "contracts/modules/absorber/rules/ArtifactStakingRules.sol";
import "contracts/modules/absorber/rules/ExtractorStakingRules.sol";

contract AbsorberFactoryTest is TestUtils {
    AbsorberFactory public absorberFactory;

    address public admin = address(111);
    address public parts = address(222);
    uint256 public partsTokenId = 7;

    address public absorberImpl;
    address public nftHandlerImpl;

    IERC20 public essence = IERC20(address(333));
    IEssencePipeline public essencePipeline = IEssencePipeline(address(444));

    address public artifactMetadataStore = address(555);
    uint256 public maxArtifactWeight = 2000e18;
    uint256 public maxStakeableTotal = 100;
    uint256 public powerFactor = 1e18;

    uint256 public maxStakeableTreasuresPerUser = 20;
    uint256 public maxStakeable = 50;
    uint256 public lifetime = 3600;

    ERC721Mintable public nftErc721;
    ERC1155Mintable public nftErc1155;
    ERC1155Mintable public nftErc1155Treasures;

    ArtifactStakingRules public erc721StakingRules;
    ExtractorStakingRules public erc1155StakingRules;

    uint256 public initTotalDepositCap = 10_000_000e18;

    IAbsorber.CapConfig public initDepositCapPerWallet =
        IAbsorber.CapConfig({parts: parts, partsTokenId: partsTokenId, capPerPart: 1e18});

    event Essence(IERC20 essence);
    event EssencePipeline(IEssencePipeline essencePipeline);
    event Upgraded(address indexed implementation);

    function setUp() public {
        vm.label(admin, "admin");
        address impl;

        absorberImpl = address(new Absorber());
        nftHandlerImpl = address(new NftHandler());

        impl = address(new AbsorberFactory());

        absorberFactory = AbsorberFactory(address(new ERC1967Proxy(impl, bytes(""))));
        absorberFactory.init(essence, essencePipeline, admin, absorberImpl, nftHandlerImpl);

        nftErc721 = new ERC721Mintable();
        nftErc1155 = new ERC1155Mintable();
        nftErc1155Treasures = new ERC1155Mintable();

        impl = address(new ArtifactStakingRules());

        erc721StakingRules = ArtifactStakingRules(address(new ERC1967Proxy(impl, bytes(""))));
        erc721StakingRules.init(
            admin,
            address(absorberFactory),
            IArtifactMetadataStore(artifactMetadataStore),
            maxArtifactWeight,
            maxStakeableTotal,
            powerFactor
        );

        impl = address(new ExtractorStakingRules());

        erc1155StakingRules = ExtractorStakingRules(address(new ERC1967Proxy(impl, bytes(""))));
        erc1155StakingRules.init(admin, address(absorberFactory), address(nftErc1155), maxStakeable, lifetime);
    }

    function test_constructor() public {
        assertEq(absorberFactory.getRoleAdmin(absorberFactory.AF_ADMIN()), absorberFactory.AF_ADMIN());
        assertTrue(absorberFactory.hasRole(absorberFactory.AF_ADMIN(), admin));

        assertEq(absorberFactory.getRoleAdmin(absorberFactory.AF_DEPLOYER()), absorberFactory.AF_ADMIN());
        assertTrue(absorberFactory.hasRole(absorberFactory.AF_DEPLOYER(), admin));

        assertEq(absorberFactory.getRoleAdmin(absorberFactory.AF_BEACON_ADMIN()), absorberFactory.AF_ADMIN());
        assertTrue(absorberFactory.hasRole(absorberFactory.AF_BEACON_ADMIN(), admin));

        assertTrue(address(absorberFactory.absorberBeacon()) != address(0));
        assertTrue(address(absorberFactory.nftHandlerBeacon()) != address(0));
    }

    function getNftAndNftConfig()
        public
        view
        returns (
            address[] memory,
            uint256[] memory,
            INftHandler.NftConfig[] memory
        )
    {
        INftHandler.NftConfig memory erc721Config = INftHandler.NftConfig({
            supportedInterface: INftHandler.Interfaces.ERC721,
            stakingRules: IStakingRules(address(erc721StakingRules))
        });

        INftHandler.NftConfig memory erc1155Config = INftHandler.NftConfig({
            supportedInterface: INftHandler.Interfaces.ERC1155,
            stakingRules: IStakingRules(address(erc1155StakingRules))
        });

        address[] memory nfts = new address[](2);
        nfts[0] = address(nftErc721);
        nfts[1] = address(nftErc1155);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = NftHandler(nftHandlerImpl).DEFAULT_ID();
        tokenIds[1] = NftHandler(nftHandlerImpl).DEFAULT_ID();

        INftHandler.NftConfig[] memory nftConfigs = new INftHandler.NftConfig[](2);
        nftConfigs[0] = erc721Config;
        nftConfigs[1] = erc1155Config;

        return (nfts, tokenIds, nftConfigs);
    }

    function checkAbsorberInit(IAbsorber _absorber, INftHandler _nftHandler) public {
        Absorber absorber = Absorber(address(_absorber));
        assertTrue(absorber.hasRole(absorber.ABSORBER_ADMIN(), admin));
        assertEq(absorber.getRoleAdmin(absorber.ABSORBER_ADMIN()), absorber.ABSORBER_ADMIN());
        assertEq(absorber.totalDepositCap(), initTotalDepositCap);
        assertEq(address(absorber.factory()), address(absorberFactory));
        assertEq(address(absorber.nftHandler()), address(_nftHandler));

        (address initParts, uint256 tokenId, uint256 initCapPerPart) = absorber.depositCapPerWallet();
        assertEq(initParts, initDepositCapPerWallet.parts);
        assertEq(tokenId, initDepositCapPerWallet.partsTokenId);
        assertEq(initCapPerPart, initDepositCapPerWallet.capPerPart);
    }

    function checkNftHandlerInit(INftHandler _nftHandler, IAbsorber _absorber) public {
        NftHandler nftHandler = NftHandler(address(_nftHandler));
        assertEq(nftHandler.getRoleAdmin(nftHandler.NH_ADMIN()), nftHandler.NH_ADMIN());
        assertTrue(nftHandler.hasRole(nftHandler.NH_ADMIN(), admin));
        assertEq(address(nftHandler.absorber()), address(_absorber));
    }

    function test_deployAbsorber() public {
        assertEq(absorberFactory.getAbsorber(0), address(0));
        address[] memory emptyArray = new address[](0);
        uint256[] memory emptyUnit = new uint256[](0);
        assertAddressArrayEq(absorberFactory.getAllAbsorbers(), emptyArray);
        assertEq(absorberFactory.getAllAbsorbersLength(), 0);
        assertAddressArrayEq(absorberFactory.getAllAbsorbers(), emptyArray);

        (
            address[] memory nfts,
            uint256[] memory tokenIds,
            INftHandler.NftConfig[] memory nftConfigs
        ) = getNftAndNftConfig();

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_DEPLOYER());
        vm.expectRevert(errorMsg);
        absorberFactory.deployAbsorber(admin, initDepositCapPerWallet, nfts, tokenIds, nftConfigs);

        vm.prank(admin);
        absorberFactory.deployAbsorber(admin, initDepositCapPerWallet, nfts, tokenIds, nftConfigs);

        IAbsorber absorber = IAbsorber(absorberFactory.getAbsorber(0));

        vm.expectRevert("Initializable: contract is already initialized");
        absorber.init(
            address(2),
            INftHandler(address(2)),
            IAbsorber.CapConfig({parts: address(2), partsTokenId: 1, capPerPart: 2})
        );

        address[] memory absorbers = new address[](1);
        absorbers[0] = address(absorber);

        assertAddressArrayEq(absorberFactory.getAllAbsorbers(), absorbers);
        assertEq(absorberFactory.getAllAbsorbersLength(), 1);
        assertAddressArrayEq(absorberFactory.getAllAbsorbers(), absorbers);

        INftHandler.NftConfig[] memory emptyConfig = new INftHandler.NftConfig[](0);
        INftHandler nftHandler = absorber.nftHandler();

        vm.expectRevert("Initializable: contract is already initialized");
        nftHandler.init(address(2), address(2), emptyArray, emptyUnit, emptyConfig);

        checkAbsorberInit(absorber, nftHandler);
        checkNftHandlerInit(nftHandler, absorber);
    }

    function deployAbsorber() public returns (IAbsorber) {
        (
            address[] memory nfts,
            uint256[] memory tokenIds,
            INftHandler.NftConfig[] memory nftConfigs
        ) = getNftAndNftConfig();

        vm.prank(admin);
        absorberFactory.deployAbsorber(admin, initDepositCapPerWallet, nfts, tokenIds, nftConfigs);

        return IAbsorber(absorberFactory.getAbsorber(0));
    }

    function test_enableAbsorber() public {
        IAbsorber absorber = deployAbsorber();

        assertEq(absorber.disabled(), false);
        assertEq(absorberFactory.getAllAbsorbersLength(), 1);
        assertEq(absorberFactory.getAbsorber(0), address(absorber));

        vm.prank(admin);
        absorberFactory.disableAbsorber(absorber);

        assertEq(absorber.disabled(), true);
        assertEq(absorberFactory.getAllAbsorbersLength(), 0);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_DEPLOYER());
        vm.expectRevert(errorMsg);
        absorberFactory.enableAbsorber(absorber);

        vm.prank(admin);
        absorberFactory.enableAbsorber(absorber);

        assertEq(absorber.disabled(), false);
        assertEq(absorberFactory.getAllAbsorbersLength(), 1);
        assertEq(absorberFactory.getAbsorber(0), address(absorber));

        address fakeAbsorber = address(9999);
        vm.mockCall(fakeAbsorber, abi.encodeCall(IAbsorber.callUpdateRewards, ()), abi.encode(true));

        vm.prank(admin);
        vm.expectRevert(AbsorberFactory.NotAbsorber.selector);
        absorberFactory.enableAbsorber(IAbsorber(fakeAbsorber));
    }

    function test_disableAbsorber() public {
        IAbsorber absorber = deployAbsorber();

        assertEq(absorber.disabled(), false);
        assertEq(absorberFactory.getAllAbsorbersLength(), 1);
        assertEq(absorberFactory.getAbsorber(0), address(absorber));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_DEPLOYER());
        vm.expectRevert(errorMsg);
        absorberFactory.disableAbsorber(absorber);

        vm.prank(admin);
        absorberFactory.disableAbsorber(absorber);

        assertEq(absorber.disabled(), true);
        assertEq(absorberFactory.getAllAbsorbersLength(), 0);

        vm.prank(admin);
        vm.expectRevert(AbsorberFactory.NotAbsorber.selector);
        absorberFactory.disableAbsorber(absorber);
    }

    function test_setEssenceToken() public {
        assertEq(address(absorberFactory.essence()), address(essence));

        IERC20 newEssence = IERC20(address(76));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_ADMIN());
        vm.expectRevert(errorMsg);
        absorberFactory.setEssenceToken(newEssence);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Essence(newEssence);
        absorberFactory.setEssenceToken(newEssence);

        assertEq(address(absorberFactory.essence()), address(newEssence));
    }

    function test_setEssencePipeline() public {
        assertEq(address(absorberFactory.essencePipeline()), address(essencePipeline));

        IEssencePipeline newEssencePipeline = IEssencePipeline(address(77));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_ADMIN());
        vm.expectRevert(errorMsg);
        absorberFactory.setEssencePipeline(newEssencePipeline);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit EssencePipeline(newEssencePipeline);
        absorberFactory.setEssencePipeline(newEssencePipeline);

        assertEq(address(absorberFactory.essencePipeline()), address(newEssencePipeline));
    }

    function test_upgradeAbsorberTo() public {
        assertEq(absorberFactory.absorberBeacon().implementation(), absorberImpl);

        address newAbsorberImpl = address(78);
        vm.etch(newAbsorberImpl, bytes("0x42"));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_BEACON_ADMIN());
        vm.expectRevert(errorMsg);
        absorberFactory.upgradeAbsorberTo(newAbsorberImpl);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Upgraded(newAbsorberImpl);
        absorberFactory.upgradeAbsorberTo(newAbsorberImpl);

        assertEq(absorberFactory.absorberBeacon().implementation(), newAbsorberImpl);
    }

    function test_upgradeNftHandlerTo() public {
        assertEq(absorberFactory.nftHandlerBeacon().implementation(), nftHandlerImpl);

        address newNftHandlerImpl = address(79);
        vm.etch(newNftHandlerImpl, bytes("0x42"));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorberFactory.AF_BEACON_ADMIN());
        vm.expectRevert(errorMsg);
        absorberFactory.upgradeNftHandlerTo(newNftHandlerImpl);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Upgraded(newNftHandlerImpl);
        absorberFactory.upgradeNftHandlerTo(newNftHandlerImpl);

        assertEq(absorberFactory.nftHandlerBeacon().implementation(), newNftHandlerImpl);
    }
}
