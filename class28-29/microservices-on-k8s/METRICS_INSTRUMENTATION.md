# Prometheus Metrics Instrumentation Guide

## Overview

This guide shows how to add Prometheus metrics to all Craftista microservices for monitoring with Prometheus and Grafana.

---

## 1. Frontend Service (Node.js/Express)

### Install Dependencies

```bash
cd app/frontend
npm install prom-client
```

### Update package.json

Add to `dependencies`:
```json
{
  "dependencies": {
    "prom-client": "^15.1.0"
  }
}
```

### Modify app.js

Add metrics instrumentation at the top of `app.js`:

```javascript
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
      .labels(req.method, route, res.statusCode)
      .observe(duration);

    httpRequestsTotal
      .labels(req.method, route, res.statusCode)
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
// Existing Routes
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

// ... rest of your existing routes ...

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});

module.exports = server;
```

### Test Metrics

```bash
# Start the app
npm start

# Check metrics
curl http://localhost:3000/metrics
```

---

## 2. Catalogue Service (Python/Flask)

### Install Dependencies

```bash
cd app/catalogue
echo "prometheus-client>=0.19.0" >> requirements.txt
pip install prometheus-client
```

### Modify app.py

Add metrics at the top of `app.py`:

```python
from flask import Flask, jsonify, render_template
from datetime import datetime
import socket
import os
import json
import psycopg2
import time

# ============================================================================
# Prometheus Metrics Setup
# ============================================================================
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY, CONTENT_TYPE_LATEST

# Custom Metrics
http_requests_total = Counter(
    'catalogue_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'catalogue_http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1, 2, 5)
)

db_connection_status = Gauge(
    'catalogue_db_connection_status',
    'Database connection status (1 = connected, 0 = disconnected)'
)

products_total = Gauge(
    'catalogue_products_total',
    'Total number of products in catalogue'
)

# ============================================================================
# App Setup
# ============================================================================
app = Flask(__name__)

# Load product data from JSON file
with open('products.json', 'r') as f:
    products = json.load(f)

products_total.set(len(products))

# Load configuration
def load_config():
    # ... existing config loading code ...
    pass

config_data = load_config()

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=config_data.get("db_host"),
            database=config_data.get("db_name"),
            user=config_data.get("db_user"),
            password=config_data.get("db_password")
        )
        db_connection_status.set(1)
        return conn
    except Exception as e:
        db_connection_status.set(0)
        raise e

# ============================================================================
# Metrics Middleware
# ============================================================================
@app.before_request
def before_request():
    # Store start time
    from flask import g
    g.start_time = time.time()

@app.after_request
def after_request(response):
    from flask import g, request

    # Calculate duration
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time

        # Get endpoint
        endpoint = request.endpoint or 'unknown'

        # Record metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()

        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=endpoint
        ).observe(duration)

    return response

# ============================================================================
# Metrics Endpoint
# ============================================================================
@app.route('/metrics')
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# ============================================================================
# Health Endpoint
# ============================================================================
@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

# ============================================================================
# Existing Routes
# ============================================================================
@app.route('/')
def home():
    system_info = get_system_info()
    app_version = config_data.get("app_version", "N/A")
    return render_template('index.html', current_year=datetime.now().year,
                         system_info=system_info, version=app_version)

@app.route('/api/products', methods=['GET'])
def get_products():
    if (config_data.get("data_source") == "db"):
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT * FROM products;')
            db_products = cur.fetchall()
            products_dict = [
                {'id': p[0], 'description': p[1], 'image_url': p[2], 'name': p[3]}
                for p in db_products
            ]
            products_total.set(len(products_dict))
            cur.close()
            conn.close()
            return jsonify(products_dict), 200
        except Exception as e:
            app.logger.error(f"Database error: {str(e)}")
            app.logger.info("Falling back to JSON data source")
            return jsonify(products), 200
    else:
        return jsonify(products), 200

# ... rest of existing routes ...

if __name__ == "__main__":
    app.run(debug=True)
```

### Test Metrics

```bash
# Start the app
python app.py

# Check metrics
curl http://localhost:5000/metrics
```

---

## 3. Voting Service (Java/Spring Boot)

### Update pom.xml

Add Actuator and Micrometer dependencies:

```xml
<dependencies>
    <!-- Existing dependencies -->

    <!-- Actuator for metrics -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>

    <!-- Prometheus metrics -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

### Update application.properties

Add actuator configuration:

```properties
# Catalogue Service Endpoint
catalogue.service-url=http://catalogue:5000/api/products

# H2 Database
spring.h2.console.enabled=true
spring.h2.console.path=/h2-console

# Datasource
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=password

# JPA
spring.jpa.show-sql=true
spring.jpa.hibernate.ddl-auto=update
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect

