# System Glossary

**Version**: 1.0.0
**Last Updated**: 2026-01-02

---

## Core Terms

### Admissibility
**What it is**: The property of a memory turn being authorized for use in retrieval/promotion pipelines.
**What it is not**: Similarity, relevance, or quality (those are separate concerns).
**Layer**: Architectural (authorization boundary).
**Stability**: Locked — this is a foundational security primitive.

### AdmissibilityToken
**What it is**: HMAC-SHA256 signature proving the Graph Kernel issued a slice.
**What it is not**: A JWT, session token, or user credential.
**Layer**: Interface (cryptographic proof).
**Stability**: Stable — algorithm is locked, format may extend with optional fields.

### AdmissibleEvidenceBundle
**What it is**: Type-level wrapper for evidence that has passed token verification.
**What it is not**: Raw retrieval results or unverified slices.
**Layer**: Architectural (type safety boundary).
**Stability**: New in this project — will become stable after v1.0.

### Anchor Turn
**What it is**: The target turn around which a context slice is expanded.
**What it is not**: The most important turn in the slice (priority determines that).
**Layer**: Conceptual (slicing algorithm).
**Stability**: Locked.

### Canonical Content
**What it is**: Normalized representation of turn content for hashing (UTF-8, newline-normalized, role-excluded).
**What it is not**: The raw database `content_text` field.
**Layer**: Runtime (content immutability).
**Stability**: New spec in this project — will lock after backfill completes.

### Content Hash
**What it is**: SHA-256 of canonical content bytes.
**What it is not**: A similarity hash (LSH, MinHash) or graph fingerprint.
**Layer**: Runtime (immutability proof).
**Stability**: Stable — algorithm locked to SHA-256.

### EvidenceBundle
**What it is**: Structured metadata about retrieval results (count, diversity, salience floor, source variety).
**What it is not**: The actual turn content or embeddings.
**Layer**: Architectural (sufficiency checking).
**Stability**: New in this project — will stabilize after RAG++ integration.

### Global Retrieval
**What it is**: Unrestricted vector search across all conversations (non-admissible by definition).
**What it is not**: A backdoor — it's explicitly labeled non-admissible.
**Layer**: Architectural (retrieval mode).
**Stability**: Stable — will always exist as a separate mode.

### GraphSnapshotHash
**What it is**: Content-derived fingerprint of the graph state at slicing time.
**What it is not**: A version number or timestamp.
**Layer**: Interface (replay immutability).
**Stability**: Stable with deprecation path (stats-based → content-based).

### Kernel
**What it is**: The Graph Kernel service — sole authority for admissibility.
**What it is not**: RAG++, Orbit, or any downstream consumer.
**Layer**: Architectural (trust boundary).
**Stability**: Locked.

### Promotion
**What it is**: Advancing a memory turn's lifecycle stage (e.g., ephemeral → working → lexicon).
**What it is not**: Retrieval or similarity ranking.
**Layer**: Conceptual (lifecycle operation).
**Stability**: Stable — defined in RAG++ architecture.

### Provenance
**What it is**: Complete audit trail of where/how evidence was retrieved (slice_id, policy, snapshot, model, params).
**What it is not**: A simple "source URL" or citation.
**Layer**: Interface (auditability).
**Stability**: Extending in this project — new fields for embedding/retrieval metadata.

### Replay
**What it is**: Re-executing retrieval with identical inputs and expecting identical results.
**What it is not**: Time-travel debugging or undo.
**Layer**: Conceptual (determinism verification).
**Stability**: Stable — core invariant.

### Slice
**What it is**: Deterministic selection of turns around an anchor, defined by a policy.
**What it is not**: A random sample or top-k similarity results.
**Layer**: Conceptual (context boundary).
**Stability**: Locked.

### SliceFingerprint (slice_id)
**What it is**: Deterministic hash of (anchor, policy, selected turns).
**What it is not**: A UUID or database ID.
**Layer**: Interface (selection identity).
**Stability**: Stable.

### Sufficiency
**What it is**: Policy-defined criteria for "enough evidence" to promote a turn.
**What it is not**: A quality threshold or confidence score.
**Layer**: Architectural (promotion gate).
**Stability**: Extending in this project — from count-based to bundle-based.

### Token Verification
**What it is**: HMAC check proving a token was issued by the kernel.
**What it is not**: OAuth, API key validation, or user authentication.
**Layer**: Runtime (security primitive).
**Stability**: Stable — algorithm locked, caching modes new in this project.

---

## Overloaded Terms (Forbidden)

These terms have multiple meanings and must be split:

### ❌ "Context"
- Use "slice" for graph selections
- Use "provenance" for audit trails
- Use "evidence" for retrieval results

### ❌ "Valid"
- Use "admissible" for kernel-authorized evidence
- Use "well-formed" for data structure validation
- Use "verified" for token/signature checks

### ❌ "Hash"
- Use "content_hash" for SHA-256 of turn content
- Use "slice_id" for selection fingerprint
- Use "graph_snapshot_hash" for immutability proof
- Use "policy_params_hash" for policy identity

---

## Acronyms

| Acronym | Expansion | Notes |
|---------|-----------|-------|
| HMAC | Hash-based Message Authentication Code | Used for admissibility tokens |
| p99 | 99th percentile | Latency measurement |
| DAG | Directed Acyclic Graph | Conversation structure |
| LSH | Locality-Sensitive Hashing | Not used (explicitly noted) |
| RLS | Row-Level Security | PostgreSQL feature (separate concern) |
