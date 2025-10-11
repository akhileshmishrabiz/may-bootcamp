# Frontend Service (Node.js/Express)

## Overview

The Frontend service is the main user interface for the Craftista application, built with Node.js and Express. It aggregates data from all backend microservices and presents it to users.

---

## Build Information

- **Language**: Node.js
- **Framework**: Express.js
- **Node Version**: Latest LTS (21.x.x or higher)
- **Port**: 3000
- **Build Command**: `npm install`
- **Launch Command**: `node app.js`

---

## Dependencies

```json
{
  "axios": "^0.21.1",
  "ejs": "^3.1.6",
  "express": "^4.17.1",
  "prom-client": "^15.1.0"
}
```

---

## Monitoring & Observability

### Metrics (Prometheus)

The service exposes Prometheus metrics at `/metrics` endpoint for monitoring application performance and health.

#### Metrics Endpoint
- **URL**: `http://localhost:3000/metrics`
- **Format**: Prometheus text format
- **Scrape Interval**: 30 seconds (configured in ServiceMonitor)

#### Available Metrics

##### Custom Application Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `frontend_http_requests_total` | Counter | method, route, status_code | Total number of HTTP requests |
| `frontend_http_request_duration_seconds` | Histogram | method, route, status_code | HTTP request duration in seconds |
| `frontend_service_dependency_up` | Gauge | service | Service dependency status (1=up, 0=down) |

##### Default Node.js Metrics (Automatic)

| Metric | Description |
|--------|-------------|
| `frontend_process_cpu_user_seconds_total` | User CPU time spent in seconds |
| `frontend_process_cpu_system_seconds_total` | System CPU time spent in seconds |
| `frontend_process_resident_memory_bytes` | Resident memory size in bytes |
| `frontend_nodejs_heap_size_used_bytes` | Heap memory used by Node.js |
| `frontend_nodejs_heap_size_total_bytes` | Total heap memory allocated |
| `frontend_nodejs_eventloop_lag_seconds` | Event loop lag in seconds |
| `frontend_nodejs_active_handles_total` | Number of active handles |
| `frontend_nodejs_active_requests_total` | Number of active requests |

#### Metric Labels Explained

- **method**: HTTP method (GET, POST, etc.)
- **route**: Request route/path
- **status_code**: HTTP response status (200, 404, 500, etc.)
- **service**: Dependency service name (catalogue, voting, recommendation)

#### Example Prometheus Queries

```promql
# Request rate per second
rate(frontend_http_requests_total[5m])

# Average request duration
rate(frontend_http_request_duration_seconds_sum[5m]) / rate(frontend_http_request_duration_seconds_count[5m])

# Error rate (5xx responses)
rate(frontend_http_requests_total{status_code=~"5.."}[5m])

# Service dependency health
frontend_service_dependency_up

# Memory usage
frontend_nodejs_heap_size_used_bytes / frontend_nodejs_heap_size_total_bytes
```

---

### Logging (Loki)

The service generates structured logs that are collected by Promtail and sent to Loki for centralized log aggregation.

#### Log Output

- **Format**: Plain text (console.log)
- **Destination**: stdout/stderr
- **Collection**: Promtail sidecar or DaemonSet
- **Storage**: Grafana Loki

#### Log Types

##### 1. Application Logs
```
Server is running on port 3000
Metrics available at http://localhost:3000/metrics
```

##### 2. Request Logs
Generated automatically by metrics middleware:
```
GET /api/products 200 142ms
POST /api/origamis 201 89ms
```

##### 3. Error Logs
```
Error fetching products: Error: connect ECONNREFUSED catalogue:5000
```

##### 4. Dependency Status Logs
Service dependency failures are logged:
```
Error: Catalogue service is down
Error: Recommendation service is down
Error: Voting service is down
```

#### Log Labels (Loki)

When scraped by Promtail, logs include these labels:

