# Logging Architecture with Loki & Promtail

## Overview

This document explains how logging works in the Craftista microservices architecture using Grafana Loki and Promtail.

---

## What is Promtail?

**Promtail** is a log collection agent specifically designed to work with Grafana Loki. It's like Filebeat (for Elasticsearch) but optimized for Loki's label-based indexing.

**Key Features:**
- Automatically discovers Kubernetes pods
- Reads logs from pod stdout/stderr
- Adds metadata labels (namespace, pod, container, app)
- Streams logs to Loki in real-time
- Minimal resource footprint

---

## Logging Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. APPLICATIONS WRITE LOGS TO STDOUT/STDERR                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐│
│  │  Frontend    │  │  Catalogue   │  │   Voting     │  │  Recom  ││
│  │  (Node.js)   │  │  (Python)    │  │  (Java)      │  │  (Go)   ││
│  │              │  │              │  │              │  │         ││
│  │ console.log()│  │  print()     │  │ logger.info()│  │fmt.Print││
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────┬────┘│
│         │                 │                  │                │     │
│         ▼                 ▼                  ▼                ▼     │
│      stdout            stdout             stdout           stdout   │
└─────────┬─────────────────┬────────────────┬────────────────┬──────┘
          │                 │                │                │
┌─────────▼─────────────────▼────────────────▼────────────────▼──────┐
│  2. KUBERNETES CAPTURES POD LOGS                                    │
│                                                                      │
│  Logs written to:                                                   │
│  /var/log/pods/<namespace>_<pod-name>_<uid>/<container>/0.log      │
│                                                                      │
│  Example:                                                           │
│  /var/log/pods/craftista_frontend-abc123_xyz/frontend/0.log        │
└─────────┬────────────────────────────────────────────────────────────┘
          │
┌─────────▼────────────────────────────────────────────────────────────┐
│  3. PROMTAIL (DaemonSet - runs on every node)                        │
│                                                                       │
│  What it does:                                                        │
│  • Mounts /var/log/pods from host                                    │
│  • Watches for new log files                                         │
│  • Reads logs line by line                                           │
│  • Adds labels automatically:                                        │
│    - namespace: craftista                                            │
│    - pod: frontend-abc123                                            │
│    - container: frontend                                             │
│    - app: frontend                                                   │
│    - level: info/error/debug (parsed from log)                      │
│  • Streams logs to Loki via HTTP                                     │
│                                                                       │
│  Deployment: One Promtail pod per Kubernetes node                    │
└─────────┬────────────────────────────────────────────────────────────┘
          │
          │ HTTP Push (port 3100)
          │
┌─────────▼────────────────────────────────────────────────────────────┐
│  4. LOKI (Centralized log storage)                                   │
│                                                                       │
│  How Loki works (different from Elasticsearch):                      │
│  • Indexes ONLY labels (not log content) - Much more efficient!     │
│  • Stores log data in compressed chunks                              │
│  • Uses object storage (S3, GCS) for long-term retention            │
│  • Like "Prometheus for logs"                                        │
│                                                                       │
│  Storage structure:                                                  │
│  Labels: {namespace="craftista", app="frontend"}                    │
│  Logs: "Server is running on port 3000"                             │
│        "GET /api/products 200 142ms"                                 │
│        "Error fetching products: ECONNREFUSED"                       │
└─────────┬────────────────────────────────────────────────────────────┘
          │
          │ LogQL Queries
          │
┌─────────▼────────────────────────────────────────────────────────────┐
│  5. GRAFANA (Query & Visualize Logs)                                 │
│                                                                       │
│  Query examples:                                                     │
│  • {app="frontend"}                    - All frontend logs           │
│  • {app="frontend"} |= "ERROR"         - Only errors                │
│  • {namespace="craftista"} |= "5xx"    - All 5xx errors             │
│  • {app="voting"} |= "synchronization" - Sync logs                  │
│                                                                       │
│  Features:                                                           │
│  • Live tail logs (like kubectl logs -f)                            │
│  • Search & filter by time range                                     │
│  • Create log-based alerts                                           │
│  • Combine logs + metrics in dashboards                             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Why This Approach Works

