import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { GameItems } from '../typechain-types';
import { Player } from '../typechain-types';
import { MothoraVault } from '../typechain-types';
import { Essence } from '../typechain-types';
import { BigNumber } from 'bignumber.js';

async function main() {
  let player: Player;
  let gameitems: GameItems;
  let vault: MothoraVault;
  let token: Essence;

  console.log({ 'Account': (await ethers.getSigners())[0].address });
  
  // Deploy Player Contract
  const PlayerContractFactory = await ethers.getContractFactory('Player');
  player = await PlayerContractFactory.deploy();
  await player.deployed();
  console.log({ 'Player contract deployed to': player.address });

  // Deploy GameItems Contract
  const GameItemsFactory = await ethers.getContractFactory('GameItems');
  gameitems = await GameItemsFactory.deploy(
    'https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/',
    player.address
  );
  await gameitems.deployed();
  console.log({ 'GameItems contract deployed to': gameitems.address });
  await player.setGameItems(gameitems.address);

  // Deploy Essence Contract
  const EssenceFactory = await ethers.getContractFactory('Essence');
  token = await EssenceFactory.deploy();
  await token.deployed();
  console.log({ 'Essence contract deployed to': token.address });

  // Deploy MothoraVault Contract
  const MothoraVaultFactory = await ethers.getContractFactory('MothoraVault');

  vault = await MothoraVaultFactory.deploy(token.address, gameitems.address, player.address, 15, 600);
  await vault.deployed();
  console.log({ 'MothoraVault contract deployed to': vault.address });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });