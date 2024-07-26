const axios = require('axios');
const { ethers } = require('ethers');
const { initContracts } = require('./initContracts');
const { getTokenAddresses, fetchPricesCrossChain } = require('./crossChainService');
const { adjustGasPrice, executeFlashbotTransaction } = require('./flashbotService');
const { crossChainArbitrage } = require('./crossChainArbitrage');
const { executeSameChainArbitrage } = require('./sameChainArbitrage');
const { getChainIdForToken } = require('./chainIdService');
const pLimit = require('p-limit');
const winston = require('winston');
require('dotenv').config();

const {
    INFURA_URL,
    SLIPPAGE_TOLERANCE = 0.01,
    TRANSACTION_FEE = 0.0001,
    GAS_COST = 0.0005,
    LIQUIDITY_THRESHOLD = 100,
    RECEIVER_ADDRESS,
    FLASHLOAN_CONTRACT_ADDRESS, // Address of the deployed smart contract
    FLASK_API_URL
} = process.env;

const provider = new ethers.JsonRpcProvider(INFURA_URL);

// Logger setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message }) => `${timestamp} ${level}: ${message}`)
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'arbitrage.log' })
    ]
});

const limit = pLimit(10); // Limit concurrency to 10

// ABI of the deployed flashloan smart contract
const flashloanContractABI = [
    "function executeArbitrage(address[] calldata tokens, uint256[] calldata amounts, address[] calldata dexes, address[] calldata bridges) external"
];

// Create an instance of the flashloan smart contract
const flashloanContract = new ethers.Contract(FLASHLOAN_CONTRACT_ADDRESS, flashloanContractABI, provider.getSigner());

const fetchPrices = async (tokens) => {
    try {
        const prices = await fetchPricesCrossChain(tokens);
        return prices;
    } catch (error) {
        logger.error(`Error fetching prices: ${error.message}`);
        return null;
    }
};

const calculateProfits = async (pairData) => {
    const enrichedData = await Promise.all(pairData.map(async ({ tokens, prices }) => {
        const data = {
            token0_price: prices.uniswapPrice * (1 - SLIPPAGE_TOLERANCE),
            token1_price: prices.sushiSwapPrice* (1 - SLIPPAGE_TOLERANCE),
            token2_price: prices.oneInchPrice* (1 - SLIPPAGE_TOLERANCE),
            token3_price: prices.pancakeSwapPrice* (1 - SLIPPAGE_TOLERANCE),
            token4_price: prices.cowSwapPrice* (1 - SLIPPAGE_TOLERANCE),
            volume: tokens.reduce((acc, token) => acc + token.volume, 0),
            liquidity: tokens.reduce((acc, token) => acc + token.liquidity, 0),
            sma_50: tokens.reduce((acc, token) => acc + token.sma_50, 0) / tokens.length,
            sma_200: tokens.reduce((acc, token) => acc + token.sma_200, 0) / tokens.length,
            rsi: tokens.reduce((acc, token) => acc + token.rsi, 0) / tokens.length,
            sentiment: tokens.reduce((acc, token) => acc + token.sentiment, 0) / tokens.length
        };

        if (data.liquidity < LIQUIDITY_THRESHOLD) {
            return null;
        }

        const response = await axios.post(`${FLASK_API_URL}/predict`, data);
        const profit = response.data.prediction - (TRANSACTION_FEE + GAS_COST);

        return profit > 0 ? { tokens, profit } : null;
    }));

    return enrichedData.filter(result => result !== null);
};

const selectBestPairs = async (tokenPaths) => {
    try {
        const pairData = await Promise.all(tokenPaths.map(async (tokens) => {
            const prices = await fetchPrices(tokens);
            return { tokens, prices };
        }));

        return calculateProfits(pairData);
    } catch (error) {
        logger.error(`Error in selecting best pairs: ${error.message}`);
        return [];
    }
};

const determineSwapType = (pathData) => {
    const { uniswapPrice, sushiSwapPrice, oneInchPrice, pancakeSwapPrice, cowSwapPrice } = pathData.prices;

    const prices = {
        uniswap: uniswapPrice,
        sushiSwap: sushiSwapPrice,
        oneInch: oneInchPrice,
        pancakeSwap: pancakeSwapPrice,
        cowSwap: cowSwapPrice
    };

    const bestSwapType = Object.keys(prices).reduce((a, b) => (prices[a] > prices[b] ? a : b));

    return bestSwapType;
};

