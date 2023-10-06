const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PokerToken Deploy", function () {
  async function deployOneYearLockFixture() {
    const [owner, otherAccount1] = await ethers.getSigners();

    const PineappleToken = await ethers.getContractFactory(
      "PineapplePokerToken"
    );
    const pokerToken = await PineappleToken.deploy(ethers.parseEther("100"));

    await pokerToken.transfer(otherAccount1.address, ethers.parseEther("10"));

    return {
      owner,
      pokerToken,
      otherAccount1,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { owner, pokerToken } = await loadFixture(deployOneYearLockFixture);

      expect(await pokerToken.balanceOf(owner.address)).to.equal(
        ethers.parseEther("90")
      );
    });
  });
});
