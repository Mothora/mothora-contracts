import { PinataUtils } from './pinata-utils';
import { CID } from 'multiformats/cid';
import { isHexString, hexlify } from '@ethersproject/bytes';
import { BytesLike } from 'ethers';
import { v4 as uuidv4 } from 'uuid';

export interface IBlueprint {
  name: string;
  description: string;
  image: string;
}

// Metadata that is pinned to IPFS
export const artifactBlueprints: IBlueprint[] = [
  {
    name: 'Artifacts',
    description: 'Incredibly complex technology.',
    image: '#https://ipfs.io/ipfs/QmZ8gXFWbMNjimfLmiSX1VDPtzDdCfLEqG56H3CFGqw9wg',
  },
];

// Metadata that is pinned to IPFS
export const factionSkinsBlueprints: IBlueprint[] = [
  {
    name: 'Thoroks',
    description: "Nature's Protector",
    image: 'https://ipfs.io/ipfs/QmYDhFLFR3qBTiopVjqcd9iDAD99cQYRVj3SzEpd6SRVnW',
  },
  {
    name: 'Conglomerate',
    description: 'Profit Seeker',
    image: 'https://ipfs.io/ipfs/QmRsYEMt8GJLjTxXubPCBHimk1fP2LNLdRb6YAq4hSZ4zt',
  },
  {
    name: 'Disciple of Cataclysm',
    description: 'Pursuer of the Dark Knowledge',
    image: 'https://ipfs.io/ipfs/QmcY2Ba4aG75w1pbLGXvKMtrArGFsB7b44XH1WoTGRhne2',
  },
];

// returns the base16 cid link to save in the NFT
// these were generated previously and hardcoded onto the NFTs
export const pin_blueprint_and_return_base16cid = async (blueprint: IBlueprint): Promise<BytesLike> => {
  // pin to pinata
  const jsonResponse = await PinataUtils.pinJsonWithPinata(blueprint);
  // convert v1 CID to its base16 representation and save
  const base16_cid = CID.parse(jsonResponse.IpfsHash).bytes;
  const base16_core: BytesLike = hexlify(base16_cid);
  return base16_core;
};
