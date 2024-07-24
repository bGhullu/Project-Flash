const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
require('dotenv').config(); // Load environment variables from .env file

// Configure logging
const log = console.log;

const RPC_URL = process.env.RPC_URL;
const FLASHBOTS_AUTH = process.env.FLASHBOTS_AUTH;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const ARB_ABI_KEY = process.env.ARB_ABI_KEY;

// Connect to Ethereum node
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);


(async () => {
    // Configure Flashbots
    const flashbotsProvider = await FlashbotsBundleProvider.create(
        provider,
        new ethers.Wallet(PRIVATE_KEY, provider)
    );

    // Replace with your contract address
    const contractAddress = CONTRACT_ADDRESS;
    const contractAbi = JSON.parse(fs.readFileSync('./artifacts/build-info/contracts/AdvancedArbitrageBot.json', 'utf8'));
    const contract = new ethers.Contract(CONTRACT_ADDRESS, contractAbi, provider);


    async function sendTransaction(transactionData) {
        const { token0, token1, amountIn0, amountIn1, sourceLow, sourceHigh } = transactionData.args;

        log(`Arbitrage Triggered: ${token0} ${token1} ${amountIn0.toString()} ${amountIn1.toString()} ${sourceLow.toString()} ${sourceHigh.toString()}`);

        // Encode the data for the contract function call
        const data = contract.interface.encodeFunctionData('initiateArbitrage', [token0, token1, amountIn0, amountIn1, sourceLow, sourceHigh]);

        const transaction = {
            to: contractAddress,
            value: ethers.utils.parseEther('0.1'), // Adjust the value as needed
            gasLimit: 2000000,
            gasPrice: ethers.utils.parseUnits('20', 'gwei'),
            nonce: await provider.getTransactionCount(wallet.address),
            data: data
        };

        try {
            const signedTx = await wallet.signTransaction(transaction);
            const txResponse = await flashbotsProvider.sendBundle([{ transaction: signedTx }], await provider.getBlockNumber() + 1);
            log(`Transaction sent: ${txResponse.bundleHash}`);
        } catch (error) {
            log(`Error sending transaction: ${error.message}`);
        }
    }

    async function main() {
        // Listen for events
        contract.on('ArbitrageTriggered', sendTransaction);

        log('Listening for ArbitrageTriggered events...');
    }
  

    main().catch(error => log(`Error in main function: ${error.message}`));
})();
module.exports = { sendTransaction };
