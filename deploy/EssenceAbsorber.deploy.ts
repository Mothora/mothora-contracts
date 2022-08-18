import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('EssenceAbsorber', {
    from: deployer,
    log: true,
    args: [(await deployments.get('MothoraGame')).address, 15, 600],
  });
  if ((await read('MothoraGame', 'getEssenceAbsorber')) === ethers.constants.AddressZero) {
    await execute(
      'MothoraGame',
      { from: deployer, log: true },
      'setEssenceAbsorber',
      (
        await deployments.get('EssenceAbsorber')
      ).address
    );
  }
};
export default func;
func.tags = ['EssenceAbsorber', 'Test'];
func.dependencies = ['MothoraGame'];
