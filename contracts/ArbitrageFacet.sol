// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/protocol-v2/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
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
import "./DiamondStorageLib.sol";

contract ArbitrageFacet is IFlashLoanReceiver {
    using DiamondStorageLib for DiamondStorageLib.DiamondStorage;

    IAaveV3LendingPool public lendingPool;

    function initializeArbitrage(address _lendingPool) external {
        DiamondStorageLib.enforceIsContractOwner();

        lendingPool = IAaveV3LendingPool(_lendingPool);
    }

    function setDexAddress(
        uint256 chainId,
        string memory dexName,
        address dexAddress
    ) external {
        DiamondStorageLib.enforceIsContractOwner();
        DiamondStorageLib.setDexAddress(chainId, dexName, dexAddress);
    }

    function setBridgeAddress(
        uint256 chainId,
        string memory bridgeName,
        address bridgeAddress
    ) external {
        DiamondStorageLib.enforceIsContractOwner();
        DiamondStorageLib.setBridgeAddress(chainId, bridgeName, bridgeAddress);
    }

    function executeArbitrage(
        address[] calldata tokens,
        uint256[] calldata amounts,
        DexOperation[] calldata dexOperations,
        BridgeOperation[] calldata bridgeOperations
    ) external {
        DiamondStorageLib.enforceIsContractOwner();

        uint256[] memory modes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            modes[i] = 0;
        }

        bytes memory params = abi.encode(
            tokens,
            amounts,
            dexOperations,
            bridgeOperations
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
            DexOperation[] memory dexOperations,
            BridgeOperation[] memory bridgeOperations
        ) = abi.decode(
                params,
                (address[], uint256[], DexOperation[], BridgeOperation[])
            );

        executeArbitrageInternal(
            tokens,
            amounts,
            dexOperations,
            bridgeOperations
        );

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            IERC20(assets[i]).approve(address(lendingPool), amountOwing);
        }

        return true;
    }

    function executeArbitrageInternal(
        address[] memory tokens,
        uint256[] memory amounts,
        DexOperation[] memory dexOperations,
        BridgeOperation[] memory bridgeOperations
    ) internal {
        for (uint i = 0; i < dexOperations.length; i++) {
            DexOperation memory dexOp = dexOperations[i];
            if (dexOp.dexAddress == address(0)) {
                dexOp.dexAddress = DiamondStorageLib.getDexAddress(
                    dexOp.chainId,
                    "dexName"
                ); // Replace "dexName" with actual dex name
            }
            if (dexOp.dexAddress == address(cowSwapRouter)) {
                swapOnCowSwap(
                    dexOp.path[0],
                    dexOp.path[1],
                    dexOp.amountIn,
                    dexOp.amountOutMin
                );
            } else {
                swapOnDex(
                    dexOp.path,
                    dexOp.amountIn,
                    dexOp.amountOutMin,
                    dexOp.dexAddress
                );
            }
        }

        for (uint i = 0; i < bridgeOperations.length; i++) {
            BridgeOperation memory bridgeOp = bridgeOperations[i];
            if (bridgeOp.bridgeAddress == address(0)) {
                bridgeOp.bridgeAddress = DiamondStorageLib.getBridgeAddress(
                    bridgeOp.destinationChainId,
                    "bridgeName"
                ); // Replace "bridgeName" with actual bridge name
            }
            bridgeTokens(
                bridgeOp.token,
                bridgeOp.amount,
                bridgeOp.bridgeAddress,
                bridgeOp.destinationChainId,
                bridgeOp.recipient
            );
        }
    }

    function swapOnDex(
        address[] memory path,
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
}
