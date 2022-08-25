import pinataSDK, { PinataPinByHashResponse, PinataPinResponse } from '@pinata/sdk';
import { IBlueprint } from './testUtils';
import * as dotenv from 'dotenv';

dotenv.config();

export type IPinataFileMetadata = Record<string, string | number | null>;

export class PinataUtils {
  static async pinWithPinata(data: ArrayBuffer | Buffer): Promise<PinataPinResponse> {
    const pinata = pinataSDK(process.env.PINATA_API_KEY as string, process.env.PINATA_API_SECRET as string);
    return await pinata.pinFileToIPFS(data);
  }

  static async pinByHash(hash: string): Promise<PinataPinByHashResponse> {
    const pinata = pinataSDK(process.env.PINATA_API_KEY as string, process.env.PINATA_API_SECRET as string);
    return await pinata.pinByHash(hash);
  }

  static async pinJsonWithPinata(metadata: IBlueprint): Promise<PinataPinResponse> {
    const pinata = pinataSDK(process.env.PINATA_API_KEY as string, process.env.PINATA_API_SECRET as string);
    const options = {
      pinataMetadata: {
        name: metadata.uuid,
      },
      pinataOptions: {
        cidVersion: 1 as 1,
      },
    };
    return await pinata.pinJSONToIPFS(metadata, options);
  }
}
