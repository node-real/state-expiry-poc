const hre = require("hardhat");
const fs = require("fs");

async function main() {
  // Get the ABCToken contract instance
  const ABCToken = await hre.ethers.getContractFactory("ABCToken");

    // Read from the JSON file and get the contract address
    const data = fs.readFileSync('../deployed_contracts.json');
    const { ABCToken: contractAddress } = JSON.parse(data);
    const contract = await ABCToken.attach(contractAddress);

  // Set the address to check the balance of
  const sender = "0xD8C0Aa483406A1891E5e03B21F2bc01379fc3b20";
  const receiver = "0x169eD8eD04D45b572dbCF7354f680D7557253345";

  // Call the balanceOf function
  const balance1 = await contract.balanceOf(sender);
  console.log(`Balance of ${sender}: ${ethers.utils.formatEther(balance1)} ABC`);
  const balance2 = await contract.balanceOf(receiver);
  console.log(`Balance of ${receiver}: ${ethers.utils.formatEther(balance2)} ABC`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });