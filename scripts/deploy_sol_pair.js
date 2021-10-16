const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contract with the account:", deployer.address);
  const BinaryOptions = await hre.ethers.getContractFactory("BinaryOptions");
  const hardhatBinaryOptions = await BinaryOptions.deploy(
    "0xfdd972446c5bcf4c3c65817462de1a0b70764eeb",
    "1635613200",
    "170",
    "1635613200",
    "0x4ffC43a60e009B551865A93d232E33Fce9f01507",
    "sol/usd"
  );

  console.log("BinaryOptions address:", hardhatBinaryOptions.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
