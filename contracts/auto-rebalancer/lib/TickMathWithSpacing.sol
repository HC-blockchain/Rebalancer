// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

library TickMathWithSpacing {
    function getTickAtSqrtRatio(uint160 sqrtPriceX96, int24 tickSpacing) internal pure returns (int24 tick) {
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        if (tick % tickSpacing != 0) {
            tick /= tickSpacing;
            tick *= tickSpacing;
        }
    }
}
