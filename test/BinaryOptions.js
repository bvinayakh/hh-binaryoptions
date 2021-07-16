const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BinaryOptions", function () {
  it("Should display option expiry timestamp", async function () {
    const [owner] = await ethers.getSigners();
    const BinaryOptions = await ethers.getContractFactory("BinaryOptions");
    const hardhatBinaryOptions = await BinaryOptions.deploy(
      "0xC73b99833423630C087D0C50C1372db23360bE69",
      "1627187473",
      "3000",
      "1626323473",
      "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e"
    );
    describe("Deployment", function () {
      it("Validate BinaryOptions Owner", async function () {
        expect(await hardhatBinaryOptions.getOwner()).to.eq(owner.address);
      });
    });
  });
});
