# Graph Kernel Service

The Graph Kernel Service exposes the context slicing engine as a REST API, enabling downstream services (like RAG++) to request admissible context slices.

---

## Quick Start

### Running Locally

```bash
# Set database connection
export DATABASE_URL="postgresql://user:pass@localhost:5432/orbit"

# Run with service feature
cargo run --bin graph_kernel_service --features service
```

### Docker

```bash
# Build
docker build -f Dockerfile.service -t graph-kernel-service .

# Run
docker run -p 8001:8001 \
  -e DATABASE_URL="postgresql://..." \
  graph-kernel-service
```

---

## API Reference

### Health Check

```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "schema_version": "1.0.0",
  "policy_count": 1,
  "registry_fingerprint": "abc123..."
}
```

---

### Construct Slice

```
POST /api/slice
```

Constructs an admissible context slice around an anchor turn.

**Request Body:**
```json
{
  "anchor_turn_id": "550e8400-e29b-41d4-a716-446655440000",
  "policy_ref": {
    "policy_id": "slice_policy_v1",
    "params_hash": "abc123..."
  }
}
```

- `anchor_turn_id` (required): UUID of the turn to slice around
- `policy_ref` (optional): Reference to a registered policy. If omitted, uses default.

**Response:**
```json
{
  "slice": {
    "slice_id": "deterministic_fingerprint_hash",
    "anchor_turn_id": "550e8400-e29b-41d4-a716-446655440000",
    "turn_ids": ["turn1-uuid", "turn2-uuid", "turn3-uuid"],
    "edge_count": 2,
    "policy_id": "slice_policy_v1",
    "policy_params_hash": "abc123...",
    "schema_version": "1.0.0"
  },
  "policy_ref": {
    "policy_id": "slice_policy_v1",
    "params_hash": "abc123..."
  }
}
```

**Errors:**
- `400 INVALID_TURN_ID`: Anchor is not a valid UUID
- `404 POLICY_NOT_FOUND`: Referenced policy doesn't exist
- `500 SLICE_FAILED`: Internal error during slice construction

---

### Batch Slice

```
POST /api/slice/batch
```

Constructs multiple slices in a single request.

**Request Body:**
```json
{
  "anchor_turn_ids": ["uuid-1", "uuid-2", "uuid-3"],
  "policy_ref": {
    "policy_id": "slice_policy_v1",
    "params_hash": "abc123..."
  }
}
```

**Response:**
```json
{
  "slices": [
    { "slice_id": "...", "anchor_turn_id": "uuid-1", ... },
    { "slice_id": "...", "anchor_turn_id": "uuid-2", ... }
  ],
  "policy_ref": { "policy_id": "...", "params_hash": "..." },
  "success_count": 2,
  "errors": [
    { "anchor_turn_id": "uuid-3", "error": "Turn not found" }
  ]
}
```

---

### List Policies

```
GET /api/policies
```

Returns all registered policies.

**Response:**
```json
{
  "policies": [
    { "policy_id": "slice_policy_v1", "params_hash": "abc123..." }
  ],
  "registry_fingerprint": "xyz789..."
}
```

---

### Register Policy

```
POST /api/policies
```

Registers a new slice policy.

**Request Body:**
```json
{
  "policy": {
    "version": "slice_policy_v1",
    "max_nodes": 256,
    "max_radius": 10,
    "phase_weights": {
      "synthesis": 1.0,
      "planning": 0.9,
      "consolidation": 0.6,
      "debugging": 0.5,
      "exploration": 0.3
    },
    "salience_weight": 0.3,
    "distance_decay": 0.9,
    "include_siblings": true,
    "max_siblings_per_node": 5
  }
}
```

**Response:**
```json
{
  "policy_ref": {
    "policy_id": "slice_policy_v1",
    "params_hash": "new_hash..."
  }
}
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8001` | HTTP server port |
| `HOST` | `0.0.0.0` | Bind address |
| `DATABASE_URL` | - | PostgreSQL connection string (required) |
| `RUST_LOG` | `info` | Log level (`debug`, `info`, `warn`, `error`) |

### Database Schema

The service reads from the `memory_turns` table:

```sql
-- Required columns
id                      UUID PRIMARY KEY
session_id              TEXT
role                    TEXT
trajectory_phase        TEXT
salience_score          FLOAT
trajectory_depth        INTEGER
trajectory_sibling_order INTEGER
trajectory_homogeneity  FLOAT
trajectory_temporal     FLOAT
trajectory_complexity   FLOAT
created_at              TIMESTAMP
parent_id               UUID  -- For edge construction
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    graph_kernel_service                       │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐    ┌────────────────┐    ┌──────────────┐   │
│  │   Routes    │───▶│  ServiceState  │───▶│ ContextSlicer│   │
│  │  (Axum)     │    │                │    │              │   │
│  └─────────────┘    │ • store        │    │ • slice()    │   │
│                     │ • registry     │    │ • fingerprint│   │
│                     └────────────────┘    └──────────────┘   │
│                            │                     │           │
│                            ▼                     ▼           │
│                     ┌─────────────────────────────────┐      │
│                     │      PostgresGraphStore         │      │
│                     │                                 │      │
│                     │ • get_turn()                    │      │
│                     │ • get_parents()                 │      │
│                     │ • get_children()                │      │
│                     │ • get_siblings()                │      │
│                     └─────────────────────────────────┘      │
│                                    │                         │
└────────────────────────────────────┼─────────────────────────┘
                                     ▼
                            ┌─────────────────┐
                            │   PostgreSQL    │
                            │  memory_turns   │
                            └─────────────────┘
```

---

## Determinism Guarantees

The Graph Kernel provides strong determinism guarantees:

1. **Same inputs → Same outputs**
   - Identical (anchor, policy, graph_state) → identical slice_id

2. **Canonical ordering**
   - Turns ordered by TurnId
   - Edges ordered by (parent_id, child_id)

3. **Fingerprint construction**
   - xxHash64 of canonicalized JSON
   - Includes policy_id, policy_params_hash, schema_version

4. **Verification**
   - Run 100x with same inputs → 1 unique slice_id

---

## Deployment

### Cloud Run

```bash
# Build
gcloud builds submit --tag gcr.io/PROJECT/graph-kernel-service

# Deploy
gcloud run deploy graph-kernel-service \
  --image gcr.io/PROJECT/graph-kernel-service \
  --port 8001 \
  --set-env-vars "DATABASE_URL=..." \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10
```

### Docker Compose

See `cc-rag-plus-plus/docker-compose.yml`:

```yaml
graph-kernel:
  build:
    context: ../cc-graph-kernel
    dockerfile: Dockerfile.service
  ports:
    - "8001:8001"
  environment:
    - DATABASE_URL=${DATABASE_URL}
  profiles:
    - with-kernel
```

---

## Testing

### Unit Tests

```bash
cargo test --features service
```

### Integration Tests

```bash
# Start service
DATABASE_URL=... cargo run --bin graph_kernel_service --features service &

# Test endpoints
curl http://localhost:8001/health

curl -X POST http://localhost:8001/api/slice \
  -H "Content-Type: application/json" \
  -d '{"anchor_turn_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

### Golden Tests

```rust
#[test]
fn test_slice_golden() {
    // Fixed graph state → fixed slice response
    // 100 runs → identical JSON output
}
```

