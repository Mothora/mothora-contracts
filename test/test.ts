import { expect } from "chai";
import { ethers } from "hardhat";
import { CharacterNFT } from "../typechain-types";

describe("Function: mintCharacter", function () {
    let contract: CharacterNFT;

    beforeEach(async () => {
        const CharacterFactory = await ethers.getContractFactory("CharacterNFT");
        contract = await CharacterFactory.deploy();
        await contract.deployed();
    });

    it("Initial state", async function () {
        console.log({Contract_Address: contract.address});
    });

});