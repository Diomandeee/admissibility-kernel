# Admissibility Kernel: Cryptographically-Verified Context Slicing for Conversational Memory Systems

**Version**: 1.0.0
**Authors**: Mohamed Diomande
**Date**: January 2026

---

## Abstract

We present the Admissibility Kernel, a deterministic context slicing engine that transforms unbounded conversation graphs into bounded, cryptographically-verified evidence bundles suitable for retrieval-augmented generation (RAG) systems. Modern conversational AI systems face a fundamental challenge: context windows are finite, yet conversation histories grow unboundedly. Naive truncation loses important context; naive retrieval risks including irrelevant or manipulated evidence. The Admissibility Kernel addresses this through three key innovations: (1) a priority-queue BFS slicing algorithm with phase-weighted importance scoring that selects the most relevant context around any anchor point; (2) HMAC-SHA256 admissibility tokens that cryptographically bind slices to the issuing kernel, preventing forgery; and (3) a type-safe `AdmissibleEvidenceBundle` that makes it impossible at compile time to use unverified evidence in security-critical operations. Evaluation shows deterministic slice construction in <50ms p99 latency, cached verification in <5ms, and linear scaling under multi-threaded contention. The kernel is deployed in production serving trajectory-aware retrieval across 107,000+ conversation turns.

**Keywords**: context slicing, cryptographic verification, conversation DAG, priority-queue BFS, HMAC tokens, type-safe security

---

## 1. Introduction

### 1.1 Problem Statement

Conversational AI systems accumulate extensive interaction histories. A single user may generate thousands of conversation turns across multiple sessions, creating a directed acyclic graph (DAG) of interconnected messages. When generating a response, the system must select relevant context from this graph. This selection faces three challenges:

**Bounded Context Windows**: Language models have finite context windows (4K-128K tokens). Even with extended windows, including irrelevant context degrades generation quality through attention dilution.

**Trust and Provenance**: In systems where evidence influences decisions (e.g., memory promotion, pattern learning), we must guarantee that evidence came from authorized sources. An adversary who can inject arbitrary evidence can manipulate system behavior.

**Reproducibility**: For debugging, auditing, and scientific reproducibility, the same query should produce identical context slices across runs, machines, and time.

### 1.2 Motivation

Existing approaches fail to address these challenges holistically:

- **Truncation**: Takes the most recent N turns, ignoring conversation structure and importance.
- **Vector similarity**: Retrieves turns similar to a query embedding, but provides no cryptographic guarantees about provenance.
- **Summarization**: Compresses history but loses fine-grained evidence for specific claims.

We need a system that can:
1. Select contextually relevant turns from arbitrary positions in the conversation DAG
2. Cryptographically certify that the selection was performed by an authorized authority
3. Produce identical results given identical inputs, across all execution environments

### 1.3 Contributions

This paper makes the following contributions:

1. **Priority-Queue BFS Slicing Algorithm**: A novel graph traversal that expands from an anchor turn, prioritizing nodes by phase-weighted importance scores with distance decay. This produces focused, contextually relevant slices while respecting budget constraints.

2. **HMAC Token Authority Pattern**: A cryptographic framework where only the kernel holding a secret can issue valid admissibility tokens. Downstream systems verify tokens without needing the secret, creating a clear authority boundary.

3. **Type-Safe AdmissibleEvidenceBundle**: A Rust type that can only be constructed through verified kernel operations. This shifts security enforcement from runtime checks to compile-time guarantees—code that accepts unverified evidence simply cannot compile.

4. **Sufficiency Framework**: A diversity-based quality gate that prevents gaming through homogeneous low-quality evidence. Evidence must meet minimum thresholds for role diversity, phase coverage, and salience distribution.

5. **Determinism Guarantees**: Mathematical invariants and implementation techniques (canonical serialization, float quantization, BTreeMap ordering) that ensure byte-identical outputs across runs.

---

## 2. Related Work

