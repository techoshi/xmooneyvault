const { expect } = require("chai");
const { ethers } = require("hardhat");

let xMooneyContract, xMooneyVaultContract;

let returnObject = {}

if (true == true)
    describe("SuperGas", function () {
        let buyer, contractOwner, hashValue;
        before(async () => {
            const [contractOwner, taxWallet] = await ethers.getSigners();
            //Step 1 Load xMooney Contract
            const xMooneyToken = await ethers.getContractFactory("xMooneyToken");
            xMooneyContract = await xMooneyToken.deploy('xMooney', 'xM', 9, 21000000000,3,0,7,contractOwner.address,contractOwner.address);        
            await xMooneyContract.deployed();

            returnObject.contract = xMooneyContract.address;
            
            //Step 2 Load xMooney Vault Contract
            const xMooneyVault = await ethers.getContractFactory("xMooneyVault");
            xMooneyVaultContract = await xMooneyVault.deploy(xMooneyContract.address);        
            returnObject.xMooneyVaultAddress = xMooneyVaultContract.address;
            await xMooneyVaultContract.deployed();            
        });

        it("Will get total supply", async function () {
            const totalSupply = await xMooneyContract.totalSupply();
            returnObject.totalSupply = totalSupply;           
            
            const charityFee = await xMooneyContract._CHARITY_FEE();
            returnObject.totalCharity = charityFee;
            
            const taxFee = await xMooneyContract._TAX_FEE();
            returnObject.taxFee = taxFee;                                  
        });  

        it("GetTimeStamp", async function () {
            const currentBlockTime = await xMooneyVaultContract.currentTimestamp();

            returnObject.currentBlockTime = currentBlockTime;        
            const thisCycle = await xMooneyVaultContract.getCurrentCycle();
            
            returnObject.thisCycle = thisCycle;    
                          
        });     
        
        it("Will Transfer Tokens from contract to wallets", async function () {
            const [contractOwner, taxWallet, nonCirculatingWallet1, , nonCirculatingWallet2] = await ethers.getSigners();
            
            returnObject.ownerBalance = await xMooneyContract.balanceOf(contractOwner.address); 
            await xMooneyContract.approve(contractOwner.address, returnObject.ownerBalance)
            await xMooneyContract.transferFrom(contractOwner.address, returnObject.xMooneyVaultAddress, 100000); 
            await xMooneyContract.transferFrom(contractOwner.address, taxWallet.address, 100000); 
            await xMooneyContract.transferFrom(contractOwner.address, nonCirculatingWallet1.address, 100000); 
            await xMooneyContract.transferFrom(contractOwner.address, nonCirculatingWallet2.address, 100000); 
            
            await xMooneyContract.approve(nonCirculatingWallet1.address, await xMooneyContract.balanceOf(nonCirculatingWallet1.address));
            //await xMooneyContract.transferFrom(nonCirculatingWallet1.address, nonCirculatingWallet2.address, 10000); 
            await xMooneyContract.connect(nonCirculatingWallet1).transfer(nonCirculatingWallet2.address, 5000);
             
            returnObject.ownerBalance1 = await xMooneyContract.balanceOf(contractOwner.address); 
            returnObject.taxWallet = await xMooneyContract.balanceOf(taxWallet.address); 

            returnObject.nonCirculatingWallet1 = { adddress : nonCirculatingWallet1.address, amount: await xMooneyContract.balanceOf(nonCirculatingWallet1.address) }; 
            returnObject.nonCirculatingWallet2 = { adddress : nonCirculatingWallet2.address, amount:  await xMooneyContract.balanceOf(nonCirculatingWallet2.address) }; 
            returnObject.vaultBalance  = { adddress : returnObject.xMooneyVaultAddress, amount:  await xMooneyContract.balanceOf(returnObject.xMooneyVaultAddress) };

            console.log(returnObject); 
        });

        it("getCirculatingSupply", async function () {            
            const circulating = await xMooneyVaultContract.getCirculatingSupply();
            
            returnObject.circulating = circulating;                              
        });             

        it("Console Log Object", async function () {            
            console.log(returnObject);                           
        });     
    })
