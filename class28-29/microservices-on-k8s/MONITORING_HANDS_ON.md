# Monitoring Hands-On Guide

A practical guide to using Prometheus and Grafana for monitoring your Kubernetes applications.

---

## Quick Access

| Tool | URL | Login |
|------|-----|-------|
| **Prometheus** | https://ms1.akhileshmishra.tech/prometheus | No login required |
| **Grafana** | https://ms1.akhileshmishra.tech/grafana | Username: `admin`<br>Password: `admin123` |

---

## Part 1: Understanding Prometheus

Prometheus is your **metrics database**. It collects numbers (metrics) from your applications every 30 seconds.

### What Prometheus Does

```
Every 30 seconds:
Prometheus → Scrapes → Your App's /metrics endpoint
          ← Receives ← cpu_usage=0.5, memory_usage=1024MB, http_requests=150
          → Stores   → In time-series database
```

---

## Part 2: Prometheus Targets Page

**URL:** https://ms1.akhileshmishra.tech/prometheus/targets

### What You'll See

A list of all applications Prometheus is monitoring.

### Check These Things

1. **State Column**
   - ✅ **UP** (green) = Prometheus is successfully collecting metrics
   - ❌ **DOWN** (red) = Something is wrong

2. **Last Scrape Column**
   - Shows when metrics were last collected
   - Should be "2s ago", "5s ago", etc.
   - If it says "1 minute ago" → Something is slow or broken

3. **Scrape Duration**
   - How long it took to collect metrics
   - Should be under 50ms
   - If it's 2 seconds+ → Your app is slow

4. **Error Column**
   - Empty = Good
   - "Connection refused" = Your app is not running
   - "Timeout" = Your app is too slow
   - "404" = Your metrics endpoint is wrong

### Real Example

```
serviceMonitor/craftista/frontend-metrics/0 (1/1 up)
└─ ✅ http://10.0.1.123:3000/metrics
   State: UP
   Last Scrape: 3.2s ago
   Scrape Duration: 12ms

✅ This is perfect! Prometheus is collecting metrics from the frontend service.
```

```
serviceMonitor/craftista/voting-metrics/0 (0/1 up)
└─ ❌ http://10.0.3.789:8080/actuator/prometheus
   State: DOWN
   Last Scrape: 2.1s ago
   Error: Get "http://...": connection refused

❌ This is broken! The voting service is not running or not exposing metrics.
```

### How to Fix Issues

**Problem:** State = DOWN, Error = "connection refused"
- **Cause:** Service is not running
- **Fix:** Check if pod is running: `kubectl get pods -n craftista`

**Problem:** State = DOWN, Error = "404"
- **Cause:** Wrong metrics endpoint URL
- **Fix:** Check if you're using the correct path (e.g., `/metrics` vs `/actuator/prometheus`)

**Problem:** State = UP but "Last Scrape" is old (> 1 minute)
- **Cause:** Prometheus is overloaded or network issues
- **Fix:** Check Prometheus pod logs

---

## Part 3: Prometheus Graph UI

**URL:** https://ms1.akhileshmishra.tech/prometheus/graph

### What It Does

Test PromQL queries and see quick graphs. Like SQL but for metrics.

### Quick Queries to Try

#### 1. Check if Services Are Running
```promql
up
```
**What you see:**
```
up{job="frontend"} = 1    ← Service is up
up{job="catalogue"} = 1
up{job="voting"} = 0      ← Service is down!
```

#### 2. Current CPU Usage
```promql
rate(container_cpu_usage_seconds_total[5m])
```
**What it means:** CPU usage over the last 5 minutes

#### 3. Memory Usage by Pod
```promql
container_memory_usage_bytes / 1024 / 1024
```
**What it means:** Memory in MB for each container

#### 4. HTTP Request Rate
```promql
rate(frontend_http_requests_total[5m])
```
**What it means:** How many requests per second your frontend is handling

#### 5. Error Rate
```promql
rate(frontend_http_requests_total{status_code="500"}[5m])
```
**What it means:** How many 5xx errors per second

#### 6. P95 Response Time
```promql
histogram_quantile(0.95, rate(frontend_http_request_duration_seconds_bucket[5m]))
```
**What it means:** 95% of requests complete within X seconds

### How to Use Graph UI

1. **Type a query** in the text box
2. **Click "Execute"** button
3. **Choose view:**
   - **Table** = See exact numbers
   - **Graph** = See trend over time
4. **Adjust time range** at the top (1h, 3h, 24h, etc.)

### Tips

- Start simple: Try `up` first
- Use **Ctrl+Space** to see suggestions
- Click on metric names in the table to add them to your query
- Use the **⊞** button next to metrics to copy the query

---

## Part 4: Prometheus Alerts

**URL:** https://ms1.akhileshmishra.tech/prometheus/alerts

### What You'll See

List of all alerting rules and their current state.

### Alert States

- **Inactive** (green) = Everything is fine
- **Pending** (yellow) = Problem detected, waiting to see if it persists
- **Firing** (red) = Alert is active! Something is wrong!

### Common Alerts

| Alert Name | What It Means | What to Do |
|------------|---------------|------------|
| **KubePodCrashLooping** | A pod keeps restarting | Check pod logs: `kubectl logs <pod>` |
| **KubePodNotReady** | Pod is not ready to serve traffic | Check pod status: `kubectl describe pod <pod>` |
| **KubeNodeNotReady** | A node is down | Check node: `kubectl get nodes` |
| **PrometheusTargetDown** | Can't scrape metrics from a service | Check Targets page |

---

## Part 5: Using Grafana

**URL:** https://ms1.akhileshmishra.tech/grafana

**Login:**
- Username: `admin`
- Password: `admin123`

### What Grafana Does

Grafana takes Prometheus data and makes it **beautiful**. It's like Excel charts for your metrics.

---

## Part 6: Grafana Dashboard Tour

### Step 1: Find Dashboards

1. Click **☰** (hamburger menu) on the left
2. Click **Dashboards**
3. You'll see pre-installed dashboards:
   - Kubernetes Cluster Monitoring
   - Kubernetes Networking (Pod)
   - NGINX Ingress Controller
   - Node Exporter

### Step 2: Open a Dashboard

Click on **"Kubernetes Cluster Monitoring"**

### What You'll See

**Top Row (Overview):**
- Total CPU Usage
- Total Memory Usage
- Total Pods Running
- Total Nodes

**Second Row (Per Namespace):**
- CPU usage by namespace
- Memory usage by namespace
- Network traffic by namespace

**Bottom Rows:**
- Individual pod metrics
- Container restarts
- Disk usage

### How to Use Dashboards

1. **Time Range** (top right)
   - Click to change: Last 5m, 15m, 1h, 6h, 24h
   - Click **↻** to refresh

2. **Variables** (top dropdowns)
   - Select namespace: `craftista`, `monitoring`, etc.
   - Select pod: `frontend-abc123`, etc.
   - Dashboard updates automatically

3. **Panel Actions**
   - **Hover over a graph** → See exact values
   - **Click and drag** → Zoom into time range
   - **Double click** → Reset zoom
   - **Click panel title** → More options (Edit, Share, etc.)

---

## Part 7: Pre-Installed Dashboards (From Terraform)

Your monitoring stack comes with 3 dashboards automatically imported from Grafana.com.

### Dashboard 1: Kubernetes Cluster Monitoring (ID: 7249)

**Access:** Dashboards → Browse → "Kubernetes Cluster Monitoring"

**What it shows:**
- **Overview Row:**
  - Total CPU usage across cluster
  - Total memory usage
  - Total pods running
  - Current pod capacity

- **Deployment Stats:**
  - Deployments by namespace
  - ReplicaSet status
  - StatefulSet status

- **Pod Resources:**
  - CPU usage per pod
  - Memory usage per pod
  - CPU requests vs limits
  - Memory requests vs limits

- **Network:**
  - Network I/O by namespace
  - Network I/O by pod

**What to look for:**
- ✅ CPU usage < 70% → Healthy
- ⚠️ CPU usage 70-90% → Consider scaling
- ❌ CPU usage > 90% → Scale immediately!
- ✅ Memory usage < 80% → Healthy
- ❌ Pods restarting → Check logs
- ❌ High network I/O → Investigate which pod

**Variables (top of dashboard):**
- **Datasource:** Select Prometheus (default)
- **Cluster:** Select your cluster
- **Namespace:** Filter by namespace (`craftista`, `monitoring`, etc.)

---

### Dashboard 2: Kubernetes Networking (Pod) (ID: 6417)

**Access:** Dashboards → Browse → "Kubernetes Networking (Pod)"

**What it shows:**
- **Current Rate:**
  - Receive bandwidth (download)
  - Transmit bandwidth (upload)
  - Rate of received packets
  - Rate of transmitted packets

- **Errors:**
  - Receive errors
  - Transmit errors
  - Receive packets dropped
  - Transmit packets dropped

- **Historical Data:**
  - Bandwidth over time
  - Packet rate over time
  - Error rate over time

**What to look for:**
- ✅ No dropped packets → Network is healthy
- ❌ Packet drops increasing → Network congestion or pod issues
- ⚠️ High receive rate → Pod is downloading a lot (check if expected)
- ⚠️ High transmit rate → Pod is uploading a lot
- ❌ Error rate > 0 → Network interface issues

**Variables:**
- **Cluster:** Select your cluster
- **Namespace:** Select namespace (e.g., `craftista`)
- **Pod:** Select specific pod to monitor

**Use Cases:**
- Debug slow network performance
- Find which pod is using too much bandwidth
- Detect network interface errors

---

### Dashboard 3: NGINX Ingress Controller (ID: 9614)

**Access:** Dashboards → Browse → "NGINX Ingress Controller"

**What it shows:**
- **Overview:**
  - Total requests per second
  - Success rate (2xx, 3xx responses)
  - Error rate (4xx, 5xx responses)
  - P50, P95, P99 response times

- **By Ingress:**
  - Requests per ingress resource
  - Response time per ingress
  - Errors per ingress

- **Controller Stats:**
  - NGINX reloads
  - Config reload errors
  - SSL certificate expiry time

**What to look for:**
- ✅ Success rate > 99% → Healthy
- ⚠️ 4xx errors increasing → Bad client requests (check what's being requested)
- ❌ 5xx errors → Your application is broken!
- ✅ P95 response time < 1 second → Fast
- ⚠️ P95 response time > 2 seconds → Slow, investigate
- ❌ Config reload errors → Check ingress YAML

**Variables:**
- **Namespace:** Filter by namespace
- **Ingress:** Filter by specific ingress resource
- **Status:** Filter by HTTP status code

**Use Cases:**
- Monitor overall application traffic
- Detect traffic spikes
- Find slow endpoints
- Debug 5xx errors

---

## Part 8: Creating Custom Dashboards for Your Apps

Now let's create custom dashboards to monitor your microservices!

### Dashboard 4: Craftista Application Dashboard (Custom)

We'll create a dashboard to monitor all 4 microservices in one place.

#### Step 1: Create New Dashboard

1. Click **☰** (hamburger menu) → **Dashboards**
2. Click **New** → **New Dashboard**
3. Click **+ Add visualization**

#### Step 2: Add Frontend Panel

1. **Select datasource:** Prometheus
2. **Panel title:** Click "Panel Title" → Edit → "Frontend - Request Rate"
3. **Query:**
   ```promql
   rate(frontend_http_requests_total[5m])
   ```
4. **Legend:** `{{method}} {{route}}`
5. **Panel type:** Time series (default)
6. **Unit:** req/s (in right sidebar → Standard options → Unit → "requests/sec")
7. Click **Apply**

#### Step 3: Add Catalogue Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "Catalogue - Request Rate"
3. **Query:**
   ```promql
   rate(catalogue_http_requests_total[5m])
   ```
4. **Legend:** `{{method}} {{endpoint}}`
5. Click **Apply**

#### Step 4: Add Voting Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "Voting - Request Rate"
3. **Query:**
   ```promql
   rate(http_server_requests_seconds_count{namespace="craftista", pod=~"voting.*"}[5m])
   ```
4. **Legend:** `{{method}} {{uri}}`
5. Click **Apply**

#### Step 5: Add Recommendation Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "Recommendation - Request Rate"
3. **Query:**
   ```promql
   rate(recommendation_http_requests_total[5m])
   ```
4. **Legend:** `{{method}} {{endpoint}}`
5. Click **Apply**

#### Step 6: Add Error Rate Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "Error Rate (All Services)"
3. **Query A:**
   ```promql
   rate(frontend_http_requests_total{status_code=~"5.."}[5m])
   ```
4. **Query B (click + Query):**
   ```promql
   rate(catalogue_http_requests_total{status=~"5.."}[5m])
   ```
5. **Query C:**
   ```promql
   rate(http_server_requests_seconds_count{namespace="craftista", pod=~"voting.*", status=~"5.."}[5m])
   ```
6. **Query D:**
   ```promql
   rate(recommendation_http_requests_total{status=~"Internal Server Error"}[5m])
   ```
7. **Legend:** `{{job}} errors`
8. Click **Apply**

#### Step 7: Add Response Time Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "P95 Response Time"
3. **Query A (Frontend):**
   ```promql
   histogram_quantile(0.95, rate(frontend_http_request_duration_seconds_bucket[5m]))
   ```
4. **Query B (Catalogue):**
   ```promql
   histogram_quantile(0.95, rate(catalogue_http_request_duration_seconds_bucket[5m]))
   ```
5. **Query C (Voting):**
   ```promql
   histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{namespace="craftista", pod=~"voting.*"}[5m]))
   ```
6. **Query D (Recommendation):**
   ```promql
   histogram_quantile(0.95, rate(recommendation_http_request_duration_seconds_bucket[5m]))
   ```
7. **Legend:** Use expressions like `Frontend P95`, `Catalogue P95`, etc.
8. **Unit:** seconds (s)
9. Click **Apply**

#### Step 8: Add Memory Usage Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "Memory Usage by Service"
3. **Query:**
   ```promql
   sum(container_memory_usage_bytes{namespace="craftista", container!=""}) by (pod) / 1024 / 1024
   ```
4. **Legend:** `{{pod}}`
5. **Unit:** MiB
6. Click **Apply**

#### Step 9: Add CPU Usage Panel

1. Click **Add** → **Visualization**
2. **Panel title:** "CPU Usage by Service"
3. **Query:**
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="craftista", container!=""}[5m])) by (pod)
   ```
4. **Legend:** `{{pod}}`
5. **Unit:** cores
6. Click **Apply**

#### Step 10: Save Dashboard

1. Click **💾 Save dashboard** (top right)
2. **Name:** "Craftista Application Monitoring"
3. **Folder:** General (or create new folder)
4. Click **Save**

---

### Dashboard 5: Service-Specific Deep Dive (Example: Frontend)

Create detailed dashboard for a single service.

#### Step 1: Create Dashboard

1. **New Dashboard** → **+ Add visualization**

#### Step 2: Add Key Panels

**Panel 1: Request Rate by Route**
```promql
rate(frontend_http_requests_total[5m])
```
Legend: `{{method}} {{route}} - {{status_code}}`

**Panel 2: Service Dependency Health**
```promql
frontend_service_dependency_up
```
Legend: `{{service}}`
Panel type: **Stat**
Thresholds: 1 = Green, 0 = Red

**Panel 3: Error Breakdown**
```promql
sum(rate(frontend_http_requests_total{status_code=~"5.."}[5m])) by (route)
```
Legend: `{{route}}`
Panel type: **Bar chart**

**Panel 4: Request Duration Heatmap**
Query:
```promql
rate(frontend_http_request_duration_seconds_bucket[5m])
```
Panel type: **Heatmap**

**Panel 5: Active Handles (Node.js specific)**
```promql
frontend_nodejs_active_handles_total
```

**Panel 6: Event Loop Lag**
```promql
frontend_nodejs_eventloop_lag_seconds
```
Unit: seconds
Thresholds: < 0.1 = Green, > 0.1 = Yellow, > 0.5 = Red

#### Step 3: Add Variables

1. Click **⚙️ Dashboard settings** (top right)
2. Click **Variables** → **New variable**
3. **Name:** `interval`
4. **Type:** Interval
5. **Values:** `5m,10m,30m,1h,6h`
6. Click **Apply**

Now you can use `$interval` in queries:
```promql
rate(frontend_http_requests_total[$interval])
```

#### Step 4: Organize Panels into Rows

1. Click **Add** → **Row**
2. Name it "Request Metrics"
3. Drag panels into the row
4. Create more rows: "Performance Metrics", "Resource Usage"

#### Step 5: Save Dashboard

Name: "Frontend Service - Deep Dive"

---

## Part 9: Dashboard Best Practices

### Layout Tips

**Good Dashboard Structure:**
```
Row 1: Overview (4 panels)
  - Total requests | Error rate | P95 latency | Service health

