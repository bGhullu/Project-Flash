// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
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
        address indexed ipoolAddressProvider,
        address uniswapV2Router,
        address indexed uniswapV3Pool,
        address sushiswapRouter,
        address oneInchRouter,
        address indexed owner
    );

    event ArbitrageTriggered(
        address[] tokens,
        uint256[] amountsIn,
        string[] sources
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
        address[] tokens;
        uint256[] amountsIn;
        string[] sources;
    }

    address private constant IPOOL_ADDRESS_PROVIDER =
        0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant UNISWAP_V3_POOL =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant SUSHISWAP_ROUTER =
        0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address private constant ONEINCH_ROUTER =
        0x11111112542D85B3EF69AE05771c2dCCff4fAa26;

    constructor() {
        lendingPool = IPool(
            IPoolAddressesProvider(IPOOL_ADDRESS_PROVIDER).getPool()
        );
        oneInchRouter = I1inchRouter(ONEINCH_ROUTER);
        sushiSwapRouter = IUniswapV2Router02(SUSHISWAP_ROUTER);
        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        uniswapV3Router = ISwapRouter(UNISWAP_V3_POOL);
        owner = msg.sender;

        emit ContractDeployed(
            IPOOL_ADDRESS_PROVIDER,
            UNISWAP_V2_ROUTER,
            UNISWAP_V3_POOL,
            SUSHISWAP_ROUTER,
            ONEINCH_ROUTER,
            owner
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
            arbParams.tokens,
            arbParams.amountsIn,
            arbParams.sources
        );

        uint256 totalDebt = amounts[0] + premiums[0];
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

        IERC20(assets[0]).approve(address(lendingPool), totalDebt0);

        emit OperationExecuted(true);
        return true;
    }

    function initiateFlashLoanArbitrage(
        address[] memory tokens,
        uint256[] memory amountsIn,
        string[] memory sources
    ) public onlyWhenActive nonReentrant {
        require(
            tokens.length == amountsIn.length &&
                tokens.length == sources.length + 1,
            "Mismatched input lengths"
        );

        address[] memory assets = new address[](1);
        assets[0] = tokens[0];
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountsIn[0];
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // No debt mode for token0

        ArbitrageParams memory arbParams = ArbitrageParams(
            tokens,
            amountsIn,
            sources
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
            emit ArbitrageTriggered(tokens, amountsIn, sources);
        } catch {
            revert FlashLoanFailed();
        }
    }

    function executeArbitrage(
        address[] memory tokens,
        uint256[] memory amountsIn,
        string[] memory sources
    ) internal returns (uint256 profit) {
        uint256[] memory amountsOut = new uint256[](tokens.length - 1);

        for (uint256 i = 0; i < tokens.length - 1; i++) {
            amountsOut[i] = executeSwap(
                tokens[i],
                tokens[i + 1],
                amountsIn[i],
                sources[i]
            );
        }

        uint256 totalAmountOut = amountsOut[amountsOut.length - 1];
        uint256 totalAmountIn = amountsIn[0];

        profit = totalAmountOut > totalAmountIn
            ? totalAmountOut - totalAmountIn
            : 0;

        return profit;
    }

    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string memory source
    ) internal returns (uint256 amountOut) {
        if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("uniswapV2"))
        ) {
            amountOut = swapUniswapV2(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("uniswapV3"))
        ) {
            amountOut = swapUniswapV3(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("sushiswap"))
        ) {
            amountOut = swapSushiSwap(tokenIn, tokenOut, amountIn);
        } else if (
            keccak256(abi.encodePacked(source)) ==
            keccak256(abi.encodePacked("swap1inch"))
        ) {
            amountOut = swap1inch(tokenIn, tokenOut, amountIn);
        } else {
            revert UnsupportedSwapSource();
        }
        return amountOut;
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

        uint256[] memory amountsOut = uniswapV2Router.swapExactTokensForTokens(
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
                fee: 3000, // Fee tier for Uniswap V3
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

    function swap1inch(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        address[] memory tokens = new address[](2);
        tokens[0] = tokenIn;
        tokens[1] = tokenOut;

        uint256 amountOut = oneInchRouter.swap(
            tokens,
            amountIn,
            0, // Set amountOutMin to 0 for simplicity; you might want to improve this
            bytes("") // Empty bytes for the 1inch data parameter
        );

        emit SwapExecuted("1inch", tokenIn, tokenOut, amountIn, amountOut);
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
}
