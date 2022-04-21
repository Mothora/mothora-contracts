import { expect } from "chai";
import { ethers } from "hardhat";
import { GameItems } from "../typechain-types";

async function main() {
    let gameitems: GameItems;

    const GameItemsFactory = await ethers.getContractFactory("GameItems");
    gameitems = await GameItemsFactory.deploy();
    await gameitems.deployed();
    console.log({ "GameItems contract deployed to": gameitems.address });

    await gameitems.setTokenUri(3,"https://bafybeihul6zsmbzyrgmjth3ynkmchepyvyhcwecn2yxc57ppqgpvr35zsq.ipfs.dweb.link/3.json")
    await gameitems.mint(3, 1);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });