// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConfigurableParameters {
    uint256 public slippageTolerance;
    uint256 public transactionFee;
    uint256 public gasCost;
    uint256 public liquidityThreshold;
    address public receiverAddress;

    constructor(
        uint256 _slippageTolerance,
        uint256 _transactionFee,
        uint256 _gasCost,
        uint256 _liquidityThreshold,
        address _receiverAddress
    ) {
        slippageTolerance = _slippageTolerance;
        transactionFee = _transactionFee;
        gasCost = _gasCost;
        liquidityThreshold = _liquidityThreshold;
        receiverAddress = _receiverAddress;
    }

    function updateSlippageTolerance(uint256 _slippageTolerance) external {
        slippageTolerance = _slippageTolerance;
    }

    function updateTransactionFee(uint256 _transactionFee) external {
        transactionFee = _transactionFee;
    }

    function updateGasCost(uint256 _gasCost) external {
        gasCost = _gasCost;
    }

    function updateLiquidityThreshold(uint256 _liquidityThreshold) external {
        liquidityThreshold = _liquidityThreshold;
    }

    function updateReceiverAddress(address _receiverAddress) external {
        receiverAddress = _receiverAddress;
    }
}
