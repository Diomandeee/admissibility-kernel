# Graph Kernel Deployment Guide

## Overview

The Graph Kernel is the **admissibility authority** for the semantic system. It defines what evidence is allowed to exist for any operation that mutates the semantic ledger.

**Critical Understanding**: While HTTP arrows point from RAG++ to the kernel, **authority flows the other way**. The kernel is the judge that issues admissibility warrants; RAG++ is the attorney that can only present evidence the judge has allowed.

## Authority Model

RAG++ operates in two regimes:

| Regime | Authority Source | Can Mutate Ledger? |
|--------|------------------|-------------------|
| **Admissible** (slice mode) | Graph Kernel | Yes - promotions, lexicon mutations, phase advancement |
| **Non-Admissible** (global mode) | None | No - read-only notes browsing |

Without a kernel-issued slice and attestation token, retrieval results are **non-admissible by definition** and cannot:
- Promote atoms or proposals
- Mutate the lexicon
- Advance lifecycle phases
- Affect the semantic ledger in any way

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         AUTHORITY LAYER         │
                    │  ┌───────────────────────────┐  │
                    │  │      Graph Kernel         │  │
                    │  │      (THE JUDGE)          │  │
                    │  │                           │  │
                    │  │  • Issues SliceExport     │  │
                    │  │  • Signs HMAC tokens      │  │
                    │  │  • Defines admissible set │  │
                    │  └─────────────┬─────────────┘  │
                    └────────────────┼────────────────┘
                                     │ defines what
                                     │ evidence is allowed
                                     ▼
                    ┌─────────────────────────────────┐
                    │        EXECUTION LAYER          │
                    │  ┌───────────────────────────┐  │
                    │  │         RAG++             │  │
                    │  │     (THE ATTORNEY)        │  │
                    │  │                           │  │
                    │  │  • Searches within slice  │  │
                    │  │  • Ranks candidates       │  │
                    │  │  • Returns with provenance│  │
                    │  └─────────────┬─────────────┘  │
                    └────────────────┼────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
              ┌─────▼─────┐                   ┌───────▼──────┐
              │search/slice│                   │search/global │
              │  DEFAULT   │                   │ ESCAPE HATCH │
              │is_admissible│                   │is_admissible │
              │   = true   │                   │   = false    │
              └─────┬──────┘                   └───────┬──────┘
                    │                                  │
                    ▼                                  ▼
           ┌────────────────┐                ┌────────────────┐
           │Semantic Ledger │                │  Notes Only    │
           │ (can mutate)   │                │  (read-only)   │
           └────────────────┘                └────────────────┘
```

## Prerequisites

1. **HMAC Secret**: Generate before deployment
2. **Database**: PostgreSQL with `content_hash` column on `memory_turns`
3. **Supabase URL**: Same database as RAG++

## Quick Start

### 1. Generate HMAC Secret

```bash
# Generate 32-byte (64 hex char) secret
openssl rand -hex 32
# Example output: 7a2f8c4e1b3d5a9e0c2f4a8b6d1e3f5a7c9b0d2e4f6a8c0e2d4b6a8c0e2f4a6
```

### 2. Run Migration

Ensure the `content_hash` column exists:

```bash
# Apply migration to Supabase
psql $DATABASE_URL -f ../cc-rag-plus-plus/migrations/011_add_content_hash.sql
```

### 3. Local Development

```bash
# Add to .env
echo "KERNEL_HMAC_SECRET=$(openssl rand -hex 32)" >> .env
echo "DATABASE_URL=postgresql://..." >> .env

# Build and run
cargo build --release --features service --bin graph_kernel_service
./target/release/graph_kernel_service
```

### 4. Docker Deployment

```bash
cd /path/to/Comp-Core/core/cc-rag-plus-plus

# Set environment
export KERNEL_HMAC_SECRET=$(openssl rand -hex 32)
export DATABASE_URL=postgresql://...

# Deploy with Graph Kernel
docker compose --profile with-kernel up -d
```

### 5. Cloud Run Deployment

```bash
# 1. Create HMAC secret (if not already created)
export KERNEL_HMAC_SECRET=$(openssl rand -hex 32)
echo -n "$KERNEL_HMAC_SECRET" | gcloud secrets create kernel-hmac-secret --data-file=-

