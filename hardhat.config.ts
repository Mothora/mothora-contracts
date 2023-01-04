import '@openzeppelin/hardhat-upgrades';
import 'dotenv/config';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_TOKEN}`,
      },
      live: false,
      tags: ['test'],
      chainId: 1337,
      deploy: ['deploy'],
    },
    localhost: {
      live: false,
      saveDeployments: true,
      tags: ['test'],
    },
    goerli: {
      url: 'https://eth-goerli.g.alchemy.com/v2/' + process.env.ALCHEMY_TOKEN,
      accounts: {
        mnemonic: process.env.MNEMONIC as string,
      },
      saveDeployments: true,
      deploy: ['deploy'],
      live: true,
    },
    arbitrumGoerli: {
      url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_TOKEN}`,
      accounts: {
        mnemonic: process.env.MNEMONIC as string,
      },
      saveDeployments: true,
      deploy: ['deploy'],
      live: true,
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 100,
    enabled: true,
    coinmarketcap: process.env.COINMARKETCAP_TOKEN,
    excludeContracts: [],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_TOKEN,
  },
  namedAccounts: {
    deployer: 0,
    tester1: 1,
    tester2: 2,
    tester3: 3,
    hacker: 4,
    tester5: 5,
    tester6: 6,
    tester7: 7,
    tester8: 8,
    tester9: 9,
    tester10: 10,
    tester11: 11,
    tester12: 12,
  },
  mocha: {
    timeout: 100000,
  },
  paths: {
    artifacts: 'artifacts',
    cache: 'cache',
    deploy: 'deploy',
    deployments: 'deployments',
    imports: 'imports',
    sources: 'contracts',
    tests: 'test',
  },
};

export default config;
