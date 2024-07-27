// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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

contract Arbitrage is Ownable, IFlashLoanReceiver {
    struct DexAddresses {
        address uniswapRouter;
        address sushiSwapRouter;
        address oneInchRouter;
        address balancerVault;
        address pancakeSwapRouter;
        address cowSwapRouter;
    }

    struct BridgeAddresses {
        address wormholeBridge;
        address jumperBridge;
        address stargateBridge;
        address debridgeBridge;
        address bungeeBridge;
    }

    mapping(uint256 => DexAddresses) public dexAddresses;
    mapping(uint256 => BridgeAddresses) public bridgeAddresses;

    IAaveV3LendingPool public lendingPool;

    constructor(
        uint256[] memory chainIds,
        DexAddresses[] memory dexAddrs,
        BridgeAddresses[] memory bridgeAddrs,
        address _lendingPool
    ) {
        require(chainIds.length == dexAddrs.length, "Mismatched input lengths");
        require(
            chainIds.length == bridgeAddrs.length,
            "Mismatched input lengths"
        );

        for (uint256 i = 0; i < chainIds.length; i++) {
            dexAddresses[chainIds[i]] = dexAddrs[i];
            bridgeAddresses[chainIds[i]] = bridgeAddrs[i];
        }

        lendingPool = IAaveV3LendingPool(_lendingPool);
    }

    function swapOnDex(
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address dexRouter
    ) internal returns (uint[] memory) {
        IERC20(path[0]).approve(dexRouter, amountIn);

        if (dexRouter == dexAddresses[block.chainid].uniswapRouter) {
            return
                IUniswapV2Router(dexRouter).swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == dexAddresses[block.chainid].sushiSwapRouter) {
            return
                IUniswapV2Router(dexRouter).swapExactTokensForTokens(
                    amountIn,
                    amountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
        } else if (dexRouter == dexAddresses[block.chainid].oneInchRouter) {
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

            I1inchAggregationRouterV4(dexRouter).swap(address(this), desc, "");
        } else if (dexRouter == dexAddresses[block.chainid].balancerVault) {
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

            IBalancerVault(dexRouter).swap(
                singleSwap,
                funds,
                amountOutMin,
                block.timestamp
            );
        } else if (dexRouter == dexAddresses[block.chainid].pancakeSwapRouter) {
            return
                IPancakeRouter(dexRouter).swapExactTokensForTokens(
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
        IERC20(fromToken).approve(
            address(dexAddresses[block.chainid].cowSwapRouter),
            amountIn
        );
        return
            ICowSwap(dexAddresses[block.chainid].cowSwapRouter).swap(
                fromToken,
                toToken,
                amountIn,
                minReturn
            );
    }

    function bridgeTokens(
        address token,
        uint256 amount,
        address bridge,
        uint256 destinationChainId,
        address recipient
    ) internal {
        IERC20(token).approve(bridge, amount);

        if (bridge == bridgeAddresses[block.chainid].wormholeBridge) {
            IWormholeBridge(bridge).transferTokens(
                token,
                amount,
                uint16(destinationChainId),
                bytes32(uint256(uint160(recipient))),
                0,
                0
            );
        } else if (bridge == bridgeAddresses[block.chainid].jumperBridge) {
            ISynapseBridge(bridge).deposit(
                token,
                amount,
                destinationChainId,
                recipient
            );
        } else if (bridge == bridgeAddresses[block.chainid].stargateBridge) {
            IStargateRouter.lzTxObj memory lzTxParams = IStargateRouter
                .lzTxObj({
                    dstGasForCall: 0,
                    dstNativeAmount: 0,
                    dstNativeAddr: abi.encode(recipient)
                });
            IStargateRouter(bridge).swap{value: msg.value}(
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
        } else if (bridge == bridgeAddresses[block.chainid].debridgeBridge) {
            IDeBridgeGate(bridge).send{value: msg.value}(
                token,
                amount,
                destinationChainId,
                abi.encodePacked(recipient),
                "",
                true,
                0,
                ""
            );
        } else if (bridge == bridgeAddresses[block.chainid].bungeeBridge) {
            IBungeeBridge(bridge).deposit(
                token,
                amount,
                destinationChainId,
                recipient
            );
        } else {
            revert("Unknown bridge");
        }
    }

    function executeArbitrage(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata dexes,
        address[] calldata bridges,
        uint256 destinationChainId,
        address recipient
    ) external onlyOwner {
        uint256[] memory modes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            modes[i] = 0;
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

        executeArbitrageInternal(
            tokens,
            amounts,
            dexes,
            bridges,
            destinationChainId,
            recipient
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
                amountOutMin = amounts[1];
            } else {
                amountIn = IERC20(tokens[i - 1]).balanceOf(address(this));
                amountOutMin = amounts[i + 1];
            }

            if (
                dexes[i] == address(dexAddresses[block.chainid].cowSwapRouter)
            ) {
                swapOnCowSwap(tokens[i], tokens[i + 1], amountIn, amountOutMin);
            } else {
                address[] memory path = new address[](2);
                path[0] = tokens[i];
                path[1] = tokens[i + 1];
                swapOnDex(path, amountIn, amountOutMin, dexes[i]);
            }

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
