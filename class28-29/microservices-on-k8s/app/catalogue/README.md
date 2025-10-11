# Catalogue Service (Python/Flask)

## Overview

The Catalogue microservice provides product catalogue information for the Craftista application. It's built with Python Flask and supports both JSON file and PostgreSQL database as data sources.

---

## Build Information

- **Language**: Python
- **Framework**: Flask
- **Python Version**: 3.11+
- **Port**: 5000
- **Build Tool**: pip
- **Build Command**: `pip install -r requirements.txt`
- **Launch Command**: `gunicorn app:app --bind 0.0.0.0:5000`

---

## Dependencies

```
Flask>=3.0.0
gunicorn>=20.1.0
requests>=2.26.0
flask_cors>=3.0.10
psycopg2-binary
prometheus-client>=0.19.0
```

---

## Monitoring & Observability

### Metrics (Prometheus)

The service exposes Prometheus metrics at `/metrics` endpoint for monitoring application performance and health.

#### Metrics Endpoint
- **URL**: `http://localhost:5000/metrics`
- **Format**: Prometheus text format
- **Scrape Interval**: 30 seconds (configured in ServiceMonitor)

#### Available Metrics

##### Custom Application Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `catalogue_http_requests_total` | Counter | method, endpoint, status | Total number of HTTP requests |
| `catalogue_http_request_duration_seconds` | Histogram | method, endpoint | HTTP request duration in seconds |
| `catalogue_db_connection_status` | Gauge | - | Database connection status (1=connected, 0=disconnected) |
| `catalogue_products_total` | Gauge | - | Total number of products in catalogue |

##### Default Python Process Metrics (Automatic)

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
- **endpoint**: Flask endpoint name (get_products, get_product, etc.)
- **status**: HTTP response status code

#### Example Prometheus Queries

```promql
# Request rate per second
rate(catalogue_http_requests_total[5m])

# Average request duration
rate(catalogue_http_request_duration_seconds_sum[5m]) / rate(catalogue_http_request_duration_seconds_count[5m])

# Error rate (5xx responses)
rate(catalogue_http_requests_total{status="500"}[5m])

# Database connection status
catalogue_db_connection_status

# Total products
catalogue_products_total

# Memory usage trend
process_resident_memory_bytes
```

---

### Logging (Loki)

The service generates structured logs that are collected by Promtail and sent to Loki for centralized log aggregation.

#### Log Output

- **Format**: Plain text
- **Destination**: stdout/stderr
- **Collection**: Promtail sidecar or DaemonSet
- **Storage**: Grafana Loki

#### Log Types

##### 1. Application Startup Logs
```
* Serving Flask app 'app'
* Debug mode: off
WARNING: This is a development server.
```

##### 2. Request Logs (Gunicorn)
```
[2025-10-07 10:15:23] "GET /api/products HTTP/1.1" 200
[2025-10-07 10:15:24] "GET /api/products/1 HTTP/1.1" 200
```

##### 3. Error Logs
```
ERROR Database error: could not connect to server
INFO Falling back to JSON data source
```

##### 4. Database Logs
```
INFO Using database as data source
ERROR Database error: connection timeout
INFO Falling back to JSON data source
```

#### Log Labels (Loki)

When scraped by Promtail, logs include these labels:

```yaml
labels:
  app: catalogue
  namespace: craftista
  pod: catalogue-xyz
  container: catalogue
  level: info/error/warning
  service: catalogue
```

#### Example LogQL Queries

```logql
# All catalogue logs
{app="catalogue"}

# Error logs only
{app="catalogue"} |= "ERROR"

# Database connection errors
{app="catalogue"} |= "Database error"

# Request logs
{app="catalogue"} |~ "GET|POST" |~ "/api/"

# Logs from last 5 minutes
{app="catalogue"} | json | __error__=""

# Filter by HTTP status code
{app="catalogue"} |~ "\" 500"

# Database fallback events
{app="catalogue"} |= "Falling back to JSON"
```

---

### Health Checks

#### Health Endpoint
- **URL**: `http://localhost:5000/health`
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
    port: 5000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page with system info |
| `/api/products` | GET | Returns all products (from DB or JSON) |
| `/api/products/<id>` | GET | Returns a specific product by ID |
| `/metrics` | GET | Prometheus metrics endpoint |
| `/health` | GET | Health check endpoint |

---

## Configuration

The service supports flexible configuration through multiple sources (priority order):

