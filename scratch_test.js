const https = require('https');

const apiKey = 'AIzaSyB3vabjQqJ-g6HktIaI0lBHTShmwM9I0Oo';
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

const requestBody = JSON.stringify({
  contents: [{
    parts: [{
      text: "You are academic examiner for NEET/JEE.\nGoal: Generate exactly 5 multiple-choice questions (MCQs) of Easy difficulty based on the following notes, syllabus, or topic:\n---\ngravitation field\n---\n\nProvide the quiz as a valid JSON array of objects. Each object must follow this schema:\n{\n  \"question\": \"Question text here?\",\n  \"options\": [\n    \"Option 1 text\",\n    \"Option 2 text\",\n    \"Option 3 text\",\n    \"Option 4 text\"\n  ],\n  \"correctIndex\": 0,\n  \"explanation\": \"Brief academic explanation of why this answer is correct.\"\n}\n\nReturn ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text."
    }]
  }],
  generationConfig: {
    responseMimeType: "application/json"
  }
});

const req = https.request(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(requestBody)
  }
}, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log("STATUS:", res.statusCode);
    console.log("RESPONSE:", data);
  });
});

req.on('error', (e) => {
  console.error("ERROR:", e);
});

req.write(requestBody);
req.end();