### 2.1 Context Selection in RAG Systems

Retrieval-Augmented Generation (RAG) systems typically select context through dense retrieval—encoding queries and documents into embedding spaces and selecting by similarity (Karpukhin et al., 2020). While effective for document retrieval, this approach lacks structural awareness for conversation graphs and provides no cryptographic guarantees.

LangChain and LlamaIndex implement various chunking strategies (fixed-size, semantic, recursive) but treat conversations as linear sequences rather than DAGs. Our priority-queue BFS approach preserves the graph structure, following parent-child and sibling relationships during expansion.

### 2.2 Cryptographic Verification in ML Systems

Verifiable computation (Gennaro et al., 2010) allows proving that a computation was performed correctly. Our HMAC-based approach is simpler: we don't prove correctness of the slicing algorithm, but we do prove that a particular slice was issued by an authorized kernel. This is sufficient for trust boundaries in RAG systems.

Content-addressable storage (IPFS, Git) uses hashing for integrity but not authority. Our admissibility tokens add authority—anyone can compute a hash, but only the kernel can sign it.

### 2.3 Graph Algorithms for Context

Personalized PageRank (Page et al., 1999) and its variants have been applied to knowledge graphs for context relevance. Our phase-weighted priority scoring is inspired by this work but adapted for conversation-specific semantics—synthesis turns are rare but highly valuable, while exploration turns are common but often tangential.

The TextRank algorithm (Mihalcea & Tarau, 2004) uses graph centrality for summarization. Our approach differs in that we maintain full turn fidelity (no summarization) and use external phase/salience signals rather than pure graph topology.

---

## 3. System Architecture

### 3.1 Design Principles

The Admissibility Kernel is governed by four principles:

**Determinism First**: Every operation must be deterministic. The same inputs must produce byte-identical outputs across multiple runs, sessions, machines, and code versions. This enables caching, replay, and reproducible experiments.

**Budget Discipline**: Context slices must be bounded to prevent memory exhaustion, token limit overruns, and unfocused analysis. Hard caps (`max_nodes`, `max_radius`) are enforced by construction.

**Provenance by Design**: Every slice is traceable. The `slice_id` fingerprint encodes what turns are included, what policy generated them, and what schema version was used.

**Minimal Assumptions**: The kernel makes minimal assumptions about message content (opaque strings), session structure (any DAG topology), and phase/salience accuracy (passed through as-is).

### 3.2 Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Admissibility Kernel                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Context Slicer                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │   │
│  │  │ Priority │→│ Expand   │→│ Score    │→│ Collect  │  │   │
│  │  │ Queue    │  │ Frontier │  │ Nodes    │  │ Slice    │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               Canonical Serialization                    │   │
│  │  • Sorted keys (BTreeMap)  • Float quantization (1e6)   │   │
│  │  • Stable field order      • xxHash64 fingerprint        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Token Authority                          │   │
│  │  token = HMAC-SHA256(secret, canonical_json(slice))      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Output: AdmissibleEvidenceBundle { slice, token, verified }   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Data Flow

1. **Input**: Anchor turn ID, slice policy, graph store connection
2. **Expansion**: Priority-queue BFS traverses the conversation DAG
3. **Collection**: Selected turns and edges form the raw slice
4. **Serialization**: Canonical JSON representation computed
5. **Fingerprinting**: xxHash64 produces content-derived slice_id
6. **Signing**: HMAC-SHA256 produces admissibility_token
7. **Wrapping**: Type-safe `AdmissibleEvidenceBundle` returned

---

## 4. Core Algorithms

### 4.1 Priority-Queue BFS Slicing

The slicing algorithm uses a priority queue to expand the most important nodes first, rather than breadth-first or depth-first traversal.

**Algorithm**: Priority-Queue BFS Context Slicing

