import { HardhatUserConfig } from "hardhat/types";

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import 'hardhat-typechain'
import 'hardhat-watcher'
import "hardhat-gas-reporter";

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const config: HardhatUserConfig = {
  networks: {
    ganache: {
      url: "http://127.0.0.1:8545",
      chainId: 1337
    },
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      gas: 1000000,
    },
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS]
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 250000000000,
  },
  watcher: {
    test: {
      tasks: [{ command: 'test', params: { testFiles: ['{path}'] } }],
      files: ['./test/**/*'],
      verbose: true,
    },
  },
}

export default config;