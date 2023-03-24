import { artifactBlueprints, pin_blueprint_and_return_base16cid } from './pinata/nftMetadata';

import { ethers } from 'ethers';

const encoder = ethers.utils.defaultAbiCoder;

async function main() {
  const cid = await pin_blueprint_and_return_base16cid(artifactBlueprints[0]);
  process.stdout.write(encoder.encode(['string'], [cid]));
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
