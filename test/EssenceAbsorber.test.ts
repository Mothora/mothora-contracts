import hre from 'hardhat';
import { expect } from 'chai';
import { getBlockTime, mineBlock, getCurrentTime, setNextBlockTime } from './utils';
import { deployMockContract } from 'ethereum-waffle';

const { ethers, deployments, getNamedAccounts, artifacts } = hre;
const { deploy } = deployments;

describe.only('EssenceAbsorber', function () {
  let essenceAbsorber: any, essenceField: any, mockIArtifactMetadataStore: any;
  let essenceToken: any, absorberRods: any, artifact: any;
  let staker1: any, staker2: any, staker3: any, hacker: any, deployer: any;
  let staker1Signer: any, staker2Signer: any, staker3Signer: any, hackerSigner: any, deployerSigner: any;
  let checkDeposit: any;
  let checkPendingRewardsPosition: any;
  let checkIndexes: any;

  before(async function () {
    const namedAccounts = await getNamedAccounts();
    staker1 = namedAccounts.staker1;
    staker2 = namedAccounts.staker2;
    staker3 = namedAccounts.staker3;
    hacker = namedAccounts.hacker;
    deployer = namedAccounts.deployer;

    staker1Signer = await ethers.provider.getSigner(staker1);
    staker2Signer = await ethers.provider.getSigner(staker2);
    staker3Signer = await ethers.provider.getSigner(staker3);
    hackerSigner = await ethers.provider.getSigner(hacker);
    deployerSigner = await ethers.provider.getSigner(deployer);
  });

  beforeEach(async function () {
    await deployments.fixture(['EssenceAbsorber'], { fallbackToGlobal: true });

    // This mints a ERC20 Essence test token here
    const ERC20Mintable = await ethers.getContractFactory('ERC20Mintable');
    essenceToken = await ERC20Mintable.deploy();
    await essenceToken.deployed();

    const EssenceField = await deployments.get('EssenceField');
    essenceField = new ethers.Contract(EssenceField.address, EssenceField.abi, deployerSigner);
    await essenceField.setEssenceToken(essenceToken.address);

    const ERC1155Mintable = await ethers.getContractFactory('ERC1155Mintable');
    absorberRods = await ERC1155Mintable.deploy();
    await absorberRods.deployed();

    const ERC721Mintable = await ethers.getContractFactory('ERC721Mintable');
    artifact = await ERC721Mintable.deploy();
    await artifact.deployed();

    mockIArtifactMetadataStore = await deployMockContract(
      deployerSigner,
      (
        await artifacts.readArtifact('IArtifactMetadataStore')
      ).abi
    );

    const EssenceAbsorber = await deployments.get('EssenceAbsorber');
    essenceAbsorber = new ethers.Contract(EssenceAbsorber.address, EssenceAbsorber.abi, deployerSigner);
    await essenceAbsorber.setEssenceToken(essenceToken.address);
    await essenceAbsorber.setAbsorberRods(absorberRods.address);
    await essenceAbsorber.setArtifact(artifact.address);
    await essenceAbsorber.setArtifactMetadataStore(mockIArtifactMetadataStore.address);
  });

  it('init()', async function () {
    await expect(essenceAbsorber.init(essenceToken.address, essenceField.address)).to.be.revertedWith(
      'Initializable: contract is already initialized'
    );
  });

  it('getLockPower()', async function () {
    expect((await essenceAbsorber.getLockPower(0)).power).to.be.equal(ethers.utils.parseEther('0.1'));
    expect((await essenceAbsorber.getLockPower(1)).power).to.be.equal(ethers.utils.parseEther('0.25'));
    expect((await essenceAbsorber.getLockPower(2)).power).to.be.equal(ethers.utils.parseEther('0.8'));
    expect((await essenceAbsorber.getLockPower(3)).power).to.be.equal(ethers.utils.parseEther('1.8'));
    expect((await essenceAbsorber.getLockPower(4)).power).to.be.equal(ethers.utils.parseEther('4'));
  });

  it('setEssenceToken()', async function () {
    expect(await essenceAbsorber.essence()).to.be.equal(essenceToken.address);
    await essenceAbsorber.setEssenceToken(deployer);
    expect(await essenceAbsorber.essence()).to.be.equal(deployer);
  });

  it('setAbsorberRods()', async function () {
    expect(await essenceAbsorber.absorberRods()).to.be.equal(absorberRods.address);
    await essenceAbsorber.setAbsorberRods(deployer);
    expect(await essenceAbsorber.absorberRods()).to.be.equal(deployer);
  });

  it('setArtifact()', async function () {
    expect(await essenceAbsorber.artifact()).to.be.equal(artifact.address);
    await essenceAbsorber.setArtifact(deployer);
    expect(await essenceAbsorber.artifact()).to.be.equal(deployer);
  });

  it('setArtifactMetadataStore()', async function () {
    expect(await essenceAbsorber.artifactMetadataStore()).to.be.equal(mockIArtifactMetadataStore.address);
    await essenceAbsorber.setArtifactMetadataStore(deployer);
    expect(await essenceAbsorber.artifactMetadataStore()).to.be.equal(deployer);
  });

  it('setArtifactPowerTable()', async function () {
    let artifactPowerTable = [
      // PRIMAL
      // LEGENDARY,EXOTIC,RARE,UNCOMMON,COMMON
      [
        ethers.utils.parseEther('6'),
        ethers.utils.parseEther('2'),
        ethers.utils.parseEther('0.75'),
        ethers.utils.parseEther('1'),
        ethers.utils.parseEther('0.5'),
      ],
      // SECONDARY
      // LEGENDARY,EXOTIC,RARE,UNCOMMON,COMMON
      [
        ethers.utils.parseEther('0.4'),
        ethers.utils.parseEther('0.25'),
        ethers.utils.parseEther('0.15'),
        ethers.utils.parseEther('0.1'),
        ethers.utils.parseEther('0.05'),
      ],
    ];

    expect(await essenceAbsorber.getArtifactPowerTable()).to.be.deep.equal(artifactPowerTable);

    for (let i = 0; i < artifactPowerTable.length; i++) {
      for (let j = 0; j < artifactPowerTable[i].length; j++) {
        const power = artifactPowerTable[i][j];
        expect(await essenceAbsorber.getArtifactPower(i, j)).to.be.deep.equal(power);
      }
    }

    artifactPowerTable[2][0] = artifactPowerTable[1][0];
    artifactPowerTable[2][1] = artifactPowerTable[1][1];
    artifactPowerTable[2][2] = artifactPowerTable[1][2];
    artifactPowerTable[2][3] = artifactPowerTable[1][3];
    artifactPowerTable[2][4] = artifactPowerTable[1][4];

    await expect(essenceAbsorber.connect(hackerSigner).setArtifactPowerTable(artifactPowerTable)).to.be.reverted;
    await essenceAbsorber.setArtifactPowerTable(artifactPowerTable);

    expect(await essenceAbsorber.getArtifactPowerTable()).to.be.deep.equal(artifactPowerTable);

    for (let i = 0; i < artifactPowerTable.length; i++) {
      for (let j = 0; j < artifactPowerTable[i].length; j++) {
        const power = artifactPowerTable[i][j];
        expect(await essenceAbsorber.getArtifactPower(i, j)).to.be.deep.equal(power);
      }
    }
  });

  it('isArtifact1_1()', async function () {
    const tokenId = 55;
    let metadata = {
      artifactGeneration: 0, // PRIMAL
      artifactRarity: 0, // LEGENDARY
    };
    await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(tokenId).returns(metadata);
    expect(await essenceAbsorber.isArtifact1_1(tokenId)).to.be.true;

    for (let index = 1; index < 5; index++) {
      metadata.artifactRarity = index;
      await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(index).returns(metadata);
      expect(await essenceAbsorber.isArtifact1_1(index)).to.be.false;
    }
  });

  describe('with multiple deposits', function () {
    let depositsScenarios: any[];
    let withdrawAllScenarios: any[];
    let harvestScenarios: any[];
    let rewards: any[];

    let startTimestamp: any;

    beforeEach(async function () {
      startTimestamp = await getCurrentTime();

      depositsScenarios = [
        {
          address: staker1,
          signer: staker1Signer,
          timestamp: startTimestamp + 500,
          depositId: 1,
          amount: ethers.utils.parseEther('50'),
          epAmount: ethers.utils.parseEther('55'),
          lock: 0,
        },
        {
          address: staker1,
          signer: staker1Signer,
          timestamp: startTimestamp + 1000,
          depositId: 2,
          amount: ethers.utils.parseEther('10'),
          epAmount: ethers.utils.parseEther('12.5'),
          lock: 1,
        },
        {
          address: staker1,
          signer: staker1Signer,
          timestamp: startTimestamp + 1500,
          depositId: 3,
          amount: ethers.utils.parseEther('20'),
          epAmount: ethers.utils.parseEther('56'),
          lock: 3,
        },
        {
          address: staker2,
          signer: staker2Signer,
          timestamp: startTimestamp + 2000,
          depositId: 1,
          amount: ethers.utils.parseEther('20'),
          epAmount: ethers.utils.parseEther('100'),
          lock: 4,
        },
      ];

      withdrawAllScenarios = [
        {
          address: staker1,
          signer: staker1Signer,
          timestamp: startTimestamp + 1500,
          lock: 3,
          prevBal: ethers.utils.parseEther('60'),
          balanceOf: ethers.utils.parseEther('80'),
        },
        {
          address: staker2,
          signer: staker2Signer,
          timestamp: startTimestamp + 2000,
          lock: 4,
          prevBal: ethers.utils.parseEther('0'),
          balanceOf: ethers.utils.parseEther('20'),
        },
      ];

      // 0.18/s	    deposit 1	         deposit 2	        deposit 3	         deposit 4
      // 0-500	    90                 0	                0	                 0
      // 500-1000	  90	               0	                0	                 0
      // 1000-1500	73.33333333333331	 16.666666666666668	0	                 0
      // 1500-2000	40.08097165991902	 9.109311740890687	40.80971659919028	 0
      // 2000-5000	132.88590604026845 30.201342281879192	135.3020134228188	 241.61073825503354
      //            426.3002110335208	 55.977320689436546	176.11173002200906 241.61073825503354

      harvestScenarios = [
        ethers.utils.parseEther('426.435915731507395120'),
        ethers.utils.parseEther('55.967253575342589800'),
        ethers.utils.parseEther('176.066629350868135656'),
        ethers.utils.parseEther('241.530201342281879100'),
      ];

      rewards = [
        {
          address: depositsScenarios[0].address,
          signer: depositsScenarios[0].signer,
          deposit: depositsScenarios[0].amount.add(depositsScenarios[1].amount).add(depositsScenarios[2].amount),
          reward: harvestScenarios[0].add(harvestScenarios[1]).add(harvestScenarios[2]),
        },
        {
          address: depositsScenarios[3].address,
          signer: depositsScenarios[3].signer,
          deposit: depositsScenarios[3].amount,
          reward: harvestScenarios[3],
        },
      ];

      const totalRewards = ethers.utils.parseEther('900');
      const timeDelta = 5000;
      const endTimestamp = startTimestamp + timeDelta;

      await essenceField.addFlow(essenceAbsorber.address, totalRewards, startTimestamp, endTimestamp, false);
      await essenceToken.mint(essenceField.address, totalRewards);
      await essenceAbsorber.setUtilizationOverride(ethers.utils.parseEther('1'));

      for (let index = 0; index < depositsScenarios.length; index++) {
        const deposit = depositsScenarios[index];
        await essenceToken.mint(deposit.address, deposit.amount);
        await setNextBlockTime(deposit.timestamp);
        await essenceToken.connect(deposit.signer).approve(essenceAbsorber.address, deposit.amount);
        await essenceAbsorber.connect(deposit.signer).deposit(deposit.amount, deposit.lock);
      }
    });

    it('deposit()', async function () {
      let totalEpToken = ethers.utils.parseEther('0');
      let essenceTotalDeposits = ethers.utils.parseEther('0');

      for (let index = 0; index < depositsScenarios.length; index++) {
        const deposit = depositsScenarios[index];
        const userInfo = await essenceAbsorber.userInfo(deposit.address, deposit.depositId);

        expect(userInfo.originalDepositAmount).to.be.equal(deposit.amount);
        expect(userInfo.depositAmount).to.be.equal(deposit.amount);
        expect(userInfo.epAmount).to.be.equal(deposit.epAmount);
        expect(userInfo.lock).to.be.equal(deposit.lock);

        totalEpToken = totalEpToken.add(userInfo.epAmount);
        essenceTotalDeposits = essenceTotalDeposits.add(deposit.amount);
      }

      expect(await essenceAbsorber.essenceTotalDeposits()).to.be.equal(essenceTotalDeposits);
      expect(await essenceAbsorber.totalEpToken()).to.be.equal(totalEpToken);
    });

    it('essenceTotalDeposits()', async function () {
      let essenceTotalDeposits = ethers.utils.parseEther('0');
      for (let index = 0; index < depositsScenarios.length; index++) {
        essenceTotalDeposits = essenceTotalDeposits.add(depositsScenarios[index].amount);
      }
      expect(await essenceAbsorber.essenceTotalDeposits()).to.be.equal(essenceTotalDeposits);
    });

    describe('utilization', function () {
      let totalSupply: any;
      let rewards: any;
      let circulatingSupply: any;
      let ONE: any;
      let utilizationOverride: any[];

      beforeEach(async function () {
        // set to default
        await essenceAbsorber.setUtilizationOverride(ethers.utils.parseEther('0'));

        utilizationOverride = [
          [ethers.utils.parseEther('0'), ethers.utils.parseEther('0')],
          [ethers.utils.parseEther('0.1'), ethers.utils.parseEther('0')],
          [ethers.utils.parseEther('0.3'), ethers.utils.parseEther('0.5')],
          [ethers.utils.parseEther('0.4'), ethers.utils.parseEther('0.6')],
          [ethers.utils.parseEther('0.5'), ethers.utils.parseEther('0.8')],
          [ethers.utils.parseEther('0.6'), ethers.utils.parseEther('1')],
        ];

        totalSupply = await essenceToken.totalSupply();
        const essenceTotalDeposits = await essenceAbsorber.essenceTotalDeposits();
        const bal = await essenceToken.balanceOf(essenceAbsorber.address);
        rewards = bal.sub(essenceTotalDeposits);
        circulatingSupply = totalSupply.sub(rewards);
        ONE = await essenceAbsorber.ONE();
      });

      it('getExcludedAddresses() && utilization() && addExcludedAddress() && removeExcludedAddress()', async function () {
        const util = await essenceAbsorber.utilization();
        const essenceTotalDeposits = await essenceAbsorber.essenceTotalDeposits();
        expect(essenceTotalDeposits.mul(ONE).div(circulatingSupply)).to.be.equal(util);

        await essenceToken.mint(deployer, totalSupply);
        const newUtil = await essenceAbsorber.utilization();
        expect(newUtil).to.be.equal(ethers.utils.parseEther('0.060988997584835695'));

        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([]);
        await essenceAbsorber.addExcludedAddress(deployer);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([deployer]);
        expect(await essenceAbsorber.utilization()).to.be.equal(ethers.utils.parseEther('0.156425979226629958'));

        await essenceAbsorber.addExcludedAddress(staker1);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([deployer, staker1]);

        await essenceAbsorber.addExcludedAddress(staker2);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([deployer, staker1, staker2]);

        await essenceAbsorber.addExcludedAddress(staker3);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([deployer, staker1, staker2, staker3]);

        await essenceAbsorber.removeExcludedAddress(staker1);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([deployer, staker3, staker2]);

        await essenceAbsorber.removeExcludedAddress(deployer);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([staker2, staker3]);

        await essenceAbsorber.removeExcludedAddress(staker3);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([staker2]);

        await expect(essenceAbsorber.removeExcludedAddress(staker3)).to.be.revertedWith('Address is not excluded');

        await essenceAbsorber.removeExcludedAddress(staker2);
        expect(await essenceAbsorber.getExcludedAddresses()).to.be.deep.equal([]);

        await expect(essenceAbsorber.removeExcludedAddress(staker2)).to.be.revertedWith('Address is not excluded');

        const newUtil2 = await essenceAbsorber.utilization();
        expect(newUtil2).to.be.equal(ethers.utils.parseEther('0.061049315637171707'));
        await essenceAbsorber.addExcludedAddress(deployer);
        expect(await essenceAbsorber.utilization()).to.be.equal(ethers.utils.parseEther('0.156779129562272670'));
      });

      it('setUtilizationOverride()', async function () {
        for (let index = 0; index < utilizationOverride.length; index++) {
          const utilization = utilizationOverride[index][0];
          await essenceAbsorber.setUtilizationOverride(utilization);

          let expectedUtil: any;
          if (utilization == 0) {
            expectedUtil = await essenceAbsorber.utilization();
          } else {
            expectedUtil = utilization;
          }

          expect(await essenceAbsorber.utilization()).to.be.equal(expectedUtil);
        }
      });

      it('getRealEssenceReward()', async function () {
        const rewardsAmount = ethers.utils.parseEther('1');

        for (let index = 0; index < utilizationOverride.length; index++) {
          const utilization = utilizationOverride[index][0];
          const effectiveness = utilizationOverride[index][1];

          if (utilization > 0) {
            await essenceAbsorber.setUtilizationOverride(utilization);
            const result = await essenceAbsorber.getRealEssenceReward(rewardsAmount);
            expect(result.distributedRewards).to.be.equal(rewardsAmount.mul(effectiveness).div(ONE));
            expect(result.undistributedRewards).to.be.equal(rewardsAmount.sub(result.distributedRewards));
          }
        }
      });
    });

    it('withdrawPosition()', async function () {
      for (let index = 0; index < depositsScenarios.length; index++) {
        const deposit = depositsScenarios[index];

        await expect(
          essenceAbsorber.connect(deposit.signer).withdrawPosition(deposit.depositId, deposit.amount)
        ).to.be.revertedWith('Position is still locked');

        // time travel to beginning of vesting
        const timelock = (await essenceAbsorber.getLockPower(deposit.lock)).timelock;
        await setNextBlockTime(deposit.timestamp + timelock.toNumber() + 1);

        const balBefore = await essenceToken.balanceOf(deposit.address);
        let balAfter: any;

        if (deposit.lock != 0) {
          await essenceAbsorber.connect(deposit.signer).withdrawPosition(deposit.depositId, deposit.amount);
          balAfter = await essenceToken.balanceOf(deposit.address);
          expect(balAfter.sub(balBefore)).to.be.equal(0);

          expect(
            await essenceAbsorber.connect(deposit.signer).calcualteVestedPrincipal(deposit.address, deposit.depositId)
          ).to.be.equal(0);

          const vestingTime = (await essenceAbsorber.getVestingTime(deposit.lock)).toNumber();
          const vestHalf = deposit.timestamp + timelock.toNumber() + vestingTime / 2 + 1;
          const vestingEnd = deposit.timestamp + timelock.toNumber() + vestingTime + 1;

          await mineBlock(vestHalf);

          let principalVested = await essenceAbsorber
            .connect(deposit.signer)
            .calcualteVestedPrincipal(deposit.address, deposit.depositId);
          expect(principalVested).to.be.equal(deposit.amount.div(2));

          await mineBlock(vestingEnd);
          principalVested = await essenceAbsorber
            .connect(deposit.signer)
            .calcualteVestedPrincipal(deposit.address, deposit.depositId);
          expect(principalVested).to.be.equal(deposit.amount);

          await essenceAbsorber.connect(deposit.signer).withdrawPosition(deposit.depositId, deposit.amount);

          balAfter = await essenceToken.balanceOf(deposit.address);
          expect(balAfter.sub(balBefore)).to.be.equal(deposit.amount);
        } else {
          await essenceAbsorber.connect(deposit.signer).withdrawPosition(deposit.depositId, deposit.amount);
          const balAfter = await essenceToken.balanceOf(deposit.address);

          expect(balAfter.sub(balBefore)).to.be.equal(deposit.amount);
        }
      }
    });

    it('withdrawAll()', async function () {
      for (let index = 0; index < withdrawAllScenarios.length; index++) {
        const staker = withdrawAllScenarios[index];

        // time travel to beginning of vesting
        const timelock = (await essenceAbsorber.getLockPower(staker.lock)).timelock;
        await setNextBlockTime(staker.timestamp + timelock.toNumber() + 1);

        let balAfter: any;

        await essenceAbsorber.connect(staker.signer).withdrawAll();

        balAfter = await essenceToken.balanceOf(staker.address);
        expect(balAfter).to.be.equal(staker.prevBal);

        const vestingTime = (await essenceAbsorber.getVestingTime(staker.lock)).toNumber();
        const vestingEnd = staker.timestamp + timelock.toNumber() + vestingTime + 1;

        await mineBlock(vestingEnd);

        await essenceAbsorber.connect(staker.signer).withdrawAll();

        balAfter = await essenceToken.balanceOf(staker.address);
        expect(balAfter).to.be.equal(staker.balanceOf);
      }
    });

    it('harvestPosition()', async function () {
      await mineBlock(startTimestamp + 6000);

      for (let index = 0; index < harvestScenarios.length; index++) {
        const deposit = depositsScenarios[index];
        const reward = harvestScenarios[index];

        const pendingRewardsPosition = await essenceAbsorber.pendingRewardsPosition(deposit.address, deposit.depositId);
        expect(pendingRewardsPosition).to.be.equal(reward);

        const balBefore = await essenceToken.balanceOf(deposit.address);
        await essenceAbsorber.connect(deposit.signer).harvestPosition(deposit.depositId);
        await essenceAbsorber.connect(deposit.signer).harvestPosition(deposit.depositId);
        const balAfter = await essenceToken.balanceOf(deposit.address);
        expect(balAfter.sub(balBefore)).to.be.equal(reward);
      }
    });

    it('harvestAll()', async function () {
      for (let index = 0; index < depositsScenarios.length; index++) {
        expect(await essenceToken.balanceOf(depositsScenarios[index].address)).to.be.equal(0);
      }

      let firstTimestamp = startTimestamp + 2000;
      const timestamps = [
        firstTimestamp + 50,
        firstTimestamp + 188,
        firstTimestamp + 378,
        firstTimestamp + 657,
        firstTimestamp + 938,
        firstTimestamp + 1749,
        firstTimestamp + 1837,
        firstTimestamp + 2333,
      ];

      for (let index = 0; index < timestamps.length; index++) {
        await mineBlock(timestamps[index]);

        for (let i = 0; i < depositsScenarios.length; i++) {
          await setNextBlockTime(timestamps[index] + (i + 1) * 9);
          const deposit = depositsScenarios[i];
          await essenceAbsorber.connect(deposit.signer).harvestPosition(deposit.depositId);
        }
      }

      await mineBlock(startTimestamp + 6000);

      const rewards = [
        {
          address: depositsScenarios[0].address,
          signer: depositsScenarios[0].signer,
          reward: harvestScenarios[0].add(harvestScenarios[1]).add(harvestScenarios[2]),
        },
        {
          address: depositsScenarios[3].address,
          signer: depositsScenarios[3].signer,
          reward: harvestScenarios[3],
        },
      ];

      for (let index = 0; index < rewards.length; index++) {
        await essenceAbsorber.connect(rewards[index].signer).harvestAll();
        const balAfter = await essenceToken.balanceOf(rewards[index].address);
        expect(balAfter).to.be.closeTo(rewards[index].reward, 10000);
      }
    });

    it('withdrawAndHarvestPosition()', async function () {
      for (let index = 0; index < depositsScenarios.length; index++) {
        const deposit = depositsScenarios[index];
        const reward = harvestScenarios[index];

        // time travel to beginning of vesting
        const timelock = (await essenceAbsorber.getLockPower(deposit.lock)).timelock;
        const vestingTime = (await essenceAbsorber.getVestingTime(deposit.lock)).toNumber();
        const vestingEnd = deposit.timestamp + timelock.toNumber() + vestingTime + 1;

        await mineBlock(vestingEnd);

        const balBefore = await essenceToken.balanceOf(deposit.address);
        await essenceAbsorber.connect(deposit.signer).withdrawAndHarvestPosition(deposit.depositId, deposit.amount);
        const balAfter = await essenceToken.balanceOf(deposit.address);
        expect(balAfter.sub(balBefore)).to.be.equal(deposit.amount.add(reward));
      }
    });

    it('withdrawAndHarvestAll()', async function () {
      for (let index = 0; index < depositsScenarios.length; index++) {
        expect(await essenceToken.balanceOf(depositsScenarios[index].address)).to.be.equal(0);
      }

      let firstTimestamp = startTimestamp + 2000;
      const timestamps = [
        firstTimestamp + 50,
        firstTimestamp + 188,
        firstTimestamp + 378,
        firstTimestamp + 657,
        firstTimestamp + 938,
        firstTimestamp + 1749,
        firstTimestamp + 1837,
        firstTimestamp + 2333,
      ];

      for (let index = 0; index < timestamps.length; index++) {
        await mineBlock(timestamps[index]);

        for (let i = 0; i < depositsScenarios.length; i++) {
          await setNextBlockTime(timestamps[index] + (i + 1) * 9);
          const deposit = depositsScenarios[i];
          await essenceAbsorber.connect(deposit.signer).harvestPosition(deposit.depositId);
        }
      }

      await mineBlock(startTimestamp + 6000);

      const deposit = depositsScenarios[3];

      // time travel to beginning of vesting
      const timelock = (await essenceAbsorber.getLockPower(deposit.lock)).timelock;
      const vestingTime = (await essenceAbsorber.getVestingTime(deposit.lock)).toNumber();
      const vestingEnd = deposit.timestamp + timelock.toNumber() + vestingTime + 1;

      await mineBlock(vestingEnd);

      for (let index = 0; index < rewards.length; index++) {
        const reward = rewards[index];
        await essenceAbsorber.connect(reward.signer).withdrawAndHarvestAll();
        const balAfter = await essenceToken.balanceOf(reward.address);
        expect(balAfter).to.be.closeTo(reward.reward.add(reward.deposit), 10000);
      }
    });

    it('toggleUnlockAll()', async function () {
      await expect(essenceAbsorber.connect(hackerSigner).toggleUnlockAll()).to.be.reverted;

      for (let index = 0; index < withdrawAllScenarios.length; index++) {
        const staker = withdrawAllScenarios[index];

        await expect(essenceAbsorber.connect(staker.signer).withdrawAll()).to.be.revertedWith(
          'Position is still locked'
        );
        await essenceAbsorber.toggleUnlockAll();
        await essenceAbsorber.connect(staker.signer).withdrawAll();
        await essenceAbsorber.toggleUnlockAll();

        let balAfter = await essenceToken.balanceOf(staker.address);
        expect(balAfter).to.be.equal(staker.balanceOf);
      }
    });

    it('withdrawUndistributedRewards()', async function () {
      await essenceAbsorber.setUtilizationOverride(ethers.utils.parseEther('0.4'));

      const deposit = depositsScenarios[3];
      const timelock = (await essenceAbsorber.getLockPower(deposit.lock)).timelock;
      const vestingTime = (await essenceAbsorber.getVestingTime(deposit.lock)).toNumber();
      const vestingEnd = deposit.timestamp + timelock.toNumber() + vestingTime + 1;

      await mineBlock(vestingEnd);

      await essenceAbsorber.setUtilizationOverride(ethers.utils.parseEther('1'));

      expect(await essenceToken.balanceOf(deployer)).to.be.equal(0);
      const totalUndistributedRewards = await essenceAbsorber.totalUndistributedRewards();
      expect(totalUndistributedRewards).to.be.equal(ethers.utils.parseEther('215.856'));

      await essenceAbsorber.withdrawUndistributedRewards(deployer);

      expect(await essenceToken.balanceOf(deployer)).to.be.equal(totalUndistributedRewards);
      expect(await essenceAbsorber.totalUndistributedRewards()).to.be.equal(0);
    });

    it('calcualteVestedPrincipal()');

    describe('NFT staking', function () {
      let powerScenarios: any[];
      let metadata: any;

      beforeEach(async function () {
        powerScenarios = [
          {
            nft: absorberRods.address,
            tokenId: 96,
            amount: 10,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 0,
            },
            boost: ethers.utils.parseEther('0.008'),
          },
          {
            nft: absorberRods.address,
            tokenId: 105,
            amount: 5,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 0,
            },
            boost: ethers.utils.parseEther('0.067'),
          },
          {
            nft: absorberRods.address,
            tokenId: 47,
            amount: 5,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 0,
            },
            boost: ethers.utils.parseEther('0.073'),
          },
          {
            nft: artifact.address,
            tokenId: 98,
            amount: 1,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 0,
            },
            boost: ethers.utils.parseEther('6'),
          },
          {
            nft: artifact.address,
            tokenId: 77,
            amount: 1,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 1,
            },
            boost: ethers.utils.parseEther('2'),
          },
          {
            nft: artifact.address,
            tokenId: 44,
            amount: 1,
            metadata: {
              artifactGeneration: 0,
              artifactRarity: 2,
            },
            boost: ethers.utils.parseEther('0.75'),
          },
          {
            nft: artifact.address,
            tokenId: 33,
            amount: 1,
            metadata: {
              artifactGeneration: 1,
              artifactRarity: 2,
            },
            boost: ethers.utils.parseEther('0'),
          },
          {
            nft: artifact.address,
            tokenId: 22,
            amount: 1,
            metadata: {
              artifactGeneration: 1,
              artifactRarity: 1,
            },
            boost: ethers.utils.parseEther('0.25'),
          },
        ];

        metadata = {
          artifactGeneration: 1,
          artifactRarity: 0,
        };

        for (let index = 0; index < powerScenarios.length; index++) {
          const scenario = powerScenarios[index];
          if (scenario.nft == artifact.address) {
            metadata.artifactGeneration = scenario.metadata.artifactGeneration;
            metadata.artifactRarity = scenario.metadata.artifactRarity;
            await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(scenario.tokenId).returns(metadata);
          }
        }
      });

      it('getNftPower()', async function () {
        for (let index = 0; index < powerScenarios.length; index++) {
          const scenario = powerScenarios[index];
          expect(await essenceAbsorber.getNftPower(scenario.nft, scenario.tokenId, scenario.amount)).to.be.equal(
            scenario.power.mul(scenario.amount)
          );
        }
      });

      describe('stakeAbsorberRods()', function () {
        it('Cannot stake AbsorberRods', async function () {
          await essenceAbsorber.setAbsorberRods(ethers.constants.AddressZero);
          await expect(essenceAbsorber.stakeAbsorberRods(1, 1)).to.be.revertedWith('Cannot stake AbsorberRods');
        });

        it('Amount is 0', async function () {
          await expect(essenceAbsorber.stakeAbsorberRods(1, 0)).to.be.revertedWith('Amount is 0');
        });

        it('Max 20 absorberRodss per wallet', async function () {
          for (let index = 0; index < 5; index++) {
            await absorberRods.functions['mint(address,uint256,uint256)'](staker1, index, 5);
            await absorberRods.connect(staker1Signer).setApprovalForAll(essenceAbsorber.address, true);

            if (index == 4) {
              await expect(essenceAbsorber.connect(staker1Signer).stakeAbsorberRods(index, 5)).to.be.revertedWith(
                'Max 20 absorberRodss per wallet'
              );
            } else {
              await essenceAbsorber.connect(staker1Signer).stakeAbsorberRods(index, 5);
            }
          }
        });

        it('stake powers', async function () {
          let totalPower = ethers.utils.parseEther('0');

          for (let index = 0; index < powerScenarios.length; index++) {
            const scenario = powerScenarios[index];

            if (scenario.nft == absorberRods.address) {
              const powerBefore = await essenceAbsorber.powers(staker1);

              await absorberRods.functions['mint(address,uint256,uint256)'](staker1, scenario.tokenId, scenario.amount);
              await absorberRods.connect(staker1Signer).setApprovalForAll(essenceAbsorber.address, true);
              await expect(essenceAbsorber.connect(staker1Signer).stakeAbsorberRods(scenario.tokenId, scenario.amount))
                .to.emit(essenceAbsorber, 'Staked')
                .withArgs(
                  absorberRods.address,
                  scenario.tokenId,
                  scenario.amount,
                  powerBefore.add(scenario.power.mul(scenario.amount))
                );

              expect(await absorberRods.balanceOf(essenceAbsorber.address, scenario.tokenId)).to.be.equal(
                scenario.amount
              );
              const powerAfter = await essenceAbsorber.powers(staker1);
              const powerDiff = powerAfter.sub(powerBefore);
              expect(powerDiff).to.be.equal(scenario.power.mul(scenario.amount));
              totalPower = totalPower.add(powerDiff);
            }
          }

          expect(await essenceAbsorber.powers(staker1)).to.be.equal(totalPower);
        });
      });

      describe('stakeArtifact()', function () {
        it('Cannot stake Artifact', async function () {
          await essenceAbsorber.setArtifact(ethers.constants.AddressZero);
          await expect(essenceAbsorber.stakeArtifact(1)).to.be.revertedWith('Cannot stake Artifact');
        });

        it('NFT already staked', async function () {
          let metadata = {
            artifactGeneration: 0,
            artifactClass: 0,
            artifactRarity: 0,
            questLevel: 0,
            craftLevel: 0,
            constellationRanks: [0, 1, 2, 3, 4, 5],
          };
          await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(0).returns(metadata);

          await artifact.mint(staker1);
          await artifact.connect(staker1Signer).approve(essenceAbsorber.address, 0);
          await essenceAbsorber.connect(staker1Signer).stakeArtifact(0);
          await expect(essenceAbsorber.connect(staker1Signer).stakeArtifact(0)).to.be.revertedWith(
            'NFT already staked'
          );
        });

        it('Max 3 artifacts per wallet', async function () {
          let metadata = {
            artifactGeneration: 1,
            artifactClass: 0,
            artifactRarity: 0,
            questLevel: 0,
            craftLevel: 0,
            constellationRanks: [0, 1, 2, 3, 4, 5],
          };

          for (let index = 0; index < 4; index++) {
            await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(index).returns(metadata);
            await artifact.mint(deployer);
            await artifact.approve(essenceAbsorber.address, index);

            if (index == 3) {
              await expect(essenceAbsorber.stakeArtifact(index)).to.be.revertedWith('Max 3 artifacts per wallet');
            } else {
              await essenceAbsorber.stakeArtifact(index);
            }
          }
        });

        it('Max 1 1/1 artifact per wallet', async function () {
          let metadata = {
            artifactGeneration: 0,
            artifactClass: 0,
            artifactRarity: 0,
            questLevel: 0,
            craftLevel: 0,
            constellationRanks: [0, 1, 2, 3, 4, 5],
          };
          await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(0).returns(metadata);
          await artifact.mint(staker1);
          await artifact.connect(staker1Signer).approve(essenceAbsorber.address, 0);
          await essenceAbsorber.connect(staker1Signer).stakeArtifact(0);

          await mockIArtifactMetadataStore.mock.metadataForArtifact.withArgs(1).returns(metadata);
          await artifact.mint(staker1);
          await artifact.connect(staker1Signer).approve(essenceAbsorber.address, 1);
          await expect(essenceAbsorber.connect(staker1Signer).stakeArtifact(1)).to.be.revertedWith(
            'Max 1 1/1 artifact per wallet'
          );
        });

        it('stake powers', async function () {
          let totalPower = ethers.utils.parseEther('0');

          for (let index = 0; index < powerScenarios.length; index++) {
            const scenario = powerScenarios[index];

            const stakedArtifacts = await essenceAbsorber.getStakedArtifacts(staker1);

            if (scenario.nft == artifact.address && stakedArtifacts.length < 3) {
              const powerBefore = await essenceAbsorber.powers(staker1);
              await artifact.mintWithId(staker1, scenario.tokenId);
              await artifact.connect(staker1Signer).approve(essenceAbsorber.address, scenario.tokenId);
              await essenceAbsorber.connect(staker1Signer).stakeArtifact(scenario.tokenId);
              expect(await artifact.ownerOf(scenario.tokenId)).to.be.equal(essenceAbsorber.address);
              const powerAfter = await essenceAbsorber.powers(staker1);
              expect(powerAfter.sub(powerBefore)).to.be.equal(scenario.power);
              totalPower = totalPower.add(scenario.power);
            }
          }

          expect(await essenceAbsorber.powers(staker1)).to.be.equal(totalPower);
        });
      });

      it('harvest scenarios with staking', async function () {
        for (let index = 0; index < depositsScenarios.length; index++) {
          expect(await essenceToken.balanceOf(depositsScenarios[index].address)).to.be.equal(0);
        }

        const steps = [
          {
            timestamp: startTimestamp + 2500,
            stake: [
              {
                address: staker1,
                signer: staker1Signer,
                depositId: 1,
                index: 7,
              },
              {
                address: staker1,
                signer: staker1Signer,
                depositId: 3,
                index: 5,
              },
              {
                address: staker2,
                signer: staker2Signer,
                depositId: 1,
                index: 3,
              },
            ],
            unstake: [],
          },
          {
            timestamp: startTimestamp + 3000,
            stake: [
              {
                address: staker1,
                signer: staker1Signer,
                depositId: 1,
                index: 2,
              },
              {
                address: staker1,
                signer: staker1Signer,
                depositId: 2,
                index: 4,
              },
            ],
            unstake: [],
          },
          {
            timestamp: startTimestamp + 3500,
            stake: [],
            unstake: [
              {
                address: staker1,
                signer: staker1Signer,
                depositId: 1,
                index: 2,
              },
            ],
          },
          {
            timestamp: startTimestamp + 4000,
            stake: [],
            unstake: [
              {
                address: staker2,
                signer: staker2Signer,
                depositId: 1,
                index: 3,
              },
            ],
          },
        ];

        for (let index = 0; index < steps.length; index++) {
          const step = steps[index];

          await mineBlock(step.timestamp);

          for (let i = 0; i < step.stake.length; i++) {
            const stake = step.stake[i];
            const tokenId = powerScenarios[stake.index].tokenId;
            const amount = powerScenarios[stake.index].amount;

            if (powerScenarios[stake.index].nft == artifact.address) {
              await artifact.mintWithId(stake.address, tokenId);
              await artifact.connect(stake.signer).approve(essenceAbsorber.address, tokenId);
              await essenceAbsorber.connect(stake.signer).stakeArtifact(tokenId);
            } else {
              await absorberRods.functions['mint(address,uint256,uint256)'](stake.address, tokenId, amount);
              await absorberRods.connect(stake.signer).setApprovalForAll(essenceAbsorber.address, true);
              await essenceAbsorber.connect(stake.signer).stakeAbsorberRods(tokenId, amount);
            }
          }

          for (let i = 0; i < step.unstake.length; i++) {
            const unstake = step.unstake[i];
            const tokenId = powerScenarios[unstake.index].tokenId;
            const amount = powerScenarios[unstake.index].amount;

            if (powerScenarios[unstake.index].nft == artifact.address) {
              await essenceAbsorber.connect(unstake.signer).unstakeArtifact(tokenId);
            } else {
              await essenceAbsorber.connect(unstake.signer).unstakeAbsorberRods(tokenId, amount);
            }
          }

          await essenceAbsorber.connect(staker1Signer).harvestAll();
          await essenceAbsorber.connect(staker2Signer).harvestAll();
        }

        await mineBlock(startTimestamp + 6000);

        const rewards = [
          {
            address: depositsScenarios[0].address,
            signer: depositsScenarios[0].signer,
            reward: ethers.utils.parseEther('707.994049297877092636'),
          },
          {
            address: depositsScenarios[3].address,
            signer: depositsScenarios[3].signer,
            reward: ethers.utils.parseEther('192.005950702122902940'),
          },
        ];

        for (let index = 0; index < rewards.length; index++) {
          await essenceAbsorber.connect(rewards[index].signer).harvestAll();
          const balAfter = await essenceToken.balanceOf(rewards[index].address);
          expect(balAfter).to.be.closeTo(rewards[index].reward, 10000);
        }
      });

      describe.skip('limit of deposits', function () {
        it('makes deposits and stakes NFT', async function () {
          const makeDeposits = async (count: any) => {
            for (let index = 0; index < count; index++) {
              const deposit = depositsScenarios[0];
              await essenceToken.mint(deposit.address, deposit.amount);
              await essenceToken.connect(deposit.signer).approve(essenceAbsorber.address, deposit.amount);
              await essenceAbsorber.connect(deposit.signer).deposit(deposit.amount, deposit.lock);
            }
          };

          const deposit = depositsScenarios[0];
          const tokenId = 1;
          const tokenAmount = 1;

          // Deposits: 3, GasLimit: 227321
          // Deposits: 10, GasLimit: 241688
          // Deposits: 50, GasLimit: 624958
          // Deposits: 100, GasLimit: 1107476
          // Deposits: 200, GasLimit: 2064629
          // Deposits: 500, GasLimit: 4967974
          // Deposits: 1000, GasLimit: 9693977
          // Deposits: 1250, GasLimit: 12104647
          // Deposits: 1500, GasLimit: 14497133
          // Deposits: 1750, GasLimit: 16897584
          // Deposits: 2000, GasLimit: 19313720
          // Deposits: 2250, GasLimit: 21700950
          // Deposits: 2500, GasLimit: 24082428
          // Deposits: 2750, GasLimit: 26480028
          // Deposits: 3000, GasLimit: 28905377
          const listOfDeposits = [0, 7, 40, 50, 100, 300, 500, 250, 250, 250, 250, 250, 250, 250, 250];

          for (let index = 0; index < listOfDeposits.length; index++) {
            const element = listOfDeposits[index];
            await makeDeposits(element);

            const allIds = await essenceAbsorber.getAllUserDepositIds(deposit.address);

            await absorberRods.functions['mint(address,uint256,uint256)'](deposit.address, tokenId, tokenAmount);
            await absorberRods.connect(deposit.signer).setApprovalForAll(essenceAbsorber.address, true);

            let tx = await essenceAbsorber.connect(deposit.signer).stakeAbsorberRods(tokenId, tokenAmount);
            const gasLimit = tx.gasLimit.toString();
            console.log(`Deposits: ${allIds.length}, GasLimit: ${gasLimit}`);
          }

          let getAllUserDepositIds = await essenceAbsorber.getAllUserDepositIds(deposit.address);
          expect(getAllUserDepositIds.length).to.be.equal(3000);

          await essenceToken.mint(deposit.address, deposit.amount);
          await essenceToken.connect(deposit.signer).approve(essenceAbsorber.address, deposit.amount);
          await expect(
            essenceAbsorber.connect(deposit.signer).deposit(deposit.amount, deposit.lock)
          ).to.be.revertedWith('Max deposits number reached');
        });
      });

      describe('with NFTs staked', function () {
        beforeEach(async function () {
          for (let index = 0; index < powerScenarios.slice(0, -2).length; index++) {
            const scenario = powerScenarios[index];

            if (scenario.nft == artifact.address) {
              await artifact.mintWithId(staker1, scenario.tokenId);
              await artifact.connect(staker1Signer).approve(essenceAbsorber.address, scenario.tokenId);
              await essenceAbsorber.connect(staker1Signer).stakeArtifact(scenario.tokenId);
              expect(await artifact.ownerOf(scenario.tokenId)).to.be.equal(essenceAbsorber.address);
            } else {
              await absorberRods.functions['mint(address,uint256,uint256)'](staker1, scenario.tokenId, scenario.amount);
              await absorberRods.connect(staker1Signer).setApprovalForAll(essenceAbsorber.address, true);
              await essenceAbsorber.connect(staker1Signer).stakeAbsorberRods(scenario.tokenId, scenario.amount);
              expect(await absorberRods.balanceOf(essenceAbsorber.address, scenario.tokenId)).to.be.equal(
                scenario.amount
              );
            }
          }
        });

        it('Withdraw amount too big', async function () {
          const scenario = powerScenarios[0];
          await expect(
            essenceAbsorber.connect(staker2Signer).unstakeAbsorberRods(scenario.tokenId, scenario.amount)
          ).to.be.revertedWith('Withdraw amount too big');
          expect(await absorberRods.balanceOf(essenceAbsorber.address, scenario.tokenId)).to.be.equal(scenario.amount);
        });

        it('NFT is not staked', async function () {
          const scenario = powerScenarios[7];
          await expect(essenceAbsorber.connect(staker2Signer).unstakeArtifact(scenario.tokenId)).to.be.revertedWith(
            'NFT is not staked'
          );
        });

        it('unstake powers', async function () {
          let totalPower = await essenceAbsorber.powers(staker1);

          for (let index = 0; index < powerScenarios.slice(0, -2).length; index++) {
            const scenario = powerScenarios[index];
            const powerBefore = await essenceAbsorber.powers(staker1);

            if (scenario.nft == artifact.address) {
              await essenceAbsorber.connect(staker1Signer).unstakeArtifact(scenario.tokenId);
              expect(await artifact.ownerOf(scenario.tokenId)).to.be.equal(staker1);
            } else {
              await essenceAbsorber.connect(staker1Signer).unstakeAbsorberRods(scenario.tokenId, scenario.amount);
              expect(await absorberRods.balanceOf(staker1, scenario.tokenId)).to.be.equal(scenario.amount);
            }

            const powerAfter = await essenceAbsorber.powers(staker1);
            expect(powerBefore.sub(powerAfter)).to.be.equal(scenario.power.mul(scenario.amount));
          }

          expect(await essenceAbsorber.powers(staker1)).to.be.equal(0);
        });
      });
    });
  });
});
