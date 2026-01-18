# Implementation Guide

**Version**: 1.0.0
**Last Updated**: 2026-01-02
**Authority**: Master Implementation Constitution (CLAUDE.md)

---

## Decision Rules

### Signal Requirements

Decisions are made based on converging signals:

| Decision Type | Examples | Required Signals | Allowed to Proceed? |
|---------------|----------|------------------|---------------------|
| **Micro** | Naming, formatting, local refactors | 1 signal | ✅ Yes |
| **Meso** | Module design, API shape, integration | 2 signals | ⚠️ After convergence |
| **Macro** | Architecture, schema, cross-system | 3+ signals | ❌ Only after full convergence |

**Signals** include:
- Explicit requirement in improvement document
- Existing code pattern (precedent)
- Test failure or production incident
- User clarification

**Example**:
- "Add `AdmissibleEvidenceBundle` type" — Macro decision
  - Signal 1: Improvement doc explicitly recommends it
  - Signal 2: Current code lacks type-level safety (audit finding)
  - Signal 3: Promotion pipeline could accept unverified evidence (security gap)
  - **Decision**: Proceed with implementation ✅

### Conflict Resolution

When signals disagree:
1. **Document the conflict** in this guide
2. **Ask user for clarification** via `AskUserQuestion`
3. **Do not proceed** on assumptions
4. **If micro-level**: Choose the most conservative option (easiest to reverse)

### "Done" Criteria

A task is complete when:
1. ✅ Code compiles and passes all tests (including new tests for the feature)
2. ✅ Documentation updated (inline comments + architecture doc)
3. ✅ Validation criteria met (see checklist for each task)
4. ✅ No blocking issues remain open

### "Blocked" Criteria

A task is blocked when:
- ❌ Missing dependency (e.g., database migration not yet run)
- ❌ Unclear requirement (need user clarification)
- ❌ External service unavailable (e.g., cannot deploy to test HMAC secret)

---

## Decomposition Rules

### Atomic Unit Definition

The smallest meaningful unit of work is one that:
1. Has a **single, verifiable output** (a type, a function, a test, a migration)
2. Can be **validated independently** (test passes, compiles, documented)
3. Does **not require context** from unfinished sibling tasks
4. Can be **rolled back** without affecting other units

### Task Breakdown Pattern

```
Feature (Macro)
└── Module (Meso)
    ├── Type Definition (Micro)
    ├── Constructor/Methods (Micro)
    ├── Tests (Micro)
    └── Integration (Meso)
```

**Example**: "Add AdmissibleEvidenceBundle type"
1. ✅ Define `AdmissibleEvidenceBundle` struct (micro)
2. ✅ Implement `from_verified(SliceExport, secret) -> Result<Self>` (micro)
3. ✅ Add `is_admissible()` marker trait (micro)
4. ✅ Write unit tests (micro)
5. ✅ Integrate with promotion APIs (meso)

### Maximum Scope per Task

- **Code**: 1 file or 1 coherent module (< 500 lines)
- **Test**: 1 integration scenario or 3-5 unit test cases
- **Doc**: 1 section of architecture doc (< 1000 words)
- **Migration**: 1 schema change (1 SQL file)

---

## Validation Rules

### Validation Stages

| Stage | What | When | Required? |
|-------|------|------|-----------|
| **Compilation** | `cargo check` passes | After every code change | ✅ Always |
| **Unit Tests** | `cargo test` passes | After every function/type addition | ✅ Always |
| **Integration Tests** | Service starts, API responds | After API changes | ✅ If service feature enabled |
| **Security Audit** | `cargo test --features security-audit` | Before PR merge | ✅ For security changes |
| **Documentation** | Inline docs + architecture doc updated | After API changes | ✅ For public APIs |
| **Performance** | Benchmark shows < 5ms p99 | After caching implementation | ⚠️ If perf-critical |

### Validation Artifacts

Each validation produces an artifact:
- **Compilation**: `cargo check` output (exit code 0)
- **Tests**: Test report (all passing)
- **Integration**: `curl` examples showing API responses
- **Docs**: Updated `.md` file with timestamp

### Unblocking Criteria

