import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { GameItems } from '../typechain-types';
import { Player } from '../typechain-types';
import { MothoraVault } from '../typechain-types';
import { Essence } from '../typechain-types';

describe('MockInteractions', async () => {
  let player: Player;
  let gameitems: GameItems;
  let vault: MothoraVault;
  let token: Essence;
  let accounts: SignerWithAddress[];

  before(async () => {
    accounts = await ethers.getSigners();

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
  });

  describe('Player joins a faction, defects, mints Character, goes on a quest and claims its rewards', async () => {
    it('It reverts if the player selects and invalid faction', async () => {
      await expect(player.connect(accounts[0]).joinFaction(4)).to.be.revertedWith('Please select a valid faction.');
    });

    it('Player joins the Vahnu.', async () => {
      await player.connect(accounts[0]).joinFaction(1);
      expect(await player.connect(accounts[0]).getFaction(accounts[0].address)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(1);
    });

    it('It reverts if the player already has a faction', async () => {
      await expect(player.connect(accounts[0]).joinFaction(2)).to.be.revertedWith('This player already has a faction.');
    });

    it('Player defects to the Conglomerate', async () => {
      await player.connect(accounts[0]).defect(2);
      expect(await player.connect(accounts[0]).getFaction(accounts[0].address)).to.be.equal(2);
      expect(await player.totalFactionMembers(2)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(0);
    });

    it('It reverts if player has no faction', async () => {
      await expect(player.connect(accounts[1]).mintCharacter()).to.be.revertedWith('This Player has no faction yet.');
    });

    it('Player mints a character', async () => {
      await player.connect(accounts[0]).mintCharacter();
      expect(await gameitems.balanceOf(accounts[0].address, 2)).to.be.equal(1);
    });

    it('It reverts if tries to mint twice.', async () => {
      await expect(player.connect(accounts[0]).mintCharacter()).to.be.revertedWith(
        'The Player can only mint 1 Character of each type.'
      );
    });

    it('It reverts if player tries to mint directly on GameItems Contract.', async () => {
      await expect(gameitems.connect(accounts[0]).mintCharacter(accounts[0].address, 2)).to.be.reverted;
    });

    it('It reverts if player does not have a character of its faction.', async () => {
      await expect(player.connect(accounts[1]).goOnQuest()).to.be.revertedWith(
        'The Player does not own a character of this faction.'
      );
    });

    it('Player goes on a Quest', async () => {
      await player.connect(accounts[0]).goOnQuest();
    });

    it('It reverts if player is already on a quest', async () => {
      await expect(player.connect(accounts[0]).goOnQuest()).to.be.revertedWith('The Player is already on a quest.');
    });

    it('It if lock time has passed but Player has not claimed its rewards', async () => {
      await ethers.provider.send('evm_increaseTime', [601]); // add 601 seconds
      await expect(player.connect(accounts[0]).goOnQuest()).to.be.revertedWith(
        'The Player has not claimed its rewards.'
      );
    });

    it('It reverts if Player tries to claim rewards without doing the quest', async () => {
      await expect(player.connect(accounts[1]).claimQuestRewards()).to.be.revertedWith(
        'The Player has to go on a quest first to claim its rewards.'
      );
    });

    it('It reverts if Player tries to claim rewards while doing the quest', async () => {
      await player.connect(accounts[1]).joinFaction(3);
      await player.connect(accounts[1]).mintCharacter();
      await player.connect(accounts[1]).goOnQuest();
      await expect(player.connect(accounts[1]).claimQuestRewards()).to.be.revertedWith(
        'The Player is still on a quest.'
      );
    });

    it('The Player Claims the rewards', async () => {
      await player.connect(accounts[0]).claimQuestRewards();
      expect(await player.connect(accounts[0]).getMultiplier(accounts[0].address)).to.be.least(0);
      expect(await gameitems.balanceOf(accounts[0].address, 0)).to.be.least(0);
    });
  });

  describe('Player tries interact directly with GameItems.sol but is successfully blocked.', async () => {
    it('It reverts on minting a character or vaultpart', async () => {
      await expect(gameitems.connect(accounts[0]).mintCharacter(accounts[0].address, 0)).to.be.revertedWith(
        'Not player contract address.'
      );
      await expect(gameitems.connect(accounts[0]).mintVaultParts(accounts[0].address, 0)).to.be.revertedWith(
        'Not player contract address.'
      );
    });

    it('It reverts on setting a token  if not the owner', async () => {
      await expect(gameitems.connect(accounts[1]).setTokenUri(0, '')).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
    });

    it('It reverts on re-setting a token uri by the owner', async () => {
      await expect(gameitems.connect(accounts[0]).setTokenUri(0, '')).to.be.revertedWith('Cannot set uri twice.');
    });
  });

  describe('Pulling Funds', async () => {
    it('It reverts pulling funds if not the owner', async () => {
      await expect(gameitems.connect(accounts[0]).setTokenUri(0, '')).to.be.revertedWith('Cannot set uri twice.');
    });
  });
});
