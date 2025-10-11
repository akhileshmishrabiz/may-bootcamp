# Monitoring Stack Documentation

## Overview

This monitoring stack deploys **Prometheus** and **Grafana** to your EKS cluster for comprehensive application and infrastructure monitoring.

## What's Deployed

### 1. **Prometheus**
- **Purpose**: Metrics collection and storage
- **Version**: Latest from kube-prometheus-stack
- **Retention**: 15 days
- **Storage**: 20GB persistent volume
- **Access**: `https://${subdomain}.${domain}/prometheus`

### 2. **Grafana**
- **Purpose**: Metrics visualization and dashboards
- **Version**: Latest from kube-prometheus-stack
- **Storage**: 10GB persistent volume
- **Access**: `https://${subdomain}.${domain}/grafana`
- **Default Credentials**:
  - Username: `admin`
  - Password: `admin123` ⚠️ **CHANGE IN PRODUCTION!**

### 3. **Additional Components**
- **Alertmanager**: For alert routing and management
- **Node Exporter**: For node-level metrics
- **Kube State Metrics**: For Kubernetes object metrics
- **ServiceMonitors**: Auto-discovery of application metrics

## Pre-configured Dashboards

Grafana comes with several pre-imported dashboards:

1. **Kubernetes Cluster Monitoring** (ID: 7249)
   - Overall cluster health
   - Node resource usage
   - Pod statistics

2. **Kubernetes Pods Monitoring** (ID: 6417)
   - Pod CPU and memory usage
   - Container metrics
   - Resource requests vs limits

3. **NGINX Ingress Controller** (ID: 9614)
   - Request rates
   - Response times
   - Error rates

## Application Monitoring

ServiceMonitors are configured for all Craftista microservices:

### 1. **Frontend Service**
- **Metrics Endpoint**: `/metrics`
- **Scrape Interval**: 30s

### 2. **Catalogue Service**
- **Metrics Endpoint**: `/metrics`
- **Scrape Interval**: 30s

### 3. **Voting Service** (Spring Boot)
- **Metrics Endpoint**: `/actuator/prometheus`
- **Scrape Interval**: 30s

### 4. **Recommendation Service**
- **Metrics Endpoint**: `/metrics`
- **Scrape Interval**: 30s

## Deployment

### Apply the Terraform Configuration

```bash
# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan

# Apply the monitoring stack
terraform apply -target=helm_release.kube_prometheus_stack
```

### Full Infrastructure Deployment

```bash
terraform apply
```

## Post-Deployment Steps

### 1. Get Access URLs

```bash
# Get all outputs including monitoring URLs
terraform output

# Get Grafana URL specifically
terraform output grafana_url

# Get Grafana password (marked as sensitive)
terraform output -raw grafana_admin_password
```

### 2. Access Grafana

1. Navigate to: `https://ms1.akhileshmishra.tech/grafana`
2. Login with credentials:
   - Username: `admin`
   - Password: `admin123`
3. **Important**: Change the admin password immediately:
   - Click on profile icon → Preferences → Change Password

### 3. Access Prometheus

Navigate to: `https://ms1.akhileshmishra.tech/prometheus`

### 4. Verify ServiceMonitors

```bash
# Check if ServiceMonitors are created
kubectl get servicemonitor -n craftista

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then open: http://localhost:9090/targets
```

## Customization

### Update Grafana Admin Password

Edit `monitoring.tf` and change:

```hcl
grafana = {
  adminPassword = "your-secure-password-here"
}
```

Then apply:

```bash
terraform apply
```

### Adjust Resource Limits

Modify the `resources` blocks in `monitoring.tf`:

```hcl
resources = {
  requests = {
    cpu    = "500m"
    memory = "1Gi"
  }
  limits = {
    cpu    = "1000m"
    memory = "2Gi"
  }
}
```

### Change Data Retention

Update Prometheus retention settings:

```hcl
prometheusSpec = {
  retention = "30d"        # Keep metrics for 30 days
  retentionSize = "50GB"   # Max storage size
}
```

### Add Custom Dashboards

