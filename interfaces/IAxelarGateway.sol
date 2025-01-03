// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAxelarGateway {
    function sendToken(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount
    ) external;
}
