import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  // Requires a new deployment of Essence
  const essenceMumbai = '0xA0A89db1C899c49F98E6326b764BAFcf167fC2CE';

  // this address could be the multi-sig address that will own the Essencefield
  const newOwner = '0x3D210e741cDeDeA81efCd9711Ce7ef7FEe45684B';

  await deploy('EssenceField', {
    from: deployer,
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: 'init',
          args: [essenceMumbai],
        },
      },
    },
  });

  const ESSENCE_FIELD_CREATOR_ROLE = await read('EssenceField', 'ESSENCE_FIELD_CREATOR_ROLE');

  if (!(await read('EssenceField', 'hasRole', ESSENCE_FIELD_CREATOR_ROLE, newOwner))) {
    await execute('EssenceField', { from: deployer, log: true }, 'grantRole', ESSENCE_FIELD_CREATOR_ROLE, newOwner);
  }
};
export default func;
func.tags = ['EssenceField'];
