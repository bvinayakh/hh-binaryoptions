const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contract with the account:", deployer.address);
  const BinaryOptions = await hre.ethers.getContractFactory("BinaryOptions");
  const hardhatBinaryOptions = await BinaryOptions.deploy(
    "0xf15e6Aa6b09E25dbCC9660Ff775BC568E31fDf0b",
    "1629497482",
    "3000",
    "1629497482",
    "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
    "eth/usd"
  );

  console.log("BinaryOptions address:", hardhatBinaryOptions.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
