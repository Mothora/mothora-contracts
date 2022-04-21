import { expect } from "chai";
import { ethers } from "hardhat";
import { CharacterNFT } from "../typechain-types";

async function main() {
    let character: CharacterNFT;

    const CharacterFactory = await ethers.getContractFactory("CharacterNFT");
    character = await CharacterFactory.deploy();
    await character.deployed();
    console.log({ "Character contract deployed to": character.address });

    // await character.mintNFT("0xaa2Cd8976412FC5303788Df013B8F0aD6b05D55a", "ipfs://QmYueiuRNmL4MiA2GwtVMm6ZagknXnSpQnB3z2gWbz36hP");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });