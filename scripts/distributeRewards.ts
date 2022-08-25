import hre from 'hardhat';
const { getNamedAccounts, deployments } = hre;
const { deploy, execute, read } = deployments;

async function main() {
  const namedAccounts = await getNamedAccounts();
  const deployer = namedAccounts.deployer;

  async function executeFunc(delay: number) {
    console.log('#### Distributing Rewards ####');
    await execute('EssenceAbsorber', { from: deployer, log: true }, 'distributeRewards');
    setTimeout(() => executeFunc(delay), delay);
  }
  executeFunc(11000);
}

main();
