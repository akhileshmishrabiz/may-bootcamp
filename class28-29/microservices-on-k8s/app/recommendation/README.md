# Recommendation Service (Go/Gin)

## Overview

The Recommendation microservice provides daily origami recommendations for the Craftista application. Built with Go and the Gin framework, it serves random origami suggestions to enhance user experience.

---

## Build Information

- **Language**: Go
- **Framework**: Gin
- **Go Version**: 1.20+
- **Port**: 8080
- **Build Tool**: go
- **Build Command**: `go build -o app`
- **Launch Command**: `./app`

---

## Dependencies

```go
require (
    github.com/gin-gonic/gin v1.9.1
    github.com/prometheus/client_golang v1.17.0
)
```

---

## Monitoring & Observability

### Metrics (Prometheus)

The service exposes Prometheus metrics at `/metrics` endpoint for monitoring application performance and health.

#### Metrics Endpoint
- **URL**: `http://localhost:8080/metrics`
- **Format**: Prometheus text format
- **Scrape Interval**: 30 seconds (configured in ServiceMonitor)

#### Available Metrics

##### Custom Application Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `recommendation_http_requests_total` | Counter | method, endpoint, status | Total number of HTTP requests |
| `recommendation_http_request_duration_seconds` | Histogram | method, endpoint | HTTP request duration in seconds |
| `recommendation_origami_of_day_total` | Counter | - | Total number of origami-of-the-day recommendations served |

##### Default Go Metrics (Automatic)

| Metric | Description |
|--------|-------------|
| `go_goroutines` | Number of goroutines currently running |
| `go_threads` | Number of OS threads created |
| `go_memstats_alloc_bytes` | Bytes allocated and still in use |
| `go_memstats_heap_alloc_bytes` | Heap bytes allocated and still in use |
| `go_memstats_heap_inuse_bytes` | Heap bytes in use |
| `go_memstats_stack_inuse_bytes` | Stack bytes in use |
| `go_gc_duration_seconds` | GC invocation durations |

##### Process Metrics

| Metric | Description |
|--------|-------------|
| `process_cpu_seconds_total` | Total CPU time spent by process |
| `process_resident_memory_bytes` | Resident memory size in bytes |
| `process_virtual_memory_bytes` | Virtual memory size in bytes |
| `process_open_fds` | Number of open file descriptors |
| `process_max_fds` | Maximum number of open file descriptors |
| `process_start_time_seconds` | Start time of the process since unix epoch |

#### Metric Labels Explained

- **method**: HTTP method (GET, POST, etc.)
- **endpoint**: Request endpoint/route
- **status**: HTTP response status text (OK, Not Found, Internal Server Error)

#### Example Prometheus Queries

```promql
# Request rate per second
rate(recommendation_http_requests_total[5m])

# Average request duration
rate(recommendation_http_request_duration_seconds_sum[5m]) / rate(recommendation_http_request_duration_seconds_count[5m])

# Error rate (5xx responses)
rate(recommendation_http_requests_total{status=~"Internal Server Error|Service Unavailable"}[5m])

# P95 request duration
histogram_quantile(0.95, rate(recommendation_http_request_duration_seconds_bucket[5m]))

# Total recommendations served
recommendation_origami_of_day_total

# Memory usage
process_resident_memory_bytes

# Goroutines count
go_goroutines

# GC duration
rate(go_gc_duration_seconds_sum[5m])
```

---

### Logging (Loki)

The service generates structured logs using Gin's default logging, collected by Promtail and sent to Loki for centralized log aggregation.

#### Log Output

- **Format**: Plain text (Gin default logger)
- **Destination**: stdout/stderr
- **Collection**: Promtail sidecar or DaemonSet
- **Storage**: Grafana Loki

#### Log Types

##### 1. Application Startup Logs
```
[GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.
[GIN-debug] GET    /metrics                  --> github.com/prometheus/client_golang/prometheus/promhttp.Handler.func1
[GIN-debug] GET    /health                   --> main.main.func1
[GIN-debug] GET    /                         --> main.renderHomePage
[GIN-debug] GET    /api/origami-of-the-day   --> main.getOrigamiOfTheDayWithMetrics
[GIN-debug] Listening and serving HTTP on :8080
```

##### 2. HTTP Request Logs
```
[GIN] 2025/10/07 - 10:15:23 | 200 |    1.234567ms |   172.16.0.1 | GET      "/api/origami-of-the-day"
[GIN] 2025/10/07 - 10:15:24 | 200 |     823.45µs |   172.16.0.2 | GET      "/health"
[GIN] 2025/10/07 - 10:15:25 | 200 |    2.345678ms |   172.16.0.3 | GET      "/"
```

##### 3. Middleware Logs
Prometheus middleware records metrics without explicit logs, but requests are logged by Gin:
```
[GIN] 2025/10/07 - 10:15:26 | 200 |     512.34µs |   172.16.0.4 | GET      "/metrics"
```

##### 4. Error Logs
```
[GIN] 2025/10/07 - 10:15:27 | 500 |    1.123456ms |   172.16.0.5 | GET      "/api/origami-of-the-day"
[GIN] 2025/10/07 - 10:15:28 | 404 |     234.56µs |   172.16.0.6 | GET      "/api/unknown"
```

#### Log Labels (Loki)

When scraped by Promtail, logs include these labels:

```yaml
labels:
  app: recommendation
  namespace: craftista
  pod: recommendation-xyz
  container: recommendation
  level: info/error/debug
  service: recommendation
```

