const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {

    const wnative = "0x87a851c652e5d772ba61ec320753c6349bb3c1e3"
    const factoryV2 = "0xef6726076b6c155bcb05e2f85fd3b373e049ed4d"
    const poolDeployer = "0xEC250E6856e14A494cb1f0abC61d72348c79F418"
    const factoryV3 = "0x83D4a9Ea77a4dbA073cD90b30410Ac9F95F93E7C"
    const posManager = "0x1Bfbf7721397f6e3bD1250dc44CbB6eaA10Ad1b2"

    const SwapRouter02Factory = await hre.ethers.getContractFactory("SwapRouter02");
    const SwapRouter02 = await SwapRouter02Factory.deploy(factoryV2, poolDeployer, factoryV3, posManager, wnative);
    await SwapRouter02.deployed()

    console.log("SwapRouter02", SwapRouter02.address)

    const MixedRouteQuoterV1Factory = await hre.ethers.getContractFactory("MixedRouteQuoterV1");
    const MixedRouteQuoterV1 = await MixedRouteQuoterV1Factory.deploy(factoryV3, poolDeployer, factoryV2, wnative);

    await MixedRouteQuoterV1.deployed()

    console.log("MixedRouteQuoterV1 to:", MixedRouteQuoterV1.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
