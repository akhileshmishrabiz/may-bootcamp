# Voting Service (Java/Spring Boot)

## Overview

The Voting microservice manages user voting functionality for origami designs in the Craftista application. Built with Spring Boot, it provides a REST API for voting operations and synchronizes origami data from the Catalogue service.

---

## Build Information

- **Language**: Java
- **Framework**: Spring Boot 2.5.5
- **Java Version**: 17 (tested with OpenJDK 19)
- **Port**: 8080
- **Build Tool**: Maven (tested with version 3.19)
- **Build Command**: `mvn package -DskipTests`
- **Launch Command**: `java -jar app.jar` or `mvn spring-boot:run`

---

## Dependencies

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
    <dependency>
        <groupId>com.h2database</groupId>
        <artifactId>h2</artifactId>
    </dependency>
</dependencies>
```

---

## Monitoring & Observability

### Metrics (Prometheus)

The service exposes Prometheus metrics through Spring Boot Actuator at `/actuator/prometheus` endpoint.

#### Metrics Endpoint
- **URL**: `http://localhost:8080/actuator/prometheus`
- **Format**: Prometheus text format
- **Scrape Interval**: 30 seconds (configured in ServiceMonitor)

#### Available Metrics

##### HTTP Request Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `http_server_requests_seconds` | Summary | method, uri, status, outcome | HTTP request duration and count |
| `http_server_requests_seconds_max` | Gauge | method, uri, status, outcome | Maximum request duration |

##### JVM Metrics

| Metric | Description |
|--------|-------------|
| `jvm_memory_used_bytes` | Used memory in bytes by memory area |
| `jvm_memory_max_bytes` | Maximum memory in bytes by memory area |
| `jvm_memory_committed_bytes` | Committed memory in bytes by memory area |
| `jvm_gc_pause_seconds` | Garbage collection pause duration |
| `jvm_gc_memory_allocated_bytes_total` | Total bytes allocated |
| `jvm_threads_live` | Live threads count |
| `jvm_threads_daemon` | Daemon threads count |
| `jvm_classes_loaded` | Loaded classes count |

##### System Metrics

| Metric | Description |
|--------|-------------|
| `system_cpu_usage` | System CPU usage |
| `system_cpu_count` | Number of CPUs |
| `process_cpu_usage` | Process CPU usage |
| `process_uptime_seconds` | Process uptime |
| `process_start_time_seconds` | Process start time |

##### Database Metrics (H2)

| Metric | Description |
|--------|-------------|
| `hikaricp_connections_active` | Active database connections |
| `hikaricp_connections_idle` | Idle database connections |
| `hikaricp_connections_pending` | Pending database connections |
| `hikaricp_connections_timeout_total` | Connection timeouts |

##### Tomcat Metrics

| Metric | Description |
|--------|-------------|
| `tomcat_sessions_active_current` | Active sessions |
| `tomcat_sessions_created_total` | Total sessions created |
| `tomcat_threads_busy` | Busy threads |
| `tomcat_threads_current` | Current threads |

#### Metric Labels Explained

- **method**: HTTP method (GET, POST, PUT, DELETE)
- **uri**: Request URI pattern
- **status**: HTTP status code
- **outcome**: Request outcome (SUCCESS, CLIENT_ERROR, SERVER_ERROR)
- **exception**: Exception class name (if any)
- **application**: Application name tag (voting-service)
- **environment**: Environment tag (dev/staging/prod)

#### Example Prometheus Queries

```promql
# Request rate per second
rate(http_server_requests_seconds_count[5m])

# Average request duration by endpoint
rate(http_server_requests_seconds_sum[5m]) / rate(http_server_requests_seconds_count[5m])

# Error rate (5xx responses)
rate(http_server_requests_seconds_count{status=~"5.."}[5m])

# P95 request duration
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# JVM heap usage
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}

# GC pause time
rate(jvm_gc_pause_seconds_sum[5m])

# CPU usage
process_cpu_usage{application="voting-service"}

# Active database connections
hikaricp_connections_active
```

---

### Logging (Loki)

The service generates structured logs using SLF4J and Logback, collected by Promtail and sent to Loki.

#### Log Output

- **Format**: Plain text with timestamp
- **Framework**: SLF4J + Logback
- **Destination**: stdout/stderr
- **Collection**: Promtail sidecar or DaemonSet
- **Storage**: Grafana Loki

#### Log Types

##### 1. Application Startup Logs
```
2025-10-07 10:15:23.456  INFO 1 --- [main] c.e.voting.VotingApplication : Starting VotingApplication
2025-10-07 10:15:23.789  INFO 1 --- [main] o.s.b.w.embedded.tomcat.TomcatWebServer : Tomcat started on port(s): 8080
2025-10-07 10:15:23.890  INFO 1 --- [main] c.e.voting.VotingApplication : Started VotingApplication in 2.5 seconds
```

