import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();
  const subscriptionId = 4948;
  await deploy('MockArena', {
    from: deployer,
    log: true,
    args: [subscriptionId, (await deployments.get('MothoraGame')).address],
  });
  await execute('MothoraGame', { from: deployer, log: true }, 'setArena', (await deployments.get('MockArena')).address);
};
export default func;
func.tags = ['MockArena', 'Test'];
func.dependencies = ['MothoraGame'];
