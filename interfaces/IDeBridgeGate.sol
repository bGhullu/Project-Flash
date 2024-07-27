// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDeBridgeGate {
    function send(
        address tokenAddress,
        uint256 amount,
        uint256 chainIdTo,
        bytes memory receiver,
        bytes memory permit,
        bool useAssetFee,
        uint256 referralCode,
        bytes memory autoParams
    ) external payable;

    function claim(
        bytes32 debridgeId,
        uint256 amount,
        address receiver,
        uint256 nonce,
        bytes memory signatures
    ) external;
}
