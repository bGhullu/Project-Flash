const axios = require('axios');
const { getAIPrediction } = require('./ai_service');
const { fetchPrices, crossChainArbitrage } = require('./cross_chain_service');
const { adjustGasPrice, executeFlashbotTransaction } = require('./flashbot_service');
const winston = require('winston');
require('dotenv').config();

// Logger setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'app.log' })
    ]
});

// Function to fetch and retry API calls
const fetchWithRetry = async (url, options = {}, retries = 3) => {
    for (let attempt = 0; attempt < retries; attempt++) {
        try {
            const response = await axios(url, options);
            return response.data;
        } catch (error) {
            logger.warn(`Attempt ${attempt + 1} failed: ${error.message}`);
            if (attempt === retries - 1) throw error;
        }
    }
};

// Function to analyze data with advanced logic
const analyzeData = async (data) => {
    if (!data || data.length === 0) return [];

    const slippageTolerance = parseFloat(process.env.SLIPPAGE_TOLERANCE) || 0.005;
    const transactionFee = parseFloat(process.env.TRANSACTION_FEE) || 0.0001;
    const gasCost = parseFloat(process.env.GAS_COST) || 0.0005;
    const liquidityThreshold = parseFloat(process.env.LIQUIDITY_THRESHOLD) || 200;

    return data.map(pairData => {
        const { uniswapPrice, sushiSwapPrice, volume, token0, token1 } = pairData;
        if (volume < liquidityThreshold) return null;

        const adjustedUniswapPrice = uniswapPrice * (1 + slippageTolerance);
        const adjustedSushiSwapPrice = sushiSwapPrice * (1 + slippageTolerance);
        const profit = (adjustedUniswapPrice - adjustedSushiSwapPrice) - (transactionFee + gasCost);
        return { token0, token1, profit };
    }).filter(result => result !== null);
};

const main = async () => {
    try {
        // Fetch prices with retries
        const token0Address = process.env.TOKEN0_ADDRESS;
        const token1Address = process.env.TOKEN1_ADDRESS;
        const data = await fetchWithRetry(`https://api.example.com/prices?token0=${token0Address}&token1=${token1Address}`);
        const analyzedData = await analyzeData(data);

        // Get AI prediction
        const aiPrediction = await getAIPrediction(analyzedData);

        if (aiPrediction && aiPrediction.shouldTrade) {
            logger.info('AI prediction indicates trading. Executing arbitrage...');

            // Execute cross-chain arbitrage and transactions with retries
            await crossChainArbitrage(analyzedData);
            await adjustGasPrice();
            await executeFlashbotTransaction(analyzedData);
            
            logger.info('Arbitrage and transaction execution completed successfully.');
        } else {
            logger.info('AI prediction does not indicate trading.');
        }
    } catch (error) {
        logger.error(`Error in arbitrage bot: ${error.message}`);
    }
};

// Run the main function
main();
