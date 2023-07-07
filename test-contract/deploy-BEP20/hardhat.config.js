require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.6.4",
  defaultNetwork: "local",
  networks: {
    local: {
      url: `http://localhost:8503`,
      accounts: ["190e410a96c56dcc7cbe6ee04ce68fbcf2eb7d86c441e840235373078cf6bb0c"]
    },
  }
};
