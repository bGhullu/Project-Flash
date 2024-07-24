const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
require('dotenv').config(); // Load environment variables from .env file

// Configure logging
const log = console.log;

// Connect to Ethereum node
const provider = new ethers.providers.JsonRpcProvider(process.env.ETH_NODE_URL);

(async () => {
    // Configure Flashbots
    const flashbotsProvider = await FlashbotsBundleProvider.create(
        provider,
        new ethers.Wallet(process.env.PRIVATE_KEY, provider)
    );

    // Replace with your contract address
    const contractAddress = process.env.CONTRACT_ADDRESS;
    const contractAbi = require('./YourSmartContract.json').abi; // Replace with actual ABI
    const contract = new ethers.Contract(contractAddress, contractAbi, provider);

    async function handleEvent(event) {
        const { token0, token1, amountIn0, amountIn1, sourceLow, sourceHigh } = event.args;

        log(`Arbitrage Triggered: ${token0} ${token1} ${amountIn0.toString()} ${amountIn1.toString()} ${sourceLow.toString()} ${sourceHigh.toString()}`);

        // Encode the data for the contract function call
        const data = contract.interface.encodeFunctionData('initiateArbitrage', [token0, token1, amountIn0, amountIn1, sourceLow, sourceHigh]);

        const transaction = {
            to: contractAddress,
            value: ethers.utils.parseEther('0.1'), // Adjust the value as needed
            gasLimit: 2000000,
            gasPrice: ethers.utils.parseUnits('20', 'gwei'),
            nonce: await provider.getTransactionCount(process.env.SENDER_ADDRESS),
            data: data
        };

        try {
            const signedTx = await provider.getSigner().signTransaction(transaction);
            const txResponse = await flashbotsProvider.sendBundle([{ transaction: signedTx }], await provider.getBlockNumber() + 1);
            log(`Transaction sent: ${txResponse.bundleHash}`);
        } catch (error) {
            log(`Error sending transaction: ${error.message}`);
        }
    }

    async function main() {
        // Listen for events
        contract.on('ArbitrageTriggered', handleEvent);

        log('Listening for ArbitrageTriggered events...');
    }

    main().catch(error => log(`Error in main function: ${error.message}`));
})();
