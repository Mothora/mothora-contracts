import hre from 'hardhat';
import { expect } from 'chai';
import { MockArena, Artifacts, Cosmetics, Essence, EssenceAbsorber, MothoraGame } from '../typechain-types';

const { ethers, deployments, getNamedAccounts } = hre;

describe.only('EssenceAbsorber', () => {
  let mothoraGame: MothoraGame;
  let arena: MockArena;
  let artifacts: Artifacts;
  let cosmetics: Cosmetics;
  let essenceAbsorber: EssenceAbsorber;
  let essence: Essence;
  let tester1: any,
    tester2: any,
    tester3: any,
    hacker: any,
    deployer: any,
    tester5: any,
    tester6: any,
    tester7: any,
    tester8: any,
    tester9: any;
  let tester1Signer: any,
    tester2Signer: any,
    tester3Signer: any,
    hackerSigner: any,
    deployerSigner: any,
    tester5Signer: any,
    tester6Signer: any,
    tester7Signer: any,
    tester8Signer: any,
    tester9Signer: any;
  before(async () => {
    const namedAccounts = await getNamedAccounts();
    tester1 = namedAccounts.staker1;
    tester2 = namedAccounts.staker2;
    tester3 = namedAccounts.staker3;
    hacker = namedAccounts.hacker;
    deployer = namedAccounts.deployer;
    tester5 = namedAccounts.tester5;
    tester6 = namedAccounts.tester6;
    tester7 = namedAccounts.tester7;
    tester8 = namedAccounts.tester8;
    tester9 = namedAccounts.tester9;

    tester1Signer = await ethers.provider.getSigner(tester1);
    tester2Signer = await ethers.provider.getSigner(tester2);
    tester3Signer = await ethers.provider.getSigner(tester3);
    hackerSigner = await ethers.provider.getSigner(hacker);
    deployerSigner = await ethers.provider.getSigner(deployer);
    tester5Signer = await ethers.provider.getSigner(tester5);
    tester6Signer = await ethers.provider.getSigner(tester6);
    tester7Signer = await ethers.provider.getSigner(tester7);
    tester8Signer = await ethers.provider.getSigner(tester8);
    tester9Signer = await ethers.provider.getSigner(tester9);
  });
  describe('Usage of EssenceAbsorber', function () {
    before(async function () {
      await deployments.fixture(['Test'], { fallbackToGlobal: true });

      const MothoraGame = await deployments.get('MothoraGame');
      mothoraGame = new ethers.Contract(MothoraGame.address, MothoraGame.abi, deployerSigner) as MothoraGame;

      const Arena = await deployments.get('MockArena');
      arena = new ethers.Contract(Arena.address, Arena.abi, deployerSigner) as MockArena;

      const Essence = await deployments.get('Essence');
      essence = new ethers.Contract(Essence.address, Essence.abi, deployerSigner) as Essence;

      const Artifacts = await deployments.get('Artifacts');
      artifacts = new ethers.Contract(Artifacts.address, Artifacts.abi, deployerSigner) as Artifacts;

      const EssenceAbsorber = await deployments.get('EssenceAbsorber');
      essenceAbsorber = new ethers.Contract(
        EssenceAbsorber.address,
        EssenceAbsorber.abi,
        deployerSigner
      ) as EssenceAbsorber;

      // create an account for 5 testers
      await mothoraGame.connect(tester1Signer).createAccount(1);
      await mothoraGame.connect(tester2Signer).createAccount(2);
      await mothoraGame.connect(tester3Signer).createAccount(3);
      await mothoraGame.connect(tester5Signer).createAccount(2);
      await mothoraGame.connect(tester6Signer).createAccount(3);
    });

    describe('Tests that evaluate staking in the contract', async () => {
      it('Sends tokens to Mothora Vault', async () => {
        await essence.connect(deployerSigner).approve(deployer, ethers.constants.MaxUint256);
        await essence.transferFrom(deployer, essenceAbsorber.address, 1000);
        expect(await essence.balanceOf(essenceAbsorber.address)).to.be.equal(1000);
      });

      it('Reverts if trying to stake with an innactive account', async () => {
        expect(essenceAbsorber.connect(hackerSigner).stakeTokens(222)).to.be.revertedWith('ACCOUNT_NOT_ACTIVE');
      });

      it('Reverts if amount staked is <0', async () => {
        expect(essenceAbsorber.connect(tester2Signer).stakeTokens(0)).to.be.revertedWith('AMOUNT_NOT_HIGHER_THAN_0');
      });

      it('Reverts if mothoraGame tries to stake without having Essence Tokens', async () => {
        await essence.connect(tester2Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
        expect(essenceAbsorber.connect(tester2Signer).stakeTokens(1000)).to.be.revertedWith(
          'ERC20: transfer amount exceeds balance'
        );
      });

      it('Player buys Essence Tokens (simulation) and stakes them successfully', async () => {
        await essence.transferFrom(deployer, tester2, 1000);
        //before
        expect(await essence.connect(tester2Signer).balanceOf(tester2)).to.be.equal(1000);
        expect(await essenceAbsorber.connect(tester2Signer).playerIds(tester2)).to.be.equal(0);

        await essenceAbsorber.connect(tester2Signer).stakeTokens(1000);

        // after
        expect(await essenceAbsorber.connect(tester2Signer).stakedESSBalance(tester2)).to.be.equal(1000);
        expect(await essenceAbsorber.connect(tester2Signer).playerIds(tester2)).to.be.equal(1);
        expect(await essence.connect(tester2Signer).balanceOf(tester2)).to.be.equal(0);
      });

      it('Reverts if amount staked is <=0', async () => {
        expect(essenceAbsorber.connect(tester2Signer).unstakeTokens(0)).to.be.revertedWith('AMOUNT_IS_0');
      });

      it('Reverts if Player tries to unstake without having Essence tokens staked', async () => {
        expect(essenceAbsorber.connect(tester1Signer).unstakeTokens(1000)).to.be.revertedWith('STAKED_BALANCE_IS_0');
      });

      it('Reverts if the Player chooses an amount higher than its staked balance', async () => {
        expect(essenceAbsorber.connect(tester2Signer).unstakeTokens(10000)).to.be.revertedWith(
          'INVALID_UNSTAKE_OPERATION'
        );
      });

      it('Player successfully unstakes', async () => {
        await essenceAbsorber.connect(tester2Signer).unstakeTokens(1000);
        expect(await essenceAbsorber.stakedESSBalance(tester2)).to.be.equal(0);
      });
    });
    describe('Contribute Vault Parts', async () => {
      it('Reverts if staking with an innactive account', async () => {
        await expect(essenceAbsorber.connect(hackerSigner).stakeArtifacts(0)).to.be.revertedWith('ACCOUNT_NOT_ACTIVE');
      });
      it('Reverts if amount <0', async () => {
        await expect(essenceAbsorber.connect(tester1Signer).stakeArtifacts(0)).to.be.revertedWith('AMOUNT_IS_0');
      });

      it('Reverts if the amount is higher than players Artifact Balance', async () => {
        expect(essenceAbsorber.connect(tester1Signer).stakeArtifacts(6)).to.be.revertedWith('NOT_ENOUGH_BALANCE');
      });

      it('Successfully contributes essenceAbsorber parts', async () => {
        const requestId = 1;
        const players = [tester1, tester2, tester3, tester5, tester6];
        await arena.connect(tester1Signer).startArenaSession(players);
        const randomWords = [43263626321, 6542785461323, 112412417, 412378425, 512431249];
        await arena.connect(tester1Signer).mockTerminateArenaSession(1, requestId);
        await arena.connect(tester1Signer).mockRandomnessFulfillment(requestId, randomWords);

        // reward was 2 artifacts for tester1
        expect(await artifacts.balanceOf(tester1, 0)).to.be.equal(2);

        await artifacts.connect(tester1Signer).setApprovalForAll(essenceAbsorber.address, true);
        await essenceAbsorber.connect(tester1Signer).stakeArtifacts(2);
        expect(await essenceAbsorber.connect(tester1Signer).playerStakedArtifactsBalance(tester1)).to.be.equal(2);

        const playerFaction = await mothoraGame.getPlayerFaction(tester1);
        expect(await essenceAbsorber.connect(tester1Signer).factionArtifactsBalance(playerFaction)).to.be.equal(2);
      });

      it('Reverts if amount staked is <=0', async () => {
        expect(essenceAbsorber.connect(tester1Signer).unstakeArtifacts(0)).to.be.revertedWith('AMOUNT_IS_0');
      });

      it('Reverts if player tries to unstake without having enough artifacts staked', async () => {
        expect(essenceAbsorber.connect(tester2Signer).unstakeArtifacts(1000)).to.be.revertedWith('STAKED_BALANCE_IS_0');
      });

      it('Reverts if the Player chooses an amount higher than its staked balance', async () => {
        expect(essenceAbsorber.connect(tester1Signer).unstakeArtifacts(10000)).to.be.revertedWith(
          'INVALID_UNSTAKE_OPERATION'
        );
      });

      it('Player successfully unstakes', async () => {
        await essenceAbsorber.connect(tester1Signer).unstakeArtifacts(1);
        expect(await essenceAbsorber.playerStakedArtifactsBalance(tester1)).to.be.equal(1);
        const playerFaction = await mothoraGame.getPlayerFaction(tester1);

        expect(await essenceAbsorber.factionArtifactsBalance(playerFaction)).to.be.equal(1);
      });
    });

    describe('Absorber distributes the rewards', async () => {
      it('Reverts if there are no staked tokens', async () => {
        await expect(essenceAbsorber.connect(deployerSigner).distributeRewards()).to.be.revertedWith(
          'NO_TOKENS_STAKED'
        );
      });

      it('It distributes the epoch rewards according to excel example and players claim', async () => {
        // Setting up the artifacts contribution

        await artifacts.connect(tester2Signer).setApprovalForAll(essenceAbsorber.address, true);

        await essenceAbsorber.connect(tester2Signer).stakeArtifacts(await artifacts.balanceOf(tester2, 0));

        await artifacts.connect(tester3Signer).setApprovalForAll(essenceAbsorber.address, true);
        await essenceAbsorber.connect(tester3Signer).stakeArtifacts(await artifacts.balanceOf(tester3, 0));

        await artifacts.connect(tester5Signer).setApprovalForAll(essenceAbsorber.address, true);
        await essenceAbsorber.connect(tester5Signer).stakeArtifacts(await artifacts.balanceOf(tester5, 0));

        await artifacts.connect(tester6Signer).setApprovalForAll(essenceAbsorber.address, true);
        await essenceAbsorber.connect(tester6Signer).stakeArtifacts(await artifacts.balanceOf(tester6, 0));

        // Staking and distributing

        await essence.transferFrom(deployer, tester2, ethers.BigNumber.from('10000000000000000000000'));
        await essence.connect(tester2Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
        await essenceAbsorber.connect(tester2Signer).stakeTokens(ethers.BigNumber.from('10000000000000000000000'));

        await ethers.provider.send('evm_increaseTime', [60 * 35]);

        await essence.transferFrom(deployer, tester3, ethers.BigNumber.from('10000000000000000000000'));
        await essence.connect(tester3Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
        await essenceAbsorber.connect(tester3Signer).stakeTokens(ethers.BigNumber.from('10000000000000000000000'));

        await ethers.provider.send('evm_increaseTime', [61 * 14]);

        await essence.transferFrom(deployer, tester5, ethers.BigNumber.from('1000000000000000000000'));
        await essence.connect(tester5Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
        await essenceAbsorber.connect(tester5Signer).stakeTokens(ethers.BigNumber.from('1000000000000000000000'));

        await ethers.provider.send('evm_increaseTime', [61 * 11]);

        await essence.transferFrom(deployer, tester6, ethers.BigNumber.from('50000000000000000000'));
        await essence.connect(tester6Signer).approve(essenceAbsorber.address, ethers.constants.MaxUint256);
        await essenceAbsorber.connect(tester6Signer).stakeTokens(ethers.BigNumber.from('50000000000000000000'));

        await essenceAbsorber.connect(deployerSigner).distributeRewards();

        // Claiming the rewards
        await essenceAbsorber.connect(tester2Signer).claimEpochRewards(false);
        await essenceAbsorber.connect(tester3Signer).claimEpochRewards(false);
        await essenceAbsorber.connect(tester5Signer).claimEpochRewards(false);
        await essenceAbsorber.connect(tester6Signer).claimEpochRewards(false);

        // TODO missing expected calculations
      });

      it('Reverts if a non existing account tries to claim', async () => {
        await expect(essenceAbsorber.connect(hackerSigner).claimEpochRewards(false)).to.be.revertedWith(
          'ACCOUNT_DOES_NOT_EXIST'
        );
      });

      it('Reverts if the Owner tries to distribute more than once in the same epoch', async () => {
        await expect(essenceAbsorber.connect(deployerSigner).distributeRewards()).to.be.revertedWith(
          'DISTRIBUTION_ALREADY_HAPPENED'
        );
      });

      it('Distributes rewards again on the next epoch', async () => {
        await ethers.provider.send('evm_increaseTime', [601]); // add 601 seconds
        await essenceAbsorber.connect(deployerSigner).distributeRewards();
      });
    });
  });
});
