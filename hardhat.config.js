require("dotenv").config();
require("hardhat-gas-reporter");
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    ethers: {
      url: process.env.INFURA_URL_ETH,
      accounts: [process.env.PRIVATE_KEY],
    },
    sepolya: {
      url: process.env.INFURA_URL_SEPOLYA,
      accounts: [process.env.PRIVATE_KEY],
    },
    mumbai: {
      url: process.env.MUMBAI_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    bsc: {
      url: process.env.BSC_TESTNET_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    arbOne: {
      url: process.env.ARBITRUM_ONE,
      accounts: [process.env.PRIVATE_KEY],
    },
    arbTest: {
      url: process.env.ARBITRUM_SEPOLIA_TESTNET,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 4,
      },
    },
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  customChains: [
    {
      network: "arbitrum-sepolia",
      chainId: 421614,
      urls: {
        apiURL: "https://sepolia-explorer.arbitrum.io/api",
        browserURL: "https://sepolia-explorer.arbitrum.io/",
      },
    },
  ],
};
