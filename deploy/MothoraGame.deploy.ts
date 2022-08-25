import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MothoraGame', {
    from: deployer,
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: 'init',
          args: [],
        },
      },
    },
  });
};
export default func;
func.tags = ['MothoraGame', 'Main', 'Test'];
func.dependencies = [];
