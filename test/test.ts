import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from "chai";
import { ethers } from "hardhat";
import { GameItems } from "../typechain-types";
import { Player } from "../typechain-types";

describe('MockInteractions', async () => {
    let player: Player;
    let gameitems: GameItems;
    let accounts: SignerWithAddress[];

  before(async () => {
    accounts = await ethers.getSigners();

    // Deploy Player Contract
    const PlayerContractFactory = await ethers.getContractFactory("Player");
    player = await PlayerContractFactory.deploy();
    await player.deployed();
    console.log({ "Player contract deployed to": player.address });

    // Deploy GameItems Contract
    const GameItemsFactory = await ethers.getContractFactory("GameItems");
    gameitems = await GameItemsFactory.deploy("https://bafybeiex2io5lawckt4bgjjyhmvfy7yk72s4fmhuxj2rgehwzaa6lderkm.ipfs.dweb.link/", player.address);
    await gameitems.deployed();
    console.log({ "GameItems contract deployed to": gameitems.address });
    await player.setGameItems(gameitems.address);

    /* Create a way to access the GameItems contract functions on PlayerContract without inheriting it (Creates an instance of a contract on anothercontract)
    await player.MintCharacter(0);*/
  });

  describe('Player joins a faction, defects, mints Character, goes on a quest and claims its rewards', async () => {
    
    it('It reverts if the player selects and invalid faction', async () => {
      await expect(player.connect(accounts[0]).JoinFaction(4)).to.be.revertedWith("Please select a valid faction.");
    }); 

    it('Player joins the Vahnu.', async () => {
      await player.connect(accounts[0]).JoinFaction(1);
      expect(await player.connect(accounts[0]).getFaction(accounts[0].address)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(1);
    });

    it('It reverts if the player already has a faction', async () => {
      await expect(player.connect(accounts[0]).JoinFaction(2)).to.be.revertedWith("This player already has a faction.");
    });

    it('Player defects to the Conglomerate', async () => {
      await player.connect(accounts[0]).Defect(2);
      expect(await player.connect(accounts[0]).getFaction(accounts[0].address)).to.be.equal(2);
      expect(await player.totalFactionMembers(2)).to.be.equal(1);
      expect(await player.totalFactionMembers(1)).to.be.equal(0);
    });

    it('It reverts if player has no faction', async () => {
      await expect(player.connect(accounts[1]).MintCharacter()).to.be.revertedWith("This Player has no faction yet.");  
    });

    it('Player mints a character', async () => {
      await player.connect(accounts[0]).MintCharacter()
      expect(await gameitems.balanceOf(accounts[0].address,2)).to.be.equal(1);
    });

    it('It reverts if tries to mint twice.', async () => {
      await expect(player.connect(accounts[0]).MintCharacter()).to.be.revertedWith("The Player can only mint 1 Character of each type.");  
    });

    it('It reverts if player tries to mint directly on GameItems Contract.', async () => {
      await expect(gameitems.connect(accounts[0]).mintCharacter(accounts[0].address,2)).to.be.reverted;  
    });

    it('It reverts if player does not have a character of its faction.', async () => {
      await expect(player.connect(accounts[1]).GoOnQuest()).to.be.revertedWith("The Player does not own a character of this faction.");  
    });

    it('Player goes on a Quest', async () => {
      await player.connect(accounts[0]).GoOnQuest();
    });

    it('It reverts if player is already on a quest', async () => {
      await expect(player.connect(accounts[0]).GoOnQuest()).to.be.revertedWith("The Player is already on a quest.");
    });

    it('It if lock time has passed but Player has not claimed its rewards', async () => {
      await ethers.provider.send("evm_increaseTime", [601]) // add 601 seconds
      await expect(player.connect(accounts[0]).GoOnQuest()).to.be.revertedWith("The Player has not claimed its rewards.");
    });

    it('It reverts if Player tries to claim rewards without doing the quest', async () => {
      await expect(player.connect(accounts[1]).ClaimQuestRewards()).to.be.revertedWith("The Player has to go on a quest first to claim its rewards.");
    });

    it('It reverts if Player tries to claim rewards while doing the quest', async () => {
      await player.connect(accounts[1]).JoinFaction(3);
      await player.connect(accounts[1]).MintCharacter();
      await player.connect(accounts[1]).GoOnQuest();
      await expect(player.connect(accounts[1]).ClaimQuestRewards()).to.be.revertedWith("The Player is still on a quest.");
    });

    it('The Player Claims the rewards', async () => {
      await player.connect(accounts[0]).ClaimQuestRewards();
      expect(await player.connect(accounts[0]).getMultiplier(accounts[0].address)).to.be.least(0);
      expect(await gameitems.balanceOf(accounts[0].address,0)).to.be.least(0);
    });

  });
});