// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function addLiquidity(uint256 poolId, uint256 amount, address to) external;

    function swap(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address refundAddress,
        uint256 amountLD,
        uint256 minAmountLD,
        lzTxObj calldata lzTxParams,
        bytes calldata to,
        bytes calldata payload
    ) external payable;

    function redeemLocal(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address refundAddress,
        uint256 amountLP,
        uint256 minAmountLD,
        bytes calldata to,
        lzTxObj calldata lzTxParams
    ) external payable;

    function instantRedeemLocal(
        uint256 srcPoolId,
        uint256 amountLP,
        address to
    ) external returns (uint256 amountLD);
}