Row 2: Traffic Analysis (2-3 panels)
  - Requests by route | Requests by method | Top errors

Row 3: Performance (2-3 panels)
  - Response time distribution | Slow endpoints | Cache hit rate

Row 4: Resources (2 panels)
  - CPU usage | Memory usage

Row 5: Dependencies (1-2 panels)
  - Downstream service health | Database connection pool
```

### Panel Design Tips

✅ **Do:**
- Use clear, descriptive titles
- Add units (req/s, seconds, MiB, etc.)
- Use legends with meaningful labels
- Set appropriate thresholds (Green/Yellow/Red)
- Use the right visualization type

❌ **Don't:**
- Put too many metrics in one panel (max 10 lines)
- Use default panel titles like "Panel Title"
- Forget to set time ranges
- Use complex queries without comments

### Color Coding

Use consistent colors across dashboards:
- **Green:** Healthy, < 70% utilization
- **Yellow:** Warning, 70-90% utilization
- **Red:** Critical, > 90% utilization, errors

### Useful Panel Types

| Data Type | Best Panel Type |
|-----------|----------------|
| Trends over time | Time series |
| Current value | Stat |
| Distribution | Heatmap |
| Comparison | Bar chart |
| Proportions | Pie chart |
| Yes/No status | Stat with thresholds |
| Top N items | Table |

---

## Part 10: Exporting and Sharing Dashboards

### Export Dashboard as JSON

1. Open dashboard
2. Click **⚙️ Dashboard settings**
3. Click **JSON Model**
4. Click **Copy to Clipboard**
5. Save to file: `craftista-dashboard.json`

### Import Dashboard

1. Click **☰** → **Dashboards**
2. Click **New** → **Import**
3. **Method 1:** Paste JSON
4. **Method 2:** Upload JSON file
5. **Method 3:** Import via Grafana.com ID
6. Select Prometheus datasource
7. Click **Import**

### Share Dashboard with Team

**Option 1: Export to Git**
```bash
# Save dashboard JSON
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://ms1.akhileshmishra.tech/grafana/api/dashboards/uid/YOUR_DASHBOARD_UID \
  > dashboard.json

