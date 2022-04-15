// contracts/xMooneyVaultToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTimeLib.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract xMooneyVault is Ownable, ReentrancyGuard {
    string private _NAME;
    string private _SYMBOL;
    uint256 private _DECIMALS = 9;

    using SafeMath for uint256;
    // using Counters for Counters.Counter;

    using Strings for uint256;

    uint256 public genesisDate = 1623456000; //June 12, 2021
    uint256 public callReward = 30; //3%
    uint256 private FOUNDER_ALLOTMENT = 1000000000000000000; //1,000,000,000
    uint256 private CREATION_UNIT_ALLOTMENT = 2000000000000000000; //2,000,000,000
    uint256 private initialCycleTokenDisbursement = 2125000000000000000; //2,125,000,000
    uint256 public maxReleaseSize = 1000000000; //1,000,000
    uint256 private numberOfCycles = 0;
    uint256 private startingCycleID = 1;
    uint256 private numberOfCyclesToLoad = 50;
    uint8 private cycleDurationInMonths = 9;
    uint16 private currentNoCycle = 0;

    address private contractTokenAddress;
    address[] public circulationExcludedAddresses;
    address internal SWAP_ROUTER_ADDRESS;
    address private swapV2Pair;

    IUniswapV2Router01 public uniswapLPRouter;
    IUniswapV2Router02 public uniswapRouter;

    dividingStruct private thisDividingStruct = dividingStruct({
        divider: 1000
    });

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

    struct dividingStruct {
        uint256 divider;
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
    ) {
        _NAME = _name;
        _SYMBOL = _symbol;
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

        SWAP_ROUTER_ADDRESS = Swap_Router_Address;
        uniswapLPRouter = IUniswapV2Router01(SWAP_ROUTER_ADDRESS);
        uniswapRouter = IUniswapV2Router02(SWAP_ROUTER_ADDRESS);
    }

    function decimals() public view returns (uint8) {
        return uint8(_DECIMALS);
    }

    function totalSupply() public view returns (uint256) {
        return IERC20(contractTokenAddress).balanceOf(address(this));
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

    function genesisTimestamp() public pure returns (uint256) {
        return DateTimeLib.toTimestamp(2021, 6, 12);
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
        require(
            newRewardAmount >= 0 && newRewardAmount <= 1000,
            "Reward must be between 0 and 1000"
        );
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

        tokensThatShouldBeCirculating += (FOUNDER_ALLOTMENT +
            CREATION_UNIT_ALLOTMENT);

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

    function getNextMaxTokenRelease() public view returns (uint256) {
        uint256 asOf = block.timestamp;
        uint256 pendingRelease = circulationLogic(asOf);
        uint256 NextRelease = pendingRelease > maxReleaseSize
            ? maxReleaseSize
            : pendingRelease;

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
            thisDividingStruct.divider
        );

        amountOfTokens = SafeMath.sub(amountOfTokens, methodCallerRewards);

        uint256 sellToMarket = SafeMath.div(
            SafeMath.mul(
                amountOfTokens,
                (thisDividingStruct.divider - callReward)
            ),
            thisDividingStruct.divider
        );

        uint256 contractBalance = IERC20(contractTokenAddress).balanceOf(
            address(this)
        );

        if (contractBalance > amountOfTokens) {
            require(
                IERC20(contractTokenAddress).transfer(
                    msg.sender,
                    methodCallerRewards
                ),
                "transfer to Caller failed"
            );

            uint256 amountToSell = SafeMath.div(
                SafeMath.mul(sellToMarket, 550),
                thisDividingStruct.divider
            );

            uint256 amountToBakeintoLP = SafeMath.div(
                SafeMath.mul(sellToMarket, 450),
                thisDividingStruct.divider
            );
            console.log("Amount To Sell");
            console.log(amountToSell);

            uint256 ethAmount = getEstimatedSourceTokenforContractToken(uniswapRouter.WETH(),
                amountToSell)[0];
            //Sell Token into LP and then User Value to Bake LP
            convertEthToContractToken(
                uniswapRouter.WETH(),
                amountToSell,
                ethAmount
            );

            addLP(amountToBakeintoLP);
        }
    }

    function releaseTokens1() external nonReentrant {
        uint256 asOf = block.timestamp;

        uint256 amountOfTokens = circulationLogic(asOf);

        amountOfTokens = amountOfTokens > maxReleaseSize
            ? maxReleaseSize
            : amountOfTokens;

        uint256 methodCallerRewards = SafeMath.div(
            SafeMath.mul(amountOfTokens, callReward),
            thisDividingStruct.divider
        );

        amountOfTokens = SafeMath.sub(amountOfTokens, methodCallerRewards);

        uint256 sellToMarket = SafeMath.div(
            SafeMath.mul(
                amountOfTokens,
                (thisDividingStruct.divider - callReward)
            ),
            thisDividingStruct.divider
        );

        uint256 contractBalance = IERC20(contractTokenAddress).balanceOf(
            address(this)
        );

        if (contractBalance > amountOfTokens) {
            require(
                IERC20(contractTokenAddress).transfer(
                    msg.sender,
                    methodCallerRewards
                ),
                "transfer to Caller failed"
            );

            uint256 amountToSell = SafeMath.div(
                SafeMath.mul(sellToMarket, (thisDividingStruct.divider - 550)),
                thisDividingStruct.divider
            );

            uint256 ethAmount = getEstimatedSourceTokenforContractToken(uniswapRouter.WETH(),
                amountToSell)[0];

            //Sell Token into LP and then User Value to Bake LP
            convertEthToContractToken(
                uniswapRouter.WETH(),
                amountToSell,
                ethAmount
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

    // important to receive ETH
    receive() external payable {}

    function transferNativeToken(address payable thisAddress, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        thisAddress.transfer(amount);
    }

    function addLP(uint256 addLPTokenAmount) private {
        uint256 deadline = block.timestamp + 15;

        uint256[] memory amountOfEth = getEstimatedSourceTokenforContractToken(
            uniswapRouter.WETH(),
            addLPTokenAmount
        );
        IERC20(contractTokenAddress).approve(
            address(uniswapLPRouter),
            addLPTokenAmount
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

    function addLPExternal(uint256 addLPTokenAmount) external nonReentrant {
        addLP(addLPTokenAmount);
    }

    function addLPAndTransfer(uint256 addLPTokenAmount) external nonReentrant {
        uint256 deadline = block.timestamp + 15;

        uint256[] memory amountOfEth = getEstimatedSourceTokenforContractToken(
            uniswapRouter.WETH(),
            addLPTokenAmount
        );
        IERC20(contractTokenAddress).approve(
            address(uniswapLPRouter),
            addLPTokenAmount
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

    function approveContract(
        address sourceAddress,
        address contractAddy,
        uint256 amount
    ) public onlyOwner {
        IERC20(sourceAddress).approve(contractAddy, amount);
    }    

    //Swap Stuff
    function convertEthToContractToken(
        address exchangeToken,
        uint256 exchangeTokenAmount,
        uint256 ethAMount
    ) private {
        uint256 deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        
        uniswapRouter.swapETHForExactTokens{value: ethAMount }(
            exchangeTokenAmount,
            getPathForSourceTokentoContractToken(exchangeToken),
            address(this),
            deadline
        );

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function convertEthToContractToken2(
        address exchangeToken,
        uint256 exchangeTokenAmount
    ) public payable {
        convertEthToContractToken(exchangeToken, exchangeTokenAmount, msg.value);
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

    // function getEstimatedEthforContractToken(
    //     address exchangeToken,
    //     uint256 contractTokenAmount
    // ) public view returns (uint256[] memory) {
    //     return
    //         uniswapLPRouter.getAmountsOut(
    //             contractTokenAmount,
    //             getPathForSourceTokentoContractToken(exchangeToken)
    //         );
    // }

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
