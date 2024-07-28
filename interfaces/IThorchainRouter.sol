// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IThorchainRouter {
    function deposit(
        address payable vault,
        address asset,
        uint amount,
        string calldata memo
    ) external payable;
}
