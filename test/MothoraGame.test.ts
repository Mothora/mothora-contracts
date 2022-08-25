import hre from 'hardhat';
import { expect } from 'chai';
import { MockArena, Artifacts, Cosmetics, Essence, EssenceAbsorber, MothoraGame } from '../typechain-types';

const { ethers, deployments, getNamedAccounts } = hre;

describe.only('MothoraGame', () => {
  let mothoraGame: MothoraGame;
  let arena: MockArena;
  let artifacts: Artifacts;
  let cosmetics: Cosmetics;
  let essenceAbsorber: EssenceAbsorber;
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

      const Arena = await deployments.get('MockArena');
      arena = new ethers.Contract(Arena.address, Arena.abi, deployerSigner) as MockArena;

      const Artifacts = await deployments.get('Artifacts');
      artifacts = new ethers.Contract(Artifacts.address, Artifacts.abi, deployerSigner) as Artifacts;

      const Cosmetics = await deployments.get('Cosmetics');
      cosmetics = new ethers.Contract(Cosmetics.address, Cosmetics.abi, deployerSigner) as Cosmetics;

      const Essence = await deployments.get('Essence');
      essence = new ethers.Contract(Essence.address, Essence.abi, deployerSigner) as Essence;

      const EssenceAbsorber = await deployments.get('EssenceAbsorber');
      essenceAbsorber = new ethers.Contract(
        EssenceAbsorber.address,
        EssenceAbsorber.abi,
        deployerSigner
      ) as EssenceAbsorber;
    });

    describe('Tests that evaluate account creation', async () => {
      it('It reverts if the mothoraGame selects an invalid faction', async () => {
        expect(mothoraGame.connect(deployerSigner).createAccount(4)).to.be.revertedWith('INVALID_FACTION');
      });

      it('Player creates an account and joins the Thoroks.', async () => {
        await mothoraGame.connect(tester1Signer).createAccount(1);
        expect(await mothoraGame.connect(tester1Signer).getPlayerFaction(tester1)).to.be.equal(1);
        expect(await mothoraGame.totalFactionMembers(1)).to.be.equal(1);
      });

      it('It reverts if the Player already has a faction', async () => {
        await expect(mothoraGame.connect(tester1Signer).createAccount(1)).to.be.revertedWith(
          'PLAYER_ALREADY_HAS_FACTION'
        );
      });

      it('Player defects to the Conglomerate', async () => {
        await mothoraGame.connect(tester1Signer).defect(2);
        expect(await mothoraGame.connect(tester1Signer).getPlayerFaction(tester1)).to.be.equal(2);
        expect(await mothoraGame.totalFactionMembers(2)).to.be.equal(1);
        expect(await mothoraGame.totalFactionMembers(1)).to.be.equal(0);
      });

      it('Player tries to defect again to the Conglomerate', async () => {
        expect(mothoraGame.connect(tester1Signer).defect(2)).to.be.revertedWith('CANNOT_DEFECT_TO_SAME_FACTION');
      });

      it('Freezes a player', async () => {
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester1, true);
        expect(await mothoraGame.connect(tester1Signer).getPlayerStatus(tester1)).to.be.equal(true);
      });

      it('Tries to defect to DOC while frozen', async () => {
        expect(mothoraGame.connect(tester1Signer).defect(3)).to.be.revertedWith('ACCOUNT_NOT_ACTIVE');
      });

      it('Unfreezes a player', async () => {
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester1, false);
        expect(await mothoraGame.connect(tester1Signer).getPlayerStatus(tester1)).to.be.equal(false);
      });
    });

    describe('Setting contracts in the registry', async () => {
      it('It correctly gets the Arena Contract Address', async () => {
        expect(await mothoraGame.connect(deployerSigner).getArena()).to.be.equal(arena.address);
      });

      it('It correctly gets the Artifacts Contract Address', async () => {
        expect(await mothoraGame.connect(deployerSigner).getArtifacts()).to.be.equal(artifacts.address);
      });

      it('It correctly gets the Cosmetics Contract Address', async () => {
        expect(await mothoraGame.connect(deployerSigner).getCosmetics()).to.be.equal(cosmetics.address);
      });

      it('It correctly gets the Essence Contract Address', async () => {
        expect(await mothoraGame.connect(deployerSigner).getEssence()).to.be.equal(essence.address);
      });

      it('It correctly gets the Essence Absorber Contract Address', async () => {
        expect(await mothoraGame.connect(deployerSigner).getEssenceAbsorber()).to.be.equal(essenceAbsorber.address);
      });
    });
  });
});
