// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHarmonyBridge {
    function swap(
        address token,
        uint256 amount,
        uint256 destinationChainId,
        address recipient
    ) external payable;
}
