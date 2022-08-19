import hre from 'hardhat';
import { expect } from 'chai';
import { Result } from 'ethers/lib/utils';

import { MockArena, Artifacts, Cosmetics, Essence, EssenceAbsorber, MothoraGame } from '../typechain-types';

const { ethers, deployments, getNamedAccounts } = hre;

const { deploy } = deployments;

describe.only('Arena', () => {
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

  describe('Usage of Arena contract', function () {
    before(async function () {
      await deployments.fixture(['Test'], { fallbackToGlobal: true });

      const MothoraGame = await deployments.get('MothoraGame');
      mothoraGame = new ethers.Contract(MothoraGame.address, MothoraGame.abi, deployerSigner) as MothoraGame;

      const Arena = await deployments.get('MockArena');
      arena = new ethers.Contract(Arena.address, Arena.abi, deployerSigner) as MockArena;

      const Artifacts = await deployments.get('Artifacts');
      artifacts = new ethers.Contract(Artifacts.address, Artifacts.abi, deployerSigner) as Artifacts;

      // create an account for 4 testers
      await mothoraGame.connect(tester1Signer).createAccount(1);
      await mothoraGame.connect(tester2Signer).createAccount(2);
      await mothoraGame.connect(tester3Signer).createAccount(3);
      await mothoraGame.connect(tester5Signer).createAccount(2);
    });

    describe('Tests that evaluate Arena session start', async () => {
      it('Tries to start a session with an inexistent account', async () => {
        expect(arena.connect(hackerSigner).startArenaSession([tester2])).to.be.revertedWith('ACCOUNT_NOT_ACTIVE');
      });

      it('Freezes an account and tries to start a session', async () => {
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester2, true);
        expect(arena.connect(tester2Signer).startArenaSession([tester2])).to.be.revertedWith('ACCOUNT_NOT_ACTIVE');
        await mothoraGame.connect(deployerSigner).changeFreezeStatus(tester2, false);
      });

      it('Tries to start a session with more than 24 players', async () => {
        expect(
          arena
            .connect(tester2Signer)
            .startArenaSession([
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
              tester2,
            ])
        ).to.be.revertedWith('INVALID_SESSION_SIZE');
      });

      it('Tries to start a session with an inexistent account', async () => {
        expect(arena.connect(tester1Signer).startArenaSession([tester1, tester2, tester3, hacker])).to.be.revertedWith(
          'ACCOUNT_NOT_ACTIVE'
        );
      });

      it('Tries to start a session with repeated accounts', async () => {
        expect(arena.connect(tester1Signer).startArenaSession([tester1, tester2, tester3, tester3])).to.be.revertedWith(
          'PLAYER_IN_SESSION_OR_DUPLICATE'
        );
      });

      it('Tries to start a session without the creator', async () => {
        expect(arena.connect(tester1Signer).startArenaSession([tester2, tester3, tester5])).to.be.revertedWith(
          'CREATOR_NOT_IN_SESSION'
        );
      });

      it('Tries to start a session without all the factions', async () => {
        expect(arena.connect(tester2Signer).startArenaSession([tester2, tester3, tester5])).to.be.revertedWith(
          'NOT_ENOUGH_FACTION_MEMBERS'
        );
      });

      it('Successfuly starts a session', async () => {
        const players = [tester1, tester2, tester3];
        const tx = await arena.connect(tester1Signer).startArenaSession(players);
        const confirmed = await tx.wait();

        const event = confirmed.events?.find((event: any) => event.event === 'ArenaSessionCreated');

        if (event?.args) {
          const [arenaId] = event?.args;

          const arenaSessionData = await arena.getArenaSessionData(arenaId);
          // ingame
          expect(arenaSessionData.status).to.be.equal(1);
          expect(arenaSessionData.players).to.be.deep.equal(players);
        }
      });

      it('Tries to start a session with players that already are in a session', async () => {
        expect(arena.connect(tester2Signer).startArenaSession([tester2, tester3, tester5])).to.be.revertedWith(
          'PLAYER_IN_SESSION_OR_DUPLICATE'
        );
      });
    });

    describe('Tests that evaluate Arena session termination', async () => {
      const requestId = 1;
      const randomWords = [43263626321, 6542785461323, 112412417];
      const expectedRewards = [2, 1, 2];

      it('Tries to terminate a session with an invalid account', async () => {
        expect(arena.connect(hackerSigner).mockTerminateArenaSession(1, requestId)).to.be.revertedWith(
          'ACCOUNT_NOT_ACTIVE'
        );
      });

      it('Tries to terminate a session with an account not in that session', async () => {
        expect(arena.connect(tester5Signer).mockTerminateArenaSession(1, requestId)).to.be.revertedWith(
          'TERMINATOR_NOT_IN_SESSION'
        );
      });

      it('Terminates a session successfuly', async () => {
        const tx = await arena.connect(tester1Signer).mockTerminateArenaSession(1, requestId);
        const confirmed = await tx.wait();

        const event = confirmed.events?.find((event: any) => event.event === 'ArenaSessionPostgame');

        if (event?.args) {
          const [arenaId] = event?.args;

          const arenaSessionData = await arena.getArenaSessionData(arenaId);
          //postgame
          expect(arenaSessionData.status).to.be.equal(2);
        }
      });
      it('Tries to fulfil with a terminator that was not in an arena', async () => {
        expect(arena.connect(tester1Signer).mockRandomnessFulfillment(0, randomWords)).to.be.revertedWith(
          'SESSION_MUST_EXIST'
        );
      });
      it('Fulfils a number of random words', async () => {
        await arena.connect(tester1Signer).mockRandomnessFulfillment(requestId, randomWords);

        // tester 1 has an extra artifact for being the terminator
        expect(await artifacts.balanceOf(tester1, 0)).to.be.equal(expectedRewards[0]);
        expect(await artifacts.balanceOf(tester2, 0)).to.be.equal(expectedRewards[1]);
        expect(await artifacts.balanceOf(tester3, 0)).to.be.equal(expectedRewards[2]);

        const arenaSessionData = await arena.getArenaSessionData(1);

        //rewarded
        expect(arenaSessionData.status).to.be.equal(3);
      });
    });
  });
});
