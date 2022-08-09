import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const ipfs = 'https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/';

  await deploy('GameItems', {
    from: deployer,
    log: true,
    args: [ipfs, (await deployments.get('MockPlayer')).address],
  });
};
export default func;
func.tags = ['GameItems'];
func.dependencies = ['MockPlayer'];
