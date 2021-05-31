import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";

const { ARCHIVE_URL } = process.env;

if (!ARCHIVE_URL)
  throw new Error(
    `ARCHIVE_URL env var not set. Copy .env.template to .env and set the env var`
  );

// const accounts = [`0x${process.env.PRIVATE_KEY}`];
const accounts = {
  mnemonic:
    process.env.MNEMONIC ||
    "test test test test test test test test test test test junk",
  // accountsBalance: "990000000000000000000",
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ version: "0.8.3" }],
  },
  networks: {
    hardhat: {
      forking: {
        url: ARCHIVE_URL,
        enabled: process.env.FORKING === "true",
        // blockNumber:
      },
      live: false,
      tags: ["local", "test"],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      gasPrice: 120 * 1000000000,
      chainId: 1,
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      accounts,
      chainId: 56,
      live: true,
    },
    localhost: {
      live: false,
      tags: ["local"],
    },
  },
};

export default config;
