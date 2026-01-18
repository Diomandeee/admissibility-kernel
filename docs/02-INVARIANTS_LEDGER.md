# Assumptions & Invariants Ledger

**Version**: 1.0.0
**Last Updated**: 2026-01-02

---

## Assumptions

Assumptions are things the project relies on that could be false. If violated, specific parts break.

### A-001: PostgreSQL is the only graph store
**Assumption**: All turns and edges live in PostgreSQL, accessible via `GraphStore` trait.
**What breaks if false**: Slice SQL queries won't work, connection pool assumptions fail.
**Detection**: Attempt to use a different store → compile-time error (no other `GraphStore` implementations in production).
**Mitigation**: Keep `GraphStore` trait abstract, avoid Postgres-specific SQL in core types.

### A-002: Content hashes will reach 100% coverage
**Assumption**: The incremental backfill will eventually give every turn a `content_hash`.
**What breaks if false**: `GraphSnapshotHash::from_content_hashes` can't be used universally, replay is less reliable.
**Detection**: Monitor `SELECT COUNT(*) FROM memory_turns WHERE content_hash IS NULL` → should trend to zero.
**Mitigation**: Keep stats-based fallback until coverage >= 99%.

### A-003: HMAC secret is 32+ bytes and never rotates
**Assumption**: The `KERNEL_HMAC_SECRET` is strong and stable across restarts.
**What breaks if false**: Token verification fails for old slices, replay breaks.
**Detection**: Token verification failures spike after secret rotation.
**Mitigation**: Document secret rotation requires re-slicing, or implement multi-key verification.

### A-004: Downstream services trust kernel tokens without re-verification
**Assumption**: RAG++ and Orbit check `admissibility_token` but don't re-verify HMAC locally.
**What breaks if false**: Performance degrades (double verification), but security improves.
**Detection**: Check if downstream code calls `/api/verify_token` or does HMAC locally.
**Mitigation**: Make token verification cheap enough (<5ms) that double-checking is acceptable.

### A-005: Slice policies are immutable once registered
**Assumption**: A `PolicyRef` (policy_id + params_hash) always resolves to the same policy.
**What breaks if false**: Replay fails because policy changed, provenance is misleading.
**Detection**: Policy registry fingerprint changes unexpectedly.
**Mitigation**: Enforce policy immutability in `PolicyRegistry`, version policies explicitly.

### A-006: Embedding models are versioned externally
**Assumption**: Embedding model IDs (e.g., "text-embedding-004") are stable and unambiguous.
**What breaks if false**: Replay uses a different model, results drift.
**Detection**: Provenance replay results differ despite matching hashes.
**Mitigation**: Store full model identifier + provider in provenance (new field).

---

## Invariants

Invariants must NEVER be violated. Violations trigger immediate alerts and investigation.

### INV-GK-001: Slice Boundary Integrity
**Invariant**: Any turn used in a slice-mode retrieval MUST satisfy `turn_id ∈ slice.turn_ids`.
**Why it exists**: Prevents evidence leakage from outside authorized context.
**What breaks**: Admissibility guarantees, provenance chain, security audit.
**Canary**: Log `SLICE_BOUNDARY_VIOLATION` + emit Prometheus counter `slice_boundary_violations_total`.

### INV-GK-002: Provenance Completeness
**Invariant**: Every `SliceExport` MUST include `(slice_id, policy_ref, schema_version, graph_snapshot_hash, admissibility_token)`.
**Why it exists**: Enables replay, audit, and determinism verification.
**What breaks**: Cannot trace where evidence came from, replay fails, compliance violation.
**Canary**: Schema validation in `SliceExport::new_with_secret` — fails at construction if fields are missing.

### INV-GK-003: No Phantom Authority
**Invariant**: Missing `admissibility_token` means non-admissible by definition.
**Why it exists**: Prevents accidental or malicious claims of kernel authorization.
**What breaks**: Security model (downstream could forge admissibility).
**Canary**: Promotion APIs require `AdmissibleEvidenceBundle` type, which cannot be constructed without verified token.