#### Example LogQL Queries

```logql
# All recommendation service logs
{app="recommendation"}

# Error logs only (5xx status codes)
{app="recommendation"} |~ "\\| 5[0-9]{2} \\|"

# Request logs with duration
{app="recommendation"} |~ "GET|POST|PUT|DELETE"

# Logs from last 5 minutes
{app="recommendation"} | json | __error__="" | line_format "{{.message}}"

# Slow requests (> 1 second)
{app="recommendation"} |~ "\\| [0-9]+\\.[0-9]+s \\|"

# Filter by HTTP method
{app="recommendation"} |= "GET"

# Filter by endpoint
{app="recommendation"} |= "/api/origami-of-the-day"

# Count requests by status code
sum(count_over_time({app="recommendation"} |~ "\\| [0-9]{3} \\|" [5m])) by (status)
```

---

### Health Checks

#### Health Endpoint
- **URL**: `http://localhost:8080/health`
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
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page with system information |
| `/api/origami-of-the-day` | GET | Returns a random origami recommendation |
| `/api/recommendation-status` | GET | Service status check |
| `/metrics` | GET | Prometheus metrics endpoint |
| `/health` | GET | Health check endpoint |

---

## Configuration

### Configuration File

The service uses a `config.json` file for configuration:

```json
{
    "version": "1.0.0"
}
```

Mount this as a ConfigMap at `/app/config.json`.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GIN_MODE` | debug | Gin mode (debug/release) |
| `PORT` | 8080 | Port to run the server |

---

## Service Dependencies

- None (self-contained service)

---

## Monitoring Integration

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: recommendation-metrics
  namespace: craftista
spec:
  selector:
    matchLabels:
      app: recommendation
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Grafana Dashboards

Recommended dashboards for Go monitoring:
- **Go Metrics Dashboard**: Import ID `6671`
- **Go Processes**: Import ID `6671`
- **Gin HTTP Metrics**: Import ID `14783`

---

## Development

### Local Setup

```bash
# Install dependencies
go mod download

# Build the application
go build -o app

# Run the application
./app

# Run with hot reload (install air first)
air

# Test metrics endpoint
curl http://localhost:8080/metrics

# Test health endpoint
curl http://localhost:8080/health

# Test recommendation endpoint
curl http://localhost:8080/api/origami-of-the-day
```

### Docker Build

```bash
docker build -t craftista-recommendation:latest .
docker run -p 8080:8080 craftista-recommendation:latest
```

---

## Resource Requirements

### Recommended

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### With High Traffic

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

---

## Example Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendation
  namespace: craftista
spec:
  replicas: 2
  selector:
    matchLabels:
      app: recommendation
  template:
    metadata:
      labels:
        app: recommendation
    spec:
      containers:
      - name: recommendation
        image: <your-registry>/recommendation-service:latest
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: GIN_MODE
          value: "release"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config
          mountPath: /app/config.json
          subPath: config.json
        - name: static
          mountPath: /app/static
        - name: templates
          mountPath: /app/templates
      volumes:
      - name: config
        configMap:
          name: recommendation-config
      - name: static
        emptyDir: {}
      - name: templates
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: recommendation
  namespace: craftista
  labels:
    app: recommendation
spec:
  selector:
    app: recommendation
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
```

---

## Troubleshooting

### High Memory Usage

Check memory usage metric:
```promql
process_resident_memory_bytes{app="recommendation"}
```

View memory allocation:
```promql
go_memstats_heap_alloc_bytes{app="recommendation"}
```

### Goroutine Leaks

Monitor goroutines count:
```promql
go_goroutines{app="recommendation"}
```

If goroutines count keeps increasing, check for:
- Unclosed HTTP connections
- Blocked channels
- Infinite loops

View logs for blocked operations:
```logql
{app="recommendation"} |= "timeout"
```

### Slow Response Times

Check P95 latency:
```promql
histogram_quantile(0.95, rate(recommendation_http_request_duration_seconds_bucket[5m]))
```

View slow requests in logs:
```logql
{app="recommendation"} |~ "\\| [0-9]+\\.[0-9]+s \\|"
```

### High Error Rate

Check 5xx errors:
```promql
rate(recommendation_http_requests_total{status=~"Internal Server Error"}[5m])
```

View error logs:
```logql
{app="recommendation"} |~ "\\| 5[0-9]{2} \\|"
```

---

## Performance Tuning

### GOMAXPROCS

Set the number of CPUs to use:
```bash
GOMAXPROCS=4 ./app
```

### Garbage Collection

Adjust GC percentage:
```bash
GOGC=80 ./app
```

Lower values trigger GC more frequently (lower memory, higher CPU).

### Gin Mode

For production, always use release mode:
```bash
GIN_MODE=release ./app
```

### Metrics Optimization

If metrics collection impacts performance:
- Increase scrape interval to 60s
- Reduce histogram buckets in code
- Disable default metrics collection (not recommended)

---

## Security Considerations

- Metrics endpoint is exposed internally only (should not be public)
- No sensitive data in logs or metrics
- Health check endpoint can be public (no sensitive info)
- Static files should be mounted read-only

---

## Additional Resources

- [Gin Documentation](https://gin-gonic.com/docs/)
- [Prometheus Go Client](https://github.com/prometheus/client_golang)
- [Go Best Practices](https://golang.org/doc/effective_go)
- [Loki LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
