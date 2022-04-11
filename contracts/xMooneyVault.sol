// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract xMooneyVault is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    uint256 public genesisDate = 1623513600; //June 12, 2021
    uint256 private initialCycleTokenDisbursement = 2625000000; //2,625,000,000
    uint256 private numberOfCycles = 0;
    uint256 private startingCycleID = 1;
    uint256 private numberOfCyclesToLoad = 50;
    uint16 private currentNoCycle = 0;
    address public xMooneyContractAddress;
    address[] public circulationExcludedAddresses;
    bool public active = true;
    
    struct CycleSchedule {
        string cycleID;
        uint256 cycleTokenDisbursement;
        uint256 halvingStartDate;
        uint256 halvingEndDate;
        uint256 releaseRate;
    }

    mapping(uint256 => CycleSchedule) fullSchedule;

    CycleSchedule[] public allCycles;

    constructor(address _token) {
        xMooneyContractAddress = _token;
        LoadUpSchedule();
    }

    function currentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function LoadUpSchedule() private {
        uint256 startOfCycle = genesisDate;
        uint256 currentTokenCount = initialCycleTokenDisbursement;

        uint256 endOfCycle = startOfCycle + 274 days; //Adjust to 9 months
        
        for (uint256 index = startingCycleID; index <= (startingCycleID+numberOfCyclesToLoad); index++) {
                        
            if(currentNoCycle < 4)
            {
                currentTokenCount = (currentTokenCount/2);
            }
            currentNoCycle += 1;
            
            setSchedule(
                string(abi.encodePacked("xM-cycle-", index.toString())),
                startOfCycle,
                endOfCycle - 1,
                currentTokenCount,
                1000000
            );
            
            startOfCycle = endOfCycle;
        }
    }

    function setSchedule(
        string memory cycleID,
        uint256 halvingStartDate,
        uint256 halvingEndDate,
        uint256 cycleTokenDisbursement,
        uint256 releaseRate
    ) public onlyOwner {
        numberOfCycles += 1;
        CycleSchedule memory cycleSchedule = fullSchedule[numberOfCycles];

        cycleSchedule.cycleID = cycleID;
        cycleSchedule.halvingStartDate = halvingStartDate;
        cycleSchedule.halvingEndDate = halvingEndDate;
        cycleSchedule.cycleTokenDisbursement = cycleTokenDisbursement;
        cycleSchedule.releaseRate = releaseRate;

        fullSchedule[numberOfCycles] = cycleSchedule;

        allCycles.push(cycleSchedule);
    }

    function getCurrentCycle() public view returns (CycleSchedule memory) {
        uint256 asOf = currentTimestamp();

        CycleSchedule memory CurrentCycle;

        for (uint256 index = 0; index < numberOfCycles; index++) {
            if (
                allCycles[index].halvingStartDate < asOf &&
                allCycles[index].halvingEndDate >= asOf
            ) {
                CurrentCycle = allCycles[index];
                break;
            }
        }

        return CurrentCycle;
    } 

    function getCirculatingSupply() public view returns (uint256) {
        uint256 total = 0;
        total += IERC20(xMooneyContractAddress).balanceOf(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        total += IERC20(xMooneyContractAddress).balanceOf(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
            
        return IERC20(xMooneyContractAddress).totalSupply() - total;
    } 

    function queryERC20Balance(address _tokenAddress, address _addressToQuery) view public returns (uint) {
        return IERC20(_tokenAddress).balanceOf(_addressToQuery);
    }

    function transferAnyERC20Token(address tokenAddress, address recipient, uint amount) external onlyOwner {
        require(IERC20(tokenAddress).transfer(recipient, amount), "transfer failed!");
    }    
}
