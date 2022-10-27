// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';

library OptimalSwapAmount {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    function getOptimalSwapAmount(
        uint256 _amount0,
        uint256 _amount1,
        uint160 _sqrtPriceX96,
        uint160 _lowerSqrtRatioX96,
        uint160 _upperSqrtRatioX96
    ) internal pure returns (
        int256 swapAmountIn,
        bool zeroForOne
    ){
        zeroForOne = true;
        (uint256 optimalRatioNumerator, uint256 optimalRatioDenominator) = getOptimalRatio(
            _sqrtPriceX96,
            _lowerSqrtRatioX96,
            _upperSqrtRatioX96
        );

        uint inputTokenPrice = FullMath.mulDiv(_sqrtPriceX96, _sqrtPriceX96, 2 ** 96);
        uint inputAmount = _amount0;
        uint outputAmount = _amount1;
        if (_amount0 * optimalRatioDenominator < optimalRatioNumerator * _amount1) {
            (inputAmount, outputAmount) = (_amount1, _amount0);
            (optimalRatioNumerator, optimalRatioDenominator) = (optimalRatioDenominator, optimalRatioNumerator);
            inputTokenPrice = 2 ** 192 / inputTokenPrice;
            zeroForOne = false;
        }

        uint numerator = FullMath.mulDiv(optimalRatioNumerator, outputAmount, optimalRatioDenominator);
        uint denominator = FullMath.mulDiv(optimalRatioNumerator, inputTokenPrice, optimalRatioDenominator).add(2 ** 96);

        if (numerator > inputAmount) {
            swapAmountIn = int256(FullMath.mulDiv((numerator - inputAmount), 2 ** 96, denominator)) * (-1);
        } else {
            swapAmountIn = int256(FullMath.mulDiv((inputAmount - numerator), 2 ** 96, denominator));
        }
    }

    function getOptimalRatio(
        uint160 currentSqrtPriceX96,
        uint160 lowerSqrtRatioX96,
        uint160 upperSqrtRatioX96
    ) internal pure returns (
        uint256 numerator,
        uint256 denominator
    ){
        if (currentSqrtPriceX96 > upperSqrtRatioX96 ||
            currentSqrtPriceX96 < lowerSqrtRatioX96
        ) {
            numerator = 0;
            denominator = 1;
        } else {

            numerator = SqrtPriceMath.getAmount0Delta(
                currentSqrtPriceX96,
                upperSqrtRatioX96,
                1e18,
                true
            );
            denominator = SqrtPriceMath.getAmount1Delta(
                currentSqrtPriceX96,
                lowerSqrtRatioX96,
                1e18,
                true
            );
        }
    }
}
