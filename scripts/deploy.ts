import { expect } from "chai";
import { ethers } from "hardhat";
import { CharacterNFT2 } from "../typechain-types";

async function main() {
    let character: CharacterNFT2;

    const CharacterFactory = await ethers.getContractFactory("CharacterNFT2");
    character = await CharacterFactory.deploy();
    await character.deployed();
    
    
    
    console.log({ Character: character.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });