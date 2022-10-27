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
import {expect} from "chai";

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

    describe('#simple success test', async () => {
        it('deposit success test 1', async () => {
            await rebalancer.deposit("1000000", "1");
        })
        it('deposit success test 2', async () => {
            await rebalancer.deposit("20000000", "2");
        })
        it('deposit success test 3 ', async () => {
            await rebalancer.deposit("300000000", "3");
        })
        it('deposit success test 4 ', async () => {
            await rebalancer.deposit("4000000000", "3");
        })
        it('deposit success test 5 ', async () => {
            await rebalancer.deposit("100000000000", "1");
        })
        it('deposit success test 6 ', async () => {
            await rebalancer.deposit("100000000000", "3");
        })
        it('deposit success test 7 ', async () => {
            await rebalancer.deposit("100000000000", "3");
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

        // If you want to rebalance test, Change canTriggerRebalance() result to true.
        // it('triggerRebalance success test 1 ', async () => {
        //     await rebalancer.triggerRebalance("4", "1");
        // })
        // it('triggerRebalance success test 2 ', async () => {
        //     await rebalancer.triggerRebalance("5", "2");
        // })
        // it('triggerRebalance success test 3 ', async () => {
        //     await rebalancer.triggerRebalance("6", "3");
        // })
    })

    describe('#detailed test', async () => {
        it('open position test', async () => {
            const [tester] = await ethers.getSigners();
            let inputUSDC = "10000000000";
            let positionId = await rebalancer.nextPositionId();
            await rebalancer.deposit(inputUSDC, "1");
            let position = await rebalancer.positions(positionId);
            expect(position.owner).to.eq(tester.address, "Position owner should tester");
            expect(position.liquidity.toString()).to.not.eq("0", "Position liquidity should not 0");
            expect(position.tickLower.toString()).to.not.eq("0", "Position tickLower should not 0");
            expect(position.tickUpper.toString()).to.not.eq("0", "Position tickUpper should not 0");
        })

        it('close position test', async () => {
            let positionId = await rebalancer.nextPositionId();
            await rebalancer.withdraw(positionId.sub(1));
            let position = await rebalancer.positions(positionId.sub(1));
            expect(position.owner).to.eq("0x0000000000000000000000000000000000000000",
                "Position owner should blank"
            );
            expect(position.liquidity.toString()).to.eq("0", "Position liquidity should 0");
            expect(position.tickLower.toString()).to.eq("0", "Position tickLower should 0");
            expect(position.tickUpper.toString()).to.eq("0", "Position tickUpper should 0");
            expect(position.feeGrowthInside0LastX128.toString()).to.eq(
                "0", "Position feeGrowthInside0LastX128 should 0"
            );
            expect(position.feeGrowthInside1LastX128.toString()).to.eq(
                "0", "Position feeGrowthInside1LastX128 should 0"
            );
        })

        it('USDC deposit test', async () => {
            const [tester] = await ethers.getSigners();
            let inputUSDC = "10000000000";
            let beforeUSDCBalance = await usdc.balanceOf(tester.address);
            await rebalancer.deposit(inputUSDC, "1");
            let afterUSDCBalance = await usdc.balanceOf(tester.address);
            expect(beforeUSDCBalance.sub(afterUSDCBalance).toString()).to.eq(
                inputUSDC, "Should same amount"
            );
        })

        it('USDC withdraw test', async () => {
            const [tester] = await ethers.getSigners();
            let beforeUSDCBalance = await usdc.balanceOf(tester.address);
            let positionId = await rebalancer.nextPositionId();
            await rebalancer.withdraw(positionId.sub(1));
            let afterUSDCBalance = await usdc.balanceOf(tester.address);
            expect(beforeUSDCBalance.toString()).to.not.eq(
                afterUSDCBalance.toString(), "Should not same amount"
            );
        })

        // If you want to rebalance test, Change canTriggerRebalance() result to true.
        // it('Rebalance test', async () => {
        //     let originalPosition = await rebalancer.positions("7");
        //     await rebalancer.triggerRebalance("7", "1");
        //     let rebalancedPosition = await rebalancer.positions("7");
        //     expect(originalPosition.owner).to.eq(rebalancedPosition.owner, "Position owner should same");
        //     expect(originalPosition.liquidity).to.not.eq(rebalancedPosition.liquidity,
        //         "Position liquidity should not same"
        //     );
        // })
        //
        // it('USDC Rebalance test', async () => {
        //     const [tester] = await ethers.getSigners();
        //     let beforeUSDCBalance = await usdc.balanceOf(tester.address);
        //     await rebalancer.triggerRebalance("7", "1");
        //     let afterUSDCBalance = await usdc.balanceOf(tester.address);
        //     expect(beforeUSDCBalance.toString()).to.eq(
        //         afterUSDCBalance.toString(), "Should same amount"
        //     );
        // })
    })
})
