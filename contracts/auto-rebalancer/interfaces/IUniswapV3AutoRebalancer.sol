// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

/// @title Interface of uniswap v3 auto rebalancing contract
interface IUniswapV3AutoRebalancer {
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

    /// @dev Deposit usdc and open uniswap v3 position.
    /// @param _amountUsdc position open size of usdc
    /// @param _maxIterations max swap iteration count for optimal deposit.
    function deposit(uint256 _amountUsdc, uint8 _maxIterations) external;

    /// @dev Close v3 position and Withdraw USDC to owner.
    /// @param _positionId position id
    function withdraw(uint256 _positionId) external;

    /// @dev Trigger close and open position at ㅁ rebalanced price on the same position id.
    /// @param _positionId position id
    /// @param _maxIterations max swap iteration count for optimal deposit.
    function triggerRebalance(uint256 _positionId, uint8 _maxIterations) external;
}
