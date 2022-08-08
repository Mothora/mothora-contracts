import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const essenceMumbai = '0x539bdE0d7Dbd336b79148AA742883198BBF60342';
  const newOwner = '0x3D210e741cDeDeA81efCd9711Ce7ef7FEe45684B';

  const artifact = '0x96F791C0C11bAeE97526D5a9674494805aFBEc1c';
  const artifactMetadataStore = '0x253dC801B38C79CcBFcECFDB2f5Bb5277c227537';

  await deploy('EssenceAbsorber', {
    from: deployer,
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: 'init',
          args: [essenceMumbai, (await deployments.get('EssenceField')).address],
        },
      },
    },
  });

  if ((await read('EssenceAbsorber', 'artifact')) != artifact) {
    await execute('EssenceAbsorber', { from: deployer, log: true }, 'setArtifact', artifact);
  }

  if ((await read('EssenceAbsorber', 'artifactMetadataStore')) != artifactMetadataStore) {
    await execute('EssenceAbsorber', { from: deployer, log: true }, 'setArtifactMetadataStore', artifactMetadataStore);
  }

  const FACTION_ABSORBER_ADMIN_ROLE = await read('EssenceAbsorber', 'FACTION_ABSORBER_ADMIN_ROLE');

  if (!(await read('EssenceAbsorber', 'hasRole', FACTION_ABSORBER_ADMIN_ROLE, newOwner))) {
    await execute('EssenceAbsorber', { from: deployer, log: true }, 'grantRole', FACTION_ABSORBER_ADMIN_ROLE, newOwner);
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
};
export default func;
func.tags = ['EssenceAbsorber'];
func.dependencies = ['EssenceField'];
