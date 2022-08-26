pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/ERC20Mintable.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/EssencePipeline.sol";

contract EssencePipelineTest is TestUtils {
    EssencePipeline public essencePipeline;

    address public essence = address(420);
    address public admin = address(111);
    address public essenceField = address(112);
    address public absorberFactory = address(113);
    address public corruptionToken = address(115);

    address[] public allAbsorbers;
    address[] public excludedAddresses;

    uint256 public atlasMinePower = 8e18;

    event RewardsPaid(address indexed stream, uint256 rewardsPaid, uint256 rewardsPaidInTotal);
    event AbsorberFactory(IAbsorberFactory absorberFactory);
    event EssenceField(IEssenceField essenceField);
    event CorruptionNegativePowerMatrix(uint256[][] _corruptionNegativePowerMatrix);

    function setUp() public {
        // workaround for ERC20's code check
        vm.etch(essence, bytes("34567876543456787654"));

        vm.label(essence, "essence");
        vm.label(admin, "admin");
        vm.label(essenceField, "essenceField");
        vm.label(absorberFactory, "absorberFactory");
        vm.label(corruptionToken, "corruptionToken");

        for (uint256 i = 0; i < emissionsTestCasesLength; i++) {
            address absorberAddress = address(uint160(900 + i));
            allAbsorbers.push(absorberAddress);

            vm.label(absorberAddress, "allAbsorbers[i]");
        }

        vm.mockCall(
            address(absorberFactory),
            abi.encodeCall(IAbsorberFactory.getAllAbsorbers, ()),
            abi.encode(allAbsorbers)
        );

        address impl = address(new EssencePipeline());

        essencePipeline = EssencePipeline(address(new ERC1967Proxy(impl, bytes(""))));
        essencePipeline.init(
            admin,
            IEssenceField(essenceField),
            IAbsorberFactory(absorberFactory),
            IERC20(corruptionToken)
        );
    }

    function mockGetUtilization(
        address _absorber,
        uint256 _essenceTotalDeposits,
        uint256 _totalDepositCap
    ) public {
        vm.mockCall(_absorber, abi.encodeCall(IAbsorber.essenceTotalDeposits, ()), abi.encode(_essenceTotalDeposits));
        vm.mockCall(_absorber, abi.encodeCall(IAbsorber.totalDepositCap, ()), abi.encode(_totalDepositCap));

        vm.mockCall(address(absorberFactory), abi.encodeCall(IAbsorberFactory.essence, ()), abi.encode(essence));
    }

    function test_getUtilization() public {
        address absorber = allAbsorbers[0];
        uint256 essenceTotalDeposits = 5000;
        uint256 totalDepositCap = 10000;

        mockGetUtilization(absorber, essenceTotalDeposits, totalDepositCap);
        assertEq(essencePipeline.getUtilization(absorber), 0.5e18);

        mockGetUtilization(absorber, essenceTotalDeposits * 2, totalDepositCap);
        assertEq(essencePipeline.getUtilization(absorber), 1e18);

        mockGetUtilization(absorber, essenceTotalDeposits / 2, totalDepositCap);
        assertEq(essencePipeline.getUtilization(absorber), 0.25e18);
    }

    function test_getUtilizationPower() public {
        address absorber = allAbsorbers[0];
        uint256 totalDepositCap = 10000;
        uint256 essenceTotalDeposits;

        uint256[2][14] memory testCases = [
            [uint256(10000), uint256(1e18)],
            [uint256(9000), uint256(1e18)],
            [uint256(8000), uint256(1e18)],
            [uint256(7999), uint256(0.9e18)],
            [uint256(7000), uint256(0.9e18)],
            [uint256(6999), uint256(0.8e18)],
            [uint256(6000), uint256(0.8e18)],
            [uint256(5999), uint256(0.7e18)],
            [uint256(5000), uint256(0.7e18)],
            [uint256(4999), uint256(0.6e18)],
            [uint256(4000), uint256(0.6e18)],
            [uint256(3999), uint256(0.5e18)],
            [uint256(3000), uint256(0.5e18)],
            [uint256(2999), uint256(0)]
        ];

        for (uint256 i = 0; i < testCases.length; i++) {
            essenceTotalDeposits = testCases[i][0];
            uint256 power = testCases[i][1];

            mockGetUtilization(absorber, essenceTotalDeposits, totalDepositCap);
            assertEq(essencePipeline.getUtilizationPower(absorber), power);
        }
    }

    function mockGetCorruptionNegativePower(
        address _corruptionToken,
        address _absorber,
        uint256 _absorberBal
    ) public {
        vm.mockCall(_corruptionToken, abi.encodeCall(IERC20.balanceOf, (_absorber)), abi.encode(_absorberBal));
    }

    function test_getCorruptionNegativePower() public {
        address absorber = allAbsorbers[0];

        uint256[2][13] memory testCases = [
            [uint256(600_001e18), uint256(0.4e18)],
            [uint256(600_000e18), uint256(0.5e18)],
            [uint256(500_001e18), uint256(0.5e18)],
            [uint256(500_000e18), uint256(0.6e18)],
            [uint256(400_001e18), uint256(0.6e18)],
            [uint256(400_000e18), uint256(0.7e18)],
            [uint256(300_001e18), uint256(0.7e18)],
            [uint256(300_000e18), uint256(0.8e18)],
            [uint256(200_001e18), uint256(0.8e18)],
            [uint256(200_000e18), uint256(0.9e18)],
            [uint256(100_001e18), uint256(0.9e18)],
            [uint256(100_000e18), uint256(1e18)],
            [uint256(0), uint256(1e18)]
        ];

        for (uint256 i = 0; i < testCases.length; i++) {
            uint256 absorberBal = testCases[i][0];
            uint256 power = testCases[i][1];

            mockGetCorruptionNegativePower(corruptionToken, absorber, absorberBal);

            assertEq(essencePipeline.getCorruptionNegativePower(absorber), power);
        }
    }

    function mockgetAbsorberEmissionsPower(
        address _absorber,
        uint256 _absorberTotalPower,
        uint256 _essenceTotalDeposits,
        uint256 _totalDepositCap,
        uint256 _corruptionBalance
    ) public {
        address nftHandler = address(uint160(_absorber) + 99);
        vm.mockCall(_absorber, abi.encodeCall(IAbsorber.nftHandler, ()), abi.encode(nftHandler));
        vm.mockCall(nftHandler, abi.encodeCall(INftHandler.getAbsorberTotalPower, ()), abi.encode(_absorberTotalPower));

        mockGetUtilization(_absorber, _essenceTotalDeposits, _totalDepositCap);

        mockGetCorruptionNegativePower(corruptionToken, _absorber, _corruptionBalance);
    }

    struct EmissionsShareTest {
        uint256 absorberTotalPower;
        uint256 essenceTotalDeposits;
        uint256 totalDepositCap;
        uint256 expectedUtilizationPower;
        uint256 corruptionBalance;
        uint256 expectedCorruptionNegativePower;
        uint256 expectedAbsorberEmissionsShare;
    }

    // workaround for "UnimplementedFeatureError: Copying of type struct memory to storage not yet supported."
    uint256 public constant emissionsTestCasesLength = 3;

    function getEmissionsTestCase(uint256 _index) public pure returns (EmissionsShareTest memory) {
        EmissionsShareTest[emissionsTestCasesLength] memory emissionsTestCases = [
            // TODO: add more test cases
            EmissionsShareTest({
                absorberTotalPower: 2e18,
                essenceTotalDeposits: 10000,
                totalDepositCap: 10000,
                expectedUtilizationPower: 1e18,
                corruptionBalance: 0,
                expectedCorruptionNegativePower: 1e18,
                expectedAbsorberEmissionsShare: 2e18
            }),
            EmissionsShareTest({
                absorberTotalPower: 4e18,
                essenceTotalDeposits: 3500,
                totalDepositCap: 10000,
                expectedUtilizationPower: 0.5e18,
                corruptionBalance: 0,
                expectedCorruptionNegativePower: 1e18,
                expectedAbsorberEmissionsShare: 2e18
            }),
            EmissionsShareTest({
                absorberTotalPower: 4e18,
                essenceTotalDeposits: 10000,
                totalDepositCap: 10000,
                expectedUtilizationPower: 1e18,
                corruptionBalance: 0,
                expectedCorruptionNegativePower: 1e18,
                expectedAbsorberEmissionsShare: 4e18
            })
        ];

        return emissionsTestCases[_index];
    }

    function test_getAbsorberEmissionsPower() public {
        address absorber = allAbsorbers[0];

        for (uint256 i = 0; i < emissionsTestCasesLength; i++) {
            EmissionsShareTest memory data = getEmissionsTestCase(i);

            mockgetAbsorberEmissionsPower(
                absorber,
                data.absorberTotalPower,
                data.essenceTotalDeposits,
                data.totalDepositCap,
                data.corruptionBalance
            );

            assertEq(essencePipeline.getUtilizationPower(absorber), data.expectedUtilizationPower);
            assertEq(essencePipeline.getCorruptionNegativePower(absorber), data.expectedCorruptionNegativePower);
            assertEq(essencePipeline.getAbsorberEmissionsPower(absorber), data.expectedAbsorberEmissionsShare);
        }
    }

    function setupDistributeRewards(uint256 _rewards)
        public
        returns (
            address[] memory allActiveAbsorbers,
            uint256[] memory absorberShare,
            uint256 totalShare
        )
    {
        uint256 len = allAbsorbers.length;

        allActiveAbsorbers = new address[](len);
        absorberShare = new uint256[](len);

        vm.mockCall(address(essenceField), abi.encodeCall(IEssenceField.requestRewards, ()), abi.encode(_rewards));

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            EmissionsShareTest memory data = getEmissionsTestCase(i);

            allActiveAbsorbers[i] = allAbsorbers[i];
            absorberShare[i] = data.expectedAbsorberEmissionsShare;
            totalShare += data.expectedAbsorberEmissionsShare;

            mockgetAbsorberEmissionsPower(
                allAbsorbers[i],
                data.absorberTotalPower,
                data.essenceTotalDeposits,
                data.totalDepositCap,
                data.corruptionBalance
            );
        }
    }

    function test_distributeRewards() public {
        uint256 unpaid;
        uint256 rewards = 5000;

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[i]);
            assertEq(unpaid, 0);
        }

        setupDistributeRewards(rewards);

        essencePipeline.distributeRewards();

        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[0]);
        assertEq(unpaid, 1250);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[1]);
        assertEq(unpaid, 1250);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[2]);
        assertEq(unpaid, 2500);

        vm.prank(admin);

        essencePipeline.distributeRewards();

        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[0]);
        assertEq(unpaid, 1250);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[1]);
        assertEq(unpaid, 1250);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[2]);
        assertEq(unpaid, 2500);

        vm.warp(block.timestamp + 1);
        essencePipeline.distributeRewards();

        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[0]);
        assertEq(unpaid, 3750);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[1]);
        assertEq(unpaid, 3750);
        (unpaid, ) = essencePipeline.rewardsBalance(allAbsorbers[2]);
        assertEq(unpaid, 7500);
    }

    function test_getAbsorberShares() public {
        uint256 rewards = 10000;

        vm.mockCall(
            address(essenceField),
            abi.encodeCall(IEssenceField.getPendingRewards, (address(essencePipeline))),
            abi.encode(rewards)
        );

        vm.prank(admin);

        (
            address[] memory expectedAllActiveAbsorbers,
            uint256[] memory expectedAbsorberShare,
            uint256 expectedTotalShare
        ) = setupDistributeRewards(rewards);

        for (
            uint256 expectedTargetIndex = 0;
            expectedTargetIndex < expectedAllActiveAbsorbers.length;
            expectedTargetIndex++
        ) {
            address targetAbsorber = expectedAllActiveAbsorbers[expectedTargetIndex];

            (
                address[] memory allActiveAbsorbers,
                uint256[] memory absorberShare,
                uint256 totalShare,
                uint256 targetIndex
            ) = essencePipeline.getAbsorberShares(targetAbsorber);

            assertEq(allActiveAbsorbers.length, expectedAllActiveAbsorbers.length);
            assertAddressArrayEq(allActiveAbsorbers, expectedAllActiveAbsorbers);

            assertEq(absorberShare.length, expectedAbsorberShare.length);
            assertUint256ArrayEq(absorberShare, expectedAbsorberShare);

            assertEq(totalShare, expectedTotalShare);
            assertEq(targetIndex, expectedTargetIndex);

            (uint256 unpaid, ) = essencePipeline.rewardsBalance(targetAbsorber);
            assertEq(unpaid, 0);

            uint256 pendingRewards = essencePipeline.getPendingRewards(targetAbsorber);
            assertFalse(pendingRewards == 0);
            assertEq(pendingRewards, (rewards * absorberShare[targetIndex]) / totalShare);
        }
    }

    function test_requestRewards() public {
        uint256 paid;
        uint256 unpaid;
        uint256 rewardsPaid;
        uint256 rewards = 5000;
        uint256[3] memory expectedRewards = [uint256(1250), 1250, 2500];

        setupDistributeRewards(rewards);

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            (unpaid, paid) = essencePipeline.rewardsBalance(allAbsorbers[i]);
            assertEq(unpaid, 0);
            assertEq(paid, 0);

            vm.mockCall(
                essence,
                abi.encodeCall(IERC20.transfer, (allAbsorbers[i], expectedRewards[i])),
                abi.encode(true)
            );
        }

        essencePipeline.distributeRewards();

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            (unpaid, paid) = essencePipeline.rewardsBalance(allAbsorbers[i]);
            assertEq(unpaid, expectedRewards[i]);
            assertEq(paid, 0);
        }

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            address absorber = allAbsorbers[i];
            uint256 expectedReward = expectedRewards[i];
            uint256 totalReward = expectedReward;

            vm.prank(absorber);
            vm.expectCall(essence, abi.encodeCall(IERC20.transfer, (absorber, expectedReward)));
            vm.expectEmit(true, true, true, true);
            emit RewardsPaid(absorber, expectedReward, totalReward);
            rewardsPaid = essencePipeline.requestRewards();
            assertEq(rewardsPaid, expectedReward);

            (unpaid, paid) = essencePipeline.rewardsBalance(absorber);
            assertEq(unpaid, 0);
            assertEq(paid, expectedReward);

            vm.prank(absorber);
            rewardsPaid = essencePipeline.requestRewards();
            assertEq(rewardsPaid, 0);

            (unpaid, paid) = essencePipeline.rewardsBalance(absorber);
            assertEq(unpaid, 0);
            assertEq(paid, expectedReward);
        }

        vm.warp(block.timestamp + 1);
        essencePipeline.distributeRewards();

        vm.warp(block.timestamp + 1);
        essencePipeline.distributeRewards();

        for (uint256 i = 0; i < allAbsorbers.length; i++) {
            address absorber = allAbsorbers[i];
            uint256 expectedReward = expectedRewards[i] * 2;
            uint256 totalReward = expectedRewards[i] * 3;

            vm.mockCall(essence, abi.encodeCall(IERC20.transfer, (absorber, expectedReward)), abi.encode(true));

            vm.prank(absorber);
            vm.expectCall(essence, abi.encodeCall(IERC20.transfer, (absorber, expectedReward)));
            vm.expectEmit(true, true, true, true);
            emit RewardsPaid(absorber, expectedReward, totalReward);
            rewardsPaid = essencePipeline.requestRewards();
            assertEq(rewardsPaid, expectedReward);

            (unpaid, paid) = essencePipeline.rewardsBalance(absorber);
            assertEq(unpaid, 0);
            assertEq(paid, totalReward);

            vm.prank(absorber);
            rewardsPaid = essencePipeline.requestRewards();
            assertEq(rewardsPaid, 0);

            (unpaid, paid) = essencePipeline.rewardsBalance(absorber);
            assertEq(unpaid, 0);
            assertEq(paid, totalReward);
        }

        vm.warp(block.timestamp + 1);
        essencePipeline.distributeRewards();

        vm.prank(address(1234567890));
        rewardsPaid = essencePipeline.requestRewards();
        assertEq(rewardsPaid, 0);
    }

    function test_setAbsorberFactory() public {
        assertEq(address(essencePipeline.absorberFactory()), absorberFactory);

        IAbsorberFactory newAbsorberFactory = IAbsorberFactory(address(76));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(
            address(this),
            essencePipeline.ESSENCE_PIPELINE_ADMIN()
        );
        vm.expectRevert(errorMsg);
        essencePipeline.setAbsorberFactory(newAbsorberFactory);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit AbsorberFactory(newAbsorberFactory);
        essencePipeline.setAbsorberFactory(newAbsorberFactory);

        assertEq(address(essencePipeline.absorberFactory()), address(newAbsorberFactory));
    }

    function test_setEssenceField() public {
        assertEq(address(essencePipeline.essenceField()), essenceField);

        IEssenceField newEssenceField = IEssenceField(address(76));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(
            address(this),
            essencePipeline.ESSENCE_PIPELINE_ADMIN()
        );
        vm.expectRevert(errorMsg);
        essencePipeline.setEssenceField(newEssenceField);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit EssenceField(newEssenceField);
        essencePipeline.setEssenceField(newEssenceField);

        assertEq(address(essencePipeline.essenceField()), address(newEssenceField));
    }

    uint256[][] public oldCorruptionNegativePowerMatrix = [
        [uint256(600_000e18), uint256(0.4e18)],
        [uint256(500_000e18), uint256(0.5e18)],
        [uint256(400_000e18), uint256(0.6e18)],
        [uint256(300_000e18), uint256(0.7e18)],
        [uint256(200_000e18), uint256(0.8e18)],
        [uint256(100_000e18), uint256(0.9e18)]
    ];

    function test_getCorruptionNegativePowerMatrix() public {
        assertMatrixEq(essencePipeline.getCorruptionNegativePowerMatrix(), oldCorruptionNegativePowerMatrix);
    }

    uint256[][] public newCorruptionNegativePowerMatrix = [
        [uint256(6_000e18), uint256(0.04e18)],
        [uint256(5_000e18), uint256(0.05e18)],
        [uint256(4_000e18), uint256(0.06e18)],
        [uint256(3_000e18), uint256(0.07e18)],
        [uint256(2_000e18), uint256(0.08e18)],
        [uint256(1_000e18), uint256(0.09e18)]
    ];

    function test_setCorruptionNegativePowerMatrix() public {
        assertMatrixEq(essencePipeline.getCorruptionNegativePowerMatrix(), oldCorruptionNegativePowerMatrix);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(
            address(this),
            essencePipeline.ESSENCE_PIPELINE_ADMIN()
        );
        vm.expectRevert(errorMsg);
        essencePipeline.setCorruptionNegativePowerMatrix(newCorruptionNegativePowerMatrix);
        assertMatrixEq(essencePipeline.getCorruptionNegativePowerMatrix(), oldCorruptionNegativePowerMatrix);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit CorruptionNegativePowerMatrix(newCorruptionNegativePowerMatrix);
        essencePipeline.setCorruptionNegativePowerMatrix(newCorruptionNegativePowerMatrix);

        assertMatrixEq(essencePipeline.getCorruptionNegativePowerMatrix(), newCorruptionNegativePowerMatrix);
    }
}
