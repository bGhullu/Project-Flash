const { ethers } = require('ethers');
const winston = require('winston');

// Logger setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message }) => `${timestamp} ${level}: ${message}`)
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'swapType.log' })
    ]
});

const determineSwapType = (pathData) => {
    const dexNames = [
        { name: 'uniswapV2', chain: 'ethereum', key: 'v2Price', field: 'token0Price' },
        { name: 'uniswapV3', chain: 'ethereum', key: 'v3Price', field: 'token0Price' },
        { name: 'sushiSwap', chain: 'polygon', key: 'otherPrice', field: 'token0Price' },
        { name: 'oneInch', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'pancakeSwap', chain: 'bsc', key: 'otherPrice', field: 'token0Price' },
        { name: 'cowSwap', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'serum', chain: 'solana', key: 'otherPrice', field: 'token0Price' },
        { name: 'traderJoe', chain: 'avalanche', key: 'otherPrice', field: 'token0Price' },
        { name: 'spookySwap', chain: 'fantom', key: 'otherPrice', field: 'token0Price' },
        { name: 'quickSwap', chain: 'polygon', key: 'otherPrice', field: 'token0Price' },
        { name: 'camelot', chain: 'arbitrum', key: 'otherPrice', field: 'token0Price' },
        { name: 'velodrome', chain: 'optimism', key: 'otherPrice', field: 'token0Price' },
        { name: 'baseSwap', chain: 'base', key: 'otherPrice', field: 'token0Price' },
        { name: 'lineaSwap', chain: 'linea', key: 'otherPrice', field: 'token0Price' },
        { name: 'scrollSwap', chain: 'scroll', key: 'otherPrice', field: 'token0Price' },
        { name: 'zkSwap', chain: 'zksync', key: 'otherPrice', field: 'token0Price' },
        { name: 'bancor', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'balancer', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'loopring', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'dydx', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'osmosis', chain: 'cosmos', key: 'otherPrice', field: 'token0Price' },
        { name: 'mooniswap', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'pangolin', chain: 'avalanche', key: 'otherPrice', field: 'token0Price' },
        { name: 'curve', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'kyber', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'bancor', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'gnosis', chain: 'gnosis', key: 'otherPrice', field: 'token0Price' },
        { name: 'quickswap', chain: 'polygon', key: 'otherPrice', field: 'token0Price' },
        { name: 'waultswap', chain: 'bsc', key: 'otherPrice', field: 'token0Price' },
        { name: 'saddle', chain: 'ethereum', key: 'otherPrice', field: 'token0Price' },
        { name: 'ellipsis', chain: 'bsc', key: 'otherPrice', field: 'token0Price' },
        { name: 'bake', chain: 'bsc', key: 'otherPrice', field: 'token0Price' },
        { name: 'anyswap', chain: 'multichain', key: 'otherPrice', field: 'token0Price' }
    ];

    const prices = dexNames.reduce((acc, dex) => {
        const price = pathData.prices.find(price => price.chain === dex.chain && price.prices[dex.key])?.prices[dex.key]?.[dex.field];
        if (price !== undefined) {
            acc[dex.name] = price;
        }
        return acc;
    }, {});

    const validPrices = Object.entries(prices);

    if (validPrices.length === 0) {
        throw new Error('No valid prices found');
    }

    const bestSwapType = validPrices.reduce((best, [dexName, price]) => {
        return price > best.price ? { dexName, price } : best;
    }, { dexName: null, price: -Infinity }).dexName;

    logger.info(`Best swap type determined: ${bestSwapType}`);
    return bestSwapType;
};

module.exports = { determineSwapType };