# Commit to Git
git add dashboard.json
git commit -m "Add Craftista monitoring dashboard"
git push
```

**Option 2: Snapshot Link**
1. Click **Share** (top right)
2. Click **Snapshot**
3. Set expiry time
4. Click **Publish to snapshot.raintank.io**
5. Copy link and share

**Option 3: Direct Link**
Just share the URL - anyone with access to Grafana can view it!

---

## Part 11: Creating Alerts in Grafana

### Step 1: Open a Panel

Click on any graph title → **Edit**

### Step 2: Go to Alert Tab

Click **Alert** tab on the left

### Step 3: Create Alert Rule

1. **Set Condition:**
   ```
   WHEN avg() OF query(A, 5m, now) IS ABOVE 0.8
   ```
   This means: Alert when average CPU usage is above 80%

2. **Set Duration:**
   - Wait 5 minutes before alerting (avoid false alarms)

3. **Save Dashboard** (top right)

---

## Part 12: Practical Monitoring Scenarios

### Scenario 1: "My App is Slow"

**Steps:**
1. **Check Prometheus Targets** → Is metrics collection working?
2. **Open Grafana** → Kubernetes Cluster dashboard
3. **Look at CPU/Memory** → Is a pod using 100% CPU?
4. **Check Response Times** → NGINX Ingress dashboard → P95 latency graph
5. **Run PromQL Query:**
   ```promql
   histogram_quantile(0.95, rate(frontend_http_request_duration_seconds_bucket[5m]))
   ```

**If response time is high:**
- Scale up: `kubectl scale deployment frontend --replicas=5 -n craftista`

### Scenario 2: "I'm Getting 5xx Errors"

**Steps:**
1. **Check Error Rate in Grafana:**
   - NGINX Ingress dashboard → Look for 5xx errors graph

2. **Run PromQL Query:**
   ```promql
   rate(frontend_http_requests_total{status_code="500"}[5m])
   ```

3. **Check Which Service:**
   - Look at Prometheus Targets → Which service is DOWN?

4. **Check Logs:**
   ```bash
   kubectl logs -n craftista deployment/frontend --tail=50
   ```

### Scenario 3: "Pod Keeps Restarting"

**Steps:**
1. **Check Grafana Alerts** → Look for "KubePodCrashLooping"

2. **Check Container Restarts:**
   ```promql
   kube_pod_container_status_restarts_total
   ```

3. **Find the Pod:**
   ```bash
   kubectl get pods -n craftista
   ```

4. **Check Logs:**
   ```bash
   kubectl logs <pod-name> -n craftista --previous
   ```

### Scenario 4: "High Memory Usage"

**Steps:**
1. **Grafana** → Kubernetes Cluster dashboard → Memory graph

2. **Find the Pod:**
   ```promql
   topk(5, container_memory_usage_bytes / 1024 / 1024)
   ```

3. **Check if it's a memory leak:**
   - Look at memory graph over 24 hours
   - If it keeps going up → Memory leak
   - If it's stable → Normal usage

---

## Part 13: Quick Troubleshooting Guide

### Problem: "No data in Grafana"

**Check:**
1. Prometheus Targets → Are services UP?
2. Grafana Data Source → Configuration → Datasources → Prometheus → Test
3. Time Range → Are you looking at the right time?

### Problem: "Metrics not showing up"

**Check:**
1. Is your app exposing `/metrics` endpoint?
   ```bash
   kubectl port-forward -n craftista deployment/frontend 3000:3000
   curl http://localhost:3000/metrics
   ```

2. Is ServiceMonitor created?
   ```bash
   kubectl get servicemonitor -n craftista
   ```

3. Check Prometheus Targets page → Is your service listed?

### Problem: "Grafana dashboard is empty"

**Check:**
1. Variables at the top → Select correct namespace/pod
2. Time range → Extend to "Last 6 hours"
3. Panel query → Click "Edit" → Check if query is correct

---

## Part 14: Best Practices

### Do This:

✅ **Check Targets daily** → Make sure all services are UP
✅ **Look at dashboards weekly** → Spot trends early
✅ **Set up alerts** → Get notified before users complain
✅ **Use time ranges** → Compare yesterday vs today
✅ **Export dashboards** → Save your custom dashboards as JSON

### Don't Do This:

❌ **Don't ignore DOWN targets** → Fix them immediately
❌ **Don't set alerts for everything** → You'll get alert fatigue
❌ **Don't keep only 1 hour of metrics** → Increase retention to 15 days
❌ **Don't forget to test alerts** → Make sure they actually fire
❌ **Don't modify default dashboards** → Clone them first

---

## Part 15: Useful PromQL Queries

### Resource Usage

```promql
# CPU usage per pod
rate(container_cpu_usage_seconds_total{namespace="craftista"}[5m])

