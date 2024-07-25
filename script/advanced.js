const axios = require('axios');
const { ethers } = require('ethers');
const fs = require('fs');
const WebSocket = require('ws');
const { sendTransaction } = require('./transactionHandler');
const { getRealTimeSentiment, getCrossChainPrice } = require('./externalServices');
const { DynamicGasPriceEstimator, AIModel } = require('./advancedTools');

// Load environment variables
const INFURA_URL = process.env.INFURA_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const ARB_ABI_KEY = process.env.ARB_ABI_KEY;
const DEX_ADDRESSES = {
    uniswapV2: '0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9',
    uniswapV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
    sushiSwap: '0xc35DADB65012eC5796536bD9864eD8773aBc74C4'
};

// Initialize provider and wallet
const provider = new ethers.providers.JsonRpcProvider(INFURA_URL);
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

// Fetch and initialize contracts
const initContracts = async () => {
    const factoryABIs = await Promise.all(
        Object.values(DEX_ADDRESSES).map(address => fetchAndFormatAbi(address, ARB_ABI_KEY))
    );
    
    return {
        uniswapV2: new ethers.Contract(DEX_ADDRESSES.uniswapV2, factoryABIs[0], provider),
        uniswapV3: new ethers.Contract(DEX_ADDRESSES.uniswapV3, factoryABIs[1], provider),
        sushiSwap: new ethers.Contract(DEX_ADDRESSES.sushiSwap, factoryABIs[2], provider)
    };
};

// Function to fetch token pairs from a factory
const fetchTokenPairs = async (factory) => {
    try {
        return await factory.getAllPairs(); // Adjust based on actual method
    } catch (error) {
        console.error(`Error fetching token pairs: ${error.message}`);
        return [];
    }
};

// Function to fetch prices and sentiment
const fetchPricesAndSentiment = async (token0, token1) => {
    try {
        const [prices, sentiment] = await Promise.all([
            axios.get(`https://api.uniswap.org/v2/prices`, { params: { token0, token1 } }),
            getRealTimeSentiment(token0, token1)
        ]);

        const crossChainPrices = await getCrossChainPrice(token0, token1);

        return {
            uniswapV2Price: prices.data.uniswapV2Price,
            uniswapV3Price: prices.data.uniswapV3Price,
            sushiSwapPrice: prices.data.sushiSwapPrice,
            sentiment,
            crossChainPrices
        };
    } catch (error) {
        console.error(`Error fetching prices and sentiment: ${error.message}`);
        return null;
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

    // Initialize AI model for decision making
    const aiModel = new AIModel();

    // Advanced Multi-Step Arbitrage
    const multiStepOpportunities = [];
    data.forEach(pairData => {
        const { uniswapV2Price, uniswapV3Price, sushiSwapPrice, volume, token0, token1, sentiment, crossChainPrices } = pairData;

        if (!checkLiquidity(volume, liquidityThreshold)) return;

        // Example multi-step sequence: UniswapV2 -> UniswapV3 -> SushiSwap
        const profitMultiStep = calculateProfit(
            uniswapV2Price,
            uniswapV3Price,
            slippageTolerance,
            -slippageTolerance,
            transactionFee,
            gasCost
        );

        if (profitMultiStep > bestProfit) {
            bestProfit = profitMultiStep;
            bestOption = {
                token0,
                token1,
                sourceLow: 'UniswapV2',
                sourceHigh: 'UniswapV3',
                profit: profitMultiStep
            };
        }

        // Store multi-step opportunities
        multiStepOpportunities.push({
            tokens: [token0, token1],
            sequence: ['UniswapV2', 'UniswapV3', 'SushiSwap'],
            profit: profitMultiStep
        });
    });

    // Advanced Triangular Arbitrage
    const triangularArbitrageOpportunities = [];
    data.forEach(pairData => {
        const { token0, token1, uniswapV2Price, uniswapV3Price, sushiSwapPrice, crossChainPrices } = pairData;

        const prices = {
            p1p2: uniswapV2Price,
            p2p3: uniswapV3Price,
            p3p1: sushiSwapPrice,
            p1p3: uniswapV3Price, // Example cross-chain price
            p2p1: sushiSwapPrice, // Example reverse cross-chain price
            p3p2: uniswapV2Price  // Example reverse price
        };

        // Calculate profit for triangular arbitrage
        const profitTriangular = calculateTriangularArbitrageProfit(prices);

        // Add to opportunities if profitable
        if (profitTriangular > bestProfit) {
            bestProfit = profitTriangular;
            bestOption = {
                token0,
                token1,
                sourceLow: 'UniswapV2',
                sourceHigh: 'SushiSwap',
                profit: profitTriangular
            };
        }

        triangularArbitrageOpportunities.push({
            tokens: [token0, token1],
            path: ['UniswapV2', 'UniswapV3', 'SushiSwap'],
            profit: profitTriangular
        });
    });

    // Sort and select the best multi-step and triangular opportunities
    multiStepOpportunities.sort((a, b) => b.profit - a.profit);
    triangularArbitrageOpportunities.sort((a, b) => b.profit - a.profit);

    // Return the best opportunity from all strategies
    return bestOption;
};

// Function to dynamically adjust gas prices
const adjustGasPrice = async () => {
    // Example dynamic gas price adjustment logic
    try {
        const gasPrice = await provider.getGasPrice();
        const adjustedGasPrice = await DynamicGasPriceEstimator.adjust(gasPrice);
        return adjustedGasPrice;
    } catch (error) {
        console.error(`Error adjusting gas price: ${error.message}`);
        return ethers.BigNumber.from(20000000000); // Fallback gas price
    }
};

// Function to execute trades
const executeTrade = async (tradeDetails) => {
    const { fromToken, toToken, amount, sourceLow, sourceHigh } = tradeDetails;

    try {
        const gasPrice = await adjustGasPrice();

        // Construct transaction details
        const tx = {
            to: CONTRACT_ADDRESS,
            data: encodeTradeData(fromToken, toToken, amount, sourceLow, sourceHigh),
            gasPrice,
            gasLimit: ethers.BigNumber.from(1000000)
        };

        const txResponse = await wallet.sendTransaction(tx);
        console.log(`Transaction sent: ${txResponse.hash}`);
        await txResponse.wait();
        console.log(`Transaction confirmed: ${txResponse.hash}`);
    } catch (error) {
        console.error(`Error executing trade: ${error.message}`);
    }
};

// Function to encode trade data for transaction
const encodeTradeData = (fromToken, toToken, amount, sourceLow, sourceHigh) => {
    const arbContract = new ethers.Contract(CONTRACT_ADDRESS, [], provider);
    return arbContract.interface.encodeFunctionData('executeArbitrage', [fromToken, toToken, amount, sourceLow, sourceHigh]);
};

module.exports = { analyzeData, executeTrade };
