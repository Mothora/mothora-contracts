import { ethers } from 'hardhat';
import { Inputs, Usernames, Users, UsersScore } from './interfaces';

export const usernames: Usernames = ['owner', 'alice', 'bob', 'carol', 'david'];

export const K: UsersScore = {
  alice: 10,
  bob: 20,
  carol: 5,
};

export const D: UsersScore = {
  alice: 4,
  bob: 3,
  carol: 6,
};

export const A: UsersScore = {
  alice: 2,
  bob: 6,
  carol: 1,
};

export const essenceEarned: UsersScore = {
  alice: 100,
  bob: 250,
  carol: 30,
};

export const makeUsers = async (): Promise<Users> => {
  const signers = await ethers.getSigners();
  return usernames.reduce((acc: Users, name: string, index) => {
    return {
      ...acc,
      [name]: signers[index],
    };
  }, {} as Users);
};

export const makeInputs = async (
  usernames: string[],
  K: UsersScore,
  D: UsersScore,
  A: UsersScore,
  essenceEarned: UsersScore
): Promise<Inputs> => {
  const signers = await ethers.getSigners();

  return usernames
    .filter((name: string) => !['owner', 'david'].includes(name))
    .map((name) => {
      const signerIndex = usernames.indexOf(name);
      return {
        address: signers[signerIndex].address,
        K: K[name],
        D: D[name],
        A: A[name],
        essenceEarned: essenceEarned[name],
      };
    });
};
