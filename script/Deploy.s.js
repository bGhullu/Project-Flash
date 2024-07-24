require('dotenv').config();
const { ethers } = require('ethers');
const axios = require('axios');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
const fs = require('fs');
const { get } = require('http');

// Load environment variables
const INFURA_URL = process.env.INFURA_URL;
const FLASHBOTS_AUTH = process.env.FLASHBOTS_AUTH;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const ARB_ABI_KEY = process.env.ARB_ABI_KEY;
const uniswapV2Address = '0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9'
const uniswapV3Address = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
const sushiSwapAddress = '0xc35DADB65012eC5796536bD9864eD8773aBc74C4'

// Load contract ABI
const contractAbi = JSON.parse(fs.readFileSync('./AdvancedArbitrageBot.json', 'utf8'));

// Initialize providers and wallet
const provider = new ethers.JsonRpcProvider(INFURA_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const flashbotsProvider = await FlashbotsBundleProvider.create(provider, wallet);

const uniswapV2Abi= await getAbi(uniswapV2Address,ARB_ABI_KEY);
const uinswapV3Abi= await getAbi(uniswapV3Address,ARB_ABI_KEY);
const sushiswapAbi= await getAbi(sushiSwapAddress,ARB_ABI_KEY);

const factoryABIs = {
    uniswapV2: [ uniswapV2Abi],
    uniswapV3: [uinswapV3Abi ],
    sushiSwap: [ sushiswapAbi]
    // oneInch: [ /* ABI for 1inch Factory */ ]
};

const factoryAddresses = {
    uniswapV2: uniswapV2Address,
    uniswapV3: uniswapV3Address,
    sushiSwap: sushiSwapAddress
    
    // oneInch: '0x1inchFactoryAddress'
};

const factories = {
    uniswapV2: new ethers.Contract(factoryAddresses.uniswapV2, factoryABIs.uniswapV2, provider),
    uniswapV3: new ethers.Contract(factoryAddresses.uniswapV3, factoryABIs.uniswapV3, provider),
    sushiSwap: new ethers.Contract(factoryAddresses.sushiSwap, factoryABIs.sushiSwap, provider),
    // oneInch: new ethers.Contract(factoryAddresses.oneInch, factoryABIs.oneInch, provider)
};

async function fetchTokenPairs(factory) {
    try {
        // Replace with the correct method to fetch token pairs
        return await factory.getAllPairs();
    } catch (error) {
        console.error(`Error fetching token pairs: ${error.message}`);
        return [];
    }
}

async function fetchPrices(token0, token1) {
    try {
        const [uniswapV2Price, uniswapV3Price, sushiSwapPrice] = await Promise.all([
            axios.get('https://api.uniswap.org/v2/prices', { params: { token0, token1 } }),
            axios.get('https://api.uniswap.org/v3/prices', { params: { token0, token1 } }),
            axios.get('https://api.sushi.com/v2/prices', { params: { token0, token1 } }),
            // axios.get('https://api.1inch.exchange/v5.0/eth/quote', {
            //     params: {
            //         fromTokenAddress: token0,
            //         toTokenAddress: token1,
            //         amount: '1000000000000000000' // 1 ETH in smallest unit
            //     }
            // }),
            // axios.get('https://api.cex.com/prices', { params: { token0, token1 } })
        ]);

        return {
            uniswapV2Price: uniswapV2Price.data.price,
            uniswapV3Price: uniswapV3Price.data.price,
            sushiSwapPrice: sushiSwapPrice.data.price,
            // oneinchPrice: oneinchPrice.data.price,
            // cexPrice: cexPrice.data.price
        };
    } catch (error) {
        console.error(`Error fetching prices: ${error.message}`);
        return null;
    }
}

async function fetchData() {
    try {
        const [uniswapV2Pairs, uniswapV3Pairs, sushiSwapPairs] = await Promise.all([
            fetchTokenPairs(factories.uniswapV2),
            fetchTokenPairs(factories.uniswapV3),
            fetchTokenPairs(factories.sushiSwap),
            // fetchTokenPairs(factories.oneInch)
        ]);

        const allPairs = [...uniswapV2Pairs, ...uniswapV3Pairs, ...sushiSwapPairs];

        return await Promise.all(allPairs.map(pair => {
            const [token0, token1] = pair; // Adjust based on actual pair format
            return fetchPrices(token0, token1).then(prices => ({ token0, token1, ...prices }));
        }));
        // const results = await Promise.all(allPairs.map(async pair => {
        //     const [token0, token1] = pair;
        //     try {
        //         const prices = await fetchPrices(token0, token1);
        //         return { token0, token1, ...prices };
        //     } catch (error) {
        //         console.error(`Error fetching prices for tokens ${token0} and ${token1}: ${error.message}`);
        //         return null;
        //     }
        // }));

        return results.filter(result => result !== null);
    } catch (error) {
        console.error(`Error fetching data: ${error.message}`);
        return null;
    }
}

function analyzeData(data) {
    if (!data || data.length === 0) return null;

    let bestOption = null;
    let bestProfit = 0;

    const slippageTolerance = 0.01; // 1% slippage
    const transactionFee = 0.0001;  // Example transaction fee (ETH)
    const gasCost = 0.0005;         // Example gas cost (ETH)
    const liquidityThreshold = 100; // Example liquidity threshold

    data.forEach(pairData => {
        const { uniswapV2Price, uniswapV3Price, sushiSwapPrice, volume, token0, token1 } = pairData;

        if (!checkLiquidity(volume, liquidityThreshold)) return;

        const adjustedUniswapV2Price = calculateSlippage(uniswapV2Price, slippageTolerance);
        const adjustedUniswapV3Price = calculateSlippage(uniswapV3Price, -slippageTolerance);
        const adjustedSushiSwapPrice = calculateSlippage(sushiSwapPrice, slippageTolerance);
        // const adjustedOneinchPrice = calculateSlippage(oneinchPrice, -slippageTolerance);

        // Uniswap V2 vs Uniswap V3
        const profitUniswapArbitrage = calculateProfit(
            adjustedUniswapV2Price, 
            adjustedUniswapV3Price, 
            slippageTolerance, 
            slippageTolerance, 
            transactionFee, 
            gasCost
        );


        if (adjustedUniswapV2Price > 0 && adjustedUniswapV3Price > 0 && profitUniswapArbitrage > bestProfit) {
            bestProfit = profitUniswapArbitrage;
            bestOption = {
                token0,
                token1,
                sourceLow: 'UniswapV2',
                sourceHigh: 'UniswapV3',
                profit: profitUniswapArbitrage
            };
        }

        // // SushiSwap vs 1inch
        // const profitSushiSwapArbitrage = calculateProfit(
        //     adjustedSushiSwapPrice, 
        //     adjustedOneinchPrice, 
        //     slippageTolerance, 
        //     slippageTolerance, 
        //     transactionFee, 
        //     gasCost
        // );

        // if (adjustedSushiSwapPrice > 0 && adjustedOneinchPrice > 0 && profitSushiSwapArbitrage > bestProfit) {
        //     bestProfit = profitSushiSwapArbitrage;
        //     bestOption = {
        //         token0,
        //         token1,
        //         sourceLow: 'SushiSwap',
        //         sourceHigh: '1inch',
        //         profit: profitSushiSwapArbitrage
        //     };
        // }

        // Uniswap V2 vs SushiSwap
        const profitUniswapV2SushiSwap = calculateProfit(
            adjustedUniswapV2Price, 
            adjustedSushiSwapPrice, 
            slippageTolerance, 
            slippageTolerance, 
            transactionFee, 
            gasCost
        );

        if (adjustedUniswapV2Price > 0 && adjustedSushiSwapPrice > 0 && profitUniswapV2SushiSwap > bestProfit) {
            bestProfit = profitUniswapV2SushiSwap;
            bestOption = {
                token0,
                token1,
                sourceLow: 'UniswapV2',
                sourceHigh: 'SushiSwap',
                profit: profitUniswapV2SushiSwap
            };
        }

        // Uniswap V3 vs SushiSwap
        const profitUniswapV3SushiSwap = calculateProfit(
            adjustedUniswapV3Price, 
            adjustedSushiSwapPrice, 
            slippageTolerance, 
            slippageTolerance, 
            transactionFee, 
            gasCost
        );

        if (adjustedUniswapV3Price > 0 && adjustedSushiSwapPrice > 0 && profitUniswapV3SushiSwap > bestProfit) {
            bestProfit = profitUniswapV3SushiSwap;
            bestOption = {
                token0,
                token1,
                sourceLow: 'UniswapV3',
                sourceHigh: 'SushiSwap',
                profit: profitUniswapV3SushiSwap
            };
        }

    //     // Uniswap V2 vs 1inch
    //     const profitUniswapV21inch = calculateProfit(
    //         adjustedUniswapV2Price, 
    //         adjustedOneinchPrice, 
    //         slippageTolerance, 
    //         slippageTolerance, 
    //         transactionFee, 
    //         gasCost
    //     );

    //     if (adjustedUniswapV2Price > 0 && adjustedOneinchPrice > 0 && profitUniswapV21inch > bestProfit) {
    //         bestProfit = profitUniswapV21inch;
    //         bestOption = {
    //             token0,
    //             token1,
    //             sourceLow: 'UniswapV2',
    //             sourceHigh: '1inch',
    //             profit: profitUniswapV21inch
    //         };
    //     }

    //     // Uniswap V3 vs 1inch
    //     const profitUniswapV31inch = calculateProfit(
    //         adjustedUniswapV3Price, 
    //         adjustedOneinchPrice, 
    //         slippageTolerance, 
    //         slippageTolerance, 
    //         transactionFee, 
    //         gasCost
    //     );

    //     if (adjustedUniswapV3Price > 0 && adjustedOneinchPrice > 0 && profitUniswapV31inch > bestProfit) {
    //         bestProfit = profitUniswapV31inch;
    //         bestOption = {
    //             token0,
    //             token1,
    //             sourceLow: 'UniswapV3',
    //             sourceHigh: '1inch',
    //             profit: profitUniswapV31inch
    //         };
    //     }
     });

    return bestOption;
}


(async () => {
    const data = await fetchData();
    const bestOpportunity = analyzeData(data);

    if (bestOpportunity) {
        console.log('Best Arbitrage Opportunity:', bestOpportunity);
    } else {
        console.log('No arbitrage opportunities found.');
    }
})();
