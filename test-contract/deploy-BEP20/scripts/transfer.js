const hre = require("hardhat");
const fs = require('fs');

async function main() {
  // Get the ABCToken contract instance
  const ABCToken = await hre.ethers.getContractFactory("ABCToken");

  // Read from the JSON file and get the contract address
  const data = fs.readFileSync('../deployed_contracts.json');
  const { ABCToken: contractAddress } = JSON.parse(data);
  const contract = await ABCToken.attach(contractAddress);

  let recipientAddress = "0x169eD8eD04D45b572dbCF7354f680D7557253345";

  // Set the amount of tokens to transfer
  const amount = ethers.utils.parseEther("100");

  // Call the transfer function
  const tx = await contract.transfer(recipientAddress, amount);
  console.log("Transaction hash:", tx.hash);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });