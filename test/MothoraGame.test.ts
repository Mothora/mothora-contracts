import hre from 'hardhat';
import { expect } from 'chai';
import { MockArena, Artifacts, Cosmetics, Essence, MothoraGame } from '../typechain-types';

const { ethers, deployments, getNamedAccounts } = hre;

describe.only('MothoraGame', () => {
  let mothoraGame: MothoraGame;
  let arena: MockArena;
  let artifacts: Artifacts;
  let cosmetics: Cosmetics;
  let essence: Essence;
  let tester1: any, deployer: any;
  let tester1Signer: any, deployerSigner: any;

  before(async () => {
    const namedAccounts = await getNamedAccounts();
    tester1 = namedAccounts.staker1;
    deployer = namedAccounts.deployer;

    tester1Signer = await ethers.provider.getSigner(tester1);
    deployerSigner = await ethers.provider.getSigner(deployer);
  });
  describe('Usage of MothoraGame hub', function () {
    before(async function () {
      await deployments.fixture(['Test'], { fallbackToGlobal: true });

      const MothoraGame = await deployments.get('MothoraGame');
      mothoraGame = new ethers.Contract(MothoraGame.address, MothoraGame.abi, deployerSigner) as MothoraGame;
    });

    describe('Tests that evaluate account creation', async () => {
      it('It reverts if the mothoraGame selects an invalid faction', async () => {
        expect(mothoraGame.connect(deployerSigner).createAccount(4)).to.be.revertedWithCustomError(
          mothoraGame,
          'INVALID_DAO'
        );
      });

      it('Player creates an account and joins the Shadow Council.', async () => {
        await mothoraGame.connect(tester1Signer).createAccount(1);
        expect(await mothoraGame.connect(tester1Signer).getPlayerDAO(tester1)).to.be.equal(1);
        expect(await mothoraGame.totalDAOMembers(1)).to.be.equal(1);
      });

      it('It reverts if the Player already has a faction', async () => {
        await expect(mothoraGame.connect(tester1Signer).createAccount(1)).to.be.revertedWithCustomError(
          mothoraGame,
          'PLAYER_ALREADY_HAS_DAO'
        );
      });

      it('Player defects to the Conglomerate', async () => {
        await mothoraGame.connect(tester1Signer).defect(2);
        expect(await mothoraGame.connect(tester1Signer).getPlayerDAO(tester1)).to.be.equal(2);
        expect(await mothoraGame.totalDAOMembers(2)).to.be.equal(1);
        expect(await mothoraGame.totalDAOMembers(1)).to.be.equal(0);
      });

      it('Player tries to defect again to the Conglomerate', async () => {
        expect(mothoraGame.connect(tester1Signer).defect(2)).to.be.revertedWithCustomError(
          mothoraGame,
          'CANNOT_DEFECT_TO_SAME_DAO'
        );
      });

      it('Freezes a player', async () => {
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester1, true);
        expect(await mothoraGame.connect(tester1Signer).getPlayerStatus(tester1)).to.be.equal(true);
      });

      it('Tries to defect to DOC while frozen', async () => {
        expect(mothoraGame.connect(tester1Signer).defect(3)).to.be.revertedWithCustomError(
          mothoraGame,
          'ACCOUNT_NOT_ACTIVE'
        );
      });

      it('Unfreezes a player', async () => {
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester1, false);
        expect(await mothoraGame.connect(tester1Signer).getPlayerStatus(tester1)).to.be.equal(false);
      });
    });
  });
});