```
Input: anchor (TurnId), policy (SlicePolicyV1), store (GraphStore)
Output: SliceExport

1. Initialize:
   - visited ← ∅
   - pq ← PriorityQueue()
   - slice_turns ← []
   - slice_edges ← []

2. Seed anchor:
   - anchor_turn ← store.get_turn(anchor)
   - priority ← compute_priority(anchor_turn, distance=0, policy)
   - pq.push(Candidate(anchor_turn, distance=0, priority))

3. Expansion loop:
   while |slice_turns| < policy.max_nodes and !pq.is_empty():
     candidate ← pq.pop()

     if candidate.turn.id ∈ visited:
       continue

     visited.add(candidate.turn.id)
     slice_turns.append(candidate.turn)

     if candidate.distance >= policy.max_radius:
       continue  // Don't expand beyond radius

     // Expand to parents
     for parent_id in store.get_parents(candidate.turn.id):
       parent ← store.get_turn(parent_id)
       priority ← compute_priority(parent, candidate.distance + 1, policy)
       pq.push(Candidate(parent, candidate.distance + 1, priority))
       slice_edges.append(Edge(parent_id, candidate.turn.id))

     // Expand to children
     for child_id in store.get_children(candidate.turn.id):
       child ← store.get_turn(child_id)
       priority ← compute_priority(child, candidate.distance + 1, policy)
       pq.push(Candidate(child, candidate.distance + 1, priority))
       slice_edges.append(Edge(candidate.turn.id, child_id))

     // Optionally expand to siblings
     if policy.include_siblings:
       siblings ← store.get_siblings(candidate.turn.id, policy.max_siblings_per_node)
       for sibling in siblings:
         priority ← compute_priority(sibling, candidate.distance, policy)
         pq.push(Candidate(sibling, candidate.distance, priority))

4. Return SliceExport::new(anchor, slice_turns, slice_edges, policy)
```

**Complexity**: O(k log k) where k is the number of turns visited, dominated by priority queue operations.

### 4.2 Priority Scoring Function

The priority of each candidate turn determines its expansion order:

```
priority(turn, distance, policy) =
    (phase_weight(turn.phase) + turn.salience × policy.salience_weight)
    × policy.distance_decay^distance
```

**Phase Weights** (empirically calibrated):

| Phase | Weight | Rationale |
|-------|--------|-----------|
| Synthesis | 1.0 | Rare (0.1% of turns), concentrated insight |
| Planning | 0.9 | Strategic thinking, goal-setting |
| Consolidation | 0.6 | Summarization, integration of ideas |
| Debugging | 0.5 | Problem-solving, but often repetitive |
| Exploration | 0.3 | Brainstorming, often tangential |

**Distance Decay** (default 0.9):

```
distance=0: 1.0× priority (anchor itself)
distance=1: 0.9× priority (immediate neighbors)
distance=5: 0.59× priority
distance=10: 0.35× priority
```

This balances local context (immediate parents/children) with broader context (distant ancestors).

### 4.3 Canonical Serialization

Determinism requires identical byte representations across runs. We achieve this through:

**Sorted Keys**: All maps use `BTreeMap` (ordered) rather than `HashMap` (unordered). Fields serialize in declaration order.

**Float Quantization**: Floating-point values are quantized before hashing:
```rust
fn quantize_float(f: f32) -> i64 {
    (f * 1_000_000.0).round() as i64
}
```
This eliminates platform-specific floating-point representation differences.

**Stable JSON**: Canonical JSON serialization with no whitespace, sorted keys, and deterministic field ordering.

**Fingerprint Computation**:
```rust
let canonical_bytes = serde_json::to_vec(&slice)?;
let fingerprint = xxhash::xxh64(&canonical_bytes, 0);
let slice_id = format!("{:016x}", fingerprint);
```

### 4.4 HMAC Token Generation

Admissibility tokens use HMAC-SHA256 with a kernel-held secret:

