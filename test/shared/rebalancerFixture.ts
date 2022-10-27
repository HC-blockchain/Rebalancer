import {
    abi as FACTORY_ABI,
    bytecode as FACTORY_BYTECODE,
} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'
import { abi as IUniswapV3PoolABI } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json'
import {Fixture} from 'ethereum-waffle'
import {ethers, waffle} from 'hardhat'
import {constants} from 'ethers'
import {FeeAmount, MaxUint128, TICK_SPACINGS} from './constants'
import {
    IWETH9,
    MockTimeSwapRouter,
    MockOldERC20,
    IUniswapV3Factory,
    UniswapV3AutoRebalancer,
    MockUniswapPoolMinter
} from '../../typechain'

import WETH9 from "./WETH9.json";
import {encodePriceSqrt, getMinTick, getMaxTick} from "./utilities";

const rebalancerFixture: Fixture<{
    factory: IUniswapV3Factory
    router: MockTimeSwapRouter
    weth: MockOldERC20
    usdc: MockOldERC20
    rebalancer: UniswapV3AutoRebalancer
}> = async () => {
    const [deployer] = await ethers.getSigners();
    const tokenFactory = await ethers.getContractFactory('MockOldERC20');
    const usdc = await tokenFactory.deploy("mockUSDC", "usdc", "6") as MockOldERC20;
    const weth = await tokenFactory.deploy("mockWETH", "weth", "18") as MockOldERC20;


    const weth9 = (await waffle.deployContract(deployer, {
        bytecode: WETH9.bytecode,
        abi: WETH9.abi,
    })) as IWETH9


    const factory = (await waffle.deployContract(deployer, {
        bytecode: FACTORY_BYTECODE,
        abi: FACTORY_ABI,
    })) as IUniswapV3Factory


    const router = (await (await ethers.getContractFactory('MockTimeSwapRouter')).deploy(
        factory.address,
        weth9.address
    )) as MockTimeSwapRouter

    await factory.createPool(weth.address, usdc.address, FeeAmount.LOW);
    const poolAddress = await factory.getPool(weth.address, usdc.address, FeeAmount.LOW);

    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, deployer)
    await pool.initialize("2025421045712532904326522192860678");
    let token0 = await pool.token0();
    let token1 = await pool.token1();

    const mockUniswapPoolMinterFactory = await ethers.getContractFactory('MockUniswapPoolMinter')
    const minter = await mockUniswapPoolMinterFactory.deploy(poolAddress, token0, token1) as MockUniswapPoolMinter;

    await weth.mint(minter.address, MaxUint128);
    await usdc.mint(minter.address, MaxUint128);
    await minter.doMint(
        getMinTick(TICK_SPACINGS[FeeAmount.LOW]),
        getMaxTick(TICK_SPACINGS[FeeAmount.LOW]),
        "1614233960559267871"
    );

    const uniswapV3AutoRebalancerFactory = await ethers.getContractFactory('UniswapV3AutoRebalancer')
    const rebalancer = await uniswapV3AutoRebalancerFactory.deploy(poolAddress, weth.address, usdc.address) as UniswapV3AutoRebalancer;

    return {
        factory,
        router,
        weth,
        usdc,
        rebalancer
    }
}

export default rebalancerFixture