A blocked task is unblocked when:
- Dependency completes (check checklist status)
- User clarifies requirement (documented in decision log)
- External service becomes available (verified with health check)

---

## Implementation Order

Following the improvement document's recommendation: **"Implement only one upgrade first, do the type-level one."**

### Priority 1 (Must Do First)

**Type-Level Safety**: `AdmissibleEvidenceBundle`

Rationale: Removes entire class of future bugs where unverified evidence enters promotion pipeline.

### Priority 2 (Foundational)

**Content Canonicalization**: Formal spec + enforcement

Rationale: Enables reliable content hashing (needed for Priority 3).

### Priority 3 (Performance)

**Token Verification**: Production mode with caching

Rationale: Makes verification cheap (<5ms), removes bypass temptation.

### Priority 4 (Sufficiency)

**EvidenceBundle**: Diversity metrics + sufficiency policy

Rationale: Prevents gaming with 10 identical low-quality turns.

### Priority 5 (Enforcement)

**Database-Level Slice Boundaries**: SQL pattern enforcement

Rationale: Makes violations impossible by construction.

### Priority 6 (Observability)

**Replay Provenance**: Embedding model + retrieval params

Rationale: Enables full experiment reproduction.

### Priority 7 (Incident Response)

**Metrics + Alerts**: Prometheus counters + quarantine table

Rationale: Makes violations visible and actionable.

---

## Code Style Requirements

### Rust Conventions

- Use `thiserror` for error types
- Implement `Display` for all newtype wrappers
- Mark security-critical functions with `/// # Security` doc comments
- Use `const` for version strings and magic numbers
- Prefer `Arc<T>` over `Rc<T>` (multi-threaded by default)

### Documentation Requirements

Every public type/function must have:
```rust
/// Short description (one line).
///
/// Longer explanation if needed.
///
/// # Arguments
/// * `param` - Description
///
/// # Returns
/// Description of return value.
///
/// # Security (if applicable)
/// Why this is security-critical.
///
/// # Example (if non-trivial)
/// ```rust
/// let result = function(input);
/// ```
```

### Test Requirements

- Every new type gets unit tests for: construction, validation, edge cases
- Every new API endpoint gets integration test
- Every security-critical path gets negative test (expect failure)

---

## Continuation Protocol

### Stopping Points

Stop cleanly when:
- Token limit approaching (~180k/200k)
- Natural task boundary (task completed, next one requires research)
- User interrupts

### Continuation Anchor

When resuming, always state:
```
CONTINUATION ANCHOR
-------------------
Phase: [Current phase]
Last Completed: [Most recent checklist item]
Next Active: [Next pending item]
Confidence: [Low / Medium / High]
Open Uncertainties: [List or "None"]
Blocked By: ["None" or list dependencies]
```

### State Preservation

- Checklist status in `TodoWrite` tool (always up to date)
- Code artifacts in version control (committed after each major step)
- Decision log in this document (append new decisions)

---

## Decision Log

### 2026-01-02: Implementation Order

**Decision**: Implement type-level safety (`AdmissibleEvidenceBundle`) first.

**Signals**:
1. Improvement doc explicitly recommends it
2. Current code audit shows no compile-time prevention of unverified evidence use
3. Prevents entire class of future bugs

**Confidence**: High
**Approved**: Yes (follows improvement doc recommendation)

### 2026-01-02: Content Canonicalization Spec

**Decision**: Define canonical content as `UTF-8(trim(normalize_newlines(content_text)))`, role/metadata excluded.

**Signals**:
1. Improvement doc calls for "one canonical hashing spec"
2. Current code has ad-hoc hashing without normalization
3. Backfill will need consistent spec

**Confidence**: Medium (awaiting user confirmation on normalization rules)
**Approved**: Provisional (implement with ability to change normalization)

---

## Template for New Decisions

```markdown
### YYYY-MM-DD: [Decision Title]

**Decision**: [What was decided]

**Signals**:
1. [First signal]
2. [Second signal]
3. [Third signal if macro]

**Confidence**: [Low / Medium / High]
**Approved**: [Yes / No / Provisional]
**Reversibility**: [Easy / Moderate / Hard]
```
