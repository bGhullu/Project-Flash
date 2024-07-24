const axios = require('axios');



const getAbi = async (poolAddress,apiKey) => {
    const url = `https://api.arbiscan.io/api?module=contract&action=getabi&address=${addressPoolProvider}&apikey=${apiKey}`;

    try {
        const response = await axios.get(url);
        if (response.data.status === '1') {
            return JSON.parse(response.data.result);
          
        } else {
            
                throw new Error(`Error fetching ABI: ${response.data.result}`);
            }
    } catch (error) {
        throw new Error(`Error fetching ABI: ${error.message}`);
    }
};

    
module.export = {getAbi};