### 1. **No Code Changes Required**
- Applications already write to stdout/stderr
- `console.log()`, `print()`, `logger.info()` all work as-is
- No special log libraries needed

### 2. **Automatic Discovery**
- Promtail auto-discovers all pods
- No manual configuration per service
- Add new services = logs collected automatically

### 3. **Efficient Storage (Loki's Secret)**
```
Traditional (Elasticsearch):
- Indexes EVERY word in EVERY log line
- Full-text search on everything
- Expensive storage & CPU

Loki (Better for Kubernetes):
- Indexes ONLY labels (namespace, pod, app)
- Log content stored compressed
- Query by labels first, then grep content
- 10x cheaper storage
```

### 4. **Native Kubernetes Integration**
- Promtail runs as DaemonSet (one per node)
- Automatically adds K8s metadata
- Respects pod lifecycle
- No sidecars needed (unlike Filebeat)

---

## Components in Your Stack

### Included in `kube-prometheus-stack` Helm Chart
✅ Prometheus (metrics collection)
✅ Grafana (visualization)
✅ Alertmanager (alerting)
❌ **Loki (NOT included)**
❌ **Promtail (NOT included)**

### Need Separate Installation
You'll deploy Loki + Promtail using the `loki-stack` Helm chart:
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true
```

---

## Log Labels Added by Promtail

Promtail automatically enriches logs with these labels:

```yaml
# Kubernetes-specific labels
namespace: craftista
pod: frontend-abc123-xyz
container: frontend
node: ip-10-0-1-123

# Application labels (from pod metadata)
app: frontend
version: v1.2.3

# Custom labels (can be added via Promtail config)
level: info/error/warning
service: frontend
environment: production
```

These labels make logs queryable:
```logql
# Query by app
{app="frontend"}

# Query by namespace and level
{namespace="craftista", level="error"}

# Query multiple apps
{app=~"frontend|catalogue|voting"}
```

---

## Application Logging Best Practices

### ✅ Do This (Already Implemented)

**Frontend (Node.js):**
```javascript
console.log('Server is running on port 3000');
console.error('Error fetching products:', error);
```

**Catalogue (Python):**
```python
app.logger.info("Using database as data source")
app.logger.error(f"Database error: {str(e)}")
```

**Voting (Java/Spring Boot):**
```java
logger.info("Starting origami synchronization");
logger.error("Error processing vote", exception);
```

**Recommendation (Go/Gin):**
```go
// Gin's default logger outputs to stdout
[GIN] 2025/10/07 - 10:15:23 | 200 | 1.234567ms | GET "/api/origami-of-the-day"
```

### ❌ Don't Do This

```javascript
// Don't write logs to files
fs.appendFile('/var/log/app.log', message)  // ❌

// Don't use custom log endpoints
app.get('/logs', (req, res) => res.send(logs))  // ❌

// Don't send logs directly to external services
// (Promtail handles this)
axios.post('http://loki:3100/loki/api/v1/push')  // ❌
```

---

## Promtail Configuration Example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 3101

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      # Scrape all pod logs
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod

        relabel_configs:
          # Add namespace label
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace

          # Add pod label
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod

          # Add container label
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container

          # Add app label from pod labels
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: app

        pipeline_stages:
          # Parse log level from log content
          - regex:
              expression: '^.*(?P<level>(INFO|ERROR|WARN|DEBUG)).*$'
          - labels:
              level:
```

---

## Querying Logs in Grafana

### LogQL Query Examples

```logql
# 1. All logs from frontend service
{app="frontend"}

# 2. Error logs only
{app="frontend"} |= "ERROR"

# 3. Logs from last 5 minutes with error
{app="frontend"} |= "ERROR" | json | line_format "{{.message}}"

# 4. HTTP 5xx errors across all services
{namespace="craftista"} |~ "\\| 5[0-9]{2} \\|"

# 5. Database errors in catalogue service
{app="catalogue"} |= "Database error"

# 6. Voting service synchronization logs
{app="voting"} |= "synchronization"

# 7. Slow requests (>1 second)
{app="recommendation"} |~ "\\| [0-9]+\\.[0-9]+s \\|"

# 8. Count error rate
sum(rate({app="frontend"} |= "ERROR" [5m])) by (pod)

# 9. Logs from specific pod
{pod="frontend-abc123-xyz"}

# 10. Logs with JSON parsing
{app="catalogue"} | json | level="error"
```

