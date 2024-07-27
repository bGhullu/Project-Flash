// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@aave/protocol-v2/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";

// Interface imports
import "../interfaces/I1inchAggregationRouterV4.sol";
import "../interfaces/IBalancerVault.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/ICowSwap.sol";
import "../interfaces/IAaveV3LendingPool.sol";
import "../interfaces/IWormholeBridge.sol";
import "../interfaces/ISynapseBridge.sol";
import "../interfaces/IStargateRouter.sol";
import "../interfaces/IDeBridgeGate.sol";
import "../interfaces/IBungeeBridge.sol";

contract Arbitrage is Ownable, IFlashLoanReceiver {
    // Router addresses
    IUniswapV2Router public uniswapRouter;
    IUniswapV2Router public sushiSwapRouter;
    I1inchAggregationRouterV4 public oneInchRouter;
    IBalancerVault public balancerVault;
    IPancakeRouter public pancakeSwapRouter;
    ICowSwap public cowSwapRouter;

    // Bridge addresses
    IWormholeBridge public wormholeBridge;
    ISynapseBridge public jumperBridge;
    IStargateRouter public stargateBridge;
    IDeBridgeGate public debridgeBridge;
    IBungeeBridge public bungeeBridge;

    IAaveV3LendingPool public lendingPool;

    // Constructor to initialize all the router and bridge addresses
    constructor(
        address _uniswapRouter,
        address _sushiSwapRouter,
        address _oneInchRouter,
        address _balancerVault,
        address _pancakeSwapRouter,
        address _cowSwapRouter,
        address _wormholeBridge,
        address _jumperBridge,
        address _stargateBridge,
        address _debridgeBridge,
        address _bungeeBridge,
        address _lendingPool
    ) {
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        sushiSwapRouter = IUniswapV2Router(_sushiSwapRouter);
        oneInchRouter = I1inchAggregationRouterV4(_oneInchRouter);
        balancerVault = IBalancerVault(_balancerVault);
        pancakeSwapRouter = IPancakeRouter(_pancakeSwapRouter);
        cowSwapRouter = ICowSwap(_cowSwapRouter);

        wormholeBridge = IWormholeBridge(_wormholeBridge);
        jumperBridge = ISynapseBridge(_jumperBridge);
        stargateBridge = IStargateRouter(_stargateBridge);
        debridgeBridge = IDeBridgeGate(_debridgeBridge);
        bungeeBridge = IBungeeBridge(_bungeeBridge);

        lendingPool = IAaveV3LendingPool(_lendingPool);
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
            I1inchAggregationRouterV4.SwapDescription
                memory desc = I1inchAggregationRouterV4.SwapDescription({
                    srcToken: path[0],
                    dstToken: path[path.length - 1],
                    srcReceiver: payable(address(this)),
                    dstReceiver: payable(address(this)),
                    amount: amountIn,
                    minReturnAmount: amountOutMin,
                    flags: 0,
                    permit: ""
                });

            oneInchRouter.swap(address(this), desc, "");
        } else if (dexRouter == address(balancerVault)) {
            IBalancerVault.SingleSwap memory singleSwap = IBalancerVault
                .SingleSwap({
                    poolId: keccak256(abi.encodePacked(path)),
                    kind: IBalancerVault.SwapKind.GIVEN_IN,
                    assetIn: path[0],
                    assetOut: path[path.length - 1],
                    amount: amountIn,
                    userData: ""
                });

            IBalancerVault.FundManagement memory funds = IBalancerVault
                .FundManagement({
                    sender: address(this),
                    fromInternalBalance: false,
                    recipient: payable(address(this)),
                    toInternalBalance: false
                });

            balancerVault.swap(
                singleSwap,
                funds,
                amountOutMin,
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
        uint256 destinationChainId,
        address recipient
    ) internal {
        IERC20(token).approve(bridge, amount);

        if (bridge == address(wormholeBridge)) {
            wormholeBridge.transferTokens(
                token,
                amount,
                uint16(destinationChainId),
                bytes32(uint256(uint160(recipient))),
                0,
                0
            );
        } else if (bridge == address(jumperBridge)) {
            jumperBridge.deposit(token, amount, destinationChainId, recipient);
        } else if (bridge == address(stargateBridge)) {
            IStargateRouter.lzTxObj memory lzTxParams = IStargateRouter
                .lzTxObj({
                    dstGasForCall: 0,
                    dstNativeAmount: 0,
                    dstNativeAddr: abi.encode(recipient)
                });
            stargateBridge.swap{value: msg.value}(
                uint16(destinationChainId),
                1,
                1,
                payable(address(this)),
                amount,
                amount,
                lzTxParams,
                abi.encodePacked(recipient),
                ""
            );
        } else if (bridge == address(debridgeBridge)) {
            debridgeBridge.send{value: msg.value}(
                token,
                amount,
                destinationChainId,
                abi.encodePacked(recipient),
                "",
                true,
                0,
                ""
            );
        } else if (bridge == address(bungeeBridge)) {
            bungeeBridge.deposit(token, amount, destinationChainId, recipient);
        } else {
            revert("Unknown bridge");
        }
    }

    // Function to execute an arbitrage trade, possibly involving cross-chain transfer
    function executeArbitrage(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata dexes,
        address[] calldata bridges,
        uint256 destinationChainId,
        address recipient
    ) external onlyOwner {
        // Initiate flashloan
        uint256[] memory modes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            modes[i] = 0; // 0 means no debt (flashloan)
        }

        bytes memory params = abi.encode(
            tokens,
            amounts,
            dexes,
            bridges,
            destinationChainId,
            recipient
        );

        lendingPool.flashLoan(
            address(this),
            tokens,
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
            address[] memory tokens,
            uint256[] memory amounts,
            address[] memory dexes,
            address[] memory bridges,
            uint256 destinationChainId,
            address recipient
        ) = abi.decode(
                params,
                (address[], uint256[], address[], address[], uint256, address)
            );

        // Execute arbitrage logic
        executeArbitrageInternal(
            tokens,
            amounts,
            dexes,
            bridges,
            destinationChainId,
            recipient
        );

        // Repay flash loan
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            IERC20(assets[i]).approve(address(lendingPool), amountOwing);
        }

        return true;
    }

    // Internal function to execute arbitrage logic
    function executeArbitrageInternal(
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory dexes,
        address[] memory bridges,
        uint256 destinationChainId,
        address recipient
    ) internal {
        uint numDexes = dexes.length;
        uint numBridges = bridges.length;
        uint amountIn;
        uint amountOutMin;

        for (uint i = 0; i < numDexes; i++) {
            if (i == 0) {
                amountIn = amounts[0];
                amountOutMin = amounts[1]; // assuming amounts[1] is the minimum output for the first swap
            } else {
                amountIn = IERC20(tokens[i - 1]).balanceOf(address(this)); // amount from the previous swap
                amountOutMin = amounts[i + 1]; // next amountOutMin
            }

            if (dexes[i] == address(cowSwapRouter)) {
                swapOnCowSwap(tokens[i], tokens[i + 1], amountIn, amountOutMin);
            } else {
                address[] memory path = new address[](2);
                path[0] = tokens[i];
                path[1] = tokens[i + 1];
                swapOnDex(path, amountIn, amountOutMin, dexes[i]);
            }

            // If there are bridges, handle bridging
            if (i < numBridges && bridges[i] != address(0)) {
                bridgeTokens(
                    tokens[i + 1],
                    amountIn,
                    bridges[i],
                    destinationChainId,
                    recipient
                );
            }
        }
    }
}
