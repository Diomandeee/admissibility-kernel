# Graph Kernel Monitoring Guide

## Overview

The Graph Kernel service exposes metrics, structured logs, and health endpoints for production observability. This guide covers monitoring setup, key metrics, alerting, and troubleshooting.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Observability Stack                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │
│  │ Cloud       │   │ Cloud       │   │ Cloud Run           │   │
│  │ Logging     │   │ Monitoring  │   │ Metrics             │   │
│  │ (JSON logs) │   │ (Alerts)    │   │ (Built-in)          │   │
│  └──────┬──────┘   └──────┬──────┘   └──────────┬──────────┘   │
│         │                  │                     │              │
│         └──────────────────┼─────────────────────┘              │
│                            │                                     │
│  ┌─────────────────────────┴─────────────────────────────────┐  │
│  │                  Graph Kernel Service                      │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │  │
│  │  │ /health/*   │  │ JSON Logging │  │ Custom Metrics  │   │  │
│  │  │ endpoints   │  │ (tracing)    │  │ (metrics crate) │   │  │
│  │  └─────────────┘  └──────────────┘  └─────────────────┘   │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Health Endpoints

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /health` | Detailed status | Full service state including DB |
| `GET /health/live` | Liveness probe | 200 if process is running |
| `GET /health/ready` | Readiness probe | 200 if accepting traffic, 503 otherwise |
| `GET /health/startup` | Startup probe | 200 when fully initialized |

### Health Response Example

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "schema_version": "1.0.0",
  "policy_count": 1,
  "registry_fingerprint": "a1b2c3d4e5f6",
  "database": {
    "connected": true,
    "pool_size": 5,
    "pool_idle": 3,
    "pool_max": 10
  }
}
```

## Metrics

### Request Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `graph_kernel_requests_total` | Counter | path, method, status | Total HTTP requests |
| `graph_kernel_request_duration_seconds` | Histogram | path, method | Request latency |

### Slice Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `graph_kernel_slices_generated_total` | Counter | Total slices generated |
| `graph_kernel_slice_turns_count` | Histogram | Turns per slice |
| `graph_kernel_slice_edges_count` | Histogram | Edges per slice |
| `graph_kernel_slice_latency_ms` | Histogram | Slice generation time |

### Token Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `graph_kernel_token_verifications_total` | Counter | result | Token verification attempts |

### Database Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `graph_kernel_db_queries_total` | Counter | query_type, status | Database query count |
| `graph_kernel_db_query_duration_ms` | Histogram | query_type, status | Query latency |

## Structured Logging

Logs are emitted in JSON format for Cloud Logging integration:

```json
{
  "timestamp": "2026-01-02T10:00:00.000Z",
  "level": "INFO",
  "target": "graph_kernel_service::access",
  "trace_id": "abc123def456",
  "method": "POST",
  "path": "/api/slice",
  "status": 200,
  "latency_ms": 45,
  "message": "request completed"
}
```

### Log Fields

| Field | Description |
|-------|-------------|
| `trace_id` | Cloud Trace context or generated UUID |
| `method` | HTTP method |
| `path` | Request path |
| `status` | Response status code |
| `latency_ms` | Request duration in milliseconds |

### Log Levels

- `ERROR`: Service errors, database failures
- `WARN`: Degraded operation, missing HMAC secret
- `INFO`: Request completion, startup/shutdown
- `DEBUG`: Detailed execution traces (not enabled by default)

## Alerting

### Recommended Alert Policies

#### 1. Service Unavailable

```yaml
alert: GraphKernelDown
condition: probe_success{job="graph-kernel"} == 0
for: 2m
severity: critical
annotations:
  summary: Graph Kernel service is down
  action: Check Cloud Run logs, verify database connectivity
```

#### 2. High Error Rate

```yaml
alert: GraphKernelHighErrorRate
condition: |
  sum(rate(graph_kernel_requests_total{status=~"5.."}[5m])) /
  sum(rate(graph_kernel_requests_total[5m])) > 0.05
for: 5m
severity: warning
annotations:
  summary: Graph Kernel error rate above 5%
  action: Check logs for error patterns
```

#### 3. Slow Slice Generation

```yaml
alert: GraphKernelSlowSlices
condition: |
  histogram_quantile(0.95, rate(graph_kernel_slice_latency_ms[5m])) > 5000
for: 10m
severity: warning
annotations:
  summary: Graph Kernel p95 slice latency above 5s
  action: Check database performance, consider scaling
```

#### 4. Database Connection Issues

```yaml
alert: GraphKernelDatabaseUnhealthy
condition: |
  graph_kernel_health_database_connected == 0
for: 1m
severity: critical
annotations:
  summary: Graph Kernel lost database connectivity
  action: Check Supabase status, verify DATABASE_URL
```

#### 5. Token Verification Failures

```yaml
alert: GraphKernelTokenFailures
condition: |
  sum(rate(graph_kernel_token_verifications_total{result="invalid"}[5m])) /
  sum(rate(graph_kernel_token_verifications_total[5m])) > 0.10
for: 5m
severity: warning
annotations:
  summary: High rate of invalid token verifications
  action: Check HMAC secret consistency across services
```

## Cloud Run Monitoring

### Built-in Metrics

Cloud Run automatically provides:

- Request count and latency
- Container instance count
- Memory and CPU utilization
- Cold start frequency

Access via: Cloud Console → Cloud Run → graph-kernel → Metrics

### Log Explorer Queries

#### Recent Errors

```
resource.type="cloud_run_revision"
resource.labels.service_name="graph-kernel"
severity>=ERROR
```

#### Slow Requests (>1s)

```
resource.type="cloud_run_revision"
resource.labels.service_name="graph-kernel"
jsonPayload.latency_ms > 1000
```

#### Slice Boundary Violations (Critical)

```
resource.type="cloud_run_revision"
resource.labels.service_name="graph-kernel"
jsonPayload.message:"SLICE_BOUNDARY_VIOLATION"
```

## Troubleshooting

### Common Issues

#### Service Returns 503

**Symptoms**: `/health/ready` returns 503, requests fail

**Causes**:
1. Database connection failed
2. Connection pool exhausted
3. Supabase rate limiting

**Resolution**:
1. Check `DATABASE_URL` secret is correct
2. Verify Supabase is accessible
3. Check connection pool stats in `/health`
4. Increase `DB_MAX_CONNECTIONS` if needed

#### High Latency

**Symptoms**: Slice generation >5s

**Causes**:
1. Large slice sizes (many turns)
2. Database query performance
3. Cold start overhead

**Resolution**:
1. Check `graph_kernel_slice_turns_count` histogram
2. Review slow query logs
3. Consider `min-instances=1` for warm starts
4. Tune policy `max_nodes` parameter

#### Token Verification Failures

**Symptoms**: `graph_kernel_token_verifications_total{result="invalid"}` increasing

**Causes**:
1. `KERNEL_HMAC_SECRET` mismatch between services
2. Token format corruption
3. Clock skew (if using time-based tokens)

**Resolution**:
1. Verify secret is identical in Graph Kernel and RAG++
2. Check token format (should be 32 hex chars)
3. Rotate secret and redeploy all services

#### Memory Issues

**Symptoms**: Container restarts, OOM errors

**Causes**:
1. Large batch slice requests
2. Connection leak
3. Unbounded caching

**Resolution**:
1. Increase `--memory` in Cloud Run
2. Check for connection leaks in logs
3. Monitor pool stats over time

## Runbook

### 1. Service Not Starting

```bash
# Check recent logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=graph-kernel" --limit 50

# Check revision status
gcloud run revisions list --service graph-kernel --region us-central1

# Check secrets
gcloud secrets versions access latest --secret kernel-hmac-secret
```

### 2. Force Deployment

```bash
# Trigger new deployment
cd core/cc-graph-kernel
gcloud builds submit --config=cloudbuild-service.yaml
```

### 3. Rollback

```bash
# List revisions
gcloud run revisions list --service graph-kernel --region us-central1

# Route traffic to previous revision
gcloud run services update-traffic graph-kernel \
  --region us-central1 \
  --to-revisions PREVIOUS_REVISION=100
```

### 4. Scale Manually

```bash
# Set minimum instances (avoid cold starts)
gcloud run services update graph-kernel \
  --region us-central1 \
  --min-instances 1

# Set back to 0 for cost savings
gcloud run services update graph-kernel \
  --region us-central1 \
  --min-instances 0
```

## Key Performance Indicators

| KPI | Target | Critical |
|-----|--------|----------|
| Availability | >99.9% | <99% |
| p50 Latency | <100ms | >500ms |
| p95 Latency | <500ms | >2s |
| Error Rate | <0.1% | >1% |
| Token Verification Success | >99% | <95% |

## References

- [Cloud Run Monitoring](https://cloud.google.com/run/docs/monitoring)
- [Cloud Logging Queries](https://cloud.google.com/logging/docs/view/logging-query-language)
- [Production Invariants](../../../cc-rag-plus-plus/docs/PRODUCTION_INVARIANTS.md)
- [Deployment Guide](./DEPLOYMENT.md)

