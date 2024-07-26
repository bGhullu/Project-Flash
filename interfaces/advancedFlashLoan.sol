// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ICowSwap {
    function swap(
        address fromToken,
        address toToken,
        uint amount,
        uint minReturn
    ) external returns (uint returnAmount);
}

interface ICommonBridge {
    function transfer(
        address token,
        uint256 amount,
        string calldata destinationChain,
        address recipient
    ) external;
}

interface ILendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);
}

interface ILendingPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}
