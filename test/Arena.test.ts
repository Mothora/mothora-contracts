import { expect } from 'chai';
import hre from 'hardhat';
import { makeMerkleTree } from '../utils/merkletree';
import { makeUsers } from '../utils/data';
import { Arena } from '../typechain-types';
const { ethers, deployments } = hre;

describe('Arena', function () {
  let arena: Arena;

  before(async function () {
    this.merkleTreeData = await makeMerkleTree();
    this.users = await makeUsers();
    await deployments.fixture(['Arena']);

    const Arena = await deployments.get('Arena');
    arena = new ethers.Contract(Arena.address, Arena.abi, this.users.owner) as Arena;
  });

  describe('endMatch', function () {
    it('Should revert if it tries to end a match with no merkle root', async function () {
      await expect(
        arena
          .connect(this.users.owner)
          .endMatch(1, '0x0000000000000000000000000000000000000000000000000000000000000000')
      ).to.be.revertedWithCustomError(arena, 'NULL_MERKLE_ROOT');
    });
    it('Ends a match', async function () {
      const tx = arena.connect(this.users.owner).endMatch(1, this.merkleTreeData.root);

      expect(tx).to.emit(arena, 'ArenaSessionPostgame').withArgs('matchId', 1, 'merkleRoot', this.merkleTreeData.root);
      await tx;
    });

    it('Tries to end same match', async function () {
      await expect(arena.connect(this.users.owner).endMatch(1, this.merkleTreeData.root)).to.be.revertedWithCustomError(
        arena,
        'MATCH_ALREADY_POSTED'
      );
    });

    it('Verifies a valid player KDA', async function () {
      const valid = await arena
        .connect(this.users.bob)
        .checkValidityOfPlayerData(
          1,
          this.users.bob.getAddress(),
          20,
          3,
          6,
          this.merkleTreeData.proofs[await this.users.bob.getAddress()]
        );

      expect(valid).to.equal(true);
    });

    it('Returns false on invalid player KDA', async function () {
      await expect(
        arena
          .connect(this.users.bob)
          .checkValidityOfPlayerData(
            1,
            this.users.bob.getAddress(),
            19,
            3,
            6,
            this.merkleTreeData.proofs[await this.users.bob.getAddress()]
          )
      ).to.be.revertedWithCustomError(arena, 'INVALID_PROOF');
    });
  });
});
