import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from "chai";
import { ethers } from "hardhat";
import { GameItems } from "../typechain-types";
import { PlayerContract } from "../typechain-types";

describe('MockInteractions', async () => {
    let player: PlayerContract;
    let gameitems: GameItems;
    let accounts: SignerWithAddress[];

  before(async () => {
    accounts = await ethers.getSigners();

    // Deploy Player Contract
    const PlayerContractFactory = await ethers.getContractFactory("PlayerContract");
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

  describe('Player joins a faction, defects, mints Character, goes on a Quest.', async () => {
    
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

    


  });
});