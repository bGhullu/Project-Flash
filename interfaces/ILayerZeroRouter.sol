// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILayerZeroRouter {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;
}
