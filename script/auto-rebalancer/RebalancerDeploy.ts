const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    UniswapV3AutoRebalancer__factory,
} from "../../typechain";

async function main() {
    const [deployer] = await ethers.getSigners();

    // ----------------------file setting---------------------------------
    let readFileAddress = "../../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);
    // -------------------------deploy code----------------------------------

    let rebalancerFactory = new UniswapV3AutoRebalancer__factory(deployer);
    let rebalancer = await rebalancerFactory.deploy(config.WETH_USDC_UNISWAP_POOL, config.WETH, config.USDC);
    config.USDC_ETH_POOL_REBALANCER = rebalancer.address;

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });