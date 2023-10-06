const hre = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

  const PineapplePoker = await ethers.getContractFactory("PineapplePokerProxy");
  const poker = await upgrades.deployProxy(PineapplePoker, [], {
    initializer: "initialize",
  });

  await poker.waitForDeployment();

  console.log(`PokerTokenProxy contract deployed ${await poker.getAddress()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
