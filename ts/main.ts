import { artifactBlueprints, pin_blueprint_and_return_base16cid } from './pinata/nftMetadata';
import * as fs from 'fs';

async function main() {
  const cid = await pin_blueprint_and_return_base16cid(artifactBlueprints[0]);
  createFile(String(cid));
}

function createFile(content: string) {
  fs.writeFile('cid.txt', content, function (err: any) {
    if (err) {
      return console.error(err);
    }
    console.log('File created!');
  });
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