# Memory usage per pod
container_memory_usage_bytes{namespace="craftista"} / 1024 / 1024

# Disk usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

### Application Metrics

```promql
# Request rate
rate(frontend_http_requests_total[5m])

# Error rate
rate(frontend_http_requests_total{status_code="500"}[5m])

# Request duration (average)
rate(frontend_http_request_duration_seconds_sum[5m]) / rate(frontend_http_request_duration_seconds_count[5m])

# P95 latency
histogram_quantile(0.95, rate(frontend_http_request_duration_seconds_bucket[5m]))
```

### Kubernetes Health

```promql
# Pods not ready
kube_pod_status_phase{phase!="Running"}

# Container restarts
rate(kube_pod_container_status_restarts_total[5m])

# Node CPU usage
instance:node_cpu_utilisation:rate5m * 100

# Node memory usage
instance:node_memory_utilisation:ratio * 100
```

---

## Part 16: Learning Resources

### Understand PromQL Better

**Start with these queries in Graph UI:**

1. Type: `up` → See what's running
2. Type: `up{job="frontend"}` → Filter by service
3. Type: `rate(up[5m])` → See rate of change
4. Type: `sum(up)` → Count total services up

**PromQL Functions to Learn:**
- `rate()` → Calculate per-second rate
- `sum()` → Add values together
- `avg()` → Calculate average
- `max()` → Find maximum value
- `topk(5, ...)` → Find top 5 values

### Grafana Tips

**Create Your First Dashboard:**

1. Click **+** → Create Dashboard
2. Click **Add visualization**
3. Select **Prometheus** datasource
4. Enter query: `rate(frontend_http_requests_total[5m])`
5. Click **Apply**
6. Click **💾 Save** (top right)

**Import Community Dashboards:**

1. Click **+** → Import
2. Enter dashboard ID:
   - `11159` - Node.js Application Dashboard
   - `11378` - Spring Boot Dashboard
   - `6417` - Kubernetes Pods
3. Select Prometheus datasource
4. Click **Import**

---

## Part 17: Next Steps

### Week 1: Learn the Basics
- [ ] Check Prometheus Targets daily
- [ ] Open each pre-installed Grafana dashboard
- [ ] Run 5 PromQL queries in Graph UI
- [ ] Understand one dashboard completely

### Week 2: Customize
- [ ] Create your first custom Grafana dashboard
- [ ] Set up one alert rule
- [ ] Test the alert (make it fire)
- [ ] Import a community dashboard

### Week 3: Advanced
- [ ] Create dashboards for your custom metrics
- [ ] Set up Alertmanager notifications (Slack/Email)
- [ ] Learn advanced PromQL (aggregations, joins)
- [ ] Set up recording rules for expensive queries

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│ MONITORING CHEAT SHEET                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Prometheus Targets:                                         │
│   URL: /prometheus/targets                                  │
│   Use: Check if metrics collection is working              │
│                                                             │
│ Prometheus Graph:                                           │
│   URL: /prometheus/graph                                    │
│   Use: Test PromQL queries quickly                         │
│                                                             │
│ Grafana Dashboards:                                         │
│   URL: /grafana                                             │
│   Use: Beautiful visualizations of metrics                 │
│                                                             │
│ Quick Queries:                                              │
│   up                           → Is service running?        │
│   rate(cpu_usage[5m])          → CPU usage trend           │
│   container_memory_usage_bytes → Memory usage              │
│                                                             │
│ Troubleshooting Flow:                                       │
│   1. Check Targets → Is scraping working?                  │
│   2. Check Graph UI → Are metrics being collected?         │
│   3. Check Grafana → What does the data show?              │
│   4. Check Alerts → Are there any active alerts?           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

**Remember:**
- **Prometheus** = Collects and stores metrics
- **Grafana** = Makes metrics pretty and usable
- **Targets Page** = Your health check dashboard
- **Graph UI** = Your query testing tool
- **Grafana Dashboards** = Your monitoring command center

Start simple. Master the basics. Then explore advanced features! 🚀
