import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('EssenceAbsorber', {
    from: deployer,
    log: true,
    args: [
      (await deployments.get('Essence')).address,
      (await deployments.get('GameItems')).address,
      (await deployments.get('MockPlayer')).address,
      15,
      600,
    ],
  });
};
export default func;
func.tags = ['EssenceAbsorber'];
func.dependencies = ['Essence', 'GameItems', 'MockPlayer'];
