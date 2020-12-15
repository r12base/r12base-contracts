const HDWalletProvider = require("@truffle/hdwallet-provider");
module.exports = {

  networks: {
    LinkDev: {
      provider: () => new HDWalletProvider(),
      network_id: 5,
      gas: 5500000,
      timeoutBlocks: 8000,
      skipDryRun: true
    }
  },
  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.12"
    }
  }
};
