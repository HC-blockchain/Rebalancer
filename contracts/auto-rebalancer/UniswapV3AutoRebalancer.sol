// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint128.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';

/// @title Uniswap v3 auto rebalancing contract
contract UniswapV3AutoRebalancer {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    // @dev Price ratio/threshold precision = 1e4
    uint160 private constant RATIO_PRECISION = 10000;
    // @dev lower limit ratio = sqrt(1.01) * 10000
    uint160 private constant LOWER_SQRT_PRICE_LIMIT_THRESHOLD = 10050;
    // @dev upper limit ratio = sqrt(0.99) * 10000
    uint160 private constant UPPER_SQRT_PRICE_LIMIT_THRESHOLD = 9950;
    // @dev lower open ratio = sqrt(0.95) * 10000
    uint160 private constant LOWER_SQRT_PRICE_OPEN_RATIO = 9747;
    // @dev upper open ratio = sqrt(1.05) * 10000
    uint160 private constant UPPER_SQRT_PRICE_OPEN_RATIO = 10247;

    /// @dev The position data struct
    struct Position {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @dev The token ID position data
    mapping(uint256 => Position) private positions;
    /// @dev The ID of the next position.
    uint256 private nextPositionId = 1;

    // @dev Uniswap v3 ETH-USDC pool.
    IUniswapV3Pool public pool;
    // @dev ETH-USDC pool's token0.
    address public immutable token0;
    // @dev ETH-USDC pool's token1.
    address public immutable token1;
    // @dev ETH-USDC pool's tick-spacing.
    int24 public immutable tickSpacing;
    // @dev Flag on whether weth is token0.
    bool public IsWethToken0;

    constructor(address _pool, address _weth, address _usdc) {
        pool = IUniswapV3Pool(_pool);
        token0 = pool.token0();
        token1 = pool.token1();
        tickSpacing = pool.tickSpacing();
        IsWethToken0 = false;
        if (pool.token0() == _weth && pool.token1() == _usdc) {
            IsWethToken0 = true;
            return;
        }
        require(pool.token0() == _usdc && pool.token1() == _weth, "Invalid pool/token address");
    }
}
