pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/Mock.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/interfaces/INftHandler.sol";
import "contracts/modules/absorber/interfaces/IAbsorber.sol";
import "contracts/interfaces/IArtifactMetadataStore.sol";
import "contracts/modules/absorber/rules/ArtifactStakingRules.sol";

contract ArtifactStakingRulesMock is ArtifactStakingRules {
    function setStaked(uint256 _staked) public {
        staked = _staked;
    }

    function setTotalRank(uint256 _totalRank) public {
        totalRank = _totalRank;
    }
}

contract ArtifactStakingRulesTest is TestUtils {
    struct TestCase {
        uint256 artifactGeneration;
        uint256 artifactRarity;
        uint256 power;
        uint256 rank;
        uint256 weight;
    }

    // workaround for "UnimplementedFeatureError: Copying of type struct memory to storage not yet supported."
    uint256 public constant testCasesLength = 18;

    ArtifactStakingRulesMock public artifactRules;

    address public admin = address(111);
    address public absorberFactory = address(222);
    address public absorber = address(333);
    address public artifactMetadataStore = address(new Mock("ArtifactMetadataStore"));
    uint256 public maxArtifactWeight = 200e18;
    uint256 public maxStakeableTotal = 100;
    uint256 public powerFactor = 1e18;

    function setUp() public {
        address impl = address(new ArtifactStakingRulesMock());

        artifactRules = ArtifactStakingRulesMock(address(new ERC1967Proxy(impl, bytes(""))));
        artifactRules.init(
            admin,
            absorberFactory,
            IArtifactMetadataStore(artifactMetadataStore),
            maxArtifactWeight,
            maxStakeableTotal,
            powerFactor
        );

        vm.prank(absorberFactory);
        artifactRules.setNftHandler(address(this));

        vm.mockCall(address(absorber), abi.encodeCall(IAbsorber.callUpdateRewards, ()), abi.encode(true));
    }

    function getTestCase(uint256 _i) public view returns (TestCase memory) {
        uint256 illegalWeight = maxArtifactWeight * 1e18;
        uint256 illegalRank = 1e18;

        TestCase[testCasesLength] memory testCases = [
            // TODO: add more test cases
            // TestCase(artifactGeneration, artifactRarity, power, rank, weight)
            // Genesis Artifacts
            TestCase(0, 0, 600e16, 4e18, 120e18), // LEGENDARY
            TestCase(0, 1, 200e16, 4e18, 40e18), // RARE
            TestCase(0, 2, 75e16, 2e18, 16e18), // SPECIAL
            TestCase(0, 3, 100e16, 3e18, 21e18), // UNCOMMON
            TestCase(0, 4, 50e16, 1.5e18, 11e18), // COMMON
            TestCase(0, 5, 0, illegalRank, illegalWeight), // RECRUIT
            // Aux Artifacts
            TestCase(1, 0, 0, illegalRank, illegalWeight),
            TestCase(1, 1, 25e16, 1.2e18, 5.5e18), // RARE
            TestCase(1, 2, 0, illegalRank, illegalWeight),
            TestCase(1, 3, 10e16, 1.1e18, 4e18), // UNCOMMON
            TestCase(1, 4, 5e16, 1e18, 2.5e18), // COMMON
            TestCase(1, 5, 0, illegalRank, illegalWeight),
            // Recruits
            TestCase(2, 0, 0, illegalRank, illegalWeight),
            TestCase(2, 1, 0, illegalRank, illegalWeight),
            TestCase(2, 2, 0, illegalRank, illegalWeight),
            TestCase(2, 3, 0, illegalRank, illegalWeight),
            TestCase(2, 4, 0, illegalRank, illegalWeight),
            TestCase(2, 5, 0, illegalRank, illegalWeight)
        ];

        return testCases[_i];
    }

    function getMockMetadata(uint256 _artifactGeneration, uint256 _artifactRarity)
        public
        pure
        returns (IArtifactMetadataStore.ArtifactMetadata memory metadata)
    {
        metadata = IArtifactMetadataStore.ArtifactMetadata(
            IArtifactMetadataStore.ArtifactGeneration(_artifactGeneration),
            IArtifactMetadataStore.ArtifactClass.RECRUIT,
            IArtifactMetadataStore.ArtifactRarity(_artifactRarity),
            1,
            2,
            [0, 1, 2, 3, 4, 5]
        );
    }

    function mockMetadataCall(
        uint256 _tokenId,
        uint256 _artifactGeneration,
        uint256 _artifactRarity
    ) public {
        vm.mockCall(
            artifactMetadataStore,
            abi.encodeCall(IArtifactMetadataStore.metadataForArtifact, (_tokenId)),
            abi.encode(getMockMetadata(_artifactGeneration, _artifactRarity))
        );
    }

    function test_getUserPower() public {
        for (uint256 i = 0; i < testCasesLength; i++) {
            TestCase memory testCase = getTestCase(i);
            uint256 tokenId = i;

            mockMetadataCall(tokenId, testCase.artifactGeneration, testCase.artifactRarity);

            assertEq(artifactRules.getUserPower(address(0), address(0), tokenId, 0), testCase.power);
        }
    }

    function test_getArtifactPower() public {
        for (uint256 i = 0; i < testCasesLength; i++) {
            TestCase memory testCase = getTestCase(i);
            uint256 tokenId = i;

            mockMetadataCall(tokenId, testCase.artifactGeneration, testCase.artifactRarity);

            assertEq(
                artifactRules.getArtifactPower(testCase.artifactGeneration, testCase.artifactRarity),
                testCase.power
            );
        }
    }

    function test_getRank() public {
        for (uint256 i = 0; i < testCasesLength; i++) {
            TestCase memory testCase = getTestCase(i);
            uint256 tokenId = i;

            mockMetadataCall(tokenId, testCase.artifactGeneration, testCase.artifactRarity);

            assertEq(artifactRules.getRank(tokenId), testCase.rank);
        }
    }

    function test_getWeight() public {
        for (uint256 i = 0; i < testCasesLength; i++) {
            TestCase memory testCase = getTestCase(i);
            uint256 tokenId = i;

            mockMetadataCall(tokenId, testCase.artifactGeneration, testCase.artifactRarity);

            assertEq(artifactRules.getWeight(tokenId), testCase.weight);
        }
    }

    function test_getAbsorberPower() public {
        uint256[5][15] memory testData = [
            // maxStakeableTotal, staked, totalRank, powerFactor, result
            [uint256(11), 9, 10e18, 2e18, 2955371900826446280],
            // vary maxStakeableTotal and staked
            [uint256(2400), 0, 10e18, 2e18, 1e18],
            [uint256(2400), 90, 10e18, 2e18, 1134104166666666666],
            [uint256(2400), 2400, 10e18, 2e18, 2800833333333333332],
            [uint256(1), 0, 1e18, 2e18, 1e18],
            [uint256(1), 1, 1e18, 2e18, 3e18],
            [uint256(99999), 0, 10e18, 2e18, 1e18],
            [uint256(99999), 900, 10e18, 2e18, 1032294341483600237],
            [uint256(99999), 9999, 10e18, 2e18, 1342008840122601568],
            [uint256(99999), 99999, 10e18, 2e18, 2800020000200002000],
            // vary powerFactor
            [uint256(2400), 9, 10e18, 1e18, 1007569114583333333],
            [uint256(2400), 2400, 10e18, 9e18, 9103749999999999994],
            // vary totalRank
            [uint256(2400), 2200, 1e18, 1e18, 1893795138888888888],
            [uint256(2400), 2200, 50e18, 1e18, 1896006944444444443],
            [uint256(2400), 2200, 50e19, 1e18, 1916319444444444444]
        ];

        for (uint256 i = 0; i < 1; i++) {
            vm.prank(admin);
            artifactRules.setMaxStakeableTotal(uint256(testData[0][0]));
            assertEq(artifactRules.maxStakeableTotal(), testData[0][0]);

            artifactRules.setStaked(uint256(testData[0][1]));
            assertEq(artifactRules.staked(), testData[0][1]);

            artifactRules.setTotalRank(uint256(testData[0][2]));
            assertEq(artifactRules.totalRank(), testData[0][2]);

            vm.prank(admin);
            artifactRules.setPowerFactor(uint256(testData[0][3]));
            assertEq(artifactRules.powerFactor(), testData[0][3]);

            assertEq(artifactRules.getAbsorberPower(), testData[0][4]);
        }
    }

    // function test_processStake() public {}
    // function test_processUnstake() public {}

    function test_setArtifactMetadataStore() public {
        assertEq(address(artifactRules.artifactMetadataStore()), artifactMetadataStore);

        IArtifactMetadataStore newArtifactMetadataStore = IArtifactMetadataStore(address(1234));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), artifactRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        artifactRules.setArtifactMetadataStore(newArtifactMetadataStore);
        assertEq(address(artifactRules.artifactMetadataStore()), artifactMetadataStore);

        vm.prank(admin);
        artifactRules.setArtifactMetadataStore(newArtifactMetadataStore);
        assertEq(address(artifactRules.artifactMetadataStore()), address(newArtifactMetadataStore));
    }

    function test_setMaxWeight() public {
        assertEq(artifactRules.maxArtifactWeight(), maxArtifactWeight);

        uint256 newMaxArtifactWeight = 400e18;

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), artifactRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        artifactRules.setMaxWeight(newMaxArtifactWeight);
        assertEq(artifactRules.maxArtifactWeight(), maxArtifactWeight);

        vm.prank(admin);
        artifactRules.setMaxWeight(newMaxArtifactWeight);
        assertEq(artifactRules.maxArtifactWeight(), newMaxArtifactWeight);
    }

    function test_setMaxStakeableTotal() public {
        assertEq(artifactRules.maxStakeableTotal(), maxStakeableTotal);

        uint256 newMaxStakeableTotal = 500;

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), artifactRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        artifactRules.setMaxStakeableTotal(newMaxStakeableTotal);
        assertEq(artifactRules.maxStakeableTotal(), maxStakeableTotal);

        vm.prank(admin);
        artifactRules.setMaxStakeableTotal(newMaxStakeableTotal);
        assertEq(artifactRules.maxStakeableTotal(), newMaxStakeableTotal);
    }

    function test_setPowerFactor() public {
        assertEq(artifactRules.powerFactor(), powerFactor);

        uint256 newPowerFactor = 20e18;

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), artifactRules.SR_ADMIN());
        vm.expectRevert(errorMsg);
        artifactRules.setPowerFactor(newPowerFactor);
        assertEq(artifactRules.powerFactor(), powerFactor);

        vm.prank(admin);
        artifactRules.setPowerFactor(newPowerFactor);
        assertEq(artifactRules.powerFactor(), newPowerFactor);
    }
}
