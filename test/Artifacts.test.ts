import hre from 'hardhat';
import { expect } from 'chai';
import { Arena, Artifacts, Cosmetics, Essence, EssenceAbsorber, MothoraGame } from '../typechain-types';

const { ethers, deployments, getNamedAccounts } = hre;
const { deploy } = deployments;

describe.only('Artifacts', () => {
  let mothoraGame: MothoraGame;
  let arena: Arena;
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
  const ipfs = 'https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/';

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

  describe('Usage of Artifacts NFT contract', function () {
    before(async function () {
      await deployments.fixture(['Test'], { fallbackToGlobal: true });

      const MothoraGame = await deployments.get('MothoraGame');
      mothoraGame = new ethers.Contract(MothoraGame.address, MothoraGame.abi, deployerSigner) as MothoraGame;

      const Artifacts = await deployments.get('Artifacts');
      artifacts = new ethers.Contract(Artifacts.address, Artifacts.abi, deployerSigner) as Artifacts;

      // create an account for tester 1
      await mothoraGame.connect(tester1Signer).createAccount(1);
    });

    describe('Tests that evaluate artifact minting', async () => {
      it('It reverts if an address tries to mint directly on GameItems Contract', async () => {
        expect(artifacts.connect(tester1Signer).mintArtifacts(tester1, 2)).to.be.revertedWith('NOT_CRAFTING_OR_ARENA');
      });

      it('It has the correct Mothora Game address', async () => {
        expect(await artifacts.connect(tester1Signer).getMothoraGame()).to.be.equal(mothoraGame.address);
      });
      it('It reverts on setting a token  if not the owner', async () => {
        expect(artifacts.connect(tester1Signer).setTokenUri(0, '')).to.be.revertedWith(
          'Ownable: caller is not the owner'
        );
      });

      it('It reverts on re-setting a token uri by the owner', async () => {
        expect(artifacts.connect(deployerSigner).setTokenUri(0, '')).to.be.revertedWith('CANNOT_SET_URI_TWICE');
      });

      it('The Artifacts NFT has the correct URI', async () => {
        expect(await artifacts.connect(deployerSigner).uri(0)).to.be.equal(ipfs + 0 + '.json');
      });
    });
  });
});
