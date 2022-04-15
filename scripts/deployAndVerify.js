// npx hardhat run --network rinkeby scripts/deployAndVerify.js
const hre = require("hardhat");
const ethers = hre.ethers;
const args = require("./deployArgs")

async function main() {
    const contractName = "xMooneyVault"
    const confirmationWait = 5;

    const [deployer] = await ethers.getSigners();
    console.log("Deployer Address: " + deployer.address)
    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    console.log(args)

    const Token = await ethers.getContractFactory(contractName);
    const token = await Token.deploy(...args);
    const { deployTransaction: creation_tx } = await token.deployed();
    console.log("Token address:", token.address);


    // Wait for x confirmations
    console.log('Wait for %s confirmations', confirmationWait);
    await creation_tx.wait(confirmationWait);
    console.log('%s confirmations have been made.', confirmationWait);

    // Verify contract
    try {
        console.log('Starting verification');
        await hre.run('verify:verify', {
            address: token.address,
            constructorArguments: args
        });
    } catch (err) {
        console.log(`Error verifying: ${err.message}`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });