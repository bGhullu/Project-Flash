// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWormholeBridge {
    function transferTokens(
        address token,
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient,
        uint32 nonce,
        uint256 arbiterFee
    ) external payable returns (uint64 sequence);

    function wrapAndTransferETH(
        uint16 recipientChain,
        bytes32 recipient,
        uint32 nonce,
        uint256 arbiterFee
    ) external payable returns (uint64 sequence);

    function completeTransfer(bytes memory encodedVm) external;
}
