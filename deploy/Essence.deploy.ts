import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Essence', {
    from: deployer,
    log: true,
    args: [],
  });

  await execute('MothoraGame', { from: deployer, log: true }, 'setEssence', (await deployments.get('Essence')).address);
};
export default func;
func.tags = ['Essence', 'Main', 'Test'];
func.dependencies = ['MothoraGame'];
