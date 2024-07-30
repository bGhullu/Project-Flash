const axios = require('axios');


const getAIPrediction = async (features) => {
    const apiUrl = process.env.AI_MODEL_API_URL || 'https://api.example-ai-model.com/predict';
    try{
        const response = await axios.post(apiUrl, { features });
        return response.data.prediction;
    } catch (error){
        logger.error(`Error fetching AI prediction from ${apiUrl}: ${error.message}`);
        throw error;                
    }
};

module.exports = {getAIPrediction};