import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const subscriptionId = 4948;

  await deploy('MockPlayer', {
    from: deployer,
    log: true,
    args: [subscriptionId],
  });
};
export default func;
func.tags = ['MockPlayer'];
