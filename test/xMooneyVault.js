const { expect } = require("chai");
const { ethers } = require("hardhat");
const { Console } = require("console");
const fs = require('fs');


let xMooneyContract, xMooneyVaultContract;

let returnObject = {}

if (true == true)
    describe("xMooneyVault", function () {
        let buyer, contractOwner, hashValue;
        before(async () => {
            // const Library = await ethers.getContractFactory("DateTime");
            // const library = await Library.deploy();
            // await library.deployed();

            const [contractOwner, _1, _2, _3] = await ethers.getSigners();
            //Step 1 Load xMooney Contract
            const xMooneyToken = await ethers.getContractFactory("xMooneyToken");
            xMooneyContract = await xMooneyToken.deploy('xMooney', 'xM', 9, 21000000000,3,0,7,_1.address,contractOwner.address);        
            await xMooneyContract.deployed();

            returnObject.contract = xMooneyContract.address;
            
            //Step 2 Load xMooney Vault Contract
            const xMooneyVault = await ethers.getContractFactory("xMooneyVault");
            xMooneyVaultContract = await xMooneyVault.deploy("xMooney Bank", "xMBank",xMooneyContract.address, [contractOwner.address, _2.address], 28, "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");        
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

        it("GetDay", async function () {
            const currentDay = await xMooneyVaultContract.getDay2();
            
            // console.log("Today");                          
            // console.log(currentDay);                          
        });    
        
        it("genesisTimestamp", async function () {
            const result = await xMooneyVaultContract.genesisTimestamp();
            
            // console.log("Genesis");                          
            // console.log(result);                          
        });   

        it("GetTimeStamp", async function () {
            const currentBlockTime = await xMooneyVaultContract.currentTimestamp();

            returnObject.currentBlockTime = currentBlockTime;        
            const thisCycle = await xMooneyVaultContract.getCurrentCycle();
            
            returnObject.currentCycle = thisCycle;    
                          
        });     
        
        it("Will Transfer Tokens from contract to wallets", async function () {
            const [contractOwner, taxWallet, nonCirculatingWallet1, nonCirculatingWallet2, LP] = await ethers.getSigners();
            
            returnObject.ownerBalance = await xMooneyContract.balanceOf(contractOwner.address); 
            await xMooneyContract.approve(contractOwner.address, returnObject.ownerBalance)
            await xMooneyContract.transferFrom(contractOwner.address, taxWallet.address, 21000000000); 
            await xMooneyContract.connect(taxWallet).transfer(returnObject.xMooneyVaultAddress, 21000000000); 
            
            // await xMooneyContract.transferFrom(contractOwner.address, nonCirculatingWallet1.address, 100000); 
            // await xMooneyContract.transferFrom(contractOwner.address, nonCirculatingWallet2.address, 100000); 
            console.log("LP");
            console.log(ethers.utils.getAddress(LP.address));
            await xMooneyContract.approve(nonCirculatingWallet1.address, await xMooneyContract.balanceOf(nonCirculatingWallet1.address));
            //await xMooneyContract.transferFrom(nonCirculatingWallet1.address, nonCirculatingWallet2.address, 10000); 
            // await xMooneyContract.connect(nonCirculatingWallet1).transfer(nonCirculatingWallet2.address, 5000);
             
            returnObject.ownerBalance1 = await xMooneyContract.balanceOf(contractOwner.address); 
            returnObject.taxWallet = await xMooneyContract.balanceOf(taxWallet.address); 

            returnObject.nonCirculatingWallet1 = { address : nonCirculatingWallet1.address, amount: await xMooneyContract.balanceOf(nonCirculatingWallet1.address) }; 
            returnObject.nonCirculatingWallet2 = { address : nonCirculatingWallet2.address, amount:  await xMooneyContract.balanceOf(nonCirculatingWallet2.address) }; 
            returnObject.Caller = { address : LP.address, amount: await xMooneyContract.balanceOf(contractOwner.address) }; 
            returnObject.LP = { address : LP.address, amount:await xMooneyContract.balanceOf(LP.address) }; 
            returnObject.vaultBalance  = { address : returnObject.xMooneyVaultAddress, amount:  await xMooneyContract.balanceOf(returnObject.xMooneyVaultAddress) };
            
            await xMooneyVaultContract.transferContractTokens(contractOwner.address, await xMooneyContract.balanceOf(xMooneyVaultContract.address)); 

            returnObject.vaultBalancePurged  = { address : returnObject.xMooneyVaultAddress, amount:  await xMooneyContract.balanceOf(returnObject.xMooneyVaultAddress) };
            //console.log(returnObject); 
        });

        it("getCirculatingSupply", async function () {            
            const circulating = await xMooneyVaultContract.getCirculatingSupply();
            
            returnObject.circulating = circulating;                              
        });             
        
        it("getMaxTokensThatShouldNowBeCirculating", async function () {            
            const result = await xMooneyVaultContract.getMaxTokensThatShouldNowBeCirculating();
            
            returnObject.maxCirculating = result;                              
        });   
        
        it("triggerRelease", async function () {     
            
            const [contractOwner, taxWallet, nonCirculatingWallet1, nonCirculatingWallet2, LP] = await ethers.getSigners();
            await xMooneyVaultContract.connect(nonCirculatingWallet2).releaseTokens();            
            await xMooneyVaultContract.connect(nonCirculatingWallet1).releaseTokens();            

            returnObject.LP = { address : LP.address, amount:await xMooneyContract.balanceOf(LP.address) }; 
            returnObject.vaultCaller1 = { address : nonCirculatingWallet2.address, amount:await xMooneyContract.balanceOf(nonCirculatingWallet2.address) };
            returnObject.vaultCaller2 = { address : nonCirculatingWallet1.address, amount:await xMooneyContract.balanceOf(nonCirculatingWallet1.address) };
            returnObject.vaultBalanceAfterTrigger  = { address : returnObject.xMooneyVaultAddress, amount:  await xMooneyContract.balanceOf(returnObject.xMooneyVaultAddress) };
        });    
        
        it("getMaxTokensThatShouldBeCirculatingInFuture", async function () {            
            const result = await xMooneyVaultContract.getMaxTokensThatShouldBeCirculatingInFuture(2078, 6, 11, 59, 59);
            
            returnObject.maxCirculatingFutureSpecifiedDate = result;                              
        });     

        it("getSchedule", async function () {            
            const circulating = await xMooneyVaultContract.getSchedule();
            
            returnObject.cyclesloaded = circulating.length;    
            
                // make a new logger
            const myLogger = new Console({
                stdout: fs.createWriteStream("./projectData/projectSchedule.txt"),
                stderr: fs.createWriteStream("./projectData/errStdErr.txt"),
                });
            
                myLogger.log(circulating);
        });    

        it("Console Log Object", async function () {            
           console.log(returnObject);                           
        });    
    })
