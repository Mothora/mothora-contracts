import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Essence', {
    from: deployer,
    log: true,
    args: [],
  });
};
export default func;
func.tags = ['Essence'];
func.dependencies = [];