You can import additional dashboards from [Grafana Dashboards](https://grafana.com/grafana/dashboards/):

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID or paste JSON
3. Select Prometheus datasource

Or add them to Terraform:

```hcl
dashboards = {
  default = {
    my-custom-dashboard = {
      gnetId     = 12345  # Dashboard ID from grafana.com
      revision   = 1
      datasource = "Prometheus"
    }
  }
}
```

## Application Instrumentation

For Prometheus to scrape metrics, your applications need to expose metrics endpoints.

### Node.js (Frontend/Express)

```javascript
const promClient = require('prom-client');
const express = require('express');

// Create a Registry
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### Python (Catalogue/Flask)

```python
from prometheus_client import Counter, Histogram, generate_latest
from flask import Flask, Response

app = Flask(__name__)

# Define metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype='text/plain')
```

### Go (Recommendation)

```go
package main

import (
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "net/http"
)

func main() {
    // Expose metrics endpoint
    http.Handle("/metrics", promhttp.Handler())

    // Your application routes
    http.HandleFunc("/", handler)

    http.ListenAndServe(":8080", nil)
}
```

### Java/Spring Boot (Voting)

Spring Boot with Actuator automatically exposes metrics at `/actuator/prometheus`.

Add to `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

Add to `application.properties`:

```properties
management.endpoints.web.exposure.include=health,info,prometheus
management.metrics.export.prometheus.enabled=true
```

## Monitoring Best Practices

### 1. **Use Labels Wisely**
- Add meaningful labels to metrics
- Avoid high-cardinality labels (e.g., user IDs)
- Use consistent naming conventions

### 2. **Key Metrics to Monitor**
- **RED Method** (for services):
  - **R**ate: Request rate
  - **E**rrors: Error rate
  - **D**uration: Request duration
- **USE Method** (for resources):
  - **U**tilization: Resource usage percentage
  - **S**aturation: Queue depth, waiting time
  - **E**rrors: Error count

### 3. **Set Up Alerts**
Create alert rules in Prometheus for:
- High error rates (> 5%)
- Slow response times (> 1s)
- High CPU/memory usage (> 80%)
- Pod restart count
- Certificate expiration

### 4. **Dashboard Organization**
- Create separate dashboards for each service
- Include SLI/SLO metrics
- Add business metrics alongside technical metrics

## Alerting

### Configure Alertmanager

Edit the Alertmanager configuration in `monitoring.tf`:

```hcl
alertmanager = {
  config = {
    global = {
      slack_api_url = "your-slack-webhook-url"
    }
    route = {
      group_by = ["alertname", "cluster"]
      receiver = "slack-notifications"
    }
    receivers = [
      {
        name = "slack-notifications"
        slack_configs = [
          {
            channel  = "#alerts"
            text     = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
          }
        ]
      }
    ]
  }
}
```

### Example Alert Rules

Create custom alert rules:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} requests/second"
```

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n craftista -o yaml

# Check if services have correct labels
kubectl get svc -n craftista --show-labels

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f
```

### Grafana Not Loading Dashboards

```bash
# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Check if datasource is configured
kubectl exec -n monitoring -it deploy/kube-prometheus-stack-grafana -- grafana-cli admin data-sources list
```

### High Memory Usage

```bash
# Check Prometheus memory
kubectl top pod -n monitoring -l app.kubernetes.io/name=prometheus

# Reduce retention or increase resources in monitoring.tf
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Check certificate status
kubectl get certificate -n monitoring
kubectl describe certificate grafana-tls -n monitoring
```

## Cleanup

To remove the monitoring stack:

```bash
# Remove monitoring resources
terraform destroy -target=helm_release.kube_prometheus_stack

# Or remove all infrastructure
terraform destroy
```

**Note**: This will delete all metrics data stored in persistent volumes.

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Prometheus and Grafana logs
3. Consult the official documentation
4. Check ServiceMonitor configurations

---

**Last Updated**: 2025-10-07
**Terraform Version**: >= 1.0
**Kubernetes Version**: 1.31
