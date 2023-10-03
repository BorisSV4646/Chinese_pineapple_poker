const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PineapplePoker Deploy", function () {
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
      expect(table.state).to.equal(0);
      expect(table.token).to.equal(await pokerToken.getAddress());
    });

    it("Checks and events are working", async function () {
      const { poker, pokerToken } = await loadFixture(deployOneYearLockFixture);

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

describe("PineapplePoker Functions", function () {
  async function deployCreateTableFixture() {
    const [owner, otherAccount1, otherAccount2, otherAccount3] =
      await ethers.getSigners();

    const PineapplePoker = await ethers.getContractFactory("PineapplePoker");
    const poker = await PineapplePoker.deploy();

    const PineappleToken = await ethers.getContractFactory(
      "PineapplePokerToken"
    );
    const pokerToken = await PineappleToken.deploy(ethers.parseEther("100"));

    const pokerAddress = await poker.getAddress();
    const _buyInAmount = ethers.parseEther("10");
    const _pointsCoast = ethers.parseEther("0.1");
    const createTable = await poker.createTable(
      _buyInAmount,
      _pointsCoast,
      3,
      pokerToken.getAddress()
    );

    await pokerToken.transfer(otherAccount1, _buyInAmount);
    await pokerToken.transfer(otherAccount2, _buyInAmount);
    await pokerToken.transfer(otherAccount3, _buyInAmount);

    const user1 = await poker.connect(otherAccount1);
    const user2 = await poker.connect(otherAccount2);
    const user1Token = await pokerToken.connect(otherAccount1);
    const user2Token = await pokerToken.connect(otherAccount2);

    await user1Token.approve(pokerAddress, _buyInAmount);
    await user2Token.approve(pokerAddress, _buyInAmount);

    await user1.buyIn(0, _buyInAmount);
    await user2.buyIn(0, _buyInAmount);

    return {
      poker,
      owner,
      createTable,
      _buyInAmount,
      pokerAddress,
      _pointsCoast,
      pokerToken,
      otherAccount1,
      otherAccount2,
      otherAccount3,
      user2,
      user1,
    };
  }

  describe("Function buyIn", function () {
    it("User can join to table", async function () {
      const { poker, pokerToken, _buyInAmount, otherAccount3, pokerAddress } =
        await loadFixture(deployCreateTableFixture);

      const user3 = await poker.connect(otherAccount3);
      const user3Token = await pokerToken.connect(otherAccount3);

      await user3Token.approve(pokerAddress, _buyInAmount);
      const joinTable = await user3.buyIn(0, _buyInAmount);

      await expect(joinTable).to.changeTokenBalances(
        pokerToken,
        [otherAccount3, pokerAddress],
        [-_buyInAmount, _buyInAmount]
      );

      expect(await pokerToken.balanceOf(pokerAddress)).to.equal(
        ethers.parseEther("30")
      );

      expect(await poker.chips(otherAccount3.address, 0)).to.equal(
        _buyInAmount
      );
    });

    it("Checks and events are working", async function () {
      const { poker, pokerToken, _buyInAmount, otherAccount3, pokerAddress } =
        await loadFixture(deployCreateTableFixture);

      const user3 = await poker.connect(otherAccount3);
      const user3Token = await pokerToken.connect(otherAccount3);

      await user3Token.approve(pokerAddress, _buyInAmount);

      await expect(user3.buyIn(1, _buyInAmount)).to.be.revertedWith(
        "Table not created"
      );
      await expect(user3.buyIn(0, ethers.parseEther("9"))).to.be.revertedWith(
        "Not enough buyInAmount"
      );

      const joinTable = await user3.buyIn(0, _buyInAmount);

      await expect(joinTable)
        .to.emit(poker, "NewBuyIn")
        .withArgs(0, otherAccount3.address, _buyInAmount);

      await pokerToken.approve(pokerAddress, _buyInAmount);

      await expect(poker.buyIn(0, _buyInAmount)).to.be.revertedWith(
        "Table full"
      );
    });
  });

  describe("Function dealCards", function () {
    it("DealCards work correctly", async function () {
      const { poker } = await loadFixture(deployCreateTableFixture);

      await poker.dealCards(0);

      const table = await poker.tables(0);
      expect(table.state).to.equal(1);

      const round = await poker.rounds(0, 0);
      expect(round.state).to.equal(true);
    });

    it("Checks and events are working", async function () {
      const { poker } = await loadFixture(deployCreateTableFixture);

      const dealCards = await poker.dealCards(0);

      const events = await poker.queryFilter(poker.filters.CardsDealtFirst());
      expect(events.length).to.equal(2);
      const argsFirstEvent = events[0].args;
      const argsSecondEvent = events[1].args;

      const firstArray = argsFirstEvent[2];
      const secondArray = argsSecondEvent[2];

      await expect(dealCards)
        .to.emit(poker, "CardsDealtFirst")
        .withArgs(0, 0, firstArray, 0);

      await expect(dealCards)
        .to.emit(poker, "CardsDealtFirst")
        .withArgs(0, 0, secondArray, 1);

      await expect(poker.dealCards(0)).to.be.revertedWith(
        "Game already going on"
      );
    });
  });

  describe("Function newDeal", function () {
    it("NewDeal work correctly", async function () {
      const { poker } = await loadFixture(deployCreateTableFixture);

      await poker.dealCards(0);

      const newDeal = await poker.newDeal(0);

      const events = await poker.queryFilter(poker.filters.CardsDealtSecond());
      expect(events.length).to.equal(2);
      const argsFirstEvent = events[0].args;
      const argsSecondEvent = events[1].args;

      const firstArray = argsFirstEvent[2];
      const secondArray = argsSecondEvent[2];

      await expect(newDeal)
        .to.emit(poker, "CardsDealtSecond")
        .withArgs(0, 0, firstArray, 0, 0);

      await expect(newDeal)
        .to.emit(poker, "CardsDealtSecond")
        .withArgs(0, 0, secondArray, 1, 0);

      await expect(poker.dealCards(0)).to.be.revertedWith(
        "Game already going on"
      );
    });

    it("Checks and events are working", async function () {
      const { poker } = await loadFixture(deployCreateTableFixture);

      await poker.dealCards(0);

      await poker.newDeal(0);
      await poker.newDeal(0);
      await poker.newDeal(0);
      await poker.newDeal(0);

      await expect(poker.newDeal(0)).to.be.revertedWith(
        "All cards have been dealt"
      );
      await expect(poker.newDeal(1)).to.be.revertedWith("Game not started");
    });
  });

  describe("Function endRound", function () {
    it("EndRound work correctly", async function () {
      const { poker, otherAccount1, otherAccount2 } = await loadFixture(
        deployCreateTableFixture
      );

      await poker.dealCards(0);

      await poker.newDeal(0);
      await poker.newDeal(0);
      await poker.newDeal(0);
      await poker.newDeal(0);

      await poker.endRound(0, [7, 7], [true, false]);

      const table = await poker.tables(0);
      expect(table.state).to.equal(2);
      expect(table.currentRound).to.equal(1);

      const round = await poker.rounds(0, 0);
      expect(round.state).to.equal(false);

      const chipsPointsWin = await ethers.parseEther("10.7");
      const chipsPointsLose = await ethers.parseEther("9.3");

      expect(await poker.chips(otherAccount1.address, 0)).to.equal(
        chipsPointsWin
      );
      expect(await poker.chips(otherAccount2.address, 0)).to.equal(
        chipsPointsLose
      );
    });

    it("Checks and events are working", async function () {
      const { poker, user1 } = await loadFixture(deployCreateTableFixture);

      await poker.dealCards(0);

      await poker.newDeal(0);
      await poker.newDeal(0);
      await poker.newDeal(0);

      await expect(poker.endRound(0, [7, 7], [true, false])).to.be.revertedWith(
        "Not all cards have been dealt"
      );

      await poker.newDeal(0);

      await expect(user1.checkingCards(0)).to.be.revertedWith(
        "Round is active"
      );

      const endRoud = await poker.endRound(0, [7, 7], [true, false]);

      await expect(poker.endRound(1, [7, 7], [true, false])).to.be.revertedWith(
        "Game not started"
      );

      await expect(endRoud).to.emit(poker, "RoundOver").withArgs(0, 0);
    });
  });
});

describe("PineapplePoker EndRound", function () {
  async function deployEndRound() {
    const [owner, otherAccount1, otherAccount2, otherAccount3] =
      await ethers.getSigners();

    const PineapplePoker = await ethers.getContractFactory("PineapplePoker");
    const poker = await PineapplePoker.deploy();

    const PineappleToken = await ethers.getContractFactory(
      "PineapplePokerToken"
    );
    const pokerToken = await PineappleToken.deploy(ethers.parseEther("100"));

    const pokerAddress = await poker.getAddress();
    const _buyInAmount = ethers.parseEther("10");
    const _pointsCoast = ethers.parseEther("0.1");
    const createTable = await poker.createTable(
      _buyInAmount,
      _pointsCoast,
      3,
      pokerToken.getAddress()
    );

    await pokerToken.transfer(otherAccount1, _buyInAmount);
    await pokerToken.transfer(otherAccount2, ethers.parseEther("20"));
    await pokerToken.transfer(otherAccount3, _buyInAmount);

    const user1 = await poker.connect(otherAccount1);
    const user2 = await poker.connect(otherAccount2);
    const user1Token = await pokerToken.connect(otherAccount1);
    const user2Token = await pokerToken.connect(otherAccount2);

    await user1Token.approve(pokerAddress, _buyInAmount);
    await user2Token.approve(pokerAddress, ethers.parseEther("20"));

    await user1.buyIn(0, _buyInAmount);
    await user2.buyIn(0, _buyInAmount);

    await poker.dealCards(0);

    await poker.newDeal(0);
    await poker.newDeal(0);
    await poker.newDeal(0);
    await poker.newDeal(0);

    await poker.endRound(0, [7, 7], [true, false]);

    return {
      poker,
      owner,
      createTable,
      _buyInAmount,
      pokerAddress,
      _pointsCoast,
      pokerToken,
      otherAccount1,
      otherAccount2,
      otherAccount3,
      user2,
      user1,
    };
  }

  describe("Function dealCards again", function () {
    it("Can`t deal cards again", async function () {
      const { poker } = await loadFixture(deployEndRound);

      const table = await poker.tables(0);
      expect(table.state).to.equal(2);

      await expect(poker.dealCards(0)).to.be.revertedWith(
        "Not all players have the minimum balance"
      );
    });
  });

  describe("Function addChips", function () {
    it("AddChips work correctly", async function () {
      const { poker, pokerToken, user2, _buyInAmount, otherAccount2 } =
        await loadFixture(deployEndRound);

      const addChips = await user2.addChips(0, _buyInAmount);

      await expect(addChips).to.changeTokenBalances(
        pokerToken,
        [otherAccount2.address, await poker.getAddress()],
        [-_buyInAmount, _buyInAmount]
      );

      expect(await poker.chips(otherAccount2.address, 0)).to.equal(
        _buyInAmount + ethers.parseEther("9.3")
      );

      await poker.dealCards(0);
    });

    it("Checks and events are working", async function () {
      const { poker, user2, _buyInAmount, otherAccount2, otherAccount3 } =
        await loadFixture(deployEndRound);

      const user3 = await poker.connect(otherAccount3);

      await expect(user3.addChips(0, _buyInAmount)).to.be.revertedWith(
        "Not a player in this table"
      );

      const addChips = await user2.addChips(0, _buyInAmount);

      await expect(addChips)
        .to.emit(poker, "AddChips")
        .withArgs(0, _buyInAmount, otherAccount2.address);
    });
  });

  describe("Function exitTable", function () {
    it("exitTable work correctly", async function () {
      const { poker, pokerToken, user2, user1, otherAccount2, otherAccount1 } =
        await loadFixture(deployEndRound);

      const withdrawBalance = await ethers.parseEther("9.3");
      const withdraw = await user2.exitTable(0, otherAccount2.address);

      await expect(withdraw).to.changeTokenBalances(
        pokerToken,
        [await poker.getAddress(), otherAccount2.address],
        [-withdrawBalance, withdrawBalance]
      );

      expect(await poker.chips(otherAccount2.address, 0)).to.equal(0);

      await user1.exitTable(0, otherAccount1.address);

      const table = await poker.tables(0);
      expect(table.state).to.equal(0);
    });

    it("Checks and events are working", async function () {
      const {
        poker,
        user2,
        user1,
        otherAccount1,
        otherAccount3,
        otherAccount2,
      } = await loadFixture(deployEndRound);

      const user3 = await poker.connect(otherAccount3);

      const withdraw = await user1.exitTable(0, otherAccount1.address);
      const withdrawBalance = await ethers.parseEther("10.7");

      await expect(withdraw)
        .to.emit(poker, "ExitUser")
        .withArgs(0, withdrawBalance, otherAccount1.address);

      await expect(
        user3.exitTable(0, otherAccount3.address)
      ).to.be.revertedWith("Not a valid player or not enough balance");

      await user2.exitTable(0, otherAccount2.address);

      await expect(
        user3.exitTable(0, otherAccount3.address)
      ).to.be.revertedWith("Round is active");
    });
  });

  describe("Function deleteUserFrontend", function () {
    it("DeleteUserFrontend work correctly", async function () {
      const { poker, otherAccount2, otherAccount1, otherAccount3 } =
        await loadFixture(deployEndRound);

      const deleteUser = await poker.exitTable(0, otherAccount1.address);

      await expect(deleteUser)
        .to.emit(poker, "DeleteUser")
        .withArgs(0, otherAccount1.address);

      await expect(
        poker.exitTable(0, otherAccount3.address)
      ).to.be.revertedWith("Not a valid player or not enough balance");

      await poker.exitTable(0, otherAccount2.address);

      const table = await poker.tables(0);
      expect(table.state).to.equal(0);
    });
  });

  describe("Function checkingCards", function () {
    it("СheckingCards work correctly", async function () {
      const { poker, user1 } = await loadFixture(deployEndRound);

      const cards = await user1.checkingCards(0);
      expect(cards.length).to.equal(17);

      await expect(poker.checkingCards(0)).to.be.revertedWith(
        "Not a player in this table"
      );
    });
  });
});
