const form = document.getElementById('prompt-form');
const promptElement = document.getElementById('prompt');
const humanizedTextElement = document.getElementById('humanized-text');

form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const prompt = promptElement.value;

    try {
        const response = await fetch('/process-prompt', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ prompt })
        });

        const data = await response.json();

        humanizedTextElement.textContent = data.humanizedText;
    } catch (error) {
        console.error(error);
        alert('An error occurred. Please try again.');
    }
});