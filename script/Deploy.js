async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const Arbitrage = await ethers.getContractFactory("Arbitrage");
    const arbitrage = await Arbitrage.deploy(
        // Provide appropriate addresses for the routers and bridges here
        "uniswapRouterAddress",
        "sushiSwapRouterAddress",
        "oneInchRouterAddress",
        "balancerRouterAddress",
        "pancakeSwapRouterAddress",
        "cowSwapRouterAddress",
        "wormholeBridgeAddress",
        "chainlinkBridgeAddress",
        "jumperBridgeAddress",
        "stargateBridgeAddress",
        "debridgeBridgeAddress",
        "bungeeBridgeAddress",
        "providerAddress"
    );

    console.log("Arbitrage deployed to:", arbitrage.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
