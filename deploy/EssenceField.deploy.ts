import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  // this address could be the multi-sig address that will own the Essencefield
  const newOwner = '0x3D210e741cDeDeA81efCd9711Ce7ef7FEe45684B';

  await deploy('EssenceField', {
    from: deployer,
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: 'init',
          args: [(await deployments.get('Essence')).address],
        },
      },
    },
  });

  const ESSENCE_FIELD_CREATOR_ROLE = await read('EssenceField', 'ESSENCE_FIELD_CREATOR_ROLE');

  if (!(await read('EssenceField', 'hasRole', ESSENCE_FIELD_CREATOR_ROLE, newOwner))) {
    await execute('EssenceField', { from: deployer, log: true }, 'grantRole', ESSENCE_FIELD_CREATOR_ROLE, newOwner);
  }

  await execute(
    'MothoraGame',
    { from: deployer, log: true },
    'setEssenceField',
    (
      await deployments.get('EssenceField')
    ).address
  );
};
export default func;
func.tags = ['EssenceField'];
func.dependencies = ['Essence', 'MothoraGame'];
