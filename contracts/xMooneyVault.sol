// contracts/xMooneyVaultToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTimeLib.sol";
import "hardhat/console.sol";

contract xMooneyVault is Ownable {
    using SafeMath for uint256;
    // using Counters for Counters.Counter;

    using Strings for uint256;

    uint256 public genesisDate = 1623456000; //June 12, 2021
    uint256 private startingCirculatingBalance = 1000000000; //Dev Allotment
    uint256 private initialCycleTokenDisbursement = 2625000000; //2,625,000,000
    uint256 private numberOfCycles = 0;
    uint256 private startingCycleID = 1;
    uint256 private numberOfCyclesToLoad = 50;
    uint8 private cycleDurationInMonths = 9;
    uint16 private currentNoCycle = 0;
    address public xMooneyContractAddress;
    address[] public circulationExcludedAddresses;
    bool public active = true;

    struct CycleSchedule {
        string title;
        uint256 cycleID;
        uint256 disbursementRate;
        uint256 disbursementAmount;
        // uint256 halvingStartDate;
        // uint256 halvingEndDate;
        // uint256 releaseRate;
        uint16 year;
        uint8 month;
        uint8 day;
        uint256 timestamp;
        uint16 endYear;
        uint8 endMonth;
        uint8 endDay;
        uint256 endTimestamp;
    }

    mapping(uint256 => CycleSchedule) fullSchedule;

    CycleSchedule[] public allCycles;

    constructor(address _token, address[] memory excludedAddresses) {
        xMooneyContractAddress = _token;
        // LoadUpSchedule();
        CycleSchedule memory genesis = CycleSchedule({
            title: string(abi.encodePacked("xM-cycle-", "0")),
            cycleID: 0,
            disbursementRate: 1,
            disbursementAmount: initialCycleTokenDisbursement,
            year: 2021,
            month: 6,
            day: 12,
            timestamp: DateTimeLib.toTimestamp(2021, 6, 12),
            endYear: 2022,
            endMonth: 3,
            endDay: 11,
            endTimestamp: DateTimeLib.toTimestamp(2022, 3, 11, 59, 59)
        });
        allCycles.push(genesis);
        setTokenSchedule(30);
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
                nextCycle.endDay,
                59,
                59
            );

            allCycles.push(nextCycle);
        }

        return allCycles;
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
