# Graph Kernel Security Hardening — Project Charter

**Version**: 1.0.0
**Created**: 2026-01-02
**Status**: Locked
**Authority**: Master Implementation Constitution (CLAUDE.md)

---

## Purpose

Make the Graph Kernel's security guarantees **impossible to bypass**, **cheap to verify**, and **easy to reason about when things go wrong**.

This project exists to eliminate three classes of failure:
1. **Bypass**: Code paths that skip verification because it's too expensive
2. **Confusion**: Unclear boundaries between admissible and non-admissible evidence
3. **Opacity**: Incidents that require manual log archeology to diagnose

**Falsifiability**: The project succeeds when:
- Every promotion pipeline physically cannot accept non-admissible evidence (type system enforces it)
- Token verification has < 5ms p99 latency with caching enabled
- Slice boundary violations trigger alerts within 60 seconds with full provenance context

---

## Non-Goals

This project will **NOT**:
- Change the core slicing algorithm or policy framework
- Redesign the HMAC token scheme (current HMAC-SHA256 is sufficient)
- Add new slice expansion modes or phase weights
- Build a UI or dashboard (observability is metrics + alerts only)
- Optimize slice generation performance (current ~45ms is acceptable)
- Change the external API contract (only add optional fields for provenance)

---

## Success Criteria

The project is complete when all of:

1. **Type Safety**: Promotion APIs reject non-`AdmissibleEvidenceBundle` types at compile time
2. **Verification Performance**: Token verification p99 < 5ms with Redis cache enabled
3. **Content Canonicalization**: 100% of new turns have `content_hash` computed via canonical spec
4. **Sufficiency Formalization**: `EvidenceBundle` type exists with diversity metrics, not just count
5. **Database Enforcement**: Slice retrieval SQL physically cannot return out-of-slice turns
6. **Replay Completeness**: Provenance includes embedding model ID, normalization version, retrieval params
7. **Incident Response**: Prometheus metrics + alerts for violations, quarantine table for bad tokens

**Measurement**:
- Run test suite with `--features security-audit` (new feature flag)
- Deploy to staging and verify metrics exist in Prometheus
- Trigger deliberate slice boundary violation and verify alert fires

---

## Direction Constraints

All future work must remain compatible with:

1. **Existing SliceExport format**: New fields are optional, old clients still work
2. **Current HMAC token algorithm**: No breaking changes to token computation
3. **PostgreSQL-only assumption**: No NoSQL/Redis requirements for core slicing
4. **Cloud Run deployment model**: Stateless service with connection pooling
5. **Rust-only kernel, Python RAG++**: Language boundary stays at HTTP API

---

## Commitment Level

**Locked**

This charter is considered final. Changes require:
- Explicit user override ("rebuild the charter")
- Documentation of why the original charter was insufficient
- Re-validation of all assumptions in the Invariants Ledger