### INV-GK-004: Content Immutability
**Invariant**: If `content_hash` exists, it MUST match `SHA256(canonical_content(content_text))`.
**Why it exists**: Enables content-based replay and drift detection.
**What breaks**: Replay false positives (hash matches but content differs), integrity audits fail.
**Canary**: Periodic content hash re-check job compares stored hash with fresh computation.

### INV-GK-005: HMAC Token Unforgeability
**Invariant**: Only the Graph Kernel can issue valid `AdmissibilityToken` values.
**Why it exists**: Prevents downstream services from self-authorizing evidence.
**What breaks**: Security model collapses, admissibility becomes self-asserted.
**Canary**: Token verification failure rate > 0.1% triggers alert (indicates forgery or secret leak).

### INV-GK-006: Slice Determinism
**Invariant**: Given identical (anchor, policy, graph state) → identical `slice_id`.
**Why it exists**: Enables replay, caching, and reproducible experiments.
**What breaks**: Cannot deduplicate slices, replay verification fails, science is unreproducible.
**Canary**: Regression tests verify `slice_id` stability across runs.

### INV-GK-007: Policy Immutability
**Invariant**: A `PolicyRef` (policy_id, params_hash) MUST always resolve to the same policy parameters.
**Why it exists**: Enables replay and provenance trust.
**What breaks**: Replay uses wrong policy, provenance is misleading.
**Canary**: `PolicyRegistry` refuses to re-register a policy with the same ref but different params.

### INV-GK-008: Database Slice Containment
**Invariant**: SQL queries for slice retrieval MUST only access turns where `id IN (slice.turn_ids)`.
**Why it exists**: Enforcement by construction — buggy code can't leak out-of-slice turns.
**What breaks**: Slice boundary violations become possible via SQL injection or logic bugs.
**Canary**: Log any SQL query that doesn't use a pre-validated ID list or temp table.

---

## Canary Implementation Checklist

| Invariant | Canary Type | Implemented? | Notes |
|-----------|-------------|--------------|-------|
| INV-GK-001 | Log + metric | ❌ No | Need to add `slice_boundary_violations_total` counter |
| INV-GK-002 | Schema validation | ✅ Yes | `SliceExport::new_with_secret` requires all fields |
| INV-GK-003 | Type system | ❌ No | Need to add `AdmissibleEvidenceBundle` type |
| INV-GK-004 | Periodic check | ❌ No | Need background job to re-verify content hashes |
| INV-GK-005 | Metric | ❌ No | Need `token_verification_failures_total` counter |
| INV-GK-006 | Test | ✅ Yes | `test_slice_determinism` exists |
| INV-GK-007 | Runtime check | ⚠️ Partial | `PolicyRegistry` needs to enforce immutability |
| INV-GK-008 | SQL pattern | ❌ No | Need to enforce ID list pattern in retrieval queries |

---

## Incident Response Triggers

| Canary Violation | Severity | Response Time | Action |
|------------------|----------|---------------|--------|
| INV-GK-001 | **CRITICAL** | Immediate | Page on-call, investigate source, quarantine bad tokens |
| INV-GK-002 | **HIGH** | < 1 hour | Check recent deployments, roll back if schema regression |
| INV-GK-003 | **CRITICAL** | Immediate | Audit promotion pipeline, check for security breach |
| INV-GK-004 | **MEDIUM** | < 4 hours | Re-run backfill, identify corrupted turns |
| INV-GK-005 | **CRITICAL** | Immediate | Rotate HMAC secret, invalidate all slices, investigate leak |
| INV-GK-006 | **LOW** | < 1 day | Check for non-determinism in slicing algorithm |
| INV-GK-007 | **HIGH** | < 1 hour | Identify policy mutation, version policies explicitly |
| INV-GK-008 | **CRITICAL** | Immediate | Check for SQL injection, audit query construction |