```rust
fn generate_token(secret: &[u8], slice: &SliceExport) -> AdmissibilityToken {
    let canonical = canonical_json(slice);
    let mut mac = Hmac::<Sha256>::new_from_slice(secret)?;
    mac.update(canonical.as_bytes());
    let result = mac.finalize();
    AdmissibilityToken(hex::encode(result.into_bytes()))
}
```

**Security Properties**:
- **Unforgeability**: Without the secret, an adversary cannot produce valid tokens (HMAC security)
- **Non-transferability**: A token is bound to a specific slice (changing any field invalidates the token)
- **Verification without secret exposure**: Verification re-computes the HMAC; only the kernel holds the secret

---

## 5. Type-Safe Security Model

### 5.1 AdmissibleEvidenceBundle

The key security innovation is the `AdmissibleEvidenceBundle` type, which can only be constructed through verified operations:

```rust
pub struct AdmissibleEvidenceBundle {
    slice: SliceExport,
    // Private field - cannot be set directly
}

impl AdmissibleEvidenceBundle {
    /// ONLY way to construct - requires HMAC secret for verification
    pub fn from_verified(
        slice: SliceExport,
        secret: &[u8]
    ) -> Result<Self, VerificationError> {
        let expected_token = generate_token(secret, &slice);
        if slice.admissibility_token != expected_token {
            return Err(VerificationError::InvalidToken);
        }
        Ok(Self { slice })
    }

    // No public constructor that bypasses verification
}
```

**Compile-Time Enforcement**: Any function that accepts `AdmissibleEvidenceBundle` is guaranteed to receive verified evidence—there is no way to construct this type with forged tokens.

```rust
// This function signature GUARANTEES verified evidence
fn promote_turn(
    turn_id: TurnId,
    evidence: &AdmissibleEvidenceBundle  // Compile-time guarantee
) -> Result<(), PromotionError> {
    // evidence.is_turn_admissible() is always trustworthy
    if !evidence.is_turn_admissible(&turn_id) {
        return Err(PromotionError::TurnNotInSlice);
    }
    // Proceed with promotion...
}
```

### 5.2 Security Invariants

The kernel enforces eight security invariants:

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-GK-001 | **Slice Boundary Integrity**: Any turn used in slice-mode retrieval must satisfy `turn_id ∈ slice.turn_ids` | Type system (`AdmissibleEvidenceBundle::is_turn_admissible`) |
| INV-GK-002 | **Provenance Completeness**: Every `SliceExport` must include `(slice_id, policy_ref, schema_version, graph_snapshot_hash, admissibility_token)` | Schema validation in constructor |
| INV-GK-003 | **No Phantom Authority**: Missing `admissibility_token` means non-admissible by definition | `AdmissibleEvidenceBundle` type cannot be constructed without valid token |
| INV-GK-004 | **Content Immutability**: If `content_hash` exists, it must match `SHA256(canonical(content))` | Periodic verification job |
| INV-GK-005 | **HMAC Token Unforgeability**: Only the Graph Kernel can issue valid tokens | HMAC cryptographic guarantee |
| INV-GK-006 | **Slice Determinism**: Same `(anchor, policy, graph_state)` → same `slice_id` | Canonical serialization |
| INV-GK-007 | **Policy Immutability**: A `PolicyRef` always resolves to the same parameters | PolicyRegistry enforcement |
| INV-GK-008 | **Database Slice Containment**: SQL queries only access turns in the validated ID list | Query construction pattern |

### 5.3 Sufficiency Framework

Beyond admissibility (was the slice issued by the kernel?), the sufficiency framework prevents gaming through homogeneous low-quality evidence.

**Diversity Metrics**:

```rust
pub struct DiversityMetrics {
    pub turn_count: usize,           // How many turns
    pub unique_roles: usize,         // User, Assistant, System
    pub role_distribution: HashMap<Role, usize>,
    pub unique_phases: usize,        // Exploration, Planning, etc.
    pub phase_distribution: HashMap<Phase, usize>,
    pub unique_sessions: usize,      // Cross-session diversity
    pub salience_stats: SalienceStats,  // min, max, mean, std_dev
    pub has_exchange: bool,          // User + Assistant present
}
```

