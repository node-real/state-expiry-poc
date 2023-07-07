// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  let [owner] = await ethers.getSigners();
  console.log(`owner: ${owner.address}`);

  let accountCount = 0;
  // deploy contract
  const ABCToken = await hre.ethers.getContractFactory("ABCToken");
  const abcToken = await ABCToken.deploy();
  await abcToken.deployed();
  console.log(`ABCToken deployed: ${abcToken.address}, tx: ${abcToken.deployTransaction.hash}`);
  console.log(`owner balance: ${ethers.utils.formatEther(await abcToken.balanceOf(owner.address))} ABC`);

  while (accountCount < 1_000_000) {
    if (accountCount % 1000 === 0) {
      console.log(`owner balance: ${ethers.utils.formatEther(await abcToken.balanceOf(owner.address))} ABC`);
    }
    try {
      // add account
      let acc = ethers.Wallet.createRandom();
      console.log(`new account: ${acc.address}, prvKey: ${acc.privateKey}`);

      // send token
      const tokenTx = await abcToken.transfer(acc.address, ethers.utils.parseEther("1"), {gasLimit: 200000});
      console.log(`transfer tx: ${tokenTx.hash}`);
      accountCount++;
    }catch (e) {
      console.error(`got err: ${e}`);
    }
    await sleep(100);
  }

  await sleep(10000);
  console.log(`owner balance: ${ethers.utils.formatEther(await abcToken.balanceOf(owner.address))} ABC`);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
