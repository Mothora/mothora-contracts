import { expect } from "chai";
import { ethers } from "hardhat";
import { GameItems } from "../typechain-types";
import { PlayerContract } from "../typechain-types";

async function main() {
    let player: PlayerContract;
    let gameitems: GameItems;

    // Deploy Player Contract
    const PlayerContractFactory = await ethers.getContractFactory("PlayerContract");
    player = await PlayerContractFactory.deploy();
    await player.deployed();
    console.log({ "Player contract deployed to": player.address });

    // Deploy GameItems Contract
    const GameItemsFactory = await ethers.getContractFactory("GameItems");
    gameitems = await GameItemsFactory.deploy("https://bafybeif257x7rsniq477knwmrl7cx57zqu2jmo2tjm7re5mb4hlxrypjki.ipfs.dweb.link/", player.address);
    await gameitems.deployed();
    console.log({ "GameItems contract deployed to": gameitems.address });

    // Create a way to access the GameItems contract functions on PlayerContract without inheriting it (Creates an instance of a contract on anothercontract)
    await player.setGameItems(gameitems.address);

    await player.MintCharacter(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });