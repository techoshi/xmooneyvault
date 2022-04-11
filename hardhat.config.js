require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");

const ETHERSCAN_API_KEY = 'YEURETDAHFHECCTA2F72U7K2R7F3K1F9PV' //'Y11CP9JA94G663WGI23GB2VNR932VSGMXP' //process.env.ETHERSCAN_API_KEY
const PROJECT_ID = 'fadf000024204bd998db9b39531e6572' //process.env.PROJECT_ID
const PK = '009f83b09a5faf68ce4fe9bed00f026026a3ae3ef59ff13e6a7ec9673bbdb717' //process.env.PK

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.11",
  gasReporter: {
    //enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD',
    token: 'ETH',
    gasPriceApi:	'https://api.etherscan.io/api?module=proxy&action=eth_gasPrice',
    gasPrice: 21
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    //reporterOptions : {  } // See options below
  },
  // defaultNetwork: "hardhat",
  // defaultNetwork: "rinkeby",
  // etherscan: {
  //   apiKey: ETHERSCAN_API_KEY,
  // },
  // networks: {
  //   hardhat: { chainId: 1337 },
  //   rinkeby: {
  //     url: `https://rinkeby.infura.io/v3/${PROJECT_ID}`,
  //     accounts: [`0x${PK}`],
  //   }
  // }
};
