// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBungeeBridge {
    function deposit(
        address token,
        uint256 amount,
        uint256 destinationChainId,
        address receiver
    ) external;

    function withdraw(address token, uint256 amount, address receiver) external;

    function getDeposit(
        uint256 nonce
    )
        external
        view
        returns (
            address token,
            uint256 amount,
            uint256 destinationChainId,
            address receiver
        );

    function getWithdrawal(
        uint256 nonce
    ) external view returns (address token, uint256 amount, address receiver);
}
