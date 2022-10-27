# Uniswap V3 Auto Rebalancer

## Protocol Summary
This repository contains the smart contracts for Uniswap v3 auto rebalancing.

## Protocol Components
- UniswapV3AutoRebalancer.sol
  - Contract that rebalances Uniswap v3 position according to the current price.
  - deposit() : Swap the some of input USDC to WETH and provide liquidity to v3.
    - lower open price: current price * 0.95
    - upper open price: current price * 1.05
  - withdraw() : Close the position and return USDC to user.
  - triggerRebalance() : Trigger rebalancing when the condition is met.
    - lower trigger condition: current price < position's lower price * 1.01
    - upper trigger condition: current price > position's upper price * 0.99
- OptimalSwapAmount.sol
  - Calculate optimal ratio and optimal swap amount for deposit
- SafeCastExtend.sol
  - Library for cast type safely
- TickMathWithSpacing.sol
  - Library for tick math with spacing

## Licensing
The primary license for Rebalancer is MIT