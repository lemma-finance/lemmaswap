// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

interface ILemmaSwap {

    function addLiquidity_independentAmounts(
        address stable,
        address variable,
        uint256 amountStable,
        uint256 amountVariable,
        uint256 unusedStable,
        uint256 unusedVariable,
        address to,
        uint256 deadline
    ) external returns (uint256 amountXA, uint256 amountXB, uint256 unused);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
