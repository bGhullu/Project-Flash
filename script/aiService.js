const axios = require('axios');
const winston = require('winston');

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message }) => `${timestamp} ${level}: ${message}`)
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'aiService.log' })
    ]
});

const getAIPrediction = async (features) => {
    const apiUrl = process.env.AI_MODEL_API_URL || 'https://api.example-ai-model.com/predict';
    try {
        const response = await axios.post(apiUrl, { features });
        return response.data.prediction;
    } catch (error) {
        logger.error(`Error fetching AI prediction from ${apiUrl}: ${error.message}`);
        throw error;
    }
};

module.exports = { getAIPrediction };