const determineBridgeType = async (pathData, provider) => {
    const { tokens } = pathData;

    const chainIds = await Promise.all(tokens.map(token => getChainIdForToken(token, provider)));

    const allSameChain = chainIds.every(chainId => chainId === chainIds[0]);

    if (allSameChain) {
        return null; // Same-chain swap
    } else {
        // Logic to determine the best bridge based on availability, speed, cost, etc.
        const bridges = ['wormhole', 'chainlink', 'jumper', 'stargate', 'debridge', 'bungee'];
        
        // Placeholder criteria for selecting the best bridge
        const bridgeCriteria = {
            wormhole: { availability: true, speed: 3, cost: 2 },
            chainlink: { availability: true, speed: 4, cost: 3 },
            jumper: { availability: true, speed: 5, cost: 1 },
            stargate: { availability: true, speed: 4, cost: 2 },
            debridge: { availability: true, speed: 3, cost: 4 },
            bungee: { availability: true, speed: 5, cost: 3 }
        };

        let bestBridge = null;
        let bestScore = Infinity;

        bridges.forEach(bridge => {
            if (bridgeCriteria[bridge].availability) {
                const score = bridgeCriteria[bridge].speed + bridgeCriteria[bridge].cost;
                if (score < bestScore) {
                    bestScore = score;
                    bestBridge = bridge;
                }
            }
        });

        return bestBridge;
    }
};

const executeArbitrage = async (arbitrageData, provider) => {
    const { tokens, profit, swapType, bridgeType } = arbitrageData;

    // Prepare the transaction parameters
    const amount = ethers.utils.parseUnits('1000', 18); // Example amount, adjust as needed
    const dexes = swapType === 'crossChain' ? [swapType, bridgeType] : [swapType];

    // Execute the arbitrage transaction through the flashloan contract
    const tx = await flashloanContract.executeArbitrage(tokens, [amount], dexes, []);

    // Execute the arbitrage transactions using Flashbots
    await executeFlashbotTransaction([tx], provider);

    logger.info(`Executed arbitrage for tokens: ${tokens.join(' -> ')}, Profit: ${profit}`);
};

const getTokenPaths = (tokenAddresses) => {
    const paths = [];
    for (let i = 0; i < tokenAddresses.length; i++) {
        for (let j = i + 1; j < tokenAddresses.length; j++) {
            paths.push([tokenAddresses[i], tokenAddresses[j]]);
            for (let k = j + 1; k < tokenAddresses.length; k++) {
                paths.push([tokenAddresses[i], tokenAddresses[j], tokenAddresses[k]]);
                for (let l = k + 1; l < tokenAddresses.length; l++) {
                    paths.push([tokenAddresses[i], tokenAddresses[j], tokenAddresses[k], tokenAddresses[l]]);
                }
            }
        }
    }
    return paths;
};

const runArbitrageBot = async () => {
    try {
        const tokenAddresses = await getTokenAddresses(provider);
        logger.info(`Fetched Token Addresses: ${JSON.stringify(tokenAddresses)}`);

        const tokenPaths = getTokenPaths(tokenAddresses);

        // Use selectBestPairs to get the best arbitrage opportunities
        const bestPairs = await selectBestPairs(tokenPaths);
        logger.info(`Selected Best Pairs: ${JSON.stringify(bestPairs)}`);

        for (const bestPair of bestPairs) {
            const { tokens, profit, prices } = bestPair;

            logger.info(`Processing Pair: ${tokens.join(' / ')}`);
            logger.info(`Profit: ${profit}`);

            const arbitrageData = {
                tokens,
                profit,
                swapType: determineSwapType(bestPair),
                bridgeType: await determineBridgeType(bestPair, provider)
            };

            await executeArbitrage(arbitrageData, provider);
        }
    } catch (error) {
        logger.error(`Error in arbitrage bot: ${error.message}`);
    }
};

runArbitrageBot();
