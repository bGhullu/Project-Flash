// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
// import "@sushiswap/sdk/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

interface I1inchRouter {
    function swap(
        address[] calldata tokens,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes calldata data
    ) external payable returns (uint256 amountOut);
}

contract AdvancedArbitrageBot is ReentrancyGuard, IFlashLoanReceiver {
    IPool public lendingPool;
    I1inchRouter public oneInchRouter;
    IUniswapV2Router02 public sushiSwapRouter;
    IUniswapV2Router02 public uniswapV2Router;
    ISwapRouter public uniswapV3Router;

    address public owner;
    bool public isActive = true;

    event ArbitrageStarted();
    event ArbitrageStopped();
    event ContractDeployed(
        address indexed lendingPoolAddressesProvider,
        address indexed oneInchRouter,
        address indexed sushiSwapRouter
    );
    event ArbitrageTriggered(
        address token0,
        address token1,
        uint256 amountIn0,
        uint256 amountIn1,
        string sourceLow,
        string sourceHigh
    );
    event SwapExecuted(
        string source,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event OperationExecuted(bool success);

    error NotOwner();
    error ArbitrageInactive();
    error InvalidOperation();
    error InsufficientProfit();
    error UnsupportedSwapSource();
    error FlashLoanFailed();

    struct ArbitrageParams {
        address token0;
        address token1;
        uint256 amountIn0;
        uint256 amountIn1;
        string sourceLow;
        string sourceHigh;
    }

    constructor(
        address _lendingPoolAddressesProvider,
        address _oneInchRouter,
        address _sushiSwapRouter,
        address _uniswapV2Router,
        address _uniswapV3Router
    ) {
        require(
            _lendingPoolAddressesProvider != address(0) &&
                _oneInchRouter != address(0) &&
                _uniswapV2Router != address(0) &&
                _sushiSwapRouter != address(0) &&
                _uniswapV3Router != address(0),
            "One or more router addresses cannot be zero."
        );

        lendingPool = IPool(
            IPoolAddressesProvider(_lendingPoolAddressesProvider).getPool()
        );
        oneInchRouter = I1inchRouter(_oneInchRouter);
        sushiSwapRouter = IUniswapV2Router02(_sushiSwapRouter);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
        owner = msg.sender;

        emit ContractDeployed(
            _lendingPoolAddressesProvider,
            _oneInchRouter,
            _sushiSwapRouter
        );
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyWhenActive() {
        if (!isActive) revert ArbitrageInactive();
        _;
    }

    function startArbitrage() external onlyOwner {
        isActive = true;
        emit ArbitrageStarted();
    }

    function stopArbitrage() external onlyOwner {
        isActive = false;
        emit ArbitrageStopped();
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        if (assets.length == 0 || amounts.length == 0 || premiums.length == 0) {
            revert InvalidOperation();
        }

        ArbitrageParams memory arbParams = abi.decode(
            params,
            (ArbitrageParams)
        );

        uint256 amountOut = executeArbitrage(
            arbParams.token0,
            arbParams.token1,
            arbParams.amountIn0,
            arbParams.amountIn1,
            arbParams.sourceLow,
            arbParams.sourceHigh
        );

        uint256 totalDebt = amounts[0] + premiums[0] + amounts[1] + premiums[1];
        if (amountOut < totalDebt) {
            revert InsufficientProfit();
        }

        return _handleRepayment(assets, amounts, premiums);
    }

    function _handleRepayment(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums
    ) internal returns (bool) {
        uint256 totalDebt0 = amounts[0] + premiums[0];
        uint256 totalDebt1 = amounts[1] + premiums[1];

        IERC20(assets[0]).approve(address(lendingPool), totalDebt0);
        IERC20(assets[1]).approve(address(lendingPool), totalDebt1);

        emit OperationExecuted(true);
        return true;
    }

    function initiateFlashLoanArbitrage(
        address token0,
        address token1,
        uint256 amountIn0,
        uint256 amountIn1,
        string memory sourceLow,
        string memory sourceHigh
    ) public onlyWhenActive nonReentrant {
        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountIn0;
        amounts[1] = amountIn1;
        uint256[] memory modes = new uint256[](2);
        modes[0] = 0; // No debt mode for token0
        modes[1] = 0; // No debt mode for token1

        ArbitrageParams memory arbParams = ArbitrageParams(
            token0,
            token1,
            amountIn0,
            amountIn1,
            sourceLow,
            sourceHigh
        );

        try
            lendingPool.flashLoan(
                address(this),
                assets,
                amounts,
                modes,
                address(this),
                abi.encode(arbParams),
                0
            )
        {
            emit ArbitrageTriggered(
                token0,
                token1,
                amountIn0,
                amountIn1,
                sourceLow,
                sourceHigh
            );
        } catch {
            revert FlashLoanFailed();
        }
    }

    function executeArbitrage(
        address token0,
        address token1,
        uint256 amountIn0,
        uint256 amountIn1,
        string memory sourceLow,
        string memory sourceHigh
    ) internal returns (uint256) {
        uint256 amountOut0 = executeSwap(token0, token1, amountIn0, sourceLow);
        uint256 amountOut1 = executeSwap(token1, token0, amountIn1, sourceLow);

        amountOut0 = executeSwap(token1, token0, amountOut0, sourceHigh);
        amountOut1 = executeSwap(token0, token1, amountOut1, sourceHigh);

        uint256 profit = (amountOut0 + amountOut1 - amountIn0 - amountIn1);

        return profit;
    }

    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string memory source
    ) internal returns (uint256) {
        if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("uniswapV2"))
        ) {
            return swapUniswapV2(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("uniswapV3"))
        ) {
            return swapUniswapV3(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("sushiswap"))
        ) {
            return swapSushiSwap(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("swap1inch"))
        ) {
            return swap1inch(tokenIn, tokenOut, amountIn);
        } else {
            revert UnsupportedSwapSource();
        }
    }

    function swapUniswapV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        TransferHelper.safeApprove(tokenIn, address(uniswapV2Router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amountsOut = sushiSwapRouter.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        emit SwapExecuted(
            "UniswapV2",
            tokenIn,
            tokenOut,
            amountIn,
            amountsOut[1]
        );
        return amountsOut[1];
    }

    function swapUniswapV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        TransferHelper.safeApprove(tokenIn, address(uniswapV3Router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = uniswapV3Router.exactInputSingle(params);

        emit SwapExecuted("UniswapV3", tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

    function swapSushiSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        TransferHelper.safeApprove(tokenIn, address(sushiSwapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amountsOut = sushiSwapRouter.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        emit SwapExecuted(
            "SushiSwap",
            tokenIn,
            tokenOut,
            amountIn,
            amountsOut[1]
        );
        return amountsOut[1];
    }

    // Fixed version of the swap1inch function and utility functions

    function swap1inch(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        // Transfer the specified amount of tokens from the sender to this contract
        TransferHelper.safeTransferFrom(
            tokenIn,
            msg.sender,
            address(this),
            amountIn
        );

        // Approve the router to spend the tokens
        TransferHelper.safeApprove(tokenIn, address(oneInchRouter), amountIn);

        // Prepare the data for the 1inch swap
        address[] memory tokens = new address[](2);
        tokens[0] = tokenIn;
        tokens[1] = tokenOut;

        bytes memory data = abi.encodeWithSelector(
            oneInchRouter.swap.selector,
            tokens,
            amountIn,
            0,
            address(this),
            block.timestamp
        );

        // Execute the swap
        uint256 amountOut = oneInchRouter.swap(tokens, amountIn, 0, data);
        return amountOut;
    }

    function ADDRESSES_PROVIDER()
        external
        view
        returns (IPoolAddressesProvider)
    {
        return lendingPool.ADDRESSES_PROVIDER();
    }

    function POOL() external view returns (IPool) {
        return lendingPool;
    }

    // function max(uint256 a, uint256 b) internal pure returns (uint256) {
    //     return a >= b ? a : b;
    // }

    // function min(uint256 a, uint256 b) internal pure returns (uint256) {
    //     return a < b ? a : b;
    // }
}