# ============================================================================
# Actuator Configuration
# ============================================================================
# Expose all actuator endpoints
management.endpoints.web.exposure.include=health,info,prometheus,metrics

# Base path for actuator endpoints
management.endpoints.web.base-path=/actuator

# Enable Prometheus metrics
management.metrics.export.prometheus.enabled=true

# Include more details in health endpoint
management.endpoint.health.show-details=always

# Application info
management.info.env.enabled=true
info.app.name=Voting Service
info.app.description=Craftista Voting Microservice
info.app.version=1.0.0

# Custom metrics
management.metrics.tags.application=voting-service
management.metrics.tags.environment=${ENVIRONMENT:dev}
```

### Create MetricsConfiguration.java (Optional - for custom metrics)

Create `src/main/java/com/example/voting/config/MetricsConfiguration.java`:

```java
package com.example.voting.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfiguration {

    @Bean
    public Counter votesCounter(MeterRegistry registry) {
        return Counter.builder("voting_votes_total")
                .description("Total number of votes cast")
                .tag("service", "voting")
                .register(registry);
    }

    @Bean
    public Counter origamiSyncCounter(MeterRegistry registry) {
        return Counter.builder("voting_origami_sync_total")
                .description("Total number of origami synchronizations")
                .tag("service", "voting")
                .register(registry);
    }
}
```

### Rebuild Application

```bash
cd app/voting
mvn clean package
```

### Test Metrics

```bash
# Start the app
mvn spring-boot:run

# Check health
curl http://localhost:8080/actuator/health

# Check Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

---

## 4. Recommendation Service (Go/Gin)

### Install Prometheus Client

Update `go.mod`:

```bash
cd app/recommendation
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promhttp
```

### Modify main.go

Add metrics instrumentation:

```go
package main

import (
	"github.com/gin-gonic/gin"
	"recommendation/api"
	"net/http"
	"time"
	"encoding/json"
	"net"
	"os"

	// Prometheus imports
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// ============================================================================
// Prometheus Metrics
// ============================================================================
var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "recommendation_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "recommendation_http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	recommendationsServed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "recommendation_origami_of_day_total",
			Help: "Total number of origami-of-the-day recommendations served",
		},
	)
)

// ============================================================================
// Prometheus Middleware
// ============================================================================
func prometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		// Process request
		c.Next()

		// Record metrics
		duration := time.Since(start).Seconds()
		status := c.Writer.Status()

		httpRequestsTotal.WithLabelValues(
			c.Request.Method,
			path,
			http.StatusText(status),
		).Inc()

		httpRequestDuration.WithLabelValues(
			c.Request.Method,
			path,
		).Observe(duration)
	}
}

// ============================================================================
// Existing Code
// ============================================================================

type Config struct {
    Version string `json:"version"`
}

func loadConfig() (Config, error) {
    file, err := os.Open("config.json")
    if err != nil {
        return Config{}, err
    }
    defer file.Close()

    config := Config{}
    decoder := json.NewDecoder(file)
    err = decoder.Decode(&config)
    return config, err
}

type SystemInfo struct {
	Hostname      string
	IPAddress     string
	IsContainer   bool
	IsKubernetes  bool
}

func GetSystemInfo() SystemInfo {
	hostname, _ := os.Hostname()
	addrs, _ := net.InterfaceAddrs()
	ip := ""
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				ip = ipnet.IP.String()
				break
			}
		}
	}
	isContainer := false
	if _, err := os.Stat("/.dockerenv"); err == nil {
		isContainer = true
	}
	isKubernetes := false

	return SystemInfo{
		Hostname:      hostname,
		IPAddress:     ip,
		IsContainer:   isContainer,
		IsKubernetes: isKubernetes,
	}
}

func getRecommendationStatus(c *gin.Context) {
	status := "operational"
	c.JSON(http.StatusOK, gin.H{
		"status": status,
	})
}

func renderHomePage(c *gin.Context) {
	config, err := loadConfig()
	if err != nil {
		c.String(http.StatusInternalServerError, "Internal Server Error")
		return
	}

	systemInfo := GetSystemInfo()

	c.HTML(http.StatusOK, "index.html", gin.H{
		"Year":        time.Now().Year(),
		"Version":     config.Version,
		"SystemInfo":  systemInfo,
	})
}

// Wrapped origami handler to count recommendations
func getOrigamiOfTheDayWithMetrics(c *gin.Context) {
	recommendationsServed.Inc()
	api.GetOrigamiOfTheDay(c)
}

// ============================================================================
// Main Function
// ============================================================================
func main() {
	router := gin.Default()

	// Add Prometheus middleware
	router.Use(prometheusMiddleware())

	// Load HTML files
	router.LoadHTMLGlob("templates/*")

	// Set path to serve static files
	router.Static("/static", "./static")

	// ========================================================================
	// Metrics and Health Endpoints
	// ========================================================================
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// ========================================================================
	// Application Routes
	// ========================================================================
	router.GET("/", renderHomePage)
	router.GET("/api/origami-of-the-day", getOrigamiOfTheDayWithMetrics)
	router.GET("/api/recommendation-status", getRecommendationStatus)

	// Start the server on port 8080
	router.Run(":8080")
}
```

