// contracts/xMooneyVaultToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTimeLib.sol";
import "hardhat/console.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract xMooneyVault1 is ERC20, Ownable, ReentrancyGuard {
    string private _NAME;
    string private _SYMBOL;
    uint256 private _DECIMALS;

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
    address private contractTokenAddress;
    address[] public circulationExcludedAddresses;
    bool public active = true;

    address private whereToSendTokens =
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; //Dummy Address
    address internal UNISWAP_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IUniswapV2Router01 public uniswapLPRouter;
    IUniswapV2Router02 public uniswapRouter;
    IERC20 public something;

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

    constructor(
        string memory _name,
        string memory _symbol,
        address _token,
        address[] memory excludedAddresses,
        uint8 cycleDepth,
        address Swap_Router_Address
    ) ERC20(_name, _symbol) {
        // _NAME = _name;
        // _SYMBOL = _symbol;
        contractTokenAddress = _token;
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

        uniswapLPRouter = IUniswapV2Router01(Swap_Router_Address);
        uniswapRouter = IUniswapV2Router02(Swap_Router_Address);
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

    function setToken(address newTokenAddress) external onlyOwner {
        contractTokenAddress = newTokenAddress;
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

    function updateExcludedAddresses(address[] memory _excluded)
        external
        onlyOwner
    {
        delete circulationExcludedAddresses;

        for (uint256 index = 0; index < _excluded.length; index++) {
            circulationExcludedAddresses.push(_excluded[index]);
        }
    }

    function updateCallerReward(uint256 newRewardAmount) external onlyOwner {
        callReward = newRewardAmount;
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

    function getNextMaxTokenRelease()
        public
        view
        returns (uint256)
    {
        uint256 asOf = block.timestamp;
        uint256 pendingRelease = circulationLogic(asOf);
        uint256 NextRelease = pendingRelease > maxReleaseSize ? maxReleaseSize : pendingRelease;

        return NextRelease;
    }

    function getMaxTokensThatShouldBeCirculatingInFuture(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 minute,
        uint8 second
    ) public view returns (uint256) {
        uint256 asOf = DateTimeLib.toTimestamp(
            year,
            month,
            day,
            minute,
            second
        );
        return circulationLogic(asOf);
    }

    function releaseTokens() external nonReentrant {
        uint256 asOf = block.timestamp;

        uint256 amountOfTokens = circulationLogic(asOf);
        amountOfTokens = amountOfTokens > maxReleaseSize
            ? maxReleaseSize
            : amountOfTokens;
        uint256 methodCallerRewards = SafeMath.div(
            SafeMath.mul(amountOfTokens, callReward),
            100
        );
        uint256 sellToMarket = SafeMath.div(
            SafeMath.mul(amountOfTokens, 100 - callReward),
            100
        );

        if (
            IERC20(contractTokenAddress).balanceOf(address(this)) >
            amountOfTokens
        ) {
            require(
                IERC20(contractTokenAddress).transfer(
                    msg.sender,
                    methodCallerRewards
                ),
                "transfer to Caller failed"
            );

            uint256 amountToSell = SafeMath.div(sellToMarket, 2);
            uint256 amountToBakeintoLP = SafeMath.div(sellToMarket, 2);

            //Sell Token into LP and then User Value to Bake LP
            convertSourceTokenToContractToken(
                uniswapRouter.WETH(),
                amountToSell
            );
            uint256 deadline = block.timestamp + 15;
            uint256[]
                memory amountOfEth = getEstimatedSourceTokenforContractToken(
                    uniswapRouter.WETH(),
                    amountToBakeintoLP
                );

            uint256 minAmountOfValueToPair = SafeMath.div(SafeMath.mul(amountOfEth[0], 100 - 0),100);
            uint256 minAmountToBakeintoLP = SafeMath.div(SafeMath.mul(amountToSell, 100 - 20),100);

            IERC20(contractTokenAddress).approve(uniswapLPRouter, amountToBakeintoLP);
            uniswapLPRouter.addLiquidityETH{value: amountOfEth[0]}(
                contractTokenAddress,
                amountToBakeintoLP,
                minAmountToBakeintoLP,
                minAmountOfValueToPair,
                address(this),
                deadline
            );
        }
    }

    function transferContractTokens(address destination, uint256 amount)
        public
        onlyOwner
    {
        require(
            IERC20(contractTokenAddress).transfer(destination, amount),
            "transfer failed"
        );
    }

    function getCirculatingSupply() public view returns (uint256) {
        uint256 total = 0;

        for (
            uint256 index = 0;
            index < circulationExcludedAddresses.length;
            index++
        ) {
            total += IERC20(contractTokenAddress).balanceOf(
                circulationExcludedAddresses[index]
            );

            if (index > 10) {
                break;
            }
        }

        return IERC20(contractTokenAddress).totalSupply() - total;
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

    // important to receive ETH
    receive() external payable {}

    function sendBNB(address payable thisAddress, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        thisAddress.transfer(amount);
    }

    function addLP(uint256 addLPTokenAmount) external nonReentrant {
        uint256 deadline = block.timestamp + 15;

        uint256[] memory amountOfEth = getEstimatedSourceTokenforContractToken(
            uniswapRouter.WETH(),
            addLPTokenAmount
        );
        _approve1(
            address(this),
            address(uniswapLPRouter),
            10000000000000000000
        );
        //uniswapLPRouter.approve(address(this), 1);
        uniswapLPRouter.addLiquidityETH{value: amountOfEth[0]}(
            contractTokenAddress,
            addLPTokenAmount,
            SafeMath.div(SafeMath.mul(addLPTokenAmount, 100 - 20), 100),
            SafeMath.div(SafeMath.mul(amountOfEth[0], 100 - 20), 100),
            address(this),
            deadline
        );
    }

    function addLP2(uint256 addLPTokenAmount) external nonReentrant {
        uint256 deadline = block.timestamp + 15;

        uint256[] memory amountOfEth = getEstimatedSourceTokenforContractToken(
            uniswapRouter.WETH(),
            addLPTokenAmount
        );
        _approve1(
            address(this),
            address(uniswapLPRouter),
            10000000000000000000
        );
        uniswapLPRouter.addLiquidityETH{value: amountOfEth[0]}(
            contractTokenAddress,
            addLPTokenAmount,
            SafeMath.div(SafeMath.mul(addLPTokenAmount, 100 - 20), 100),
            SafeMath.div(SafeMath.mul(amountOfEth[0], 100 - 20), 100),
            msg.sender,
            deadline
        );
    }

    function _approve1(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        //  _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approveContract(uint256 amount) public onlyOwner {
        _approve1(address(this), address(uniswapLPRouter), amount);
    }

    function approveContract2(
        address sourceAddy,
        address contractAddy,
        uint256 amount
    ) public onlyOwner {
        IERC20(sourceAddy).approve(contractAddy, amount);
    }

    //Swap Stuff
    function convertSourceTokenToContractToken(
        address exchangeToken,
        uint256 exchangeTokenAmount
    ) public payable {
        uint256 deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        uniswapRouter.swapETHForExactTokens{value: msg.value}(
            exchangeTokenAmount,
            getPathForSourceTokentoContractToken(exchangeToken),
            address(this),
            deadline
        );

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function getEstimatedSourceTokenforContractToken(
        address exchangeToken,
        uint256 contractTokenAmount
    ) public view returns (uint256[] memory) {
        return
            uniswapLPRouter.getAmountsIn(
                contractTokenAmount,
                getPathForSourceTokentoContractToken(exchangeToken)
            );
    }

    function getPathForSourceTokentoContractToken(address exchangeToken)
        private
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = exchangeToken;
        path[1] = contractTokenAddress;

        return path;
    }
}
