import {loadFixture} from 'ethereum-waffle'
import {BigNumberish, constants, Wallet} from 'ethers'
import {ethers, waffle} from 'hardhat'
import {
    IUniswapV3Factory,
    SwapRouter,
    MockERC20,
    UniswapV3AutoRebalancer
} from '../typechain'
import rebalancerFixture from './shared/rebalancerFixture'

describe('UniswapV3AutoRebalancer', () => {
    let factory: IUniswapV3Factory
    let router: SwapRouter
    let weth: MockERC20
    let usdc: MockERC20
    let rebalancer: UniswapV3AutoRebalancer

    beforeEach('load fixture', async () => {
        const [tester] = await ethers.getSigners();
        ({factory, router, weth, usdc, rebalancer} = await loadFixture(rebalancerFixture))
        await weth.mint(tester.address, "10000000000000000000000")
        await weth.approve(rebalancer.address, constants.MaxUint256)

        await usdc.mint(tester.address, "10000000000000000000000")
        await usdc.approve(rebalancer.address, constants.MaxUint256)
    })

    describe('#success test', async () => {
        it('deposit success test 1', async () => {
            await rebalancer.deposit("1000000000000000000", "1");
        })
        it('deposit success test 2', async () => {
            await rebalancer.deposit("2000000000000000000", "3");
        })
        it('deposit success test 3 ', async () => {
            await rebalancer.deposit("300000000000000000", "5");
        })
        it('deposit success test 4 ', async () => {
            await rebalancer.deposit("5000000000000000000", "3");
        })
        it('deposit success test 5 ', async () => {
            await rebalancer.deposit("10000000000000000000", "4");
        })
        it('deposit success test 6 ', async () => {
            await rebalancer.deposit("10000000000000000000", "9");
        })

        it('withdraw success test 1', async () => {
            await rebalancer.withdraw("1");
        })
        it('withdraw success test 2', async () => {
            await rebalancer.withdraw("2");
        })
        it('withdraw success test 3 ', async () => {
            await rebalancer.withdraw("3");
        })

        it('triggerRebalance success test 1 ', async () => {
            await rebalancer.triggerRebalance("4", "3");
        })
        it('triggerRebalance success test 2 ', async () => {
            await rebalancer.triggerRebalance("5", "3");
        })
        it('triggerRebalance success test 3 ', async () => {
            await rebalancer.triggerRebalance("6", "3");
        })
    })
})
