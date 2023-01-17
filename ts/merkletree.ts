import ethers from 'ethers';
import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';
import { makeInputs, usernames, K, D, A, essenceEarned } from './data';
import { Leaves, MerkleTreeData, Input, Inputs, Proofs } from './interfaces';

const makeLeaves = (users: Inputs): Leaves => {
  const leaves = users.reduce((acc: Leaves, x: Input) => {
    const leaf = ethers.utils.solidityKeccak256(
      ['address', 'uint256', 'uint256', 'uint256', 'uint256'],
      [x.address, x.K, x.D, x.A, x.essenceEarned]
    );
    return {
      ...acc,
      [x.address]: leaf,
    };
  }, {} as Leaves);

  return leaves;
};

const makeProofs = (merkleTree: MerkleTree, users: Inputs, leaves: Leaves) => {
  return users.reduce((acc: Proofs, user: Input) => {
    const { address } = user;
    const leaf = leaves[address];
    if (!leaf) throw new Error(`Leaf not found: ${address}`);
    const proof = merkleTree.getHexProof(leaf);
    return {
      ...acc,
      [address]: proof,
    };
  }, {} as Proofs);
};

export const makeMerkleTree = async (): Promise<MerkleTreeData> => {
  const inputs = await makeInputs(usernames, K, D, A, essenceEarned);

  const leaves = makeLeaves(inputs);

  const leavesValue = Object.values(leaves);

  const merkleTree = new MerkleTree(leavesValue, keccak256, { sort: true });

  const root = merkleTree.getHexRoot();

  const proofs = makeProofs(merkleTree, inputs, leaves);

  return {
    root,
    proofs,
  };
};
