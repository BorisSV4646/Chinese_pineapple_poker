const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("PineapplePokerProxy Deploy", function () {
  async function deployOneYearLockFixture() {
    const [owner, otherAccount1] = await ethers.getSigners();

    const PineapplePoker = await ethers.getContractFactory(
      "PineapplePokerProxy"
    );
    const poker = await upgrades.deployProxy(PineapplePoker, [], {
      initializer: "initialize",
    });

    const PineappleToken = await ethers.getContractFactory(
      "PineapplePokerToken"
    );
    const pokerToken = await PineappleToken.deploy(ethers.parseEther("100"));

    const proxyAddress = await poker.getAddress();

    return {
      poker,
      proxyAddress,
      owner,
      otherAccount1,
      pokerToken,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { poker, proxyAddress, pokerToken } = await loadFixture(
        deployOneYearLockFixture
      );

      const _buyInAmount = ethers.parseEther("10");
      const _pointsCoast = ethers.parseEther("0.1");

      await poker.createTable(
        _buyInAmount,
        _pointsCoast,
        3,
        pokerToken.getAddress()
      );

      const PineapplePokerV2 = await ethers.getContractFactory(
        "PineapplePokerProxyV2"
      );

      const implement1 = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
      );

      const poker2 = await upgrades.upgradeProxy(
        proxyAddress,
        PineapplePokerV2
      );

      const implement2 = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
      );

      expect(await poker2.totalTables()).to.equal(1);
      expect(await poker2.getAddress()).to.equal(proxyAddress);
      expect(implement1).to.not.equal(implement2);

      await poker2.test();
    });
  });
});
