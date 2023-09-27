const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("PineapplePoker", function () {
  async function deployOneYearLockFixture() {
    const [owner, otherAccount1, otherAccount2, otherAccount3] =
      await ethers.getSigners();

    const PineapplePoker = await ethers.getContractFactory("PineapplePoker");
    const poker = await PineapplePoker.deploy();

    const PineappleToken = await ethers.getContractFactory(
      "PineapplePokerToken"
    );
    const pokerToken = await PineappleToken.deploy(ethers.parseEther("100"));

    return {
      poker,
      owner,
      pokerToken,
      otherAccount1,
      otherAccount2,
      otherAccount3,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { poker, owner, pokerToken } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await poker.owner()).to.equal(owner.address);

      expect(await pokerToken.balanceOf(owner.address)).to.equal(
        ethers.parseEther("100")
      );
    });
  });

  describe("CreateTable", function () {
    it("The table is created correctly", async function () {
      const { poker, pokerToken } = await loadFixture(deployOneYearLockFixture);

      const _buyInAmount = ethers.parseEther("10");
      const _pointsCoast = ethers.parseEther("0.1");

      await poker.createTable(
        _buyInAmount,
        _pointsCoast,
        3,
        pokerToken.getAddress()
      );

      expect(await poker.totalTables()).to.equal(1);

      const table = await poker.tables(0);

      expect(table.buyInAmount).to.equal(_buyInAmount);
      expect(table.currentRound).to.equal(0);
      expect(table.pointsCoast).to.equal(_pointsCoast);
      expect(table.maxPlayers).to.equal(3);
      expect(table.state).to.equal(1);
      expect(table.token).to.equal(await pokerToken.getAddress());
    });

    it("Checks and events are working", async function () {
      const { poker, owner, pokerToken } = await loadFixture(
        deployOneYearLockFixture
      );

      const _buyInAmount = ethers.parseEther("10");
      const _pointsCoast = ethers.parseEther("0.1");

      await expect(
        poker.createTable(
          _buyInAmount,
          _pointsCoast,
          5,
          pokerToken.getAddress()
        )
      ).to.be.revertedWith("Invalid number of players");

      const createTable = await poker.createTable(
        _buyInAmount,
        _pointsCoast,
        3,
        pokerToken.getAddress()
      );

      await expect(createTable).to.emit(poker, "NewTableCreated");
    });
  });
});
