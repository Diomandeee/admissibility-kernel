# SlicePolicy v1 Specification

**Version**: 1.0.0  
**Status**: Locked  
**Effective Date**: 2026-01-01

---

## 1. Overview

SlicePolicy v1 is a **versioned contract** that defines how relevant context is selected for a given anchor node in a conversation DAG.

This specification is immutable once locked. Future changes require a new policy version (v2).

---

## 2. Policy Identifier

```
Policy ID: slice_policy_v1
```

All slices generated with this policy will have:
```json
{
  "policy_id": "slice_policy_v1",
  "policy_params_hash": "<xxHash64 of config>"
}
```

---

## 3. Configuration Parameters

### 3.1 Budget Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_nodes` | usize | 256 | Maximum turns in slice |
| `max_radius` | u32 | 10 | Maximum hops from anchor |

**Constraints**:
- `max_nodes >= 1` (at least the anchor)
- `max_radius >= 0` (0 = anchor only)

### 3.2 Scoring Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `salience_weight` | f32 | 0.3 | [0.0, 1.0] | Contribution of salience to priority |
| `distance_decay` | f32 | 0.9 | [0.0, 1.0] | Priority multiplier per hop |

### 3.3 Phase Weights

| Phase | Default Weight | Description |
|-------|---------------|-------------|
| Synthesis | 1.0 | Breakthrough insights, new understanding |
| Planning | 0.9 | Strategic thinking, goal-setting |
| Consolidation | 0.6 | Summarization, integration |
| Debugging | 0.5 | Problem-solving, troubleshooting |
| Exploration | 0.3 | Brainstorming, tangential thinking |

**Constraint**: Weights should be in [0.0, 1.0] but are not clamped.

### 3.4 Sibling Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `include_siblings` | bool | true | Whether to expand to siblings |
| `max_siblings_per_node` | usize | 5 | Limit per parent node |

---

## 4. Priority Scoring Formula

The priority of a candidate turn is computed as:

```
priority(turn, distance) = 
    (phase_weight(turn.phase) + turn.salience × salience_weight) 
    × distance_decay^distance
```

### 4.1 Component Definitions

**phase_weight(phase)**:
```rust
match phase {
    Synthesis     => phase_weights.synthesis,     // 1.0
    Planning      => phase_weights.planning,      // 0.9
    Consolidation => phase_weights.consolidation, // 0.6
    Debugging     => phase_weights.debugging,     // 0.5
    Exploration   => phase_weights.exploration,   // 0.3
}
```

**distance**:
- Anchor: distance = 0
- Direct parent/child: distance = 1
- Grandparent/grandchild: distance = 2
- etc.

**Siblings inherit the distance of the node they were discovered from.**

### 4.2 Priority Range

With default parameters:
- Minimum: `(0.3 + 0.0) × 0.9^10 ≈ 0.10` (Exploration, zero salience, distance 10)
- Maximum: `(1.0 + 0.3) × 0.9^0 = 1.30` (Synthesis, full salience, distance 0)

---

## 5. Expansion Algorithm

### 5.1 Initialization

```python
selected = []
visited = {anchor_id}
frontier = PriorityQueue()  # max-heap by priority

anchor = store.get_turn(anchor_id)
frontier.push(Candidate(anchor, distance=0, priority=compute_priority(anchor, 0)))
```

### 5.2 Main Loop

```python
while frontier.not_empty() and len(selected) < max_nodes:
    candidate = frontier.pop()  # highest priority
    
    if candidate.distance > max_radius:
        continue
    
    selected.append(candidate.turn)
    
    # Skip expansion if at radius limit
    if candidate.distance + 1 > max_radius:
        continue
    
    # Expand to parents
    for parent_id in store.get_parents(candidate.turn.id):
        if parent_id not in visited:
            visited.add(parent_id)
            parent = store.get_turn(parent_id)
            frontier.push(Candidate(
                parent, 
                distance=candidate.distance + 1,
                priority=compute_priority(parent, candidate.distance + 1)
            ))
    
    # Expand to children
    for child_id in store.get_children(candidate.turn.id):
        if child_id not in visited:
            visited.add(child_id)
            child = store.get_turn(child_id)
            frontier.push(Candidate(
                child, 
                distance=candidate.distance + 1,
                priority=compute_priority(child, candidate.distance + 1)
            ))
    
    # Expand to siblings (if enabled)
    if include_siblings:
        for sibling_id in store.get_siblings(candidate.turn.id, max_siblings_per_node):
            if sibling_id not in visited:
                visited.add(sibling_id)
                sibling = store.get_turn(sibling_id)
                frontier.push(Candidate(
                    sibling, 
                    distance=candidate.distance,  # same distance!
                    priority=compute_priority(sibling, candidate.distance)
                ))
```

### 5.3 Tie-Breaking

When candidates have equal priority:
1. **Lower distance preferred** (closer to anchor)
2. **Lower TurnId preferred** (deterministic ordering)

---

## 6. Output Specification

### 6.1 SliceExport Schema