**Sufficiency Policy**:

```rust
pub struct SufficiencyPolicy {
    pub min_turns: usize,           // default: 3
    pub min_roles: usize,           // default: 2 (requires exchange)
    pub min_phases: usize,          // default: 1
    pub min_high_salience: usize,   // default: 1 (turns with salience >= 0.7)
    pub require_exchange: bool,     // default: true
    pub min_mean_salience: f32,     // default: 0.3
}
```

A slice of 10 identical low-quality turns fails sufficiency even if admissible. This creates a two-layer defense: cryptographic verification (was it authorized?) followed by quality verification (is it meaningful?).

---

## 6. Implementation Details

### 6.1 Language and Dependencies

The kernel is implemented in Rust for:
- **Memory safety**: No null pointer dereferences, buffer overflows, or use-after-free
- **Zero-cost abstractions**: Type-safe security without runtime overhead
- **Determinism**: Predictable memory layout and execution

Key dependencies:
- `serde` / `serde_json`: Canonical serialization
- `xxhash-rust`: Fast, deterministic hashing
- `hmac` / `sha2`: HMAC-SHA256 token generation
- `uuid`: Turn identity
- `chrono`: Temporal ordering

### 6.2 Storage Backends

The `GraphStore` trait abstracts storage:

```rust
pub trait GraphStore {
    type Error: std::error::Error;

    fn get_turn(&self, id: &TurnId) -> Result<Option<TurnSnapshot>, Self::Error>;
    fn get_parents(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;
    fn get_children(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;
    fn get_siblings(&self, id: &TurnId, limit: usize) -> Result<Vec<TurnId>, Self::Error>;
    fn get_edges(&self, turn_ids: &[TurnId]) -> Result<Vec<Edge>, Self::Error>;
}
```

**Implementations**:
- `InMemoryGraphStore`: BTreeMap-based, for testing and small graphs
- `PostgresGraphStore`: Production backend with SQL-enforced ordering

All store methods return collections in deterministic order (by TurnId or specified criteria).

### 6.3 Verification Caching

Token verification is cached to amortize HMAC computation cost:

```rust
pub struct TokenVerifier {
    mode: VerificationMode,
    cache: Option<Arc<Mutex<LruCache<String, bool>>>>,
}

pub enum VerificationMode {
    LocalSecret(Vec<u8>),
    CachedWithConfig { secret: Vec<u8>, config: CacheConfig },
    RemoteService(String),  // For distributed verification
}
```

Cache keys are slice fingerprints; cache values are verification results. The LRU cache bounds memory usage while maintaining hit rates >90% in typical workloads.

### 6.4 REST API Service

The kernel exposes a REST API for integration with Python/TypeScript services:

```
POST /api/v1/slice
  Request: { anchor_turn_id, policy_id?, policy_params? }
  Response: { slice_export, admissibility_token, metrics }

POST /api/v1/verify
  Request: { slice_export, token }
  Response: { is_valid, verification_time_ms, cache_hit }

GET /api/v1/health
  Response: { status, version, uptime }
```

---

## 7. Evaluation

### 7.1 Performance Benchmarks

Benchmarks run on Apple M1 Pro, 16GB RAM, using Criterion.rs:

**Cold Verification** (no cache, full HMAC computation):

| Turns in Slice | p50 Latency | p99 Latency |
|----------------|-------------|-------------|
| 1 | 0.8ms | 1.2ms |
| 10 | 2.1ms | 3.5ms |
| 50 | 8.3ms | 12.1ms |
| 100 | 15.7ms | 22.4ms |

Target: <50ms p99 ✓

**Cached Verification** (LRU cache hit):

| Turns in Slice | p50 Latency | p99 Latency |
|----------------|-------------|-------------|
| 1 | 0.05ms | 0.12ms |
| 10 | 0.06ms | 0.14ms |
| 50 | 0.08ms | 0.18ms |
| 100 | 0.11ms | 0.24ms |