1. Environment variables (highest priority)
2. Mounted secret files
3. Mounted config files
4. config.json file (lowest priority)

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_VERSION` | 1.0.0 | Application version |
| `DATA_SOURCE` | json | Data source type (json/db) |
| `DB_HOST` | localhost | Database hostname |
| `DB_NAME` | catalogue | Database name |
| `DB_USER` | devops | Database username |
| `DB_PASSWORD` | devops | Database password |

### Configuration File

Mount this as a ConfigMap at `/app/config.json`:

```json
{
    "app_version": "1.0.0",
    "data_source": "json",
    "db_host": "catalogue-db",
    "db_name": "catalogue",
    "db_user": "devops",
    "db_password": "devops"
}
```

### Secret Mounting

For better security, mount database credentials as secrets:

```bash
# Secrets mounted at /app/secrets/
/app/secrets/db_user
/app/secrets/db_password
/app/secrets/db_host
```

### Database Configuration

Mount database config at `/app/db-config/db-config.properties`:

```properties
db_name=catalogue
db_host=catalogue-db.default.svc.cluster.local
```

---

## Data Sources

### JSON Mode (Default)
- Uses embedded `products.json` file
- No database required
- Faster startup
- Suitable for development

### Database Mode
- Uses PostgreSQL database
- Requires database connection
- Falls back to JSON on error
- Suitable for production

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

### With Database
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

## Monitoring Integration

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: catalogue-metrics
  namespace: craftista
spec:
  selector:
    matchLabels:
      app: catalogue
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Grafana Dashboards

Recommended dashboards for Python/Flask monitoring:
- **Flask Dashboard**: Import ID `14058`
- **Python Application Monitoring**: Import ID `10869`

---

## Database Setup

### PostgreSQL Schema

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    description TEXT,
    image_url VARCHAR(255),
    name VARCHAR(255)
);

-- Insert sample data
INSERT INTO products (description, image_url, name) VALUES
    ('Beautiful origami paper', '/static/images/origami/001-origami.png', 'Origami Paper Set'),
    ('Instructional book', '/static/images/origami/003-origami-3.png', 'Origami Guide');
```

### Initialize Database

Use the provided script:
```bash
python db.create.py
```

---

## Development

### Local Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Run in debug mode
python app.py

# Run with gunicorn
gunicorn app:app --bind 0.0.0.0:5000

# Test metrics endpoint
curl http://localhost:5000/metrics

# Test health endpoint
curl http://localhost:5000/health
```

### Docker Build

```bash
docker build -t craftista-catalogue:latest .
docker run -p 5000:5000 craftista-catalogue:latest
```

---

## Example Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalogue-service
  namespace: craftista
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalogue
  template:
    metadata:
      labels:
        app: catalogue
    spec:
      containers:
      - name: catalogue
        image: <your-registry>/catalogue-service:latest
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: DATA_SOURCE
          value: "json"
        - name: APP_VERSION
          valueFrom:
            configMapKeyRef:
              name: catalogue-config
              key: app_version
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
            port: 5000
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
        volumeMounts:
        - name: config
          mountPath: /app/config.json
          subPath: config.json
        - name: db-secrets
          mountPath: /app/secrets
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: catalogue-config
      - name: db-secrets
        secret:
          secretName: catalogue-db-secrets
---
apiVersion: v1
kind: Service
metadata:
  name: catalogue
  namespace: craftista
  labels:
    app: catalogue
spec:
  selector:
    app: catalogue
  ports:
  - port: 5000
    targetPort: 5000
    name: http
  type: ClusterIP
```

---

## Troubleshooting

### Database Connection Failures

Check database connection status:
```promql
catalogue_db_connection_status
```

View database error logs:
```logql
{app="catalogue"} |= "Database error"
```

### High Memory Usage

Monitor memory usage:
```promql
process_resident_memory_bytes{app="catalogue"}
```

### Slow Queries

Check request duration:
```promql
histogram_quantile(0.95, rate(catalogue_http_request_duration_seconds_bucket[5m]))
```

View slow request logs:
```logql
{app="catalogue"} |~ "GET.*200" | line_format "{{.duration}}"
```

---

## Performance Tuning

### Gunicorn Workers

```bash
# Adjust workers based on CPU cores
gunicorn app:app --bind 0.0.0.0:5000 --workers 4 --threads 2
```

### Database Connection Pooling

Consider using connection pooling for database mode:
```python
from flask_sqlalchemy import SQLAlchemy
app.config['SQLALCHEMY_POOL_SIZE'] = 10
app.config['SQLALCHEMY_MAX_OVERFLOW'] = 20
```

### Metrics Optimization

If metrics collection impacts performance:
- Increase scrape interval to 60s
- Reduce histogram buckets
- Disable process metrics collection

---

## Security Considerations

- ✅ Database credentials stored in Kubernetes secrets
- ✅ Secrets mounted as read-only files
- ✅ No sensitive data in logs or metrics
- ✅ Metrics endpoint internal only (not exposed via Ingress)
- ⚠️ Health endpoint can be public (contains no sensitive info)

---

## Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [Gunicorn Documentation](https://docs.gunicorn.org/)
- [Loki LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [PostgreSQL Python Driver](https://www.psycopg.org/)
