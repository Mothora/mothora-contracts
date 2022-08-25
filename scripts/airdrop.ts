import hre from 'hardhat';
const { ethers, getNamedAccounts, deployments } = hre;
const { deploy, execute, read } = deployments;

async function main() {
  const namedAccounts = await getNamedAccounts();
  const deployer = namedAccounts.deployer;

  const wallets = [
    '0x16209477c33400Ab214ac83b22e4A75D4B48225C',
    '0xFe51dd3E9886Dd3e5F3Edb33415AE4eAD95BFEA1',
    '0x5b83E4A643AA4F52e5D34da909aC8d3842A17252',
  ];

  for (let i = 0; i < wallets.length; i++) {
    await execute('Essence', { from: deployer, log: true }, 'transfer', wallets[i], '5000');
  }

  console.log('Tokens airdroped');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
