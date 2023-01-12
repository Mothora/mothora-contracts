import { Signer } from 'ethers';

export type Users = Record<string, Signer>;

export type UsersScore = Record<string, number>;

export type Usernames = string[];

export interface Input {
  address: string;
  K?: number;
  D?: number;
  A?: number;
  essenceEarned?: number;
}
export type Inputs = Input[];

export type Leaves = Record<string, string>;

export type Proofs = Record<string, string[]>;

export interface MerkleTreeData {
  root: string;
  proofs: Proofs;
}
