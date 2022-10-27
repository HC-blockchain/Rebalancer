// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import "./MockERC20.sol";

contract MockUniswapPoolMinter {
    IUniswapV3Pool public pool;
    MockERC20 public token0;
    MockERC20 public token1;

    constructor(IUniswapV3Pool _pool, MockERC20 _token0, MockERC20 _token1) {
        pool = _pool;
        token0 = _token0;
        token1 = _token1;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata
    ) external {
        if (amount0Owed > 0) token0.transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) token1.transfer(address(pool), amount1Owed);
    }

    function doMint(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) external {
        pool.mint(address(this), _tickLower, _tickUpper, _amount, new bytes(0));
    }

    function doBurn(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) external {
        pool.burn(_tickLower, _tickUpper, _amount);
    }
}
