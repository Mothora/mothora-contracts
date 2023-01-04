import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();
  const subscriptionId = 1498;

  await deploy('Arena', {
    from: deployer,
    log: true,
    args: [subscriptionId, (await deployments.get('MothoraGame')).address],
  });
  await execute('MothoraGame', { from: deployer, log: true }, 'setArena', (await deployments.get('Arena')).address);
};
export default func;
func.tags = ['Arena', 'Main'];
func.dependencies = ['MothoraGame'];
