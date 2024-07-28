// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRenVM {
    function mint(
        bytes calldata pHash,
        bytes calldata amount,
        bytes calldata nHash,
        bytes calldata sig
    ) external;
}
