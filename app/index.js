const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hallo vanuit AKS! 🚀',
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint, gebruikt door Kubernetes liveness/readiness probes
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`App luistert op poort ${port}`);
});
