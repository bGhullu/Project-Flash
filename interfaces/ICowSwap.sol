// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICowSwap {
    function swap(
        address fromToken,
        address toToken,
        uint amountIn,
        uint minReturn
    ) external returns (uint returnAmount);
}
