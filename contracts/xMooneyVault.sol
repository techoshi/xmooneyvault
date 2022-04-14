// contracts/xMooneyVaultToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTimeLib.sol";
import "hardhat/console.sol";

contract xMooneyVault is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    // using Counters for Counters.Counter;

    using Strings for uint256;

    uint256 public maxReleaseSize = 1000000;
    uint256 public callReward = 3; //3%
    uint256 public genesisDate = 1623456000; //June 12, 2021
    uint256 private startingCirculatingBalance = 1000000000; //Dev Allotment
    uint256 private initialCycleTokenDisbursement = 2500000000; //2,500,000,000
    uint256 private numberOfCycles = 0;
    uint256 private startingCycleID = 1;
    uint256 private numberOfCyclesToLoad = 50;
    uint8 private cycleDurationInMonths = 9;
    uint16 private currentNoCycle = 0;
    address public xMooneyContractAddress;
    address[] public circulationExcludedAddresses;
    bool public active = true;

    address private whereToSendTokens = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

    struct CycleSchedule {
        string title;
        uint256 cycleID;
        uint256 disbursementRate;
        uint256 disbursementAmount;
        uint16 year;
        uint8 month;
        uint256 timestamp;
        uint16 endYear;
        uint8 endMonth;
        uint256 endTimestamp;
        uint256 totalTicks;
        uint256 tokensPerTick;
    }

    mapping(uint256 => CycleSchedule) fullSchedule;

    CycleSchedule[] public allCycles;

    constructor(address _token, address[] memory excludedAddresses, uint8 cycleDepth) {
        xMooneyContractAddress = _token;
        // LoadUpSchedule();
        CycleSchedule memory genesis = CycleSchedule({
            title: string(abi.encodePacked("xM-cycle-", "0")),
            cycleID: 0,
            disbursementRate: 1,
            disbursementAmount: initialCycleTokenDisbursement,
            year: 2021,
            month: 6,
            timestamp: DateTimeLib.toTimestamp(2021, 6, 12),
            endYear: 2022,
            endMonth: 3,
            endTimestamp: DateTimeLib.toTimestamp(2022, 3, 11, 59, 59),
            totalTicks: 0,
            tokensPerTick: 0
        });

        genesis.totalTicks = genesis.endTimestamp - genesis.timestamp;
        genesis.tokensPerTick = genesis.disbursementAmount / genesis.totalTicks;

        allCycles.push(genesis);
        setTokenSchedule(cycleDepth);
        circulationExcludedAddresses = excludedAddresses;
    }

    function genesisTimestamp() public pure returns (uint256) {
        return DateTimeLib.toTimestamp(2021, 6, 12);
    }

    function getDay2() public view returns (string memory) {
        uint8 day2 = DateTimeLib.getWeekday(block.timestamp);

        if (day2 == 0) {
            return "Sunday";
        }

        if (day2 == 1) {
            return "Monday";
        }

        if (day2 == 2) {
            return "Tuesday";
        }

        if (day2 == 3) {
            return "Wednesday";
        }

        if (day2 == 4) {
            return "Thursday";
        }

        if (day2 == 5) {
            return "Friday";
        }

        if (day2 == 6) {
            return "Saturday";
        }

        return "";
    }

    function currentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function setTokenSchedule(uint256 cycleDepth)
        public
        returns (CycleSchedule[] memory)
    {
        uint256 TotalCycles = (allCycles.length + cycleDepth);

        for (
            uint256 index = allCycles.length + 1;
            index <= TotalCycles;
            index++
        ) {
            uint256 nextNumber = allCycles[allCycles.length - 1].cycleID + 1;

            CycleSchedule memory nextCycle = allCycles[allCycles.length - 1];

            nextCycle.cycleID = nextNumber;
            nextCycle.title = string(
                abi.encodePacked("xM-cycle-", Strings.toString(nextNumber))
            );

            if (nextNumber % 4 == 0) {
                nextCycle.disbursementRate = nextCycle.disbursementRate / 2;
                nextCycle.disbursementAmount = nextCycle.disbursementAmount / 2;
            }

            bool push2NextYear = (nextCycle.month + 9) >= 1 &&
                (nextCycle.month + 9) <= 12
                ? false
                : true;

            uint8 nextMonths1 = (nextCycle.month + cycleDurationInMonths) <= 12
                ? (nextCycle.month + cycleDurationInMonths)
                : (nextCycle.month + cycleDurationInMonths) - 12;

            nextCycle.month = push2NextYear
                ? nextMonths1
                : nextMonths1 - 12 == 0
                ? 12
                : nextMonths1 - 12;
            nextCycle.year = push2NextYear
                ? nextCycle.year + 1
                : nextCycle.year;
            nextCycle.timestamp = DateTimeLib.toTimestamp(
                nextCycle.year,
                nextCycle.month,
                12
            );

            bool push2NextYear2 = (nextMonths1 + cycleDurationInMonths) >= 1 &&
                (nextMonths1 + cycleDurationInMonths) <= 12
                ? false
                : true;

            uint8 nextMonths = (nextMonths1 + cycleDurationInMonths) <= 12
                ? (nextMonths1 + cycleDurationInMonths)
                : (nextMonths1 + cycleDurationInMonths) - 12;

            nextCycle.endMonth = nextMonths;

            nextCycle.endYear = push2NextYear2
                ? nextCycle.endYear + 1
                : nextCycle.endYear;
            nextCycle.endTimestamp = DateTimeLib.toTimestamp(
                nextCycle.endYear,
                nextCycle.endMonth,
                11,
                59,
                59
            );

            nextCycle.totalTicks = nextCycle.endTimestamp - nextCycle.timestamp;
            nextCycle.tokensPerTick =
                nextCycle.disbursementAmount /
                nextCycle.totalTicks;

            allCycles.push(nextCycle);
        }

        return allCycles;
    }

    function updateCallerReward(uint256 newReward) external onlyOwner {
        callReward = newReward;
    }

    function updateMaxTokenRelease(uint256 newAmount) external onlyOwner {
        maxReleaseSize = newAmount;
    }

    function getSchedule() public view returns (CycleSchedule[] memory) {
        return allCycles;
    }

    function getCurrentCycle() public view returns (CycleSchedule memory) {
        uint256 asOf = block.timestamp;

        CycleSchedule memory CurrentCycle;

        for (uint256 index = 0; index < allCycles.length; index++) {
            if (
                allCycles[index].timestamp < asOf &&
                allCycles[index].endTimestamp >= asOf
            ) {
                CurrentCycle = allCycles[index];
                break;
            }
        }

        return CurrentCycle;
    }

    function circulationLogic(uint256 timestamp)
        private
        view
        returns (uint256)
    {
        uint256 asOf = timestamp;
        CycleSchedule memory CurrentCycle;

        uint256 tokensThatShouldBeCirculating = 0;

        for (uint256 index = 0; index < allCycles.length; index++) {
            if (
                allCycles[index].timestamp < asOf &&
                allCycles[index].endTimestamp >= asOf
            ) {
                CurrentCycle = allCycles[index];
                break;
            }

            tokensThatShouldBeCirculating += allCycles[index]
                .disbursementAmount;
        }

        tokensThatShouldBeCirculating +=
            (asOf - CurrentCycle.timestamp) *
            CurrentCycle.tokensPerTick;

        tokensThatShouldBeCirculating += startingCirculatingBalance;

        return tokensThatShouldBeCirculating;
    }

    function getMaxTokensThatShouldNowBeCirculating()
        public
        view
        returns (uint256)
    {
        uint256 asOf = block.timestamp;

        return circulationLogic(asOf);
    }

    function getMaxTokensThatShouldBeCirculatingInFuture(uint16 year, uint8 month, uint8 day, uint8 minute, uint8 second)
        public
        view
        returns (uint256)
    {
        uint256 asOf = DateTimeLib.toTimestamp(year, month, day, minute, second);

        return circulationLogic(asOf);
    }

    function releaseTokens() external nonReentrant {
        
        uint256 asOf = block.timestamp;

        uint256 amountOfTokens = circulationLogic(asOf);      
        amountOfTokens = amountOfTokens > maxReleaseSize ? maxReleaseSize : amountOfTokens;  
        uint256 methodCallerRewards = SafeMath.div(SafeMath.mul(amountOfTokens, callReward), 100); 
        uint256 sellToMarket = SafeMath.div(SafeMath.mul(amountOfTokens, 100-callReward), 100); 

        require(IERC20(xMooneyContractAddress).transfer(msg.sender, methodCallerRewards), "transfer to Caller failed");
        require(IERC20(xMooneyContractAddress).transfer(whereToSendTokens, sellToMarket), "transfer to LP failed");
    }

    function transferContractTokens(address destination, uint256 amount) public onlyOwner
    {        
        require(IERC20(xMooneyContractAddress).transfer(destination, amount), "transfer failed");
    }

    function getCirculatingSupply() public view returns (uint256) {
        uint256 total = 0;

        for (
            uint256 index = 0;
            index < circulationExcludedAddresses.length;
            index++
        ) {
            total += IERC20(xMooneyContractAddress).balanceOf(
                circulationExcludedAddresses[index]
            );

            if (index > 10) {
                break;
            }
        }

        return IERC20(xMooneyContractAddress).totalSupply() - total;
    }

    function queryERC20Balance(address _tokenAddress, address _addressToQuery)
        public
        view
        returns (uint256)
    {
        return IERC20(_tokenAddress).balanceOf(_addressToQuery);
    }

    function transferAnyERC20Token(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(tokenAddress).transfer(recipient, amount),
            "transfer failed!"
        );
    }
}
