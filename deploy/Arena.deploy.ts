import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  // how to with foundry :https://github.com/jordaniza/OZ-Upgradeable-Foundry
  await deploy('Arena', {
    from: deployer,
    log: true,
    args: ['https://api.mothora.xyz/endpoint'],
  });
};
export default func;
func.tags = ['Test', 'Arena'];
func.dependencies = [];
