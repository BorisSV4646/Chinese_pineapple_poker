const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("PineapplePoker", function () {
  async function deployOneYearLockFixture() {
    const [owner] = await ethers.getSigners();
    const PineapplePoker = await ethers.getContractFactory("PineapplePoker");
    const poker = await PineapplePoker.deploy();

    console.log(await poker.getAddress());

    return { poker, owner };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { poker, owner } = await loadFixture(deployOneYearLockFixture);

      expect(await poker.owner()).to.equal(owner.address);
    });
  });
});
