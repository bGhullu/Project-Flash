require('dotenv').config();
const { ethers } = require('ethers');
const axios = require('axios');
const { sendTransaction } = require('./transactionHandler'); // Import sendTransaction function
const fs = require('fs');

// Load environment variables
const INFURA_URL = process.env.INFURA_URL;
const FLASHBOTS_AUTH = process.env.FLASHBOTS_AUTH;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const ARB_ABI_KEY = process.env.ARB_ABI_KEY;
const UNISWAP_V2_ADDRESS = '0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9';
const UNISWAP_V3_ADDRESS = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
const SUSHISWAP_ADDRESS = '0xc35DADB65012eC5796536bD9864eD8773aBc74C4';

// Load contract ABI
const contractAbi = JSON.parse(fs.readFileSync('./AdvancedArbitrageBot.json', 'utf8'));

// Initialize providers and wallet
const provider = new ethers.JsonRpcProvider(INFURA_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Function to fetch and format ABI
const fetchAndFormatAbi = async (address, apiKey) => {
    const url = `https://api.arbiscan.io/api?module=contract&action=getabi&address=${address}&apikey=${apiKey}`;
    try {
        const response = await axios.get(url);
        const abi = JSON.parse(response.data.result);
        return abi;
    } catch (error) {
        console.error(`Error fetching ABI for address ${address}: ${error.message}`);
        return null;
    }
};

// Fetch and organize ABIs
const getFactoryABIs = async () => {
    const [uniswapV2Abi, uniswapV3Abi, sushiSwapAbi] = await Promise.all([
        fetchAndFormatAbi(UNISWAP_V2_ADDRESS, ARB_ABI_KEY),
        fetchAndFormatAbi(UNISWAP_V3_ADDRESS, ARB_ABI_KEY),
        fetchAndFormatAbi(SUSHISWAP_ADDRESS, ARB_ABI_KEY)
    ]);

    return {
        uniswapV2: uniswapV2Abi,
        uniswapV3: uniswapV3Abi,
        sushiSwap: sushiSwapAbi
    };
};

// Fetch and initialize contracts
const initContracts = async () => {
    const factoryABIs = await getFactoryABIs();
    return {
        uniswapV2: new ethers.Contract(UNISWAP_V2_ADDRESS, factoryABIs.uniswapV2, provider),
        uniswapV3: new ethers.Contract(UNISWAP_V3_ADDRESS, factoryABIs.uniswapV3, provider),
        sushiSwap: new ethers.Contract(SUSHISWAP_ADDRESS, factoryABIs.sushiSwap, provider)
    };
};

// Function to fetch token pairs from a factory
const fetchTokenPairs = async (factory) => {
    try {
        // Replace with the correct method to fetch token pairs
        return await factory.getAllPairs();
    } catch (error) {
        console.error(`Error fetching token pairs: ${error.message}`);
        return [];
    }
};

// Function to fetch prices
const fetchPrices = async (token0, token1) => {
    try {
        const [uniswapV2Price, uniswapV3Price, sushiSwapPrice] = await Promise.all([
            axios.get('https://api.uniswap.org/v2/prices', { params: { token0, token1 } }),
            axios.get('https://api.uniswap.org/v3/prices', { params: { token0, token1 } }),
            axios.get('https://api.sushi.com/v2/prices', { params: { token0, token1 } })
        ]);

        return {
            uniswapV2Price: uniswapV2Price.data.price,
            uniswapV3Price: uniswapV3Price.data.price,
            sushiSwapPrice: sushiSwapPrice.data.price
        };
    } catch (error) {
        console.error(`Error fetching prices: ${error.message}`);
        return null;
    }
};

// Function to fetch and process data
const fetchData = async () => {
    try {
        const contracts = await initContracts();
        const [uniswapV2Pairs, uniswapV3Pairs, sushiSwapPairs] = await Promise.all([
            fetchTokenPairs(contracts.uniswapV2),
            fetchTokenPairs(contracts.uniswapV3),
            fetchTokenPairs(contracts.sushiSwap)
        ]);

        const allPairs = [...uniswapV2Pairs, ...uniswapV3Pairs, ...sushiSwapPairs];

        const results = await Promise.all(allPairs.map(async (pair) => {
            const [token0, token1] = pair; // Adjust based on actual pair format
            try {
                const prices = await fetchPrices(token0, token1);
                return { token0, token1, ...prices };
            } catch (error) {
                console.error(`Error fetching prices for tokens ${token0} and ${token1}: ${error.message}`);
                return null;
            }
        }));

        return results.filter(result => result !== null);
    } catch (error) {
        console.error(`Error fetching data: ${error.message}`);
        return [];
    }
};

// Function to analyze data for arbitrage opportunities
const analyzeData = (data) => {
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
    });

    return bestOption;
};

(async () => {
    try {
        const data = await fetchData();
        const bestOpportunity = analyzeData(data);

        if (bestOpportunity) {
            console.log(`Best Arbitrage Opportunity: ${JSON.stringify(bestOpportunity)}`);
            await sendTransaction(bestOpportunity);

        } else {
            console.log('No arbitrage opportunities found.');
        }
    } catch (error) {
        console.error(`Error in main execution: ${error.message}`);
    }
})();