# 2. Create database URL secret (get from Supabase dashboard > Settings > Database)
# Format: postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres
echo -n "postgresql://postgres:YOUR_PASSWORD@db.aaqbofotpchgpyuohmmz.supabase.co:5432/postgres" | \
  gcloud secrets create database-url --data-file=-

# 3. Deploy
cd core/cc-graph-kernel
gcloud builds submit --config=cloudbuild-service.yaml
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KERNEL_HMAC_SECRET` | **Yes** | (dev fallback) | 32+ byte hex secret for HMAC token signing |
| `DATABASE_URL` | **Yes** | - | PostgreSQL connection string (Supabase) |
| `PORT` | No | 8001 | Service port |
| `HOST` | No | 0.0.0.0 | Bind address |
| `RUST_LOG` | No | info | Log level (debug, info, warn, error) |

## Verification

### Health Check

```bash
curl http://localhost:8001/health
# {"status":"healthy","version":"0.1.0","schema_version":"1.0.0",...}
```

### Token Verification Endpoint

```bash
curl -X POST http://localhost:8001/api/verify_token \
  -H "Content-Type: application/json" \
  -d '{
    "admissibility_token": "...",
    "slice_id": "...",
    "anchor_turn_id": "...",
    "policy_id": "slice_policy_v1",
    "policy_params_hash": "...",
    "graph_snapshot_hash": "...",
    "schema_version": "1.0.0"
  }'
# {"valid": true, "reason": null}
```

### Slice Request

```bash
curl -X POST http://localhost:8001/api/slice \
  -H "Content-Type: application/json" \
  -d '{
    "anchor_turn_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

## Integration with RAG++

RAG++ automatically uses the Graph Kernel when `GRAPH_KERNEL_URL` is set:

```bash
# In RAG++ environment
GRAPH_KERNEL_URL=http://graph-kernel:8001  # Docker network
# or
GRAPH_KERNEL_URL=http://localhost:8001     # Local dev
# or
GRAPH_KERNEL_URL=https://graph-kernel-xxx.run.app  # Cloud Run
```

## Security Considerations

1. **HMAC Secret**: Never commit to git. Use Secret Manager or environment injection.

2. **Token Verification**: Two options:
   - **Shared Secret**: RAG++ has the same `KERNEL_HMAC_SECRET` and verifies locally
   - **Kernel Verification**: RAG++ calls `/api/verify_token` (kernel as verifier)

3. **Network Security**: In production, consider:
   - Internal-only networking (Cloud Run internal)
   - mTLS between services
   - VPC Service Controls

## Troubleshooting

### Token Verification Fails

```
{"valid": false, "reason": "Token does not match expected HMAC"}
```

**Causes**:
- Secret mismatch between services
- Slice parameters changed after token issuance
- Token format incorrect (should be 32 hex chars)

**Fix**: Ensure `KERNEL_HMAC_SECRET` is identical on all services.

### Database Connection Issues

```
error: failed to connect to database
```

**Fix**: Verify `DATABASE_URL` format and network access.

### No Content Hashes

```
warning: Using stats-based snapshot hash (no content_hash in turns)
```

**Fix**: Run migration `011_add_content_hash.sql` to add content_hash column.

## Monitoring

Key metrics to monitor:

- `/health` endpoint status
- Slice generation latency (p50, p95)
- Token verification rate
- `SLICE_BOUNDARY_VIOLATION` logs (should be zero)

## Rollback

If issues occur:

1. **RAG++ Fallback**: Set `GRAPH_KERNEL_URL=""` to disable slice-conditioned retrieval
2. **Docker Compose**: `docker compose --profile with-kernel down`
3. **Cloud Run**: `gcloud run services delete graph-kernel`

**Important**: When the Graph Kernel is unavailable, RAG++ can still return search results via global retrieval. However, these results are **non-admissible** and explicitly barred from:
- Triggering promotions or lifecycle advancement
- Mutating the lexicon or semantic ledger
- Being used as evidence for any meaning-making operation

This is not "graceful degradation" - it is a mode downgrade from "science mode" to "notes browsing."

