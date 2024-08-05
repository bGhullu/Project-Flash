import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
dotenv.config();

const mainnet_url=process.env.MAINNET_URL!;

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks:{
    hardhat:{
      forking:{
        url:mainnet_url,
        blockNumber:239528625
      }
    }
  }
};

export default config;
