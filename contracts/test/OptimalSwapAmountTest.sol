// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "../auto-rebalancer/lib/OptimalSwapAmount.sol";

contract OptimalSwapAmountTest {
    function getOptimalSwapAmount(
        uint256 _amount0,
        uint256 _amount1,
        uint160 _sqrtPriceX96,
        uint160 _lowerSqrtRatioX96,
        uint160 _upperSqrtRatioX96
    ) external pure returns (
        int256 swapAmountIn,
        bool zeroForO
    ) {
        (swapAmountIn, zeroForO) =
            OptimalSwapAmount.getOptimalSwapAmount(
                _amount0,
                _amount1,
                _sqrtPriceX96,
                _lowerSqrtRatioX96,
                _upperSqrtRatioX96
            );
    }

    function getOptimalRatio(
        uint160 currentSqrtPriceX96,
        uint160 lowerSqrtRatioX96,
        uint160 upperSqrtRatioX96
    ) external pure returns (
        uint256 numerator,
        uint256 denominator
    ){
        (numerator, denominator) = OptimalSwapAmount.getOptimalRatio(currentSqrtPriceX96, lowerSqrtRatioX96, upperSqrtRatioX96);
    }
}
