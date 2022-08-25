import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const ipfs = 'https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/';

  await deploy('Cosmetics', {
    from: deployer,
    log: true,
    args: [ipfs, (await deployments.get('MothoraGame')).address],
  });

  await execute(
    'MothoraGame',
    { from: deployer, log: true },
    'setCosmetics',
    (
      await deployments.get('Cosmetics')
    ).address
  );
};
export default func;
func.tags = ['Cosmetics', 'Main', 'Test'];
func.dependencies = ['MothoraGame'];