##### 2. HTTP Request Logs
```
2025-10-07 10:15:25.123  INFO 1 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/] : Initializing Spring DispatcherServlet
2025-10-07 10:15:25.456  INFO 1 --- [nio-8080-exec-2] c.e.voting.controller.VotingController : GET /api/origamis
```

##### 3. Database Logs
```
2025-10-07 10:15:24.567  INFO 1 --- [main] o.hibernate.jpa.internal.util.LogHelper : HHH000204: Processing PersistenceUnitInfo
2025-10-07 10:15:25.678  INFO 1 --- [main] org.hibernate.Version : HHH000412: Hibernate ORM core version
```

##### 4. Origami Synchronization Logs
```
2025-10-07 10:16:00.000  INFO 1 --- [scheduling-1] c.e.v.service.OrigamiSynchronizationService : Starting origami synchronization
2025-10-07 10:16:00.234  INFO 1 --- [scheduling-1] c.e.v.service.OrigamiSynchronizationService : Synchronized 24 origamis
```

##### 5. Error Logs
```
2025-10-07 10:16:30.456 ERROR 1 --- [nio-8080-exec-5] c.e.voting.controller.VotingController : Error processing vote
java.lang.NullPointerException: Origami not found
    at com.example.voting.service.OrigamiService.vote(OrigamiService.java:45)
```

#### Log Labels (Loki)

```yaml
labels:
  app: voting
  namespace: craftista
  pod: voting-xyz
  container: voting
  level: INFO/WARN/ERROR
  service: voting
```

#### Example LogQL Queries

```logql
# All voting service logs
{app="voting"}

# Error logs only
{app="voting"} |= "ERROR"

# Synchronization logs
{app="voting"} |= "synchronization"

# Request logs
{app="voting"} |~ "GET|POST|PUT|DELETE"

# Database-related logs
{app="voting"} |= "Hibernate"

# Exception stack traces
{app="voting"} |= "Exception"

# Logs from specific logger
{app="voting"} |= "VotingController"
```

---

### Health Checks

#### Health Endpoint
- **URL**: `http://localhost:8080/actuator/health`
- **Method**: GET
- **Response**:
  ```json
  {
    "status": "UP",
    "components": {
      "db": { "status": "UP" },
      "diskSpace": { "status": "UP" },
      "ping": { "status": "UP" }
    }
  }
  ```

#### Kubernetes Probes

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

---

## Actuator Endpoints

| Endpoint | Description |
|----------|-------------|
| `/actuator/health` | Health check with detailed status |
| `/actuator/prometheus` | Prometheus metrics |
| `/actuator/metrics` | List of available metrics |
| `/actuator/info` | Application information |

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome page |
| `/api/origamis` | GET | List all origamis |
| `/api/origamis/{id}` | GET | Get origami by ID |
| `/api/origamis/{id}/vote` | POST | Vote for an origami |
| `/actuator/health` | GET | Health check |
| `/actuator/prometheus` | GET | Prometheus metrics |

---

## Configuration

### Application Properties

```properties
# Catalogue Service Endpoint
catalogue.service-url=http://catalogue:5000/api/products

# H2 Database
spring.h2.console.enabled=true
spring.h2.console.path=/h2-console
spring.datasource.url=jdbc:h2:mem:testdb

# Actuator
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.metrics.export.prometheus.enabled=true
management.endpoint.health.show-details=always

# Application Info
info.app.name=Voting Service
info.app.version=1.0.0

# Metrics Tags
management.metrics.tags.application=voting-service
management.metrics.tags.environment=${ENVIRONMENT:dev}
```

---

## Service Dependencies

- **Catalogue Service** (`http://catalogue:5000`) - Syncs origami list every 1 minute

---

## Development

```bash
# Build
mvn package -DskipTests

# Run
java -jar target/voting-0.0.1-SNAPSHOT.jar

# Test endpoints
curl http://localhost:8080/actuator/prometheus
curl http://localhost:8080/actuator/health
```

---

## Resource Requirements

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

## Data Persistence

- Uses in-memory H2 database (data lost on pod restart)
- For production, consider persistent database

---

## Monitoring Integration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: voting-metrics
spec:
  selector:
    matchLabels:
      app: voting
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
```

### Grafana Dashboards

- **Spring Boot 2.1 Statistics**: Import ID `11378`
- **JVM Micrometer**: Import ID `4701`

---

## Additional Resources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Micrometer Documentation](https://micrometer.io/docs)
