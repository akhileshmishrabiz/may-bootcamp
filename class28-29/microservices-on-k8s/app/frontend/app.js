const express = require('express');
const axios = require('axios');
const os = require('os');
const fs = require('fs');
const config = require('./config.json');

// ============================================================================
// Prometheus Metrics Setup
// ============================================================================
const client = require('prom-client');

// Create a Registry to register metrics
const register = new client.Registry();

// Add default metrics (CPU, memory, event loop, etc.)
client.collectDefaultMetrics({
  register,
  prefix: 'frontend_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5]
});

// Custom Metrics
const httpRequestDuration = new client.Histogram({
  name: 'frontend_http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
  registers: [register]
});

const httpRequestsTotal = new client.Counter({
  name: 'frontend_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const serviceStatusGauge = new client.Gauge({
  name: 'frontend_service_dependency_up',
  help: 'Status of service dependencies (1 = up, 0 = down)',
  labelNames: ['service'],
  registers: [register]
});

// ============================================================================
// App Setup
// ============================================================================
const app = express();
const productsApiBaseUri = config.productsApiBaseUri;
const recommendationBaseUri = config.recommendationBaseUri;
const votingBaseUri = config.votingBaseUri;
const origamisRouter = require('./routes/origamis');

app.set('view engine', 'ejs');
app.use(express.static('public'));

// ============================================================================
// Metrics Middleware
// ============================================================================
app.use((req, res, next) => {
  const start = Date.now();

  // Capture response
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;

    // Record metrics
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration);

    httpRequestsTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc();
  });

  next();
});

// ============================================================================
// Metrics Endpoint
// ============================================================================
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ============================================================================
// Health Endpoint
// ============================================================================
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Static Middleware
app.use('/static', express.static('public'));
app.use('/api/origamis', origamisRouter);

// ============================================================================
// Application Routes
// ============================================================================

// Endpoint to serve product data to client
app.get('/api/products', async (req, res) => {
  try {
    let response = await axios.get(`${productsApiBaseUri}/api/products`);
    serviceStatusGauge.labels('catalogue').set(1);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching products:', error);
    serviceStatusGauge.labels('catalogue').set(0);
    res.status(500).send('Error fetching products');
  }
});

app.get('/', (req, res) => {
  // Gather system info
  const systemInfo = {
    hostname: os.hostname(),
    ipAddress: getIPAddress(),
    isContainer: isContainer(),
    isKubernetes: fs.existsSync('/var/run/secrets/kubernetes.io')
  };

  res.render('index', {
    systemInfo: systemInfo,
    app_version: config.version,
  });
});

function getIPAddress() {
  // Logic to fetch IP Address
  const networkInterfaces = os.networkInterfaces();
  return (networkInterfaces['eth0'] && networkInterfaces['eth0'][0].address) || 'IP not found';
}

function isContainer() {
  // Logic to check if running in a container
  try {
    fs.readFileSync('/proc/1/cgroup');
    return true;
  } catch (e) {
    return false;
  }
}

app.get('/api/service-status', async (req, res) => {
  try {
    // Example of checking the status of the products service
    const productServiceResponse = await axios.get(`${productsApiBaseUri}/api/products`);
    serviceStatusGauge.labels('catalogue').set(1);

    res.json({
      Catalogue: 'up',
    });
  } catch (error) {
    console.error('Error:', error);
    serviceStatusGauge.labels('catalogue').set(0);
    res.json({
      Catalogue: 'down',
    });
  }
});

app.get('/recommendation-status', (req, res) => {
    axios.get(config.recommendationBaseUri + '/api/recommendation-status')
        .then(response => {
            serviceStatusGauge.labels('recommendation').set(1);
            res.json({status: "up", message: "Recommendation Service is Online"});
        })
        .catch(error => {
            serviceStatusGauge.labels('recommendation').set(0);
            res.json({status: "down", message: "Recommendation Service is Offline"});
        });
});

app.get('/votingservice-status', (req, res) => {
    axios.get(config.votingBaseUri + '/api/origamis')
        .then(response => {
            serviceStatusGauge.labels('voting').set(1);
            res.json({status: "up", message: "Voting Service is Online"});
        })
        .catch(error => {
            serviceStatusGauge.labels('voting').set(0);
            res.json({status: "down", message: "Voting Service is Offline"});
        });
});

app.get('/daily-origami', (req, res) => {
    axios.get(config.recommendationBaseUri + '/api/origami-of-the-day')
        .then(response => {
            res.json(response.data);
        })
        .catch(error => {
            res.status(500).send("Error while fetching daily origami");
        });
});

// Handle 404
app.use((req, res, next) => {
    res.status(404).send('ERROR 404 - Not Found on This Server');
});

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});

module.exports = server;
