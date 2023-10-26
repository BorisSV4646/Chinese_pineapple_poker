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
        runs: 1000,
      },
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    gasPriceApi:
      "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
    token: "ETH",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
