// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@aave/protocol-v2/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";

// Interface imports
import "../interfaces/advancedFlashLoan.sol";

contract Arbitrage is Ownable, IFlashLoanReceiver {
    // Router addresses
    IUniswapV2Router public uniswapRouter;
    IUniswapV2Router public sushiSwapRouter;
    IUniswapV2Router public oneInchRouter;
    IUniswapV2Router public balancerRouter;
    IUniswapV2Router public pancakeSwapRouter;
    ICowSwap public cowSwapRouter;

    // Bridge addresses
    ICommonBridge public wormholeBridge;
    ICommonBridge public jumperBridge;
    ICommonBridge public stargateBridge;
    ICommonBridge public debridgeBridge;
    ICommonBridge public bungeeBridge;

    ILendingPoolAddressesProvider public provider;
    ILendingPool public lendingPool;

    // Constructor to initialize all the router and bridge addresses
    constructor(
        address _uniswapRouter,
        address _sushiSwapRouter,
        address _oneInchRouter,
        address _balancerRouter,
        address _pancakeSwapRouter,
        address _cowSwapRouter,
        address _wormholeBridge,
        address _jumperBridge,
        address _stargateBridge,
        address _debridgeBridge,
        address _bungeeBridge,
        address _provider
    ) {
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        sushiSwapRouter = IUniswapV2Router(_sushiSwapRouter);
        oneInchRouter = IUniswapV2Router(_oneInchRouter);
        balancerRouter = IUniswapV2Router(_balancerRouter);
        pancakeSwapRouter = IUniswapV2Router(_pancakeSwapRouter);
        cowSwapRouter = ICowSwap(_cowSwapRouter);

        wormholeBridge = ICommonBridge(_wormholeBridge);
        jumperBridge = ICommonBridge(_jumperBridge);
        stargateBridge = ICommonBridge(_stargateBridge);
        debridgeBridge = ICommonBridge(_debridgeBridge);
        bungeeBridge = ICommonBridge(_bungeeBridge);

        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());
    }

    // Function to swap tokens on the specified DEX
    function swapOnDex(
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address dexRouter
    ) internal returns (uint[] memory) {
        IERC20(path[0]).approve(dexRouter, amountIn);

        if (dexRouter == address(uniswapRouter)) {
            return
                uniswapRouter.swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == address(sushiSwapRouter)) {
            return
                sushiSwapRouter.swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == address(oneInchRouter)) {
            return
                oneInchRouter.swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == address(balancerRouter)) {
            return
                balancerRouter.swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == address(pancakeSwapRouter)) {
            return
                pancakeSwapRouter.swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else {
            revert("Unknown DEX router");
        }
    }

    function swapOnCowSwap(
        address fromToken,
        address toToken,
        uint amountIn,
        uint minReturn
    ) internal returns (uint returnAmount) {
        IERC20(fromToken).approve(address(cowSwapRouter), amountIn);
        return cowSwapRouter.swap(fromToken, toToken, amountIn, minReturn);
    }

    // Function to bridge tokens to another chain
    function bridgeTokens(
        address token,
        uint256 amount,
        address bridge,
        string calldata destinationChain,
        address recipient
    ) internal {
        IERC20(token).approve(bridge, amount);

        if (bridge == address(wormholeBridge)) {
            wormholeBridge.transfer(token, amount, destinationChain, recipient);
        } else if (bridge == address(jumperBridge)) {
            jumperBridge.transfer(token, amount, destinationChain, recipient);
        } else if (bridge == address(stargateBridge)) {
            stargateBridge.transfer(token, amount, destinationChain, recipient);
        } else if (bridge == address(debridgeBridge)) {
            debridgeBridge.transfer(token, amount, destinationChain, recipient);
        } else if (bridge == address(bungeeBridge)) {
            bungeeBridge.transfer(token, amount, destinationChain, recipient);
        } else {
            revert("Unknown bridge");
        }
    }

    // Function to execute an arbitrage trade, possibly involving cross-chain transfer
    function executeArbitrage(
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address dexRouter,
        address bridge,
        string calldata destinationChain,
        address recipient
    ) internal {
        if (dexRouter == address(cowSwapRouter)) {
            swapOnCowSwap(
                path[0],
                path[path.length - 1],
                amountIn,
                amountOutMin
            );
        } else {
            // Swap tokens on the specified DEX
            swapOnDex(path, amountIn, amountOutMin, dexRouter);
        }

        // If bridge is specified, bridge the tokens to another chain
        if (bridge != address(0)) {
            bridgeTokens(
                path[path.length - 1],
                amountIn,
                bridge,
                destinationChain,
                recipient
            );
        }
    }

    // Function to initiate a flash loan from Aave
    function initiateFlashloan(
        address[] calldata assets,
        uint256[] calldata amounts,
        address[] calldata path,
        uint amountOutMin,
        address dexRouter,
        address bridge,
        string calldata destinationChain,
        address recipient
    ) external onlyOwner {
        uint256[] memory modes = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0; // 0 means no debt (flashloan)
        }

        bytes memory params = abi.encode(
            path,
            amountOutMin,
            dexRouter,
            bridge,
            destinationChain,
            recipient
        );

        lendingPool.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    // This function is called after the contract has received the flash loaned amount
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(
            msg.sender == address(lendingPool),
            "Caller must be LendingPool"
        );

        (
            address[] memory path,
            uint amountOutMin,
            address dexRouter,
            address bridge,
            string memory destinationChain,
            address recipient
        ) = abi.decode(
                params,
                (address[], uint, address, address, string, address)
            );

        // Execute arbitrage logic
        executeArbitrage(
            path,
            amounts[0],
            amountOutMin,
            dexRouter,
            bridge,
            destinationChain,
            recipient
        );

        // Repay flash loan
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            IERC20(assets[i]).approve(address(lendingPool), amountOwing);
        }

        return true;
    }
}