```yaml
labels:
  app: frontend
  namespace: craftista
  pod: frontend-xyz
  container: frontend
  level: info/error
  service: frontend
```

#### Example LogQL Queries

```logql
# All frontend logs
{app="frontend"}

# Error logs only
{app="frontend"} |= "Error"

# Request logs with status codes
{app="frontend"} |~ "GET|POST|PUT|DELETE"

# Logs from last 5 minutes
{app="frontend"} | json | __error__="" | line_format "{{.message}}"

# Filter by log level
{app="frontend"} |= "level=error"

# Service dependency errors
{app="frontend"} |= "service" |= "down"
```

---

### Health Checks

#### Health Endpoint
- **URL**: `http://localhost:3000/health`
- **Method**: GET
- **Response**:
  ```json
  {
    "status": "healthy"
  }
  ```

#### Kubernetes Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Main UI page |
| `/api/products` | GET | Fetch products from catalogue service |
| `/api/service-status` | GET | Check catalogue service status |
| `/recommendation-status` | GET | Check recommendation service status |
| `/votingservice-status` | GET | Check voting service status |
| `/daily-origami` | GET | Get daily origami recommendation |
| `/metrics` | GET | Prometheus metrics endpoint |
| `/health` | GET | Health check endpoint |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Port to run the server |
| `NODE_ENV` | development | Environment (development/production) |

---

## Service Dependencies

The frontend depends on these backend services:

1. **Catalogue Service** (`http://catalogue:5000`)
   - Provides product catalog data
   - Monitored via `frontend_service_dependency_up{service="catalogue"}`

2. **Recommendation Service** (`http://recommendation:8080`)
   - Provides origami recommendations
   - Monitored via `frontend_service_dependency_up{service="recommendation"}`

3. **Voting Service** (`http://voting:8080`)
   - Provides voting functionality
   - Monitored via `frontend_service_dependency_up{service="voting"}`

---

## Monitoring Integration

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: frontend-metrics
  namespace: craftista
spec:
  selector:
    matchLabels:
      app: frontend
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Grafana Dashboards

Recommended dashboards for Node.js monitoring:
- **Node.js Application Dashboard**: Import ID `11159`
- **Express.js Dashboard**: Import ID `11956`

---

## Development

### Local Setup

```bash
# Install dependencies
npm install

# Run locally
npm start

# Test metrics endpoint
curl http://localhost:3000/metrics

# Test health endpoint
curl http://localhost:3000/health
```

### Docker Build

```bash
docker build -t craftista-frontend:latest .
docker run -p 3000:3000 craftista-frontend:latest
```

---

## Troubleshooting

### High Memory Usage
Check heap usage metric:
```promql
frontend_nodejs_heap_size_used_bytes
```

### Event Loop Lag
Monitor event loop lag:
```promql
frontend_nodejs_eventloop_lag_seconds
```

### Service Dependency Failures
Check dependency status:
```promql
frontend_service_dependency_up{service="catalogue"}
```

View logs:
```logql
{app="frontend"} |= "Error fetching"
```

---

## Performance Tuning

### Node.js Options

```bash
# Increase heap size
NODE_OPTIONS="--max-old-space-size=2048" node app.js

# Enable CPU profiling
NODE_OPTIONS="--prof" node app.js
```

### Metrics Optimization

If metrics collection impacts performance:
- Increase scrape interval in ServiceMonitor
- Reduce histogram buckets
- Disable default metrics collection

---

## Security Considerations

- Metrics endpoint is exposed internally only (should not be public)
- No sensitive data in logs or metrics
- Health check endpoint can be public (no sensitive info)

---

## Additional Resources

- [Express.js Documentation](https://expressjs.com/)
- [prom-client Documentation](https://github.com/siimon/prom-client)
- [Prometheus Node.js Best Practices](https://prometheus.io/docs/instrumenting/clientlibs/)
- [Loki LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