```json
{
  "anchor_turn_id": "uuid-string",
  "turns": [
    {
      "id": "uuid-string",
      "session_id": "string",
      "role": "user|assistant|system|tool",
      "phase": "exploration|debugging|planning|consolidation|synthesis",
      "salience": 0.0-1.0,
      "trajectory_depth": 0,
      "trajectory_sibling_order": 0,
      "trajectory_homogeneity": 0.0-1.0,
      "trajectory_temporal": 0.0-1.0,
      "trajectory_complexity": 0.0,
      "created_at": 1704067200
    }
  ],
  "edges": [
    {
      "parent": "uuid-string",
      "child": "uuid-string",
      "edge_type": "reply|branch|reference|default"
    }
  ],
  "policy_id": "slice_policy_v1",
  "policy_params_hash": "hex-string",
  "schema_version": "1.0.0",
  "slice_id": "hex-string"
}
```

### 6.2 Ordering Guarantees

- **turns**: Sorted by `id` (UUID lexicographic)
- **edges**: Sorted by `(parent, child, edge_type)`

### 6.3 Fingerprint Computation

```python
def compute_slice_id(anchor, turns, edges, policy_id, policy_params_hash, schema_version):
    turn_ids = sorted([t.id for t in turns])
    sorted_edges = sorted(edges, key=lambda e: (e.parent, e.child, e.edge_type))
    
    canonical = (
        anchor,
        turn_ids,
        sorted_edges,
        policy_id,
        policy_params_hash,
        schema_version
    )
    
    return xxhash64(canonical_json(canonical))
```

---

## 7. Invariants

### 7.1 Anchor Inclusion

```
INVARIANT: anchor_turn_id ∈ turns
```

The anchor is always the first node added and cannot be excluded.

### 7.2 Budget Compliance

```
INVARIANT: len(turns) <= max_nodes
INVARIANT: ∀ turn ∈ turns: distance(turn, anchor) <= max_radius
```

### 7.3 Determinism

```
INVARIANT: slice(anchor, policy, graph) == slice(anchor, policy, graph)
```

Same inputs produce byte-identical outputs.

### 7.4 Edge Completeness

```
INVARIANT: ∀ edge ∈ edges: edge.parent ∈ turns ∧ edge.child ∈ turns
```

No edges reference turns outside the slice.

---

## 8. Policy Hash Computation

The `policy_params_hash` is computed from the full policy configuration:

```rust
let policy_config = SlicePolicyV1 {
    version: "slice_policy_v1",
    max_nodes: 256,
    max_radius: 10,
    phase_weights: PhaseWeights { ... },
    salience_weight: 0.3,
    distance_decay: 0.9,
    include_siblings: true,
    max_siblings_per_node: 5,
};

let hash = xxhash64(canonical_json(policy_config));
```

**Property**: Different configurations → different hashes → different slice_ids.

---

## 9. Usage Examples

### 9.1 Default Policy

```rust
let policy = SlicePolicyV1::default();
// max_nodes: 256, max_radius: 10
// All default weights and settings
```

### 9.2 Focused Policy (Small Context)

```rust
let policy = SlicePolicyV1::new(
    32,    // max_nodes: tight budget
    3,     // max_radius: close neighbors only
    PhaseWeights::default(),
    0.5,   // salience_weight: emphasize importance
    0.8,   // distance_decay: steeper falloff
    false, // include_siblings: no
    0,     // max_siblings_per_node: N/A
);
```

### 9.3 Broad Policy (Wide Context)

```rust
let policy = SlicePolicyV1::new(
    512,   // max_nodes: large budget
    20,    // max_radius: deep exploration
    PhaseWeights::default(),
    0.2,   // salience_weight: trust phase more
    0.95,  // distance_decay: gentle falloff
    true,  // include_siblings: yes
    10,    // max_siblings_per_node: many alternatives
);
```

---

## 10. Compatibility Notes

### 10.1 Schema Version 1.0.0

This specification is compatible with:
- `GRAPH_KERNEL_SCHEMA_VERSION = "1.0.0"`
- `cc-graph-kernel v0.1.x`

### 10.2 Breaking Changes

The following changes would require a new policy version:
- Changing the priority formula
- Adding new expansion directions (e.g., cross-session)
- Modifying tie-breaking rules
- Adding/removing fingerprint components

### 10.3 Non-Breaking Changes

The following changes do NOT require a new policy version:
- Adding optional parameters with defaults
- Performance optimizations
- Bug fixes that don't change output

---

## 11. Validation Checklist

Before using a slice, verify:

- [ ] `slice_id` matches expected fingerprint (if known)
- [ ] `policy_id == "slice_policy_v1"`
- [ ] `len(turns) <= policy.max_nodes`
- [ ] `anchor_turn_id ∈ turns`
- [ ] All edges reference turns in the slice

---

## 12. Appendix: Default Configuration

```json
{
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
```

**Default params_hash**: Computed at runtime; use `SlicePolicyV1::default().params_hash()`.

