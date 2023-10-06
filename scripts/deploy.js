const hre = require("hardhat");

async function main() {
  const poker = await hre.ethers.deployContract("PineapplePoker");

  await poker.waitForDeployment();

  console.log(`Poker contract deployed ${await poker.getAddress()}`);

  const initSupply = hre.ethers.parseEther("10000");
  const pokerToken = await hre.ethers.deployContract("PineapplePokerToken", [
    initSupply,
  ]);

  await pokerToken.waitForDeployment();

  console.log(`PokerToken contract deployed ${await pokerToken.getAddress()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
