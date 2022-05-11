import { ContractTransaction, Contract } from 'ethers';
import { ethers } from 'hardhat';
import { MothoraVault } from '../typechain-types';
import { MothoraVault__factory as MothoraVaultFactory } from '../typechain-types';

const waitForTx = async (tx: ContractTransaction) => await tx.wait(1);

export const deployContract = async <ContractType extends Contract>(instance: ContractType): Promise<ContractType> => {
  await waitForTx(instance.deployTransaction);
  return instance;
};

async function main() {
  let vault: MothoraVault;
  const signer = (await ethers.getSigners())[0];
  console.log({ Account: signer.address });

  const vaultFactory = await ethers.getContractFactory('MothoraVault');
  vault = await vaultFactory.attach('0xf0713aaC7FCc56fAD8087F425De2f76143Ac079A');

  // Deploy Player Contract
  await waitForTx(await vault.connect(signer).distributeRewards());
  /*
  async function execute1(delay: number) {
    console.log(1);
    // I use axios like: axios.get('/user?ID=12345').then
    await waitForTx(await vault.connect(signer).distributeRewards());
    setTimeout(() => execute1(delay), delay);
  }
  execute1(2000);
  */
}

main();