### Test Metrics

```bash
# Build and run
go run main.go

# Check metrics
curl http://localhost:8080/metrics
```

---

## Deployment

### Rebuild Docker Images

After adding metrics, rebuild and push your Docker images:

```bash
# Frontend
cd app/frontend
docker build -t <your-ecr>/craftista-frontend:v2 .
docker push <your-ecr>/craftista-frontend:v2

# Catalogue
cd app/catalogue
docker build -t <your-ecr>/craftista-catalogue:v2 .
docker push <your-ecr>/craftista-catalogue:v2

# Voting
cd app/voting
docker build -t <your-ecr>/craftista-voting:v2 .
docker push <your-ecr>/craftista-voting:v2

# Recommendation
cd app/recommendation
docker build -t <your-ecr>/craftista-recommendation:v2 .
docker push <your-ecr>/craftista-recommendation:v2
```

### Update Kubernetes Deployments

Update image tags in your deployments to use the new versions.

---

## Verify Metrics

Once deployed, verify each service exposes metrics:

```bash
# Frontend
kubectl port-forward -n craftista svc/frontend 3000:3000
curl http://localhost:3000/metrics

# Catalogue
kubectl port-forward -n craftista svc/catalogue 5000:5000
curl http://localhost:5000/metrics

# Voting
kubectl port-forward -n craftista svc/voting 8080:8080
curl http://localhost:8080/actuator/prometheus

# Recommendation
kubectl port-forward -n craftista svc/recommendation 8080:8080
curl http://localhost:8080/metrics
```

---

## Key Metrics Exposed

### Frontend (Node.js)
- `frontend_http_requests_total` - Total HTTP requests
- `frontend_http_request_duration_seconds` - Request duration
- `frontend_service_dependency_up` - Dependency health status
- `process_cpu_user_seconds_total` - CPU usage
- `nodejs_heap_size_used_bytes` - Memory usage

### Catalogue (Python)
- `catalogue_http_requests_total` - Total HTTP requests
- `catalogue_http_request_duration_seconds` - Request duration
- `catalogue_db_connection_status` - Database connection status
- `catalogue_products_total` - Number of products
- `process_cpu_seconds_total` - CPU usage

### Voting (Java/Spring Boot)
- `http_server_requests_seconds` - HTTP request metrics
- `jvm_memory_used_bytes` - JVM memory usage
- `jvm_gc_pause_seconds` - Garbage collection metrics
- `system_cpu_usage` - CPU usage
- `voting_votes_total` - Custom: Total votes
- `voting_origami_sync_total` - Custom: Sync operations

### Recommendation (Go)
- `recommendation_http_requests_total` - Total HTTP requests
- `recommendation_http_request_duration_seconds` - Request duration
- `recommendation_origami_of_day_total` - Recommendations served
- `go_goroutines` - Number of goroutines
- `go_memstats_alloc_bytes` - Memory allocation

---

## ServiceMonitor Configuration

The ServiceMonitors in your Terraform configuration will automatically discover and scrape these endpoints:

```yaml
# Already configured in monitoring.tf
- Frontend: http://frontend:3000/metrics
- Catalogue: http://catalogue:5000/metrics
- Voting: http://voting:8080/actuator/prometheus
- Recommendation: http://recommendation:8080/metrics
```

---

## Grafana Dashboards

After deployment, import these dashboards in Grafana:

1. **Node.js Application Dashboard** - ID: `11159`
2. **Spring Boot Dashboard** - ID: `12900`
3. **Go Application Dashboard** - ID: `6671`
4. **Python Application Dashboard** - ID: `14058`

Or create custom dashboards using the metrics exposed!

---

## Troubleshooting

### Metrics endpoint returns 404

```bash
# Check if the application started correctly
kubectl logs -n craftista deployment/<service-name>

# Verify the /metrics endpoint is accessible
kubectl exec -n craftista deployment/<service-name> -- curl localhost:<port>/metrics
```

### Prometheus not scraping

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n craftista

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

### High cardinality warnings

Avoid using high-cardinality labels like:
- User IDs
- Session IDs
- Full URLs
- Timestamps

Use labels like:
- HTTP method
- Endpoint/route
- Status code
- Service name

---

**Last Updated**: 2025-10-07
**For**: Craftista Microservices on Kubernetes
