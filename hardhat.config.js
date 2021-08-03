require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const {
  metamask_mnemonic,
  projectId,
  etherscan,
  aprojectId,
  privatekey_0x0CcA67351d8384800836B937Ad61C4Ac853b744C,
  privatekey_0xa24d23355Bc1435B8590368500a68C63566D174A,
  privatekey_0x48644e352c7b8df27008e0523af97AA971ee6E2D,
  privatekey_0xfb7246b3A7094a682edb80ee157A27a5CA0Fb18F,
  ganache_mnemonic,
  ganache_privatekey,
} = require("./secrets.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  defaultNetwork: "ganache",
  networks: {
    rinkeby_0x0CcA67351d8384800836B937Ad61C4Ac853b744C: {
      url: "https://rinkeby.infura.io/v3/" + projectId,
      accounts: ["0x" + privatekey_0x0CcA67351d8384800836B937Ad61C4Ac853b744C],
    },
    rinkeby_0xa24d23355Bc1435B8590368500a68C63566D174A: {
      url: "https://rinkeby.infura.io/v3/" + projectId,
      accounts: ["0x" + privatekey_0xa24d23355Bc1435B8590368500a68C63566D174A],
    },
    rinkeby_0x48644e352c7b8df27008e0523af97AA971ee6E2D: {
      url: "https://rinkeby.infura.io/v3/" + projectId,
      accounts: ["0x" + privatekey_0x48644e352c7b8df27008e0523af97AA971ee6E2D],
    },
    rinkeby_0xfb7246b3A7094a682edb80ee157A27a5CA0Fb18F: {
      url: "https://rinkeby.infura.io/v3/" + projectId,
      accounts: ["0x" + privatekey_0xfb7246b3A7094a682edb80ee157A27a5CA0Fb18F],
    },
    ganache: {
      url: "http://127.0.0.1:8545",
      gasLimit: 6000000000,
      defaultBalanceEther: 10,
    },
    hardhat: {
      forking: {
        url: "https://eth-rinkeby.alchemyapi.io/v2/" + aprojectId,
      },
    },
  },
  etherscan: {
    apiKey: etherscan,
  },
};