Target: <5ms p99 ✓

**Cache Contention** (multi-threaded access):

| Threads | Throughput (verifications/sec) | Scaling Factor |
|---------|-------------------------------|----------------|
| 1 | 12,400 | 1.0× |
| 2 | 24,100 | 1.94× |
| 4 | 46,800 | 3.77× |
| 8 | 89,200 | 7.19× |

Near-linear scaling validates the lock-free read path with `parking_lot::RwLock`.

### 7.2 Determinism Verification

We verify determinism through golden tests:

```rust
#[test]
fn test_same_anchor_same_slice_id_100_runs() {
    let store = setup_test_graph();
    let policy = SlicePolicyV1::default();
    let anchor = TurnId::from_str("test-anchor-uuid");

    let first_slice = ContextSlicer::slice(&store, anchor, &policy);

    for _ in 0..100 {
        let slice = ContextSlicer::slice(&store, anchor, &policy);
        assert_eq!(first_slice.slice_id, slice.slice_id);
        assert_eq!(first_slice.admissibility_token, slice.admissibility_token);
    }
}
```

All 100 runs produce byte-identical slices. Cross-machine tests (Linux x86_64, macOS ARM64) confirm platform independence.

### 7.3 Security Analysis

**Threat Model**: An adversary who:
- Can observe valid slice/token pairs
- Can construct arbitrary slices
- Cannot access the HMAC secret

**Security Properties**:

1. **Token Forgery**: Requires breaking HMAC-SHA256 (computationally infeasible with 256-bit security)

2. **Token Replay**: Valid tokens only work with their exact slice—modifying any field (turn IDs, policy, etc.) invalidates the token

3. **Phantom Authority**: The `AdmissibleEvidenceBundle` type cannot be constructed without a valid token. Code that attempts to bypass verification fails to compile.

4. **Slice Boundary Bypass**: The `is_turn_admissible()` method checks against the verified turn ID set. Downstream code cannot access turns outside the slice through the bundle interface.

### 7.4 Production Deployment

The kernel is deployed serving:
- **107,000+ conversation turns** across 5 data sources
- **~45ms average slice construction time** (including database queries)
- **>95% cache hit rate** for verification
- **Zero security incidents** in 6 months of production operation

---

## 8. Discussion

### 8.1 Limitations

**Single-Authority Model**: The current design assumes a single kernel instance holds the HMAC secret. Distributed deployments require either secret synchronization or a verification service.

**Policy Evolution**: While `policy_id` versioning supports multiple policies, changing a policy's parameters creates a new `params_hash`, potentially invalidating cached slices.

**Graph Mutations**: If the underlying graph changes (turns edited, deleted), previously-valid slices may become stale. The `graph_snapshot_hash` field tracks this, but re-slicing is required for freshness.

**Content Opacity**: The kernel treats message content as opaque strings. It cannot make semantic judgments about relevance—this is delegated to phase/salience annotations provided externally.

### 8.2 Future Work

**Distributed Key Management**: Threshold signatures or HSM integration for multi-kernel deployments.

**Incremental Slicing**: Update slices efficiently as the graph grows, rather than full re-computation.

**Semantic Expansion**: Integrate embedding similarity to expand beyond graph topology to semantically related turns.

**Compressed Export**: Binary serialization format for large slices, reducing network transfer and storage.

**Policy Learning**: Automatically tune phase weights and distance decay based on downstream task performance.

---

## 9. Conclusion

The Admissibility Kernel provides a principled solution to the context selection problem in conversational AI systems. By combining priority-queue BFS traversal with cryptographic verification and type-safe enforcement, it enables:

1. **Focused context**: Phase-weighted importance scoring selects the most relevant turns
2. **Trust boundaries**: HMAC tokens create unforgeable authority claims
3. **Compile-time security**: Type-safe bundles prevent verification bypass
4. **Reproducibility**: Deterministic algorithms enable caching and auditing

