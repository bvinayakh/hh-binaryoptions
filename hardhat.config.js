require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const {
  mnemonic,
  projectId,
  etherscan,
  aprojectId,
  privatekey,
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
  networks: {
    rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/" + aprojectId,
      accounts: ["0x" + privatekey],
    },
  },
  etherscan: {
    apiKey: etherscan,
  },
};
