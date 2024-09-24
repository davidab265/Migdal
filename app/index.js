const express = require('express');
const axios = require('axios');
const dotenv = require('dotenv');

dotenv.config(); // Load environment variables

const app = express();
const port = 3000;

app.use(express.json());
app.use(express.static('public')); // Serve static files from the 'public' directory

app.get('/', (req, res) => {
    res.sendFile(__dirname + '/public/index.html');
});

app.post('/process-prompt', async (req, res) => {
    const prompt = req.body.prompt;

    try {
        const aiText = await getAiText(prompt);
        const humanizedText = await getHumanizedText(aiText);
        res.json({ humanizedText });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'An error occurred' });
    }
});

async function getAiText(prompt) {
    // Replace with your ChatGPT API endpoint and credentials
    const chatgptApiKey = process.env.CHATGPT_API_KEY;  // Assuming you have a ChatGPT API key

    const response = await axios.post('YOUR_CHATGPT_API_ENDPOINT', {
        prompt,
        max_tokens: 1024,
        temperature: 0.5, // Adjust temperature as needed
    }, {
        headers: {
            'Authorization': `Bearer ${chatgptApiKey}`
        }
    });

    return response.data.text;
}

async function getHumanizedText(aiText) {
    const stealthgptApiKey = process.env.STEALTHGPT_API_KEY;

    const response = await axios.post('https://api.stealthgpt.ai/v1/text-davinci-003', {
        prompt: aiText,
        max_tokens: 1024,
        temperature: 0.5, // Adjust temperature as needed
    }, {
        headers: {
            'Authorization': `Bearer ${stealthgptApiKey}`
        }
    });

    return response.data.text;
}

app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
});