import hre from 'hardhat';
import { expect } from 'chai';
import { getBlockTime, mineBlock, getCurrentTime, setNextBlockTime } from './utils';

const { ethers, deployments, getNamedAccounts } = hre;
const { deploy } = deployments;

describe.only('EssenceField', function () {
  let essenceField: any;
  let essenceToken: any;
  let flow1: any, flow2: any, flow3: any, hacker: any, deployer: any;
  let flow1Signer: any, flow2Signer: any, flow3Signer: any, hackerSigner: any, deployerSigner: any;
  let checkDeposit: any;
  let checkPendingRewardsPosition: any;
  let checkIndexes: any;

  before(async function () {
    const namedAccounts = await getNamedAccounts();
    flow1 = namedAccounts.staker1;
    flow2 = namedAccounts.staker2;
    flow3 = namedAccounts.staker3;
    hacker = namedAccounts.hacker;
    deployer = namedAccounts.deployer;

    flow1Signer = await ethers.provider.getSigner(flow1);
    flow2Signer = await ethers.provider.getSigner(flow2);
    flow3Signer = await ethers.provider.getSigner(flow3);
    hackerSigner = await ethers.provider.getSigner(hacker);
    deployerSigner = await ethers.provider.getSigner(deployer);
  });

  describe('use proxy', function () {
    beforeEach(async function () {
      await deployments.fixture(['EssenceField'], { fallbackToGlobal: true });

      const ERC20Mintable = await ethers.getContractFactory('ERC20Mintable');
      essenceToken = await ERC20Mintable.deploy();
      await essenceToken.deployed();

      const EssenceField = await deployments.get('EssenceField');
      essenceField = new ethers.Contract(EssenceField.address, EssenceField.abi, deployerSigner);
      await essenceField.setEssenceToken(essenceToken.address);

      // const EssenceField = await ethers.getContractFactory('EssenceField')
      // essenceField = await EssenceField.deploy()
      // await essenceField.deployed();
      // await essenceField.init(essenceToken.address);
    });

    it('init()', async function () {
      await expect(essenceField.init(essenceToken.address)).to.be.revertedWith(
        'Initializable: contract is already initialized'
      );
    });

    it('essence()', async function () {
      expect(await essenceField.essence()).to.be.equal(essenceToken.address);
    });

    it('ESSENCE_FIELD_CREATOR_ROLE()', async function () {
      expect(await essenceField.ESSENCE_FIELD_CREATOR_ROLE()).to.be.equal(
        '0x275f12656528ceae7cba2736a15cb4ce098fc404b67e9825ec13a82aaf8fabec'
      );
    });

    it('hasRole()', async function () {
      const ESSENCE_FIELD_CREATOR_ROLE = await essenceField.ESSENCE_FIELD_CREATOR_ROLE();
      expect(await essenceField.hasRole(ESSENCE_FIELD_CREATOR_ROLE, deployer)).to.be.true;
    });

    it('grantRole()', async function () {
      const ESSENCE_FIELD_CREATOR_ROLE = await essenceField.ESSENCE_FIELD_CREATOR_ROLE();

      expect(await essenceField.hasRole(ESSENCE_FIELD_CREATOR_ROLE, hacker)).to.be.false;

      await essenceField.grantRole(ESSENCE_FIELD_CREATOR_ROLE, hacker);

      expect(await essenceField.hasRole(ESSENCE_FIELD_CREATOR_ROLE, hacker)).to.be.true;
    });

    it('addFlow()', async function () {
      const totalRewards = ethers.utils.parseEther('1');
      const startTimestamp = await getCurrentTime();
      const timeDelta = 2000;
      const endTimestamp = startTimestamp + timeDelta;

      await expect(essenceField.connect(hackerSigner).addFlow(flow1, totalRewards, startTimestamp, endTimestamp, false))
        .to.be.reverted;

      await essenceField.addFlow(flow1, totalRewards, startTimestamp, endTimestamp, false);

      expect(await essenceField.getFlows()).to.be.deep.equal([flow1]);
      const ratePerSecond = await essenceField.getRatePerSecond(flow1);
      expect(ratePerSecond).to.be.equal(totalRewards.div(timeDelta));
      expect(await essenceField.getGlobalRatePerSecond()).to.be.equal(ratePerSecond);

      const currentTime = await getCurrentTime();
      expect(await essenceField.getPendingRewards(flow1)).to.be.equal(ratePerSecond.mul(currentTime - startTimestamp));
    });

    describe('with flows', function () {
      let flowsDetails: any[];
      let timestamps: any[];

      beforeEach(async function () {
        let currentTime = (await getCurrentTime()) + 5000;
        flowsDetails = [
          {
            address: flow1,
            signer: flow1Signer,
            totalRewards: ethers.utils.parseEther('1'),
            startTimestamp: currentTime,
            endTimestamp: currentTime + 2000,
          },
          {
            address: flow2,
            signer: flow2Signer,
            totalRewards: ethers.utils.parseEther('25'),
            startTimestamp: currentTime + 100,
            endTimestamp: currentTime + 1100,
          },
          {
            address: flow3,
            signer: flow3Signer,
            totalRewards: ethers.utils.parseEther('5000'),
            startTimestamp: currentTime + 200,
            endTimestamp: currentTime + 4200,
          },
        ];

        timestamps = [
          currentTime + 100, // 1 active
          currentTime + 105, // 1 & 2 active
          currentTime + 400, // 1 & 2 & 3 active
          currentTime + 1101, // 1 & 3 active
          currentTime + 2001, // 3 active
          currentTime + 4201, // 0 active
        ];

        for (let index = 0; index < flowsDetails.length; index++) {
          const _flow = flowsDetails[index];
          await essenceField.addFlow(
            _flow.address,
            _flow.totalRewards,
            _flow.startTimestamp,
            _flow.endTimestamp,
            false
          );
          await essenceToken.mint(essenceField.address, _flow.totalRewards);
        }
      });

      it('getFlows()', async function () {
        expect(await essenceField.getFlows()).to.be.deep.equal([flow1, flow2, flow3]);
      });

      it('addFlow()', async function () {
        const totalRewards = ethers.utils.parseEther('1');
        const startTimestamp = await getCurrentTime();
        const timeDelta = 2000;
        const endTimestamp = startTimestamp + timeDelta;

        await expect(essenceField.addFlow(flow2, totalRewards, startTimestamp, endTimestamp, false)).to.be.revertedWith(
          'Flow for address already exists'
        );
      });

      it('getRatePerSecond()', async function () {
        await mineBlock(flowsDetails[0].startTimestamp + 300);

        for (let index = 0; index < flowsDetails.length; index++) {
          const _flow = flowsDetails[index];
          const ratePerSecond = await essenceField.getRatePerSecond(_flow.address);
          expect(ratePerSecond).to.be.equal(_flow.totalRewards.div(_flow.endTimestamp - _flow.startTimestamp));
        }
      });

      it('getGlobalRatePerSecond()', async function () {
        await mineBlock(flowsDetails[0].startTimestamp + 300);
        let globalRatePerSecond = ethers.BigNumber.from(0);

        for (let index = 0; index < flowsDetails.length; index++) {
          const _flow = flowsDetails[index];
          const ratePerSecond = await essenceField.getRatePerSecond(_flow.address);
          globalRatePerSecond = globalRatePerSecond.add(ratePerSecond);
        }
        expect(await essenceField.getGlobalRatePerSecond()).to.be.equal(globalRatePerSecond);
      });

      it('getPendingRewards()', async function () {
        for (let i = 0; i < timestamps.length; i++) {
          await mineBlock(timestamps[i]);

          for (let index = 0; index < flowsDetails.length; index++) {
            const _flow = flowsDetails[index];
            let currentTime = await getCurrentTime();
            const ratePerSecond = await essenceField.getRatePerSecond(_flow.address);
            if (_flow.startTimestamp < currentTime && currentTime < _flow.endTimestamp) {
              expect(ratePerSecond).to.be.equal(_flow.totalRewards.div(_flow.endTimestamp - _flow.startTimestamp));
            } else {
              expect(ratePerSecond).to.be.equal(0);
            }
          }
        }
      });

      it('grantTokenToFlow()', async function () {
        const _flow = flowsDetails[1];
        const grant = ethers.utils.parseEther('5.5');

        await setNextBlockTime(_flow.startTimestamp + 300);
        await essenceField.connect(_flow.signer).requestRewards();

        const flowConfigBefore = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceBefore = await essenceToken.balanceOf(essenceField.address);

        await essenceToken.mint(deployer, grant);
        await essenceToken.approve(essenceField.address, grant);
        await setNextBlockTime(_flow.startTimestamp + 500);
        await essenceField.grantTokenToFlow(_flow.address, grant);

        const flowConfigAfter = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceAfter = await essenceToken.balanceOf(essenceField.address);

        expect(flowConfigAfter.startTimestamp).to.be.equal(flowConfigBefore.startTimestamp);
        expect(flowConfigAfter.endTimestamp).to.be.equal(flowConfigBefore.endTimestamp);
        expect(flowConfigAfter.lastRewardTimestamp).to.be.equal(flowConfigBefore.lastRewardTimestamp);
        expect(flowConfigAfter.paid).to.be.equal(flowConfigBefore.paid);

        expect(flowConfigAfter.totalRewards).to.be.equal(flowConfigBefore.totalRewards.add(grant));
        expect(essenceFieldBalanceAfter).to.be.equal(essenceFieldBalanceBefore.add(grant));

        expect(flowConfigAfter.ratePerSecond).to.be.equal(ethers.utils.parseEther('0.032857142857142857'));
      });

      it('fundFlow()', async function () {
        const _flow = flowsDetails[1];
        const grant = ethers.utils.parseEther('5.5');

        await setNextBlockTime(_flow.startTimestamp + 300);
        await essenceField.connect(_flow.signer).requestRewards();

        const flowConfigBefore = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceBefore = await essenceToken.balanceOf(essenceField.address);

        await setNextBlockTime(_flow.startTimestamp + 500);
        await essenceField.fundFlow(_flow.address, grant);

        const flowConfigAfter = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceAfter = await essenceToken.balanceOf(essenceField.address);

        expect(flowConfigAfter.startTimestamp).to.be.equal(flowConfigBefore.startTimestamp);
        expect(flowConfigAfter.endTimestamp).to.be.equal(flowConfigBefore.endTimestamp);
        expect(flowConfigAfter.lastRewardTimestamp).to.be.equal(flowConfigBefore.lastRewardTimestamp);
        expect(flowConfigAfter.paid).to.be.equal(flowConfigBefore.paid);

        expect(flowConfigAfter.totalRewards).to.be.equal(flowConfigBefore.totalRewards.add(grant));
        expect(essenceFieldBalanceAfter).to.be.equal(essenceFieldBalanceBefore);

        expect(flowConfigAfter.ratePerSecond).to.be.equal(ethers.utils.parseEther('0.032857142857142857'));
      });

      it('defundFlow()', async function () {
        const _flow = flowsDetails[2];
        const defund = ethers.utils.parseEther('1250');

        await setNextBlockTime(_flow.startTimestamp + 800);
        await essenceField.connect(_flow.signer).requestRewards();

        const flowConfigBefore = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceBefore = await essenceToken.balanceOf(essenceField.address);

        await setNextBlockTime(_flow.startTimestamp + 1200);
        await essenceField.defundFlow(_flow.address, defund);

        const flowConfigAfter = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceAfter = await essenceToken.balanceOf(essenceField.address);

        expect(flowConfigAfter.startTimestamp).to.be.equal(flowConfigBefore.startTimestamp);
        expect(flowConfigAfter.endTimestamp).to.be.equal(flowConfigBefore.endTimestamp);
        expect(flowConfigAfter.lastRewardTimestamp).to.be.equal(flowConfigBefore.lastRewardTimestamp);
        expect(flowConfigAfter.paid).to.be.equal(flowConfigBefore.paid);

        expect(flowConfigAfter.totalRewards).to.be.equal(flowConfigBefore.totalRewards.sub(defund));
        expect(essenceFieldBalanceAfter).to.be.equal(essenceFieldBalanceBefore);

        expect(flowConfigAfter.ratePerSecond).to.be.equal(ethers.utils.parseEther('0.859375'));
      });

      it('updateFlowTime()', async function () {
        const newTimestamps = [
          {
            startTimestamp: flowsDetails[2].startTimestamp + 750,
            endTimestamp: flowsDetails[2].endTimestamp + 750,
          },
          {
            startTimestamp: 0,
            endTimestamp: flowsDetails[2].endTimestamp + 750 + 2000,
          },
          {
            startTimestamp: flowsDetails[2].startTimestamp + 1500 + 250,
            endTimestamp: 0,
          },
        ];

        const newFlowData = [
          {
            ...flowsDetails[2],
            startTimestamp: flowsDetails[2].startTimestamp + 750,
            endTimestamp: flowsDetails[2].endTimestamp + 750,
            lastRewardTimestamp: flowsDetails[2].startTimestamp + 750,
            ratePerSecond: ethers.utils.parseEther('1.09375'),
            getRatePerSecond: 0,
            getPendingRewards: 0,
            paid: ethers.utils.parseEther('625'),
          },
          {
            ...flowsDetails[2],
            startTimestamp: flowsDetails[2].startTimestamp + 750,
            endTimestamp: flowsDetails[2].endTimestamp + 750 + 2000,
            lastRewardTimestamp: flowsDetails[2].startTimestamp + 1000,
            ratePerSecond: ethers.utils.parseEther('0.713315217391304347'),
            getRatePerSecond: ethers.utils.parseEther('0.713315217391304347'),
            getPendingRewards: ethers.utils.parseEther('7.133152173913043470'),
            paid: ethers.utils.parseEther('898.4375'),
          },
          {
            ...flowsDetails[2],
            startTimestamp: flowsDetails[2].startTimestamp + 1500 + 250,
            endTimestamp: flowsDetails[2].endTimestamp + 750 + 2000,
            lastRewardTimestamp: flowsDetails[2].startTimestamp + 1500 + 250,
            ratePerSecond: ethers.utils.parseEther('0.748980978260869565'),
            getRatePerSecond: 0,
            getPendingRewards: 0,
            paid: ethers.utils.parseEther('1255.095108695652173500'),
          },
        ];

        const _flow = flowsDetails[2];

        let futureTimestamp = _flow.startTimestamp + 500;

        for (let index = 0; index < newTimestamps.length; index++) {
          await setNextBlockTime(futureTimestamp);
          await essenceField.connect(_flow.signer).requestRewards();
          futureTimestamp += 500;

          await essenceField.updateFlowTime(
            _flow.address,
            newTimestamps[index].startTimestamp,
            newTimestamps[index].endTimestamp
          );

          await mineBlock(futureTimestamp - 500 + 10);

          const flowConfig = await essenceField.getFlowConfig(_flow.address);
          const getRatePerSecond = await essenceField.getRatePerSecond(_flow.address);
          const getPendingRewards = await essenceField.getPendingRewards(_flow.address);

          expect(flowConfig.totalRewards).to.be.equal(_flow.totalRewards);

          expect(flowConfig.startTimestamp).to.be.equal(newFlowData[index].startTimestamp);
          expect(flowConfig.endTimestamp).to.be.equal(newFlowData[index].endTimestamp);

          expect(flowConfig.lastRewardTimestamp).to.be.equal(newFlowData[index].lastRewardTimestamp);
          expect(flowConfig.ratePerSecond).to.be.equal(newFlowData[index].ratePerSecond);
          expect(getRatePerSecond).to.be.equal(newFlowData[index].getRatePerSecond);
          expect(getPendingRewards).to.be.equal(newFlowData[index].getPendingRewards);
          expect(flowConfig.paid).to.be.equal(newFlowData[index].paid);
        }

        await mineBlock(futureTimestamp);

        const flowConfigAfter = await essenceField.getFlowConfig(_flow.address);
        const getRatePerSecondAfter = await essenceField.getRatePerSecond(_flow.address);
        const getPendingRewardsAfter = await essenceField.getPendingRewards(_flow.address);

        expect(flowConfigAfter.ratePerSecond).to.be.equal(newFlowData[2].ratePerSecond);
        expect(getRatePerSecondAfter).to.be.equal(newFlowData[2].ratePerSecond);
        expect(getPendingRewardsAfter).to.be.equal(newFlowData[2].ratePerSecond.mul(250));
      });

      it('removeFlow()', async function () {
        const _flow = flowsDetails[2];
        const defund = ethers.utils.parseEther('1250');

        await setNextBlockTime(_flow.startTimestamp + 800);
        await essenceField.connect(_flow.signer).requestRewards();

        const flowConfigBefore = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceBefore = await essenceToken.balanceOf(essenceField.address);
        const flowBalanceBefore = await essenceToken.balanceOf(_flow.address);

        await setNextBlockTime(_flow.startTimestamp + 1200);
        await essenceField.removeFlow(_flow.address);
        await essenceField.connect(_flow.signer).requestRewards();

        const flowConfigAfter = await essenceField.getFlowConfig(_flow.address);
        const essenceFieldBalanceAfter = await essenceToken.balanceOf(essenceField.address);
        const flowBalanceAfter = await essenceToken.balanceOf(_flow.address);

        expect(flowConfigAfter.startTimestamp).to.be.equal(0);
        expect(flowConfigAfter.endTimestamp).to.be.equal(0);
        expect(flowConfigAfter.lastRewardTimestamp).to.be.equal(0);
        expect(flowConfigAfter.paid).to.be.equal(0);
        expect(flowConfigAfter.totalRewards).to.be.equal(0);
        expect(flowConfigAfter.ratePerSecond).to.be.equal(0);

        expect(essenceFieldBalanceAfter).to.be.equal(essenceFieldBalanceBefore);
        expect(flowBalanceBefore.totalRewards).to.be.equal(flowBalanceAfter.totalRewards);
      });

      it('withdrawEssence()', async function () {
        const amount = ethers.utils.parseEther('500');

        const essenceFieldBalanceBefore = await essenceToken.balanceOf(essenceField.address);
        const deployerBalanceBefore = await essenceToken.balanceOf(deployer);

        await essenceField.withdrawEssence(deployer, amount);

        const essenceFieldBalanceAfter = await essenceToken.balanceOf(essenceField.address);
        const deployerBalanceAfter = await essenceToken.balanceOf(deployer);

        expect(essenceFieldBalanceAfter).to.be.equal(essenceFieldBalanceBefore.sub(amount));
        expect(deployerBalanceAfter).to.be.equal(deployerBalanceBefore.add(amount));
      });
    });
  });

  describe('requestRewards()', function () {
    let scenarios: any[] = Array.from({ length: 7 });
    let scenarioTimestamps: any[];
    let essenceTokenFresh: any;
    let essenceFieldFresh: any;

    before(async function () {
      let currentTime = (await getCurrentTime()) + 5000;

      let scenarioFlows = [
        {
          address: flow1,
          signer: flow1Signer,
          totalRewards: ethers.utils.parseEther('1'),
          startTimestamp: currentTime,
          endTimestamp: currentTime + 2000,
        },
        {
          address: flow2,
          signer: flow2Signer,
          totalRewards: ethers.utils.parseEther('25'),
          startTimestamp: currentTime + 100,
          endTimestamp: currentTime + 1100,
        },
        {
          address: flow3,
          signer: flow3Signer,
          totalRewards: ethers.utils.parseEther('5000'),
          startTimestamp: currentTime + 200,
          endTimestamp: currentTime + 4200,
        },
      ];

      scenarioTimestamps = [
        currentTime + 100, // 1 active
        currentTime + 120, // 1 & 2 active
        currentTime + 400, // 1 & 2 & 3 active
        currentTime + 1101, // 1 & 3 active
        currentTime + 2001, // 3 active
        currentTime + 4201, // 0 active
      ];

      scenarios = [
        // + 0, 0 active
        [
          {
            ...scenarioFlows[0],
            lastRewardTimestamp: scenarioFlows[0].startTimestamp,
            ratePerSecond: ethers.utils.parseEther('0.0005'),
            paid: 0,
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioFlows[1].startTimestamp,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: 0,
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioFlows[2].startTimestamp,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: 0,
          },
        ],
        // + 100, 1 & 2 active
        [
          {
            ...scenarioFlows[0],
            lastRewardTimestamp: scenarioTimestamps[0],
            ratePerSecond: ethers.utils.parseEther('0.0005'),
            paid: ethers.utils.parseEther('0.05'),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioFlows[1].startTimestamp + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: ethers.utils.parseEther('0.125'),
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioFlows[2].startTimestamp,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: 0,
          },
        ],
        // + 120, 1 & 2 active
        [
          {
            ...scenarioFlows[0],
            lastRewardTimestamp: scenarioTimestamps[1],
            ratePerSecond: ethers.utils.parseEther('0.0005'),
            paid: ethers.utils.parseEther('0.06'),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioTimestamps[1] + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: ethers.utils.parseEther('0.625'),
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioFlows[2].startTimestamp,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: 0,
          },
        ],
        // + 400, 1 & 2 & 3 active
        [
          {
            ...scenarioFlows[0],
            lastRewardTimestamp: scenarioTimestamps[2],
            ratePerSecond: ethers.utils.parseEther('0.0005'),
            paid: ethers.utils.parseEther('0.2'),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioTimestamps[2] + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: ethers.utils.parseEther('7.625'),
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioTimestamps[2] + 10,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: ethers.utils.parseEther('262.5'),
          },
        ],
        // + 1101, 1 & 3 active
        [
          {
            ...scenarioFlows[0],
            totalRewards: scenarioFlows[0].totalRewards.mul(2),
            lastRewardTimestamp: scenarioTimestamps[3],
            ratePerSecond: ethers.utils.parseEther('0.001125'),
            paid: ethers.utils.parseEther('0.988625'),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioTimestamps[3] + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: ethers.utils.parseEther('25'),
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioTimestamps[3] + 10,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: ethers.utils.parseEther('1138.75'),
          },
        ],
        // + 2001, 3 active
        [
          {
            ...scenarioFlows[0],
            totalRewards: scenarioFlows[0].totalRewards.mul(2).sub(ethers.utils.parseEther('0.5')),
            lastRewardTimestamp: scenarioTimestamps[4],
            ratePerSecond: ethers.utils.parseEther('0.000568826473859844'),
            paid: scenarioFlows[0].totalRewards.mul(2).sub(ethers.utils.parseEther('0.5')),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioTimestamps[3] + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: scenarioFlows[1].totalRewards,
          },
          {
            ...scenarioFlows[2],
            lastRewardTimestamp: scenarioTimestamps[4] + 10,
            ratePerSecond: ethers.utils.parseEther('1.25'),
            paid: ethers.utils.parseEther('2263.75'),
          },
        ],
        // + 4201, 0 active
        [
          {
            ...scenarioFlows[0],
            totalRewards: scenarioFlows[0].totalRewards.mul(2).sub(ethers.utils.parseEther('0.5')),
            lastRewardTimestamp: scenarioTimestamps[4],
            ratePerSecond: ethers.utils.parseEther('0.000568826473859844'),
            paid: scenarioFlows[0].totalRewards.mul(2).sub(ethers.utils.parseEther('0.5')),
          },
          {
            ...scenarioFlows[1],
            lastRewardTimestamp: scenarioTimestamps[3] + 5,
            ratePerSecond: ethers.utils.parseEther('0.025'),
            paid: scenarioFlows[1].totalRewards,
          },
          {
            ...scenarioFlows[2],
            endTimestamp: scenarioFlows[2].endTimestamp + 1000,
            lastRewardTimestamp: scenarioTimestamps[5] + 10,
            ratePerSecond: ethers.utils.parseEther('0.858027594857322044'),
            paid: ethers.utils.parseEther('4151.410708686108496800'),
          },
        ],
      ];

      await deployments.fixture(['EssenceField'], { fallbackToGlobal: true });

      const ERC20Mintable = await ethers.getContractFactory('ERC20Mintable');
      essenceTokenFresh = await ERC20Mintable.deploy();
      await essenceTokenFresh.deployed();

      const EssenceField = await deployments.get('EssenceField');
      essenceFieldFresh = new ethers.Contract(EssenceField.address, EssenceField.abi, deployerSigner);
      await essenceFieldFresh.setEssenceToken(essenceTokenFresh.address);

      for (let index = 0; index < scenarioFlows.length; index++) {
        const _flow = scenarioFlows[index];
        await essenceFieldFresh.addFlow(
          _flow.address,
          _flow.totalRewards,
          _flow.startTimestamp,
          _flow.endTimestamp,
          false
        );
        await essenceTokenFresh.mint(essenceFieldFresh.address, _flow.totalRewards);
      }
    });

    scenarios.forEach((testCase, i) => {
      it(`[${i}] requestRewards()`, async function () {
        let scenario = scenarios[i];

        for (let index = 0; index < scenario.length; index++) {
          const _flow = scenario[index];
          const flowConfig = await essenceFieldFresh.getFlowConfig(_flow.address);
          let steamBalance = await essenceTokenFresh.balanceOf(_flow.address);

          expect(flowConfig.totalRewards).to.be.equal(_flow.totalRewards);
          expect(flowConfig.startTimestamp).to.be.equal(_flow.startTimestamp);
          expect(flowConfig.endTimestamp).to.be.equal(_flow.endTimestamp);
          expect(flowConfig.ratePerSecond).to.be.equal(_flow.ratePerSecond);

          expect(flowConfig.lastRewardTimestamp).to.be.equal(_flow.lastRewardTimestamp);
          expect(flowConfig.paid).to.be.equal(_flow.paid);
          expect(steamBalance).to.be.equal(_flow.paid);

          if (i == 3 && index == 0) {
            // test grantTokenToFlow()
            await essenceTokenFresh.mint(deployer, _flow.totalRewards);
            await essenceTokenFresh.approve(essenceFieldFresh.address, _flow.totalRewards);
            await essenceFieldFresh.grantTokenToFlow(_flow.address, _flow.totalRewards);
          }

          if (i == 4 && index == 0) {
            // test defundFlow()
            await essenceFieldFresh.defundFlow(_flow.address, ethers.utils.parseEther('0.5'));
          }

          if (i == 5 && index == 2) {
            // test updateFlowTime()
            await essenceFieldFresh.updateFlowTime(_flow.address, 0, _flow.endTimestamp + 1000);
          }

          if (i < 6) {
            let futureTimestamp = scenarioTimestamps[i] + 5 * index;
            await setNextBlockTime(futureTimestamp);
            let tx = await essenceFieldFresh.connect(_flow.signer).requestRewards();
            expect(await getBlockTime(tx.blockNumber)).to.be.equal(futureTimestamp);
          }
        }
      });
    });
  });
});
