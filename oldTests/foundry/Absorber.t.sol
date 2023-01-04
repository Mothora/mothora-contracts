pragma solidity ^0.8.0;

import "foundry/lib/TestUtils.sol";
import "foundry/lib/ERC20Mintable.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "contracts/modules/absorber/Absorber.sol";

contract AbsorberMock is Absorber {
    function addDeposit(address _user) public returns (UserInfo memory user, uint256 newDepositId) {
        return super._addDeposit(_user);
    }

    function removeDeposit(address _user, uint256 _depositId) public {
        super._removeDeposit(_user, _depositId);
    }

    function setGlobalDepositAmount(address _user, uint256 _amount) public {
        GlobalUserDeposit storage g = getUserGlobalDeposit[_user];
        g.globalDepositAmount = _amount;
    }
}

contract EssencePipelineMock {
    ERC20Mintable public essence;

    constructor(ERC20Mintable _essence) {
        essence = _essence;
    }

    function setReward(uint256 _reward) public {
        essence.mint(address(this), _reward);
    }

    function requestRewards() public returns (uint256 rewards) {
        rewards = essence.balanceOf(address(this));
        essence.transfer(msg.sender, rewards);
    }

    function getPendingRewards(address _absorber) public returns (uint256 rewards) {}
}

contract AbsorberTest is TestUtils {
    Absorber public absorber;

    address public admin = address(111);
    address public nftHandler = address(222);
    address public parts = address(333);
    uint256 public partsTokenId = 7;
    address public absorberFactory = address(this);
    address public randomWallet = address(444);
    address public essencePipeline = address(555);
    address public stakingRules = address(665);

    address public user1 = address(1001);
    address public user2 = address(1002);
    address public user3 = address(1003);
    address public user4 = address(1004);

    ERC20Mintable public essence;
    EssencePipelineMock public essencePipelineMock;

    uint256 public initTotalDepositCap = 10_000_000e18;

    IAbsorber.CapConfig public initDepositCapPerWallet =
        IAbsorber.CapConfig({parts: parts, partsTokenId: partsTokenId, capPerPart: 1e18});

    event NftHandler(INftHandler _nftHandler);
    event DepositCapPerWallet(IAbsorber.CapConfig _depositCapPerWallet);
    event TotalDepositCap(uint256 _totalDepositCap);
    event UnlockAll(bool _value);
    event Enable();
    event Disable();
    event Deposit(address indexed user, uint256 indexed index, uint256 amount, uint256 lock);
    event Withdraw(address indexed user, uint256 indexed index, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event TimelockOption(IAbsorber.Timelock timelock, uint256 id);
    event TimelockOptionEnabled(IAbsorber.Timelock timelock, uint256 id);
    event TimelockOptionDisabled(IAbsorber.Timelock timelock, uint256 id);

    function setUp() public {
        vm.label(admin, "admin");
        vm.label(nftHandler, "nftHandler");

        address impl = address(new Absorber());

        absorber = Absorber(address(new ERC1967Proxy(impl, bytes(""))));
        absorber.init(admin, INftHandler(nftHandler), initDepositCapPerWallet);

        uint256 TWO_WEEKS = absorber.TWO_WEEKS();
        uint256 ONE_MONTH = absorber.ONE_MONTH();
        uint256 THREE_MONTHS = absorber.THREE_MONTHS();
        uint256 SIX_MONTHS = absorber.SIX_MONTHS();
        uint256 TWELVE_MONTHS = absorber.TWELVE_MONTHS();

        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(0.1e18, TWO_WEEKS, 0, true));
        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(0.25e18, ONE_MONTH, 7 days, true));
        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(0.8e18, THREE_MONTHS, 14 days, true));
        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(1.8e18, SIX_MONTHS, 30 days, true));
        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(4e18, TWELVE_MONTHS, 45 days, true));

        essence = new ERC20Mintable();
        vm.mockCall(absorberFactory, abi.encodeCall(IAbsorberFactory.essence, ()), abi.encode(address(essence)));

        essencePipelineMock = new EssencePipelineMock(essence);
    }

    function test_init() public {
        assertTrue(absorber.hasRole(absorber.ABSORBER_ADMIN(), admin));
        assertEq(absorber.getRoleAdmin(absorber.ABSORBER_ADMIN()), absorber.ABSORBER_ADMIN());
        assertEq(absorber.totalDepositCap(), initTotalDepositCap);
        assertEq(address(absorber.factory()), absorberFactory);
        assertEq(address(absorber.nftHandler()), nftHandler);

        (address initParts, uint256 tokenId, uint256 initCapPerPart) = absorber.depositCapPerWallet();
        assertEq(initParts, initDepositCapPerWallet.parts);
        assertEq(tokenId, initDepositCapPerWallet.partsTokenId);
        assertEq(initCapPerPart, initDepositCapPerWallet.capPerPart);
    }

    function test_getTimelockOptionsIds() public {
        uint256[] memory expectedIds = new uint256[](6);

        for (uint256 i = 0; i < expectedIds.length; i++) {
            expectedIds[i] = i;
        }

        uint256[] memory ids = absorber.getTimelockOptionsIds();

        assertUint256ArrayEq(ids, expectedIds);
    }

    function test_getUserPower(address _user, uint256 _power) public {
        vm.mockCall(nftHandler, abi.encodeCall(INftHandler.getUserPower, (_user)), abi.encode(_power));
        assertEq(absorber.getUserPower(_user), _power);
    }

    function test_getNftPower(
        address _user,
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _power
    ) public {
        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getNftPower, (_user, _nft, _tokenId, _amount)),
            abi.encode(_power)
        );
        assertEq(absorber.getNftPower(_user, _nft, _tokenId, _amount), _power);
    }

    function deployMockAbsorber() public returns (AbsorberMock) {
        address impl = address(new AbsorberMock());

        AbsorberMock mockAbsorber = AbsorberMock(address(new ERC1967Proxy(impl, bytes(""))));
        mockAbsorber.init(admin, INftHandler(nftHandler), initDepositCapPerWallet);
        return mockAbsorber;
    }

    function test_getAllUserDepositIds_getAllUserDepositIdsLength() public {
        AbsorberMock mockAbsorber = deployMockAbsorber();

        uint256 newDepositId;

        (, newDepositId) = mockAbsorber.addDeposit(user1);
        assertEq(newDepositId, 1);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user1), 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[0], 1);

        (, newDepositId) = mockAbsorber.addDeposit(user1);
        assertEq(newDepositId, 2);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user1), 2);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[0], 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[1], 2);

        (, newDepositId) = mockAbsorber.addDeposit(user1);
        assertEq(newDepositId, 3);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user1), 3);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[0], 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[1], 2);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[2], 3);

        mockAbsorber.removeDeposit(user1, 2);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user1), 2);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[0], 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[1], 3);

        (, newDepositId) = mockAbsorber.addDeposit(user2);
        assertEq(newDepositId, 1);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user2), 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user2)[0], 1);

        vm.expectRevert(Absorber.DepositDoesNotExists.selector);
        mockAbsorber.removeDeposit(user2, 2);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user2), 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user2)[0], 1);

        mockAbsorber.removeDeposit(user2, 1);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user2), 0);

        (, newDepositId) = mockAbsorber.addDeposit(user2);
        assertEq(newDepositId, 2);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user2), 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user2)[0], 2);

        (, newDepositId) = mockAbsorber.addDeposit(user2);
        assertEq(newDepositId, 3);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user2), 2);
        assertEq(mockAbsorber.getAllUserDepositIds(user2)[0], 2);
        assertEq(mockAbsorber.getAllUserDepositIds(user2)[1], 3);

        (, newDepositId) = mockAbsorber.addDeposit(user1);
        assertEq(newDepositId, 4);
        assertEq(mockAbsorber.getAllUserDepositIdsLength(user1), 3);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[0], 1);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[1], 3);
        assertEq(mockAbsorber.getAllUserDepositIds(user1)[2], 4);
    }

    function test_getUserDepositCap() public {
        uint256 amountStaked = 20;

        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getStakingRules, (parts, partsTokenId)),
            abi.encode(address(0))
        );
        assertEq(absorber.getUserDepositCap(user1), 0);

        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getStakingRules, (parts, partsTokenId)),
            abi.encode(stakingRules)
        );
        vm.mockCall(
            stakingRules,
            abi.encodeCall(IPartsStakingRules.getAmountStaked, (user1)),
            abi.encode(amountStaked)
        );

        assertEq(absorber.getUserDepositCap(user1), amountStaked * initDepositCapPerWallet.capPerPart);
    }

    function test_isUserExceedingDepositCap() public {
        AbsorberMock mockAbsorber = deployMockAbsorber();

        uint256 amountStaked = 5;

        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getStakingRules, (parts, partsTokenId)),
            abi.encode(address(0))
        );

        assertFalse(mockAbsorber.isUserExceedingDepositCap(user1));

        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getStakingRules, (parts, partsTokenId)),
            abi.encode(stakingRules)
        );
        vm.mockCall(
            stakingRules,
            abi.encodeCall(IPartsStakingRules.getAmountStaked, (user1)),
            abi.encode(amountStaked)
        );

        assertFalse(mockAbsorber.isUserExceedingDepositCap(user1));

        mockAbsorber.setGlobalDepositAmount(user1, initDepositCapPerWallet.capPerPart * amountStaked);

        assertFalse(mockAbsorber.isUserExceedingDepositCap(user1));

        mockAbsorber.setGlobalDepositAmount(user1, initDepositCapPerWallet.capPerPart * amountStaked + 1);

        assertTrue(mockAbsorber.isUserExceedingDepositCap(user1));
    }

    function test_getLockPower() public {
        uint256 power;
        uint256 timelock;

        (power, timelock) = absorber.getLockPower(0);
        assertEq(power, 0);
        assertEq(timelock, 0);

        (power, timelock) = absorber.getLockPower(1);
        assertEq(power, 0.1e18);
        assertEq(timelock, absorber.TWO_WEEKS());

        (power, timelock) = absorber.getLockPower(2);
        assertEq(power, 0.25e18);
        assertEq(timelock, absorber.ONE_MONTH());

        (power, timelock) = absorber.getLockPower(3);
        assertEq(power, 0.8e18);
        assertEq(timelock, absorber.THREE_MONTHS());

        (power, timelock) = absorber.getLockPower(4);
        assertEq(power, 1.8e18);
        assertEq(timelock, absorber.SIX_MONTHS());

        (power, timelock) = absorber.getLockPower(5);
        assertEq(power, 4e18);
        assertEq(timelock, absorber.TWELVE_MONTHS());
    }

    function test_getVestingTime() public {
        assertEq(absorber.getVestingTime(0), 0);
        assertEq(absorber.getVestingTime(1), 0);
        assertEq(absorber.getVestingTime(2), 7 days);
        assertEq(absorber.getVestingTime(3), 14 days);
        assertEq(absorber.getVestingTime(4), 30 days);
        assertEq(absorber.getVestingTime(5), 45 days);
    }

    function test_enable() public {
        vm.prank(absorberFactory);
        absorber.disable();

        assertTrue(absorber.disabled());

        vm.prank(randomWallet);
        vm.expectRevert(Absorber.OnlyFactory.selector);
        absorber.enable();

        vm.prank(absorberFactory);
        vm.expectEmit(true, true, true, true);
        emit Enable();
        absorber.enable();

        assertFalse(absorber.disabled());
    }

    function test_disable() public {
        assertFalse(absorber.disabled());

        vm.prank(randomWallet);
        vm.expectRevert(Absorber.OnlyFactory.selector);
        absorber.disable();

        vm.prank(absorberFactory);
        vm.expectEmit(true, true, true, true);
        emit Disable();
        absorber.disable();

        assertTrue(absorber.disabled());
    }

    function test_callUpdateRewards() public {
        TestAction memory data = getTestAction(0);
        mockForAction(data);
        doDeposit(data);
        checkState(data);

        uint256 expectedRequestRewards = 2e18;

        essencePipelineMock.setReward(expectedRequestRewards);
        vm.mockCall(
            address(absorberFactory),
            abi.encodeCall(IAbsorberFactory.essencePipeline, ()),
            abi.encode(address(essencePipelineMock))
        );

        uint256 totalRewardsEarnedBefore = absorber.totalRewardsEarned();
        absorber.callUpdateRewards();
        uint256 totalRewardsEarnedAfter = absorber.totalRewardsEarned();

        assertEq(totalRewardsEarnedAfter - totalRewardsEarnedBefore, expectedRequestRewards);
    }

    enum Actions {
        Deposit,
        Withdraw,
        WithdrawAll,
        Harvest,
        WithdrawAndHarvest,
        WithdrawAndHarvestAll,
        WithdrawAmountFromAll
    }

    struct TestAction {
        Actions action;
        address user;
        uint256 depositId;
        uint256 nftPower;
        uint256 timeTravel;
        uint256 requestRewards;
        uint256 withdrawAmount;
        uint256 lock;
        uint256 expectedLock;
        uint256 originalDepositAmount;
        uint256 depositAmount;
        uint256 lockEpAmount;
        uint256 lockedUntil;
        uint256 globalDepositAmount;
        uint256 globalLockEpAmount;
        uint256 globalEpAmount;
        int256 globalRewardDebt;
        uint256 essenceTotalDeposits;
        uint256 totalEpToken;
        uint256 accEssencePerShare;
        uint256 pendingRewardsBefore;
        uint256 pendingRewards;
        uint256 maxWithdrawableAmount;
        bytes4 revertString;
    }

    // workaround for "UnimplementedFeatureError: Copying of type struct memory to storage not yet supported."
    uint256 public constant depositTestCasesLength = 21;

    function getTestAction(uint256 _index) public view returns (TestAction memory) {
        TestAction[depositTestCasesLength] memory testDepositCases = [
            // TODO: add more tests
            TestAction({
                action: Actions.Deposit,
                user: user1,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.1e18,
                globalEpAmount: 1.65e18,
                globalRewardDebt: 0,
                essenceTotalDeposits: 1e18,
                totalEpToken: 1.65e18,
                accEssencePerShare: 0,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user2,
                depositId: 1,
                nftPower: 0.8e18,
                timeTravel: 0,
                requestRewards: 0.1e18,
                withdrawAmount: 0,
                lock: 3,
                expectedLock: 3,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.8e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.8e18,
                globalEpAmount: 3.24e18,
                globalRewardDebt: 0.196363636363636363e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 4.89e18,
                accEssencePerShare: 0.060606060606060606e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Harvest,
                user: user1,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.1e18,
                globalEpAmount: 1.65e18,
                globalRewardDebt: 0.099999999999999999e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 4.89e18,
                accEssencePerShare: 0.060606060606060606e18,
                pendingRewardsBefore: 0.099999999999999999e18,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Withdraw,
                user: user1,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.1e18,
                globalEpAmount: 1.65e18,
                globalRewardDebt: 0.099999999999999999e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 4.89e18,
                accEssencePerShare: 0.060606060606060606e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: Absorber.ZeroAmount.selector
            }),
            TestAction({
                action: Actions.Withdraw,
                user: user1,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 1e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.1e18,
                globalEpAmount: 1.65e18,
                globalRewardDebt: 0.099999999999999999e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 4.89e18,
                accEssencePerShare: 0.060606060606060606e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: Absorber.StillLocked.selector
            }),
            TestAction({
                action: Actions.Withdraw,
                user: user1,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: absorber.TWO_WEEKS(),
                requestRewards: 0,
                withdrawAmount: 1e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 0,
                globalLockEpAmount: 0,
                globalEpAmount: 0,
                globalRewardDebt: 0,
                essenceTotalDeposits: 1e18,
                totalEpToken: 3.24e18,
                accEssencePerShare: 0.060606060606060606e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 1e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user2,
                depositId: 2,
                nftPower: 0.8e18,
                timeTravel: 0,
                requestRewards: 0.1e18,
                withdrawAmount: 0,
                lock: 3,
                expectedLock: 3,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.8e18,
                lockedUntil: 0,
                globalDepositAmount: 2e18,
                globalLockEpAmount: 3.6e18,
                globalEpAmount: 6.48e18,
                globalRewardDebt: 0.492727272727272724e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 6.48e18,
                accEssencePerShare: 0.091470258136924803e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0.099999999999999999e18,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAll,
                user: user2,
                depositId: 2,
                nftPower: 0.8e18,
                timeTravel: absorber.THREE_MONTHS(),
                requestRewards: 0.1e18,
                withdrawAmount: 1e18,
                lock: 3,
                expectedLock: 3,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.8e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.8e18,
                globalEpAmount: 3.24e18,
                globalRewardDebt: 0.146363636363636365e18,
                essenceTotalDeposits: 1e18,
                totalEpToken: 3.24e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0.099999999999999999e18,
                pendingRewards: 0.199999999999999994e18,
                maxWithdrawableAmount: 1e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAndHarvestAll,
                user: user2,
                depositId: 2,
                nftPower: 0.8e18,
                timeTravel: absorber.TWO_WEEKS() + 1,
                requestRewards: 0,
                withdrawAmount: 1e18,
                lock: 3,
                expectedLock: 3,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 0,
                globalLockEpAmount: 0,
                globalEpAmount: 0,
                globalRewardDebt: 0,
                essenceTotalDeposits: 0,
                totalEpToken: 0,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0.199999999999999994e18,
                pendingRewards: 0,
                maxWithdrawableAmount: 1e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user2,
                depositId: 3,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1.1e18,
                globalEpAmount: 2.2e18,
                globalRewardDebt: 0.235185185185185182e18,
                essenceTotalDeposits: 1e18,
                totalEpToken: 2.2e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user2,
                depositId: 4,
                nftPower: 1e18,
                timeTravel: absorber.ONE_WEEK(),
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 2e18,
                globalLockEpAmount: 2.2e18,
                globalEpAmount: 4.4e18,
                globalRewardDebt: 0.470370370370370364e18,
                essenceTotalDeposits: 2e18,
                totalEpToken: 4.4e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user2,
                depositId: 5,
                nftPower: 1e18,
                timeTravel: absorber.ONE_WEEK(),
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 3e18,
                globalLockEpAmount: 3.3e18,
                globalEpAmount: 6.6e18,
                globalRewardDebt: 0.705555555555555546e18,
                essenceTotalDeposits: 3e18,
                totalEpToken: 6.6e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 1e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 3,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 2e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1.1e18,
                lockedUntil: 0,
                globalDepositAmount: 3e18,
                globalLockEpAmount: 3.3e18,
                globalEpAmount: 6.6e18,
                globalRewardDebt: 0.705555555555555546e18,
                essenceTotalDeposits: 3e18,
                totalEpToken: 6.6e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 1e18,
                revertString: Absorber.StillLocked.selector
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 3,
                nftPower: 1e18,
                timeTravel: absorber.ONE_WEEK(),
                requestRewards: 0,
                withdrawAmount: 1.5e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 1.5e18,
                globalLockEpAmount: 1.65e18,
                globalEpAmount: 3.3e18,
                globalRewardDebt: 0.352777777777777773e18,
                essenceTotalDeposits: 1.5e18,
                totalEpToken: 3.3e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 2e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 3,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0.5000001e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 1.5e18,
                globalLockEpAmount: 1.65e18,
                globalEpAmount: 3.3e18,
                globalRewardDebt: 0.352777777777777773e18,
                essenceTotalDeposits: 1.5e18,
                totalEpToken: 3.3e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0.5e18,
                revertString: Absorber.StillLocked.selector
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 4,
                nftPower: 1e18,
                timeTravel: absorber.ONE_WEEK(),
                requestRewards: 0,
                withdrawAmount: 1e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0.5e18,
                lockEpAmount: 0.55e18,
                lockedUntil: 0,
                globalDepositAmount: 0.5e18,
                globalLockEpAmount: 0.55e18,
                globalEpAmount: 1.1e18,
                globalRewardDebt: 0.117592592592592591e18,
                essenceTotalDeposits: 0.5e18,
                totalEpToken: 1.1e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 1.5e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 5,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0.500001e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 0.5e18,
                globalLockEpAmount: 0.55e18,
                globalEpAmount: 1.1e18,
                globalRewardDebt: 0.117592592592592591e18,
                essenceTotalDeposits: 0.5e18,
                totalEpToken: 1.1e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0.5e18,
                revertString: Absorber.AmountTooBig.selector
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 4,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0.5e18,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 0,
                globalLockEpAmount: 0,
                globalEpAmount: 0,
                globalRewardDebt: 0,
                essenceTotalDeposits: 0,
                totalEpToken: 0,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0.5e18,
                revertString: ""
            }),
            TestAction({
                action: Actions.WithdrawAmountFromAll,
                user: user2,
                depositId: 4,
                nftPower: 1e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 1,
                lock: 1,
                expectedLock: 1,
                originalDepositAmount: 1e18,
                depositAmount: 0,
                lockEpAmount: 0,
                lockedUntil: 0,
                globalDepositAmount: 0,
                globalLockEpAmount: 0,
                globalEpAmount: 0,
                globalRewardDebt: 0,
                essenceTotalDeposits: 0,
                totalEpToken: 0,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: Absorber.AmountTooBig.selector
            }),
            TestAction({
                action: Actions.Deposit,
                user: user4,
                depositId: 1,
                nftPower: 0.5e18,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 0,
                expectedLock: 0,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1e18,
                globalEpAmount: 1.5e18,
                globalRewardDebt: 0.160353535353535351e18,
                essenceTotalDeposits: 1e18,
                totalEpToken: 1.5e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 0,
                revertString: ""
            }),
            TestAction({
                action: Actions.Deposit,
                user: user4,
                depositId: 1,
                nftPower: 0,
                timeTravel: 0,
                requestRewards: 0,
                withdrawAmount: 0,
                lock: 98,
                expectedLock: 0,
                originalDepositAmount: 1e18,
                depositAmount: 1e18,
                lockEpAmount: 1e18,
                lockedUntil: 0,
                globalDepositAmount: 1e18,
                globalLockEpAmount: 1e18,
                globalEpAmount: 1.5e18,
                globalRewardDebt: 0.160353535353535351e18,
                essenceTotalDeposits: 1e18,
                totalEpToken: 1.5e18,
                accEssencePerShare: 0.106902356902356901e18,
                pendingRewardsBefore: 0,
                pendingRewards: 0,
                maxWithdrawableAmount: 1e18,
                revertString: Absorber.InvalidValueOrDisabledTimelock.selector
            })
        ];

        (, uint256 timelock) = absorber.getLockPower(testDepositCases[_index].lock);
        console2.log("block.timestamp", block.timestamp);
        console2.log("timelock", timelock);
        if (testDepositCases[_index].action == Actions.Deposit) {
            testDepositCases[_index].lockedUntil = block.timestamp + timelock + testDepositCases[_index].timeTravel;
        } else {
            uint256 len = depositTestCasesLength;
            uint256 timeTravelAdjustment;
            for (uint256 i = 0; i < len; i++) {
                timeTravelAdjustment += testDepositCases[i].timeTravel;

                if (
                    testDepositCases[i].action == Actions.Deposit &&
                    testDepositCases[i].depositId == testDepositCases[_index].depositId &&
                    testDepositCases[i].user == testDepositCases[_index].user
                ) {
                    timeTravelAdjustment = 0;
                    len = _index;
                }
            }
            console2.log("timeTravelAdjustment", timeTravelAdjustment);
            testDepositCases[_index].lockedUntil = block.timestamp + timelock - timeTravelAdjustment;
        }

        return testDepositCases[_index];
    }

    function mockForAction(TestAction memory data) public {
        vm.mockCall(
            nftHandler,
            abi.encodeCall(INftHandler.getStakingRules, (parts, partsTokenId)),
            abi.encode(stakingRules)
        );

        vm.mockCall(nftHandler, abi.encodeCall(INftHandler.getUserPower, (data.user)), abi.encode(data.nftPower));
        vm.mockCall(
            address(absorberFactory),
            abi.encodeCall(IAbsorberFactory.essencePipeline, ()),
            abi.encode(address(essencePipelineMock))
        );

        essencePipelineMock.setReward(data.requestRewards);

        assertEq(absorber.pendingRewardsAll(data.user), data.pendingRewardsBefore);

        if (data.timeTravel != 0) {
            vm.warp(block.timestamp + data.timeTravel);
        }

        assertEq(absorber.getMaxWithdrawableAmount(data.user), data.maxWithdrawableAmount);
    }

    function doDeposit(TestAction memory data) public {
        essence.mint(data.user, data.originalDepositAmount);
        vm.prank(data.user);
        essence.approve(address(absorber), data.originalDepositAmount);

        vm.mockCall(stakingRules, abi.encodeCall(IPartsStakingRules.getAmountStaked, (data.user)), abi.encode(500));

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            vm.expectCall(
                address(essence),
                abi.encodeCall(IERC20.transferFrom, (data.user, address(absorber), data.originalDepositAmount))
            );
            vm.expectEmit(true, true, true, true);
            emit Deposit(data.user, data.depositId, data.originalDepositAmount, data.lock);
            absorber.deposit(data.originalDepositAmount, data.lock);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.deposit(data.originalDepositAmount, data.lock);
        }
    }

    function doWithdraw(TestAction memory data) public {
        uint256 balanceBefore = essence.balanceOf(data.user);

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            vm.expectCall(address(essence), abi.encodeCall(IERC20.transfer, (data.user, data.withdrawAmount)));
            vm.expectEmit(true, true, true, true);
            emit Withdraw(data.user, data.depositId, data.withdrawAmount);
            absorber.withdrawPosition(data.depositId, data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter - data.withdrawAmount, balanceBefore);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.withdrawPosition(data.depositId, data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter, balanceBefore);
        }
    }

    function doWithdrawAll(TestAction memory data) public {
        uint256 balanceBefore = essence.balanceOf(data.user);

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            absorber.withdrawAll();

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter - data.withdrawAmount, balanceBefore);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.withdrawAll();

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter, balanceBefore);
        }
    }

    function doWithdrawAmountFromAll(TestAction memory data) public {
        uint256 balanceBefore = essence.balanceOf(data.user);

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            absorber.withdrawAmountFromAll(data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter - data.withdrawAmount, balanceBefore);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.withdrawAmountFromAll(data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter, balanceBefore);
        }
    }

    function doHarvest(TestAction memory data) public {
        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            vm.expectCall(address(essence), abi.encodeCall(IERC20.transfer, (data.user, data.pendingRewardsBefore)));
            vm.expectEmit(true, true, true, true);
            emit Harvest(data.user, data.pendingRewardsBefore);
            absorber.harvestAll();
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.harvestAll();
        }
    }

    function doWithdrawAndHarvest(TestAction memory data) public {
        uint256 balanceBefore = essence.balanceOf(data.user);

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            absorber.withdrawAndHarvestPosition(data.depositId, data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter - data.withdrawAmount - data.pendingRewards, balanceBefore);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.withdrawAndHarvestPosition(data.depositId, data.withdrawAmount);

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter, balanceBefore);
        }
    }

    function doWithdrawAndHarvestAll(TestAction memory data) public {
        uint256 balanceBefore = essence.balanceOf(data.user);

        if (data.revertString == bytes4(0)) {
            vm.prank(data.user);
            absorber.withdrawAndHarvestAll();

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter - data.withdrawAmount - data.pendingRewardsBefore, balanceBefore);
        } else {
            vm.prank(data.user);
            vm.expectRevert(data.revertString);
            absorber.withdrawAndHarvestAll();

            uint256 balanceAfter = essence.balanceOf(data.user);
            assertEq(balanceAfter, balanceBefore);
        }
    }

    function checkState(TestAction memory data) public {
        assertEq(absorber.essenceTotalDeposits(), data.essenceTotalDeposits);
        assertEq(absorber.totalEpToken(), data.totalEpToken);
        assertEq(absorber.accEssencePerShare(), data.accEssencePerShare);
        assertEq(absorber.pendingRewardsAll(data.user), data.pendingRewards);

        (
            uint256 originalDepositAmount,
            uint256 depositAmount,
            uint256 lockEpAmount,
            uint256 lockedUntil,
            uint256 lock
        ) = absorber.userInfo(data.user, data.depositId);

        assertEq(originalDepositAmount, data.originalDepositAmount);
        assertEq(depositAmount, data.depositAmount);
        assertEq(lockEpAmount, data.lockEpAmount);
        assertEq(lockedUntil, data.lockedUntil);
        assertEq(uint256(lock), uint256(data.expectedLock));

        (
            uint256 globalDepositAmount,
            uint256 globalLockEpAmount,
            uint256 globalEpAmount,
            int256 globalRewardDebt
        ) = absorber.getUserGlobalDeposit(data.user);

        assertEq(globalDepositAmount, data.globalDepositAmount);
        assertEq(globalLockEpAmount, data.globalLockEpAmount);
        assertEq(globalEpAmount, data.globalEpAmount);
        assertEq(globalRewardDebt, data.globalRewardDebt);

        uint256[] memory ids = absorber.getAllUserDepositIds(data.user);
        for (uint256 i = 0; i < ids.length; i++) {
            console2.log("allUserDepositIds[i]", ids[i]);
        }
    }

    function test_depositWithdrawHarvestScenarios() public {
        (uint256 power, uint256 timelock, uint256 vesting, bool enabled) = absorber.timelockOptions(0);

        assertEq(power, 0);
        assertEq(timelock, 0);
        assertEq(vesting, 0);
        assertEq(enabled, true);

        for (uint256 i = 0; i < depositTestCasesLength; i++) {
            console2.log("TEST CASE:", i);

            TestAction memory data = getTestAction(i);

            mockForAction(data);

            if (data.action == Actions.Deposit) {
                doDeposit(data);
            } else if (data.action == Actions.Withdraw) {
                doWithdraw(data);
            } else if (data.action == Actions.WithdrawAll) {
                doWithdrawAll(data);
            } else if (data.action == Actions.Harvest) {
                doHarvest(data);
            } else if (data.action == Actions.WithdrawAndHarvest) {
                doWithdrawAndHarvest(data);
            } else if (data.action == Actions.WithdrawAndHarvestAll) {
                doWithdrawAndHarvestAll(data);
            } else if (data.action == Actions.WithdrawAmountFromAll) {
                doWithdrawAmountFromAll(data);
            }

            checkState(data);
        }
    }

    function test_depositDisabledTimelock() public {
        TestAction memory data = getTestAction(0);

        vm.prank(admin);
        absorber.disableTimelockOption(data.lock);

        mockForAction(data);

        essence.mint(data.user, data.originalDepositAmount);
        vm.prank(data.user);
        essence.approve(address(absorber), data.originalDepositAmount);

        vm.mockCall(stakingRules, abi.encodeCall(IPartsStakingRules.getAmountStaked, (data.user)), abi.encode(500));

        vm.prank(data.user);
        vm.expectRevert(Absorber.InvalidValueOrDisabledTimelock.selector);
        absorber.deposit(data.originalDepositAmount, data.lock);

        vm.prank(data.user);
        vm.expectRevert(Absorber.InvalidValueOrDisabledTimelock.selector);
        absorber.deposit(data.originalDepositAmount, 9999999);

        vm.prank(admin);
        absorber.enableTimelockOption(data.lock);

        doDeposit(data);
        checkState(data);
    }

    function test_calculateVestedPrincipal() public {
        uint256 originalDepositAmount;
        uint256 lockedUntil;
        uint256 lock;

        TestAction memory data0 = getTestAction(0);
        mockForAction(data0);
        doDeposit(data0);

        (originalDepositAmount, , , lockedUntil, lock) = absorber.userInfo(data0.user, data0.depositId);

        assertEq(absorber.calculateVestedPrincipal(data0.user, data0.depositId), 0);

        vm.warp(lockedUntil);

        assertEq(absorber.calculateVestedPrincipal(data0.user, data0.depositId), originalDepositAmount);

        TestAction memory data1 = getTestAction(1);
        mockForAction(data1);
        doDeposit(data1);

        (originalDepositAmount, , , lockedUntil, lock) = absorber.userInfo(data1.user, data1.depositId);

        assertEq(absorber.calculateVestedPrincipal(data1.user, data1.depositId), 0);

        uint256 vestingTime = absorber.getVestingTime(lock);
        uint256 vestingBegin = lockedUntil;

        vm.warp(vestingBegin);

        assertEq(absorber.calculateVestedPrincipal(data1.user, data1.depositId), 0);

        uint256 quaterVestingTime = vestingTime / 4;
        uint256 quaterDepositAmount = originalDepositAmount / 4;

        for (uint256 i = 0; i < 4; i++) {
            vm.warp(block.timestamp + quaterVestingTime);

            uint256 vestedAmount = absorber.calculateVestedPrincipal(data1.user, data1.depositId);

            assertEq(vestedAmount, quaterDepositAmount + quaterDepositAmount * i);
        }
    }

    function test_updateNftPower() public {
        TestAction memory data0 = getTestAction(0);
        TestAction memory data1 = getTestAction(1);
        mockForAction(data0);
        mockForAction(data1);
        doDeposit(data0);
        doDeposit(data1);

        (
            uint256 globalDepositAmount,
            uint256 globalLockEpAmount,
            uint256 globalEpAmount,
            int256 globalRewardDebt
        ) = absorber.getUserGlobalDeposit(data1.user);

        assertEq(globalDepositAmount, data1.globalDepositAmount);
        assertEq(globalLockEpAmount, data1.globalLockEpAmount);
        assertEq(globalEpAmount, data1.globalEpAmount);
        assertEq(globalRewardDebt, data1.globalRewardDebt);

        uint256 newUserPower = 2.5e18;
        vm.mockCall(nftHandler, abi.encodeCall(INftHandler.getUserPower, (data1.user)), abi.encode(newUserPower));

        absorber.updateNftPower(data1.user);

        (globalDepositAmount, globalLockEpAmount, globalEpAmount, globalRewardDebt) = absorber.getUserGlobalDeposit(
            data1.user
        );

        uint256 newGlobalEpAmount = globalLockEpAmount + (globalLockEpAmount * newUserPower) / 1e18;
        uint256 globalEpDiff = newGlobalEpAmount - data1.globalEpAmount;
        uint256 newGlobalRewardDebt = uint256(data1.globalRewardDebt) +
            (globalEpDiff * data1.accEssencePerShare) /
            1e18;

        assertEq(globalDepositAmount, data1.globalDepositAmount);
        assertEq(globalLockEpAmount, data1.globalLockEpAmount);
        assertEq(globalEpAmount, newGlobalEpAmount);
        assertEq(uint256(globalRewardDebt), newGlobalRewardDebt);
    }

    function test_pendingRewardsAll() public {
        TestAction memory data = getTestAction(1);

        mockForAction(data);
        doDeposit(data);

        assertEq(absorber.pendingRewardsAll(data.user), data.pendingRewards);

        uint256 newPendingRewards = 1e18;

        vm.mockCall(
            address(absorberFactory),
            abi.encodeCall(IAbsorberFactory.essencePipeline, ()),
            abi.encode(essencePipeline)
        );
        vm.mockCall(
            essencePipeline,
            abi.encodeCall(IEssencePipeline.getPendingRewards, (address(absorber))),
            abi.encode(newPendingRewards)
        );

        assertEq(absorber.pendingRewardsAll(data.user), newPendingRewards - 1);

        vm.mockCall(
            essencePipeline,
            abi.encodeCall(IEssencePipeline.getPendingRewards, (address(absorber))),
            abi.encode(newPendingRewards * 2)
        );

        assertEq(absorber.pendingRewardsAll(data.user), (newPendingRewards - 1) * 2);
    }

    function test_getDepositTotalPower(
        uint256 _timelockPower,
        uint256 _nftPower,
        uint256 _deposit
    ) public {
        vm.assume(_timelockPower < 100e18);
        vm.assume(_nftPower < 100e18);
        vm.assume(_deposit < initDepositCapPerWallet.capPerPart);

        TestAction memory data = TestAction({
            action: Actions.Deposit,
            user: user1,
            depositId: 1,
            nftPower: _nftPower,
            timeTravel: 0,
            requestRewards: 0,
            withdrawAmount: 0,
            lock: 0, //overriden
            expectedLock: 1,
            originalDepositAmount: _deposit,
            depositAmount: _deposit,
            lockEpAmount: 0,
            lockedUntil: 0,
            globalDepositAmount: 0,
            globalLockEpAmount: 0,
            globalEpAmount: 0,
            globalRewardDebt: 0,
            essenceTotalDeposits: 0,
            totalEpToken: 0,
            accEssencePerShare: 0,
            pendingRewardsBefore: 0,
            pendingRewards: 0,
            maxWithdrawableAmount: 0,
            revertString: ""
        });

        uint256[] memory timelockIds = absorber.getTimelockOptionsIds();
        data.lock = timelockIds.length;

        vm.prank(admin);
        absorber.addTimelockOption(IAbsorber.Timelock(_timelockPower, 0, 0, true));

        mockForAction(data);

        doDeposit(data);

        (uint256 globalDepositAmount, , uint256 globalEpAmount, ) = absorber.getUserGlobalDeposit(data.user);
        uint256 power = absorber.getDepositTotalPower(data.user, data.depositId);

        assertEq(globalDepositAmount, data.originalDepositAmount);
        assertApproxEqAbs(globalEpAmount, (data.originalDepositAmount * power) / absorber.ONE(), 1);
    }

    function test_setNftHandler() public {
        assertEq(address(absorber.nftHandler()), nftHandler);

        INftHandler newNftHandler = INftHandler(address(76e18));

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.setNftHandler(newNftHandler);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit NftHandler(newNftHandler);
        absorber.setNftHandler(newNftHandler);

        assertEq(address(absorber.nftHandler()), address(newNftHandler));
    }

    function test_setDepositCapPerWallet() public {
        (address initParts, uint256 tokenId, uint256 initCapPerPart) = absorber.depositCapPerWallet();
        assertEq(initParts, initDepositCapPerWallet.parts);
        assertEq(tokenId, initDepositCapPerWallet.partsTokenId);
        assertEq(initCapPerPart, initDepositCapPerWallet.capPerPart);

        IAbsorber.CapConfig memory newDepositCapPerWallet = IAbsorber.CapConfig({
            parts: parts,
            partsTokenId: partsTokenId,
            capPerPart: 1e18
        });

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.setDepositCapPerWallet(newDepositCapPerWallet);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit DepositCapPerWallet(newDepositCapPerWallet);
        absorber.setDepositCapPerWallet(newDepositCapPerWallet);

        (address newParts, uint256 newTokenId, uint256 newCapPerPart) = absorber.depositCapPerWallet();
        assertEq(newParts, newDepositCapPerWallet.parts);
        assertEq(newTokenId, newDepositCapPerWallet.partsTokenId);
        assertEq(newCapPerPart, newDepositCapPerWallet.capPerPart);
    }

    function test_setTotalDepositCap() public {
        assertEq(absorber.totalDepositCap(), initTotalDepositCap);

        uint256 newTotalDepositCap = 11e18;

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.setTotalDepositCap(newTotalDepositCap);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TotalDepositCap(newTotalDepositCap);
        absorber.setTotalDepositCap(newTotalDepositCap);

        assertEq(absorber.totalDepositCap(), newTotalDepositCap);
    }

    function test_setUnlockAll() public {
        assertFalse(absorber.unlockAll());

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.setUnlockAll(true);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit UnlockAll(true);
        absorber.setUnlockAll(true);

        assertTrue(absorber.unlockAll());
    }

    function test_addTimelockOption() public {
        IAbsorber.Timelock memory newTimelockOption = IAbsorber.Timelock(0.99e18, absorber.TWO_WEEKS(), 0, true);

        uint256[] memory ids = absorber.getTimelockOptionsIds();

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.addTimelockOption(newTimelockOption);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TimelockOption(newTimelockOption, ids.length);
        absorber.addTimelockOption(newTimelockOption);

        (uint256 power, uint256 timelock, uint256 vesting, bool enabled) = absorber.timelockOptions(ids.length);
        uint256[] memory newIds = absorber.getTimelockOptionsIds();

        assertEq(newIds.length, ids.length + 1);
        assertEq(power, newTimelockOption.power);
        assertEq(timelock, newTimelockOption.timelock);
        assertEq(vesting, newTimelockOption.vesting);
        assertEq(enabled, newTimelockOption.enabled);
    }

    function test_enableTimelockOption() public {
        uint256 id = 0;

        vm.prank(admin);
        absorber.disableTimelockOption(id);

        (uint256 power, uint256 timelock, uint256 vesting, bool enabled) = absorber.timelockOptions(id);

        assertFalse(enabled);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.enableTimelockOption(id);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TimelockOptionEnabled(IAbsorber.Timelock(power, timelock, vesting, !enabled), id);
        absorber.enableTimelockOption(id);

        (, , , enabled) = absorber.timelockOptions(id);

        assertTrue(enabled);
    }

    function test_disableTimelockOption() public {
        uint256 id = 0;

        (uint256 power, uint256 timelock, uint256 vesting, bool enabled) = absorber.timelockOptions(id);

        assertTrue(enabled);

        bytes memory errorMsg = TestUtils.getAccessControlErrorMsg(address(this), absorber.ABSORBER_ADMIN());
        vm.expectRevert(errorMsg);
        absorber.disableTimelockOption(id);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TimelockOptionDisabled(IAbsorber.Timelock(power, timelock, vesting, !enabled), id);
        absorber.disableTimelockOption(id);

        (, , , enabled) = absorber.timelockOptions(id);

        assertFalse(enabled);
    }
}
