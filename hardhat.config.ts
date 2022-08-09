import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@openzeppelin/hardhat-upgrades';
import '@primitivefi/hardhat-marmite';
import '@typechain/hardhat';
import 'dotenv/config';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import 'solidity-coverage';

const GWEI = 1000 * 1000 * 1000;

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_TOKEN}`,
      },
      live: false,
      saveDeployments: true,
      tags: ['test', 'local'],
      chainId: 1337,
      deploy: ['deploy/mumbai'],
    },
    goerli: {
      url: 'https://eth-goerli.alchemyapi.io/v2/' + process.env.ALCHEMY_TOKEN,
      accounts: {
        mnemonic: process.env.MNEMONIC as string,
      },
      saveDeployments: true,
      gasPrice: 65 * GWEI,
      deploy: ['deploy/goerli'],
      live: true,
    },
    arbitrumRinkeby: {
      url: 'https://arb-rinkeby.g.alchemy.com/v2/' + process.env.ALCHEMY_TOKEN,
      accounts: {
        mnemonic: process.env.MNEMONIC as string,
      },
      saveDeployments: true,
      deploy: ['deploy/arbitrumRinkeby'],
      live: true,
    },
    mumbai: {
      url: 'https://polygon-mumbai.g.alchemy.com/v2/' + process.env.ALCHEMY_TOKEN,
      accounts: {
        mnemonic: process.env.MNEMONIC as string,
      },
      saveDeployments: true,
      gasPrice: 1100000000,
      deploy: ['deploy/mumbai'],
      live: true,
    },
    hardhatevm: {
      hardfork: 'berlin',
      blockGasLimit: 9500000,
      gas: 9500000,
      gasPrice: 8000000000,
      chainId: 31337,
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      url: 'http://localhost:8545',
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.15',
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
    enabled: process.env.REPORT_GAS === 'true',
    excludeContracts: [],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_TOKEN,
  },
  namedAccounts: {
    deployer: 0,
    staker1: 1,
    staker2: 2,
    staker3: 3,
    hacker: 4,
    tester5: 5,
    tester6: 6,
    tester7: 7,
    tester8: 8,
    tester9: 9,
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