---

## Deployment Steps

### 1. Install Loki Stack

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki + Promtail
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --create-namespace \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.config.table_manager.retention_deletes_enabled=true \
  --set loki.config.table_manager.retention_period=168h
```

### 2. Verify Installation

```bash
# Check Loki pod
kubectl get pods -n monitoring -l app=loki

# Check Promtail DaemonSet
kubectl get daemonset -n monitoring -l app=promtail

# Check Promtail pods (one per node)
kubectl get pods -n monitoring -l app=promtail
```

### 3. Configure Grafana Data Source

Loki is automatically added as a data source if installed in the same namespace. Otherwise:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
        isDefault: false
```

### 4. Test Queries in Grafana

1. Open Grafana → Explore
2. Select "Loki" data source
3. Run query: `{namespace="craftista"}`
4. Should see logs from all services

---

## Monitoring Promtail & Loki

### Check Promtail Status

```bash
# View Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=50

# Check if Promtail is sending logs
kubectl logs -n monitoring -l app=promtail | grep "pushed"

# Port-forward to Promtail metrics
kubectl port-forward -n monitoring daemonset/promtail 3101:3101
curl http://localhost:3101/metrics
```

### Check Loki Status

```bash
# View Loki logs
kubectl logs -n monitoring -l app=loki --tail=50

# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Check Loki ready
curl http://localhost:3100/ready

# Check Loki metrics
curl http://localhost:3100/metrics
```

---

## Troubleshooting

### Promtail Not Collecting Logs

```bash
# Check Promtail is running on all nodes
kubectl get pods -n monitoring -l app=promtail -o wide

# Check Promtail can access pod logs
kubectl exec -n monitoring <promtail-pod> -- ls -la /var/log/pods/

# Check Promtail configuration
kubectl get configmap -n monitoring promtail -o yaml
```

### Loki Not Receiving Logs

```bash
# Check Loki ingester
kubectl logs -n monitoring -l app=loki -c loki | grep ingester

# Check Loki can receive pushes
curl -X POST http://loki:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams": [{"stream": {"test": "data"}, "values": [["$(date +%s)000000000", "test log"]]}]}'
```

### No Logs Appearing in Grafana

1. Check Loki data source is configured correctly
2. Verify time range in Grafana (default is last 1 hour)
3. Test with simple query: `{namespace="craftista"}`
4. Check label names: `{app="frontend"}` not `{service="frontend"}`

---

## Resource Requirements

### Promtail (per node)
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Loki
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Storage (Loki)
- **Development**: 10Gi
- **Production**: 50Gi+ with S3 backend recommended

---

## Log Retention

Default retention is 7 days (168 hours). To change:

```yaml
# In Loki config
loki:
  config:
    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h  # 30 days
```

---

## Cost Optimization

### Loki vs Elasticsearch Costs

| Feature | Elasticsearch | Loki |
|---------|--------------|------|
| Indexing | Full-text index | Label index only |
| Storage | High (5-10x data) | Low (1-2x data) |
| CPU | High | Low |
| Memory | High | Medium |
| Cost | $$$$$ | $ |

**Example**: 100GB/day logs
- Elasticsearch: ~500GB storage, 8GB RAM, 4 CPUs
- Loki: ~150GB storage, 2GB RAM, 1 CPU

---

## Summary

✅ **Applications** → Write logs to stdout/stderr (already done)
✅ **Kubernetes** → Captures logs in /var/log/pods/
✅ **Promtail** → Reads logs, adds labels, ships to Loki
✅ **Loki** → Stores logs efficiently with label indexing
✅ **Grafana** → Query and visualize logs with LogQL

**No code changes needed. Just deploy Loki + Promtail!**

---

## Next Steps

1. Install Loki + Promtail Helm chart
2. Verify logs are being collected
3. Add Loki data source in Grafana
4. Create log dashboards
5. Set up log-based alerts
6. Configure log retention policy

---

## Additional Resources

- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Loki Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
