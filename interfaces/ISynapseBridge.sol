// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISynapseBridge {
    function deposit(
        address to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function redeem(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external;

    function withdraw(address token, uint256 amount, address receiver) external;

    function getDeposit(
        uint256 nonce
    )
        external
        view
        returns (address to, uint256 chainId, address token, uint256 amount);
}
