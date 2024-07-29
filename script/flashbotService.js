const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
const { fetchGasPrice } = require('./gasPriceService');
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
        new winston.transports.File({ filename: 'flashbots.log' })
    ]
});

const adjustGasPrice = async (chainId) => {
    try {
        const gasPrice = await fetchGasPrice(chainId);
        logger.info(`Adjusted Gas Price for chainId ${chainId}: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
        return gasPrice;
    } catch (error) {
        logger.error(`Error adjusting gas price for chainId ${chainId}: ${error.message}`);
        const fallbackGasPrice = ethers.utils.parseUnits('100', 'gwei');
        logger.info(`Using fallback gas price: ${ethers.utils.formatUnits(fallbackGasPrice, 'gwei')} gwei`);
        return fallbackGasPrice;
    }
};

const executeFlashbotTransaction = async (transactions, provider, chainId) => {
    try {
        const flashbotsProvider = await FlashbotsBundleProvider.create(provider, ethers.Wallet.createRandom());

        // Adjust gas price for all transactions
        const finalGasPrice = await adjustGasPrice(chainId);
        logger.info(`Preparing Flashbots transactions with data: ${JSON.stringify(transactions)}`);

        const signedTransactions = await Promise.all(transactions.map(async (tx) => {
            tx.gasPrice = finalGasPrice;
            const signedTx = await provider.getSigner().sendTransaction(tx);
            return {
                transaction: signedTx,
                signer: provider.getSigner()
            };
        }));

        const result = await flashbotsProvider.sendBundle(signedTransactions, await provider.getBlockNumber() + 1);

        if ('error' in result) {
            throw new Error(`Flashbots transaction failed: ${result.error.message}`);
        }

        logger.info('Flashbots transactions executed successfully.');
    } catch (error) {
        logger.error(`Error executing Flashbots transactions: ${error.message}`);
        throw error;
    }
};

module.exports = { adjustGasPrice, executeFlashbotTransaction };
