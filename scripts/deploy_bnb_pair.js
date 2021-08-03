const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contract with the account:", deployer.address);
  const BinaryOptions = await hre.ethers.getContractFactory("BinaryOptions");
  const hardhatBinaryOptions = await BinaryOptions.deploy(
    "0xefBa2d2a4fdAc112E47152f48D0Dee90E26A9E3C",
    "1629497482",
    "200",
    "1629497482",
    "0xcf0f51ca2cDAecb464eeE4227f5295F2384F84ED",
    "bnb/usd"
  );

  console.log("BinaryOptions address:", hardhatBinaryOptions.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
