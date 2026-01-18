# Graph Kernel Design Document

**Version**: 1.0.0  
**Status**: Locked  
**Last Updated**: 2026-01-01

---

## 1. Purpose

The Graph Kernel is a **deterministic context construction engine** that transforms raw conversation DAG data into bounded, reproducible context slices suitable for semantic analysis.

### 1.1 What It Does

- Selects relevant turns around an anchor point
- Prioritizes by phase importance and salience
- Respects budget constraints (node count, radius)
- Produces content-derived fingerprints for provenance

### 1.2 What It Does NOT Do

- Parse or analyze message content
- Make semantic judgments
- Learn or adapt from data
- Store or persist slices

---

## 2. Design Principles

### 2.1 Determinism First

Every operation must be deterministic. The same inputs must produce byte-identical outputs across:
- Multiple runs in the same session
- Multiple sessions on the same machine
- Multiple machines with the same code version

**Implementation**:
- BTreeMap/BTreeSet instead of HashMap/HashSet
- Explicit Ord implementations on all types
- Canonical JSON serialization for hashing
- No floating-point comparison in ordering logic

### 2.2 Budget Discipline

Context slices must be bounded to prevent:
- Memory exhaustion
- Token limit overruns
- Unfocused semantic analysis

**Implementation**:
- Hard caps: `max_nodes`, `max_radius`
- Priority-queue expansion (best-first, not breadth-first)
- Early termination when budget exhausted

### 2.3 Provenance by Design

Every slice must be traceable. The `slice_id` fingerprint encodes:
- What turns are included
- What policy generated them
- What schema version was used

**Implementation**:
- Content-derived hashing (xxHash64)
- Policy params included in fingerprint
- Schema version included in fingerprint

### 2.4 Minimal Assumptions

The kernel makes minimal assumptions about:
- Message content (opaque strings)
- Session structure (any DAG topology)
- Phase/salience accuracy (passed through as-is)

**Implementation**:
- Types are containers, not interpreters
- Validation is structural, not semantic
- Defaults are explicit and documented

---

## 3. Type System Design

### 3.1 Identity Types

```
TurnId
├── Wraps: Uuid
├── Ordering: Lexicographic (via Uuid)
├── Hashing: xxHash64 of UUID bytes
└── Serialization: UUID string format
```

**Design Decision**: Use UUID directly rather than content-derived hashes because turns are mutable (content can change) while identity must be stable.

### 3.2 Snapshot Types

```
TurnSnapshot
├── id: TurnId (identity)
├── session_id: String (grouping)
├── role: Role (classification)
├── phase: Phase (priority signal)
├── salience: f32 (priority signal)
├── trajectory_*: f32 (5D coordinates)
└── created_at: i64 (temporal ordering)

Ordering: By TurnId only (not by content)
```

**Design Decision**: Snapshot contains minimal fields needed for slicing. Full turn content is not included to keep slices lightweight and to avoid content-based identity issues.

### 3.3 Edge Types

```
Edge
├── parent: TurnId
├── child: TurnId
├── edge_type: EdgeType
└── Ordering: (parent, child, edge_type)
```

**Design Decision**: Edges are directed and typed. Ordering by parent-first ensures deterministic serialization in parent-child traversal order.

---

## 4. Policy System Design

### 4.1 Policy Contract

A policy defines:
1. **Budget limits**: How many turns, how far from anchor
2. **Priority weights**: How to rank candidate turns
3. **Expansion rules**: Whether to include siblings

A policy does NOT define:
- Message filtering (content-based)
- Session boundaries
- Temporal windows

### 4.2 Phase Weights Rationale

```
Synthesis     → 1.0  (rare, high value: breakthrough insights)
Planning      → 0.9  (strategic thinking, goal-setting)
Consolidation → 0.6  (summarization, integration)
Debugging     → 0.5  (problem-solving, but often repetitive)
Exploration   → 0.3  (brainstorming, often tangential)
```

**Design Decision**: Weights are calibrated based on typical information density per phase. Synthesis turns are rare (0.1% of dataset) but contain concentrated insight.

### 4.3 Distance Decay Rationale

```
distance_decay = 0.9 (default)

At distance 0: 1.0x priority
At distance 1: 0.9x priority
At distance 5: 0.59x priority
At distance 10: 0.35x priority
```

**Design Decision**: 10% decay per hop balances local context (immediate parents/children) with broader context (distant ancestors). This can be tuned via policy.

### 4.4 Policy Versioning

Policy IDs are versioned strings: `"slice_policy_v1"`, `"slice_policy_v2"`, etc.

**Design Decision**: Breaking changes to priority calculation or expansion logic require a new policy version. This ensures slices with the same `policy_id` are comparable.

---

## 5. Expansion Algorithm Design

### 5.1 Algorithm Choice: Priority BFS

We chose priority-queue BFS over alternatives:

| Algorithm | Pros | Cons |
|-----------|------|------|
| **BFS** | Simple, fair | Ignores importance |
| **DFS** | Follows chains | Misses branches |
| **Priority BFS** | Best-first | More complex |
| **Random walk** | Diverse | Non-deterministic |

**Design Decision**: Priority BFS gives us best-first expansion while maintaining determinism (ties broken by TurnId).

### 5.2 Candidate Ordering

When multiple candidates have equal priority:

