// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint128.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';

import '@uniswap/v3-periphery/contracts/libraries/PositionKey.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import "./lib/OptimalSwapAmount.sol";
import "./lib/TickMathWithSpacing.sol";
import "./lib/SafeCastExtend.sol";

import "hardhat/console.sol";

/// @title Uniswap v3 auto rebalancing contract
contract UniswapV3AutoRebalancer {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCastExtend for uint256;
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

    // @dev For reentrancy lock guard.
    bool private constant _ENTERED = true;
    bool private constant _NOT_ENTERED = false;

    event Deposit(
        uint256 indexed positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event Withdraw(
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );

    event Rebalance(
        uint256 indexed positionId,
        uint256 amount0Old,
        uint256 amount1Old,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

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

    /// @dev For reentrancy lock guard.
    bool public _ALREADY_LOCKED;

    /// @dev Reentrancy lock guard.
    modifier lock() {
        require(!_ALREADY_LOCKED, 'Already locked.');
        _ALREADY_LOCKED = _ENTERED;
        _;
        _ALREADY_LOCKED = _NOT_ENTERED;
    }

    /// @dev Prevent calling a function from anyone except UniswapV3 ETH-USDC pool.
    modifier onlyPool() {
        require(msg.sender == address(pool), "onlyPool: Unauthorized.");
        _;
    }

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

    /// @dev Uniswap v3 mint callback function with no data
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata
    ) external onlyPool {
        if (amount0Owed > 0) TransferHelper.safeTransfer(token0, address(pool), amount0Owed);
        if (amount1Owed > 0) TransferHelper.safeTransfer(token1, address(pool), amount1Owed);
    }

    /// @dev Uniswap v3 swap callback function with no data
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external onlyPool {
        require(amount0Delta > 0 || amount1Delta > 0);

        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(token0, address(pool), uint256(amount0Delta));
            return;
        }
        TransferHelper.safeTransfer(token1, address(pool), uint256(amount1Delta));
    }


    /// @dev Deposit usdc and open uniswap v3 position
    /// @param _amountUsdc position open size of usdc
    /// @param _maxIterations max swap iteration count for optimal deposit
    function deposit(uint256 _amountUsdc, uint8 _maxIterations) external lock {
        require(_amountUsdc != 0, "Cannot deposit zero USDC.");
        require(_maxIterations >= 1, "At least one iteration.");
        require(_maxIterations < 10, "Too many iterations.");

        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        address usdc = IsWethToken0 ? token1 : token0;
        TransferHelper.safeTransferFrom(usdc, msg.sender, address(this), _amountUsdc);

        uint256 positionId = nextPositionId++;

        (int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1) =
            openPosition(
                OpenPositionParam({
                    owner: msg.sender,
                    positionId: positionId,
                    balance0Before: balance0Before,
                    balance1Before: balance1Before,
                    maxIterations: _maxIterations
                })
            );

        emit Deposit(positionId, tickLower, tickUpper, liquidity, amount0, amount1);
    }

    struct OpenPositionParam {
        address owner;
        uint256 positionId;
        uint256 balance0Before;
        uint256 balance1Before;
        uint8 maxIterations;
    }

    function openPosition(OpenPositionParam memory _param) internal returns (
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        (uint160 sqrtPriceX96, , , , , ,) = pool.slot0();
        uint160 lowerSqrtRatioX96 = sqrtPriceX96 * LOWER_SQRT_PRICE_OPEN_RATIO / RATIO_PRECISION;
        uint160 upperSqrtRatioX96 = sqrtPriceX96 * UPPER_SQRT_PRICE_OPEN_RATIO / RATIO_PRECISION;

        tickLower = TickMathWithSpacing.getTickAtSqrtRatio(lowerSqrtRatioX96, tickSpacing);
        tickUpper = TickMathWithSpacing.getTickAtSqrtRatio(upperSqrtRatioX96, tickSpacing);

        for (uint8 i = 0; i < _param.maxIterations; i++) {
            (int256 swapAmountIn, bool zeroForOne) =
            OptimalSwapAmount.getOptimalSwapAmount(
                IERC20(token0).balanceOf(address(this)).sub(_param.balance0Before),
                IERC20(token1).balanceOf(address(this)).sub(_param.balance1Before),
                sqrtPriceX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96
            );

            if (swapAmountIn == 0) break;

            pool.swap(
                address(this),
                zeroForOne,
                swapAmountIn,
                zeroForOne ? lowerSqrtRatioX96: upperSqrtRatioX96,
                new bytes(0)
            );

            (sqrtPriceX96, , , , , ,) = pool.slot0();
        }

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            lowerSqrtRatioX96,
            upperSqrtRatioX96,
            IERC20(token0).balanceOf(address(this)).sub(_param.balance0Before),
            IERC20(token1).balanceOf(address(this)).sub(_param.balance1Before)
        );

        (amount0, amount1) = pool.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            new bytes(0)
        );

        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.positions(positionKey);

        positions[_param.positionId] = Position({
            owner: _param.owner,
            tickLower : tickLower,
            tickUpper : tickUpper,
            liquidity : liquidity,
            feeGrowthInside0LastX128 : feeGrowthInside0LastX128,
            feeGrowthInside1LastX128 : feeGrowthInside1LastX128,
            tokensOwed0 : IERC20(token0).balanceOf(address(this)).sub(_param.balance0Before).toUint128(),
            tokensOwed1 : IERC20(token1).balanceOf(address(this)).sub(_param.balance1Before).toUint128()
        });
    }

    function withdraw(uint256 _positionId) external lock {
        require(positions[_positionId].owner == msg.sender, "Not position owner.");

        (uint256 amount0, uint256 amount1) = closePosition(_positionId);

        uint256 totalAmount0 = amount0.add(positions[_positionId].tokensOwed0);
        uint256 totalAmount1 = amount1.add(positions[_positionId].tokensOwed1);

        // Swap WETH to USDC
        bool zeroForOne = IsWethToken0 ? true : false;
        address usdc = IsWethToken0 ? token1 : token0;
        uint256 usdcBalanceBeforeSwap = IERC20(usdc).balanceOf(address(this));

        pool.swap(
            address(this),
            zeroForOne,
            zeroForOne ? totalAmount0.toInt256() : totalAmount1.toInt256(),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            new bytes(0)
        );

        uint withdrawUsdcAmount =
            IERC20(usdc).balanceOf(address(this))
                .add(zeroForOne ? amount1 : amount0)
                .sub(usdcBalanceBeforeSwap);

        TransferHelper.safeTransfer(
            usdc,
            msg.sender,
            withdrawUsdcAmount
        );
        delete positions[_positionId];

        emit Withdraw(_positionId, totalAmount0, totalAmount1);
    }

    function closePosition(
        uint256 _positionId
    ) internal returns (
        uint256 amount0,
        uint256 amount1
    ) {
        Position storage position = positions[_positionId];
        require(position.liquidity != 0, "Already closed position.");

        (amount0, amount1) = pool.burn(position.tickLower, position.tickUpper, position.liquidity);
        collectFromPool(position.tickLower, position.tickUpper);

        bytes32 positionKey = PositionKey.compute(address(this), position.tickLower, position.tickUpper);
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.positions(positionKey);

        position.tokensOwed0 +=
        uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                    position.liquidity,
                FixedPoint128.Q128
            )
        );
        position.tokensOwed1 +=
        uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                    position.liquidity,
                FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        position.liquidity = 0;
    }

    function collectFromPool(
        int24 _tickLower,
        int24 _tickUpper
    ) internal returns (
        uint128 amount0,
        uint128 amount1
    ) {
        // the actual amounts collected are returned
        (amount0, amount1) = pool.collect(
            address(this),
            _tickLower,
            _tickUpper,
            type(uint128).max,
            type(uint128).max
        );
    }

    function triggerRebalance(uint256 _positionId, uint8 _maxIterations) external lock {
        require(_maxIterations >= 1, "At least 1 iteration.");
        require(
            _maxIterations >= 3
            || positions[_positionId].owner == msg.sender,
            "At least 3 iteration for others."
        );
        require(_maxIterations < 10, "Too many iterations.");
        require(canTriggerRebalance(_positionId), "Not exceed trigger conditions");

        (uint256 amount0Old, uint256 amount1Old) = closePosition(_positionId);

        Position memory position = positions[_positionId];

        amount0Old = amount0Old.add(position.tokensOwed0);
        amount1Old = amount1Old.add(position.tokensOwed1);

        uint256 balance0Before = IERC20(token0).balanceOf(address(this)).sub(amount0Old);
        uint256 balance1Before = IERC20(token1).balanceOf(address(this)).sub(amount1Old);

        (int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1) =
            openPosition(
                OpenPositionParam({
                    owner: position.owner,
                    positionId: _positionId,
                    balance0Before: balance0Before,
                    balance1Before: balance1Before,
                    maxIterations: _maxIterations
                })
            );

        emit Rebalance(_positionId, amount0Old, amount1Old, tickLower, tickUpper, liquidity, amount0, amount1);
    }

    function canTriggerRebalance(uint256 _positionId) internal view returns (bool) {
        (uint160 sqrtPriceX96, , , , , ,) = pool.slot0();
        uint160 lowerSqrtRatioX96 = TickMath.getSqrtRatioAtTick(positions[_positionId].tickLower);
        uint160 upperSqrtRatioX96 = TickMath.getSqrtRatioAtTick(positions[_positionId].tickUpper);

        if (sqrtPriceX96 >= lowerSqrtRatioX96 * LOWER_SQRT_PRICE_LIMIT_THRESHOLD &&
            sqrtPriceX96 <= upperSqrtRatioX96 * UPPER_SQRT_PRICE_LIMIT_THRESHOLD) return false;
        return true;
    }
}
