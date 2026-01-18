# cc-graph-kernel

**Deterministic Context Slicing for Conversation DAGs**

The Graph Kernel transforms a 107K+ turn conversation DAG into deterministic, replayable context slices. It answers one question:

> Given a target turn, which other turns are **allowed to influence meaning**?

---

## Table of Contents

1. [Overview](#overview)
2. [Core Contract](#core-contract)
3. [Architecture](#architecture)
4. [Installation](#installation)
5. [Quick Start](#quick-start)
6. [Types Reference](#types-reference)
7. [SlicePolicy v1](#slicepolicy-v1)
8. [Priority Scoring](#priority-scoring)
9. [Context Slicer Algorithm](#context-slicer-algorithm)
10. [Graph Stores](#graph-stores)
11. [SliceExport & Fingerprinting](#sliceexport--fingerprinting)
12. [Determinism Guarantees](#determinism-guarantees)
13. [Integration with CognitiveTwin Bridge](#integration-with-cognitivetwin-bridge)
14. [Testing](#testing)
15. [API Reference](#api-reference)

---

## Overview

The Graph Kernel is the "context construction engine" for the semantic kernel stack. It sits between raw conversation data and semantic analysis, providing:

- **Bounded context windows** around any anchor turn
- **Phase-aware prioritization** (Synthesis > Planning > Consolidation > Debugging > Exploration)
- **Deterministic fingerprints** for reproducibility and provenance
- **Salience-weighted expansion** to capture the most important turns first

### Why This Matters

Without deterministic context slicing:
- "Same input" can produce different semantic analyses
- Provenance becomes meaningless
- Replay and debugging are impossible
- Evidence accumulation can't be trusted

With the Graph Kernel:
- Every slice has a unique, content-derived `slice_id`
- Same anchor + same policy + same graph = identical slice
- Downstream artifacts can reference their source context
- The entire pipeline becomes auditable

---

## Core Contract

The Graph Kernel guarantees exactly three things:

1. **Deterministic Selection**: Same inputs → same slice, byte-for-byte
2. **Budget Compliance**: Slices respect `max_nodes` and `max_radius` limits
3. **Canonical Ordering**: Turns sorted by TurnId, edges by (parent, child)

These guarantees are enforced by:
- BTreeMap/BTreeSet for all internal collections (no HashMap)
- Canonical JSON serialization for fingerprinting
- Explicit ordering implementations on all types

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContextSlicer                            │
├─────────────────────────────────────────────────────────────────┤
│  Input: TurnId (anchor)                                         │
│  Output: SliceExport { turns, edges, slice_id }                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   │
│  │  GraphStore   │───▶│  SlicePolicyV1│───▶│ BFS Expansion │   │
│  │ (Postgres or  │    │ (phase weights│    │ (priority     │   │
│  │  InMemory)    │    │  + budgets)   │    │  queue)       │   │
│  └───────────────┘    └───────────────┘    └───────────────┘   │
│                                                                 │
│                              │                                  │
│                              ▼                                  │
│                    ┌───────────────────┐                        │
│                    │   SliceExport     │                        │
│                    │ ┌───────────────┐ │                        │
│                    │ │ slice_id      │ │ ◀── xxHash64           │
│                    │ │ turns[]       │ │     (canonical)        │
│                    │ │ edges[]       │ │                        │
│                    │ │ policy_hash   │ │                        │
│                    │ └───────────────┘ │                        │
│                    └───────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
cc-graph-kernel = { path = "../cc-graph-kernel" }

# For PostgreSQL support (optional)
cc-graph-kernel = { path = "../cc-graph-kernel", features = ["postgres"] }

# For REST service (optional)
cc-graph-kernel = { path = "../cc-graph-kernel", features = ["service"] }
```

### Feature Flags

| Feature | Description | Dependencies |
|---------|-------------|--------------|
| `default` | In-memory store only | None |
| `postgres` | PostgreSQL graph store | `sqlx`, `tokio` |
| `service` | REST API service | `axum`, `tower`, `tower-http`, `postgres` |

### REST Service

The Graph Kernel can be deployed as a standalone REST service:

```bash
# Run locally
DATABASE_URL=... cargo run --bin graph_kernel_service --features service

# Or with Docker
docker build -f Dockerfile.service -t graph-kernel .
docker run -p 8001:8001 -e DATABASE_URL=... graph-kernel
```

**Endpoints:**
- `POST /api/slice` - Construct a slice around an anchor
- `POST /api/slice/batch` - Batch slice construction
- `GET /api/policies` - List registered policies
- `POST /api/policies` - Register a new policy
- `GET /health` - Service health check

See [docs/SERVICE.md](docs/SERVICE.md) for full API documentation.

---

## Quick Start

### In-Memory (Testing)

```rust
use cc_graph_kernel::{
    ContextSlicer, SlicePolicyV1, InMemoryGraphStore,
    TurnId, TurnSnapshot, Edge, EdgeType, Role, Phase,
};
use uuid::Uuid;

// Build a graph
let mut store = InMemoryGraphStore::new();

store.add_turn(TurnSnapshot::new(
    TurnId::new(Uuid::from_u128(1)),
    "session_1".to_string(),
    Role::User,
    Phase::Synthesis,
    0.9,  // salience
    0,    // depth
    0,    // sibling_order
    0.5,  // homogeneity
    0.5,  // temporal
    1.0,  // complexity
    1704067200,  // created_at (Unix timestamp)
));

// Add more turns and edges...

// Create slicer
let policy = SlicePolicyV1::default();
let slicer = ContextSlicer::new(store, policy);

// Generate slice
let anchor_id = TurnId::new(Uuid::from_u128(1));
let slice = slicer.slice(anchor_id).unwrap();

println!("Slice ID: {}", slice.slice_id);
println!("Turns: {}", slice.num_turns());
println!("Edges: {}", slice.num_edges());
```

### PostgreSQL (Production)

```rust
use cc_graph_kernel::{
    ContextSlicer, SlicePolicyV1, PostgresGraphStore, PostgresConfig,
    TurnId,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Connect to Orbit database
    let config = PostgresConfig {
        database_url: std::env::var("DATABASE_URL")?,
        max_connections: 5,
        connect_timeout_secs: 30,
    };
    
    let store = PostgresGraphStore::new(config).await?;
    let policy = SlicePolicyV1::default();
    let slicer = ContextSlicer::new(store, policy);
    
    // Slice around a specific turn
    let anchor_id = TurnId::from_str("550e8400-e29b-41d4-a716-446655440000")?;
    let slice = slicer.slice(anchor_id)?;
    
    println!("Context slice: {} turns, {} edges", 
             slice.num_turns(), slice.num_edges());
    println!("Fingerprint: {}", slice.slice_id);
    
    Ok(())
}
```

---

## Types Reference

### TurnId

Unique identifier for a turn in the conversation DAG.

```rust
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TurnId(Uuid);

impl TurnId {
    pub fn new(uuid: Uuid) -> Self;
    pub fn from_str(s: &str) -> Result<Self, uuid::Error>;
    pub fn as_uuid(&self) -> Uuid;
}
```

### Role

Role of the turn author.

```rust
pub enum Role {
    User,       // User message
    Assistant,  // AI response
    System,     // System message
    Tool,       // Tool/function call result
}
```

### Phase

Trajectory phase of the turn. Ordered by importance for context selection.

```rust
pub enum Phase {
    Exploration,   // weight: 0.3 (lowest)
    Debugging,     // weight: 0.5
    Consolidation, // weight: 0.6
    Planning,      // weight: 0.9
    Synthesis,     // weight: 1.0 (highest)
}
```

### TurnSnapshot

Minimal snapshot of a turn for slicing.

```rust
pub struct TurnSnapshot {
    pub id: TurnId,
    pub session_id: String,
    pub role: Role,
    pub phase: Phase,
    pub salience: f32,                  // [0, 1]
    pub trajectory_depth: u32,
    pub trajectory_sibling_order: u32,
    pub trajectory_homogeneity: f32,    // [0, 1]
    pub trajectory_temporal: f32,       // [0, 1]
    pub trajectory_complexity: f32,
    pub created_at: i64,                // Unix timestamp
}
```

### Edge

Directed edge in the conversation DAG.

```rust
pub struct Edge {
    pub parent: TurnId,
    pub child: TurnId,
    pub edge_type: EdgeType,
}

pub enum EdgeType {
    Reply,      // Direct reply/continuation
    Branch,     // Fork in conversation
    Reference,  // Reference to earlier turn
    Default,    // Unspecified
}
```

---

## SlicePolicy v1

The policy controls how context slices are expanded around an anchor turn.

### Configuration

```rust
pub struct SlicePolicyV1 {
    pub version: String,              // "slice_policy_v1"
    pub max_nodes: usize,             // Budget: max turns in slice (default: 256)
    pub max_radius: u32,              // Budget: max hops from anchor (default: 10)
    pub phase_weights: PhaseWeights,  // Priority weights per phase
    pub salience_weight: f32,         // How much salience contributes (default: 0.3)
    pub distance_decay: f32,          // Priority decay per hop (default: 0.9)
    pub include_siblings: bool,       // Whether to include siblings (default: true)
    pub max_siblings_per_node: usize, // Limit per parent (default: 5)
}

pub struct PhaseWeights {
    pub synthesis: f32,      // 1.0 (highest priority)
    pub planning: f32,       // 0.9
    pub consolidation: f32,  // 0.6
    pub debugging: f32,      // 0.5
    pub exploration: f32,    // 0.3 (lowest priority)
}
```

### Policy Hash

Each policy configuration produces a deterministic `params_hash`:

```rust
let policy = SlicePolicyV1::default();
let hash = policy.params_hash(); // e.g., "a1b2c3d4e5f6789a"
```

Different policy parameters → different hash → different slice_id.

---

## Priority Scoring

The priority of a turn determines its likelihood of inclusion in the slice.

### Formula

```
priority = (phase_weight + salience × salience_weight) × distance_decay^distance
```

### Components

| Component | Description | Range |
|-----------|-------------|-------|
| `phase_weight` | Weight from PhaseWeights based on turn's phase | 0.3 - 1.0 |
| `salience` | Turn's salience score from database | 0.0 - 1.0 |
| `salience_weight` | How much salience contributes to priority | 0.0 - 1.0 |
| `distance_decay` | Multiplicative decay per hop from anchor | 0.0 - 1.0 |
| `distance` | Number of hops from anchor turn | 0, 1, 2, ... |

### Example

For a Synthesis turn with salience 0.8 at distance 2:
- phase_weight = 1.0
- salience_weight = 0.3 (default)
- distance_decay = 0.9 (default)

```
priority = (1.0 + 0.8 × 0.3) × 0.9² = 1.24 × 0.81 = 1.004
```

For an Exploration turn with salience 0.3 at distance 2:
```
priority = (0.3 + 0.3 × 0.3) × 0.9² = 0.39 × 0.81 = 0.316
```

The Synthesis turn is 3× more likely to be selected.

---

## Context Slicer Algorithm

The slicer uses a **priority-queue BFS** to expand around the anchor:

### Algorithm

```
1. Initialize:
   - selected = []
   - visited = {anchor_id}
   - frontier = PriorityQueue(anchor at distance 0)

2. While frontier not empty AND |selected| < max_nodes:
   a. Pop highest-priority candidate
   b. If distance > max_radius: skip
   c. Add to selected
   d. For each neighbor (parents, children, siblings):
      - If not visited:
        - Mark visited
        - Compute priority score
        - Add to frontier with distance + 1

3. Collect edges between selected turns

4. Sort turns by TurnId, edges by (parent, child)

5. Compute slice_id fingerprint

6. Return SliceExport
```

### Key Properties

- **Priority-first**: High-priority turns (Synthesis, high salience) selected first
- **Distance-aware**: Closer turns preferred via decay
- **Budget-bounded**: Never exceeds max_nodes or max_radius
- **Deterministic**: Same priority → ordered by TurnId for tie-breaking

---

## Graph Stores

### GraphStore Trait

```rust
pub trait GraphStore {
    type Error: std::error::Error;
    
    fn get_turn(&self, id: &TurnId) -> Result<Option<TurnSnapshot>, Self::Error>;
    fn get_turns(&self, ids: &[TurnId]) -> Result<Vec<TurnSnapshot>, Self::Error>;
    fn get_parents(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;
    fn get_children(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;
    fn get_siblings(&self, id: &TurnId, limit: usize) -> Result<Vec<TurnId>, Self::Error>;
    fn get_edges(&self, turn_ids: &[TurnId]) -> Result<Vec<Edge>, Self::Error>;
}
```

### InMemoryGraphStore

For testing and small datasets:

```rust
let mut store = InMemoryGraphStore::new();
store.add_turn(turn);
store.add_edge(edge);

// Uses BTreeMap internally for deterministic iteration
```

### PostgresGraphStore

For production with Orbit database:

```rust
// Requires "postgres" feature
let store = PostgresGraphStore::from_env().await?;

// Queries:
// - memory_turns table for turn data
// - memory_turn_edges table for parent/child relationships
```

#### Expected Schema

```sql
-- memory_turns
CREATE TABLE memory_turns (
    id UUID PRIMARY KEY,
    session_id TEXT,
    role TEXT,
    trajectory_phase TEXT,
    salience_score REAL,
    trajectory_depth INTEGER,
    trajectory_sibling_order INTEGER,
    trajectory_homogeneity REAL,
    trajectory_temporal REAL,
    trajectory_complexity REAL,
    created_at TIMESTAMP
);

-- memory_turn_edges
CREATE TABLE memory_turn_edges (
    parent_turn_id UUID REFERENCES memory_turns(id),
    child_turn_id UUID REFERENCES memory_turns(id),
    edge_type TEXT,
    PRIMARY KEY (parent_turn_id, child_turn_id)
);
```

---

## SliceExport & Fingerprinting

### SliceExport

The output of context slicing:

```rust
pub struct SliceExport {
    pub anchor_turn_id: TurnId,
    pub turns: Vec<TurnSnapshot>,    // Sorted by TurnId
    pub edges: Vec<Edge>,            // Sorted by (parent, child)
    pub policy_id: String,           // "slice_policy_v1"
    pub policy_params_hash: String,  // Hash of policy config
    pub schema_version: String,      // "1.0.0"
    pub slice_id: SliceFingerprint,  // Content-derived hash
}
```

### SliceFingerprint

The fingerprint is computed from:

```rust
let canonical = (
    anchor,           // The anchor TurnId
    turn_ids,         // Vec<TurnId> of all turns
    edges,            // Vec<Edge> of all edges
    policy_id,        // "slice_policy_v1"
    policy_params_hash, // Hash of policy config
    schema_version,   // "1.0.0"
);

let slice_id = xxHash64(canonical_json_bytes(canonical));
```

### Why This Design?

1. **Content-derived**: Changes to slice content → different fingerprint
2. **Policy-aware**: Different policy params → different fingerprint (even if turns are same)
3. **Version-aware**: Schema changes → different fingerprint
4. **Deterministic**: Same inputs → same fingerprint, always

---

## Determinism Guarantees

### What Is Guaranteed

| Property | Guarantee |
|----------|-----------|
| Turn ordering | Always sorted by TurnId |
| Edge ordering | Always sorted by (parent, child, edge_type) |
| Slice ID | Same inputs → identical slice_id on every run |
| Policy hash | Same policy config → identical params_hash |
| Serialization | Canonical JSON (no HashMap, sorted keys) |

### What Is NOT Guaranteed

| Property | Reason |
|----------|--------|
| Slice content stability | Changes to graph → changes to slice |
| Cross-version stability | Schema version changes may change fingerprints |
| Float precision | Standard IEEE 754 (use quantization if needed) |

### Golden Tests

The crate includes 13 golden tests verifying determinism:

```rust
#[test]
fn test_same_anchor_same_slice_id_100_runs() {
    // Generate 100 slices from same anchor
    // All must have identical slice_id
}

#[test]
fn test_policy_param_change_changes_slice_id() {
    // Different policy params → different fingerprint
}

#[test]
fn test_edge_ordering_determinism() {
    // Edges always in same order
}
```

---

## Integration with CognitiveTwin Bridge

The Graph Kernel provides the "context" for semantic analysis:

```
┌─────────────────────────────────────────────────────────────────┐
│                     CognitiveTwin Bridge                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    │
│  │  Atomizer   │───▶│   Proposer   │───▶│   Evidence      │    │
│  │             │    │              │    │   Runner        │    │
│  └─────────────┘    └──────────────┘    └─────────────────┘    │
│         │                  │                    │               │
│         │                  │                    │               │
│         ▼                  ▼                    ▼               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    slice_id provenance                   │   │
│  │  "This atom was extracted from slice a1b2c3d4..."       │   │
│  │  "This proposal was made in context of slice x9y8z7..." │   │
│  │  "This observation occurred under slice e5f6g7h8..."    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ▲                                  │
│                              │                                  │
│                    ┌─────────────────┐                          │
│                    │  Graph Kernel   │                          │
│                    │  SliceExport    │                          │
│                    └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

### Usage Pattern

```rust
// In the Atomizer
let slice = graph_kernel.slice(anchor_turn_id)?;

let atom = TrajectoryAtom {
    id: AtomId::compute(...),
    provenance: AtomProvenance {
        slice_id: slice.slice_id.to_string(),
        anchor_turn_id: slice.anchor_turn_id,
        // ...
    },
    // ...
};

// In the EvidenceRunner
let observation = TraceObserved {
    slice_id: slice.slice_id.to_string(),
    trace_stats: TraceStats { ... },
    // ...
};
```

---

## Testing

### Run All Tests

```bash
cd cc-graph-kernel
cargo test
```

### Run Specific Test Category

```bash
# Unit tests only
cargo test --lib

# Golden tests only
cargo test --test golden

# With postgres feature
cargo test --features postgres
```

### Test Coverage

| Category | Tests | Description |
|----------|-------|-------------|
| Types | 6 | TurnId ordering, Phase weights, Role parsing |
| Policy | 3 | Phase weights, params hash determinism |
| Scoring | 4 | Priority calculation, candidate ordering |
| Store | 4 | Add/get turns, edges, siblings |
| Slicer | 4 | Anchor inclusion, budget limits, determinism |
| Golden | 13 | 100-run determinism, edge ordering, fingerprinting |

---

## API Reference

### Main Entry Points

```rust
// Create a slicer
pub fn ContextSlicer::new(store: S, policy: SlicePolicyV1) -> Self;

// Generate a slice
pub fn ContextSlicer::slice(&self, anchor_id: TurnId) -> Result<SliceExport, SlicerError>;

// Access policy
pub fn ContextSlicer::policy(&self) -> &SlicePolicyV1;

// Access store
pub fn ContextSlicer::store(&self) -> &S;
```

### SliceExport Methods

```rust
pub fn SliceExport::num_turns(&self) -> usize;
pub fn SliceExport::num_edges(&self) -> usize;
pub fn SliceExport::contains_turn(&self, id: &TurnId) -> bool;
pub fn SliceExport::anchor_turn(&self) -> Option<&TurnSnapshot>;
```

### Policy Configuration

```rust
// Default policy
let policy = SlicePolicyV1::default();

// Custom policy
let policy = SlicePolicyV1::new(
    128,                      // max_nodes
    5,                        // max_radius
    PhaseWeights::default(),  // phase_weights
    0.4,                      // salience_weight
    0.85,                     // distance_decay
    true,                     // include_siblings
    3,                        // max_siblings_per_node
);

// Get policy hash
let hash = policy.params_hash();
```

### Canonical Hashing

```rust
use cc_graph_kernel::{canonical_hash, canonical_hash_hex};

let hash_u64 = canonical_hash(&my_struct);
let hash_hex = canonical_hash_hex(&my_struct);
```

---

## Constants

```rust
/// Schema version for all graph kernel types.
pub const GRAPH_KERNEL_SCHEMA_VERSION: &str = "1.0.0";

/// Default policy version identifier.
pub const DEFAULT_POLICY_VERSION: &str = "slice_policy_v1";
```

---

## Error Handling

```rust
pub enum SlicerError {
    /// Anchor turn not found in graph.
    AnchorNotFound(TurnId),
    
    /// Error from the underlying store.
    StoreError(String),
}
```

---

## License

MIT

---

## Changelog

### v0.2.0 (2026-01-01)

- **NEW: REST Service Feature**
  - `graph_kernel_service` binary for standalone deployment
  - Axum-based REST API with `/api/slice`, `/api/policies` endpoints
  - PolicyRegistry for immutable policy management
  - Docker support via `Dockerfile.service`
  - RAG++ integration via SliceClient
- ServiceState for shared store and policy registry
- PolicyRef for stable policy references

### v0.1.0 (2026-01-01)

- Initial release
- TurnId, TurnSnapshot, Edge types with canonical ordering
- SlicePolicyV1 with phase weights and budgets
- Priority-queue BFS expansion algorithm
- InMemoryGraphStore for testing
- PostgresGraphStore for production (optional feature)
- SliceExport with deterministic fingerprinting
- 37 tests (24 unit + 13 golden)