```rust
impl Ord for ExpansionCandidate {
    fn cmp(&self, other: &Self) -> Ordering {
        // 1. Higher priority first
        match self.priority.partial_cmp(&other.priority) {
            Some(Ordering::Equal) | None => {
                // 2. Lower distance first (closer to anchor)
                match self.distance.cmp(&other.distance).reverse() {
                    Ordering::Equal => {
                        // 3. By TurnId for determinism
                        self.turn.id.cmp(&other.turn.id)
                    }
                    ord => ord
                }
            }
            Some(ord) => ord
        }
    }
}
```

**Design Decision**: TurnId is the final tiebreaker, ensuring identical priority queues across runs.

### 5.3 Sibling Handling

Siblings (turns with the same parent) can provide valuable context but risk explosion.

**Design Decision**: 
- Siblings are optional (`include_siblings: bool`)
- Limited per parent (`max_siblings_per_node`)
- Ranked by salience (highest first)
- Added at same distance as current node

---

## 6. Fingerprinting Design

### 6.1 What's Included

```rust
let canonical = (
    anchor,           // Which turn we started from
    turn_ids,         // Which turns are in the slice (not full content!)
    edges,            // How turns connect
    policy_id,        // Which policy version
    policy_params_hash, // Policy configuration
    schema_version,   // Type schema version
);
```

### 6.2 What's Excluded

- Turn content (would make slices content-sensitive)
- Timestamps (would make slices time-sensitive)
- Random values (would destroy determinism)

### 6.3 Hash Algorithm Choice

We use xxHash64 because:
- Fast (important for large slices)
- Deterministic (critical for reproducibility)
- Low collision rate (sufficient for fingerprinting)
- Available in pure Rust (no external dependencies)

**Design Decision**: We do NOT use cryptographic hashes because we're fingerprinting, not securing.

---

## 7. Storage Design

### 7.1 Store Trait

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

### 7.2 Ordering Requirements

All store methods returning collections MUST return them in deterministic order:
- `get_parents`: Ordered by TurnId
- `get_children`: Ordered by TurnId
- `get_siblings`: Ordered by salience DESC, then TurnId
- `get_edges`: Ordered by (parent, child)

### 7.3 In-Memory Implementation

Uses BTreeMap/BTreeSet for deterministic iteration:

```rust
pub struct InMemoryGraphStore {
    turns: BTreeMap<TurnId, TurnSnapshot>,
    children: BTreeMap<TurnId, BTreeSet<TurnId>>,
    parents: BTreeMap<TurnId, BTreeSet<TurnId>>,
    edges: Vec<Edge>,
}
```

### 7.4 PostgreSQL Implementation

Queries enforce ordering via SQL:

```sql
SELECT parent_turn_id 
FROM memory_turn_edges 
WHERE child_turn_id = $1 
ORDER BY parent_turn_id
```

---

## 8. Error Handling Design

### 8.1 Error Types

```rust
pub enum SlicerError {
    AnchorNotFound(TurnId),  // Anchor doesn't exist
    StoreError(String),      // Storage layer failed
}
```

### 8.2 Error Philosophy

- **Fail fast**: Missing anchor is an error, not an empty slice
- **Propagate context**: Error messages include IDs
- **Don't panic**: All errors are recoverable

---

## 9. Testing Strategy

### 9.1 Test Categories

| Category | Purpose | Count |
|----------|---------|-------|
| Unit | Individual component behavior | 24 |
| Golden | Determinism verification | 13 |
| Integration | Full pipeline (future) | 0 |

### 9.2 Golden Test Philosophy

Golden tests verify *contracts*, not implementations:

```rust
// GOOD: Tests the contract
fn test_same_anchor_same_slice_id_100_runs();

// BAD: Tests implementation details
fn test_priority_queue_has_5_elements();
```

### 9.3 Determinism Tests

Every test that produces output runs 100 times and asserts identical results.

---

## 10. Future Evolution

### 10.1 Planned Extensions

1. **SlicePolicyV2**: Add temporal windows, session boundaries
2. **Batch slicing**: Slice multiple anchors in one query
3. **Incremental slicing**: Update slices as graph changes
4. **Compressed export**: Binary format for large slices

### 10.2 Compatibility Rules

- New policy versions don't break old fingerprints
- Schema version changes require migration path
- Store implementations can be swapped transparently

---

## 11. Invariants

These invariants MUST hold at all times:

### 11.1 Determinism Invariant

```
∀ anchor, policy, graph:
    slice(anchor, policy, graph).slice_id == slice(anchor, policy, graph).slice_id
```

### 11.2 Anchor Invariant

```
∀ slice:
    slice.contains_turn(slice.anchor_turn_id) == true
```

### 11.3 Budget Invariant

```
∀ slice, policy:
    slice.num_turns() <= policy.max_nodes
```

### 11.4 Ordering Invariant

```
∀ slice:
    slice.turns == sort_by_turn_id(slice.turns)
    slice.edges == sort_by_parent_child(slice.edges)
```

---

## 12. Glossary

| Term | Definition |
|------|------------|
| **Anchor** | The target turn around which a slice is built |
| **Slice** | A bounded subset of the DAG with provenance |
| **Fingerprint** | Content-derived hash identifying a slice |
| **Policy** | Configuration controlling slice expansion |
| **Phase** | Trajectory classification of a turn |
| **Salience** | Importance score of a turn [0, 1] |
| **Distance** | Number of hops from anchor |
| **Priority** | Computed score determining selection order |

---

## 13. References

- [CognitiveTwin Bridge Spec](../../cc-cognitivetwin-bridge/README.md)
- [Semantic Kernel Architecture](../../cc-semantic-language/README.md)
- [Orbit Database Schema](../../../orbit/schema.sql)