The kernel demonstrates that security and performance are not at odds—cached verification achieves sub-millisecond latency while maintaining cryptographic guarantees. The type-safe design shifts security enforcement from runtime vigilance to compile-time verification, reducing the attack surface and cognitive load on downstream developers.

We believe this approach generalizes beyond conversational AI to any system requiring bounded, verifiable evidence selection from graph-structured data.

---

## References

1. Karpukhin, V., et al. (2020). Dense Passage Retrieval for Open-Domain Question Answering. EMNLP.

2. Gennaro, R., Gentry, C., & Parno, B. (2010). Non-Interactive Verifiable Computing. CRYPTO.

3. Page, L., et al. (1999). The PageRank Citation Ranking: Bringing Order to the Web. Stanford InfoLab.

4. Mihalcea, R., & Tarau, P. (2004). TextRank: Bringing Order into Texts. EMNLP.

5. Krawczyk, H., Bellare, M., & Canetti, R. (1997). HMAC: Keyed-Hashing for Message Authentication. RFC 2104.

---

## Appendix A: Configuration Reference

### SlicePolicyV1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_nodes` | usize | 256 | Maximum turns in slice |
| `max_radius` | usize | 10 | Maximum hops from anchor |
| `distance_decay` | f32 | 0.9 | Priority multiplier per hop |
| `salience_weight` | f32 | 0.3 | Weight of salience in priority |
| `include_siblings` | bool | true | Expand to sibling turns |
| `max_siblings_per_node` | usize | 5 | Limit siblings per parent |
| `phase_weights` | HashMap | (see below) | Weight per conversation phase |

### Default Phase Weights

```json
{
  "synthesis": 1.0,
  "planning": 0.9,
  "consolidation": 0.6,
  "debugging": 0.5,
  "exploration": 0.3
}
```

---

## Appendix B: SliceExport Schema

```json
{
  "schema_version": "1.0.0",
  "anchor_turn_id": "uuid-string",
  "turns": [
    {
      "id": "uuid-string",
      "session_id": "string",
      "role": "user|assistant|system",
      "phase": "exploration|planning|consolidation|debugging|synthesis",
      "salience": 0.0-1.0,
      "trajectory_depth": 0.0-1.0,
      "trajectory_sibling_order": 0.0-1.0,
      "trajectory_homogeneity": 0.0-1.0,
      "trajectory_temporal": 0.0-1.0,
      "trajectory_complexity": 1.0+,
      "created_at": 1234567890
    }
  ],
  "edges": [
    {
      "parent": "uuid-string",
      "child": "uuid-string",
      "edge_type": "reply|branch|reference"
    }
  ],
  "policy_id": "slice_policy_v1",
  "policy_params_hash": "hex-string",
  "graph_snapshot_hash": "string",
  "slice_id": "hex-string-16-chars",
  "admissibility_token": "hex-string-64-chars"
}
```

---

## Appendix C: API Examples

### Slice Construction

```bash
curl -X POST http://localhost:8080/api/v1/slice \
  -H "Content-Type: application/json" \
  -d '{
    "anchor_turn_id": "550e8400-e29b-41d4-a716-446655440000",
    "policy_id": "slice_policy_v1",
    "policy_params": {
      "max_nodes": 128,
      "max_radius": 5
    }
  }'
```

### Token Verification

```bash
curl -X POST http://localhost:8080/api/v1/verify \
  -H "Content-Type: application/json" \
  -d '{
    "slice_id": "a1b2c3d4e5f67890",
    "admissibility_token": "abc123..."
  }'
```

---

## Citation

```bibtex
@article{diomande2026admissibility,
  title={Admissibility Kernel: Cryptographically-Verified Context Slicing for Conversational Memory Systems},
  author={Diomande, Mohamed},
  journal={arXiv preprint},
  year={2026}
}
```
