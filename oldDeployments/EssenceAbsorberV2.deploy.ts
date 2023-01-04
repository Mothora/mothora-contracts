import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const newOwner = '0x3D210e741cDeDeA81efCd9711Ce7ef7FEe45684B';

  const artifact = '0x96F791C0C11bAeE97526D5a9674494805aFBEc1c';
  const artifactMetadataStore = '0x253dC801B38C79CcBFcECFDB2f5Bb5277c227537';

  await deploy('EssenceAbsorberV2', {
    from: deployer,
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: 'init',
          args: [(await deployments.get('Essence')).address, (await deployments.get('EssenceField')).address],
        },
      },
    },
  });

  if ((await read('EssenceAbsorberV2', 'artifact')) != artifact) {
    await execute('EssenceAbsorberV2', { from: deployer, log: true }, 'setArtifact', artifact);
  }

  if ((await read('EssenceAbsorberV2', 'artifactMetadataStore')) != artifactMetadataStore) {
    await execute(
      'EssenceAbsorberV2',
      { from: deployer, log: true },
      'setArtifactMetadataStore',
      artifactMetadataStore
    );
  }

  const FACTION_ABSORBER_ADMIN_ROLE = await read('EssenceAbsorberV2', 'FACTION_ABSORBER_ADMIN_ROLE');

  if (!(await read('EssenceAbsorberV2', 'hasRole', FACTION_ABSORBER_ADMIN_ROLE, newOwner))) {
    await execute(
      'EssenceAbsorberV2',
      { from: deployer, log: true },
      'grantRole',
      FACTION_ABSORBER_ADMIN_ROLE,
      newOwner
    );
  }

  // setup EssenceField stream
  // if(streamConfig.totalRewards.eq(0)) {
  //   const totalRewards = ethers.utils.parseEther('10000');
  //   let ms = Date.now();
  //   const startTimestamp = Math.floor(ms / 1000 + 20);
  //   const endTimestamp = startTimestamp + 60 * 60 * 24 * 7;
  //   const callback = false;
  //
  //   await execute(
  //     'EssenceField',
  //     { from: deployer, log: true },
  //     'addStream',
  //     essenceAbsorber.address,
  //     totalRewards,
  //     startTimestamp,
  //     endTimestamp,
  //     callback
  //   );
  // }

  await execute(
    'MothoraGame',
    { from: deployer, log: true },
    'setEssenceAbsorber',
    (
      await deployments.get('EssenceAbsorberV2')
    ).address
  );
};
export default func;
func.tags = ['EssenceAbsorberV2'];
func.dependencies = ['Essence', 'EssenceField', 'MothoraGame'];
