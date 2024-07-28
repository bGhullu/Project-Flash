// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRainbowBridge {
    function transfer(
        address token,
        uint256 amount,
        address recipient,
        uint256 destinationChainId
    ) external;
}
