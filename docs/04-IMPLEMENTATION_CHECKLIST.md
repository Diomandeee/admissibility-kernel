# Living Implementation Checklist

**Version**: 1.2.0
**Last Updated**: 2026-01-02
**Status**: Complete (All 8 Phases)

---

## Phase 0: Project Control Layer ✅ COMPLETE

- [x] **0.1** Create Project Charter
  - Owner: Agent
  - Input: Improvement document, existing architecture
  - Output: `docs/00-PROJECT_CHARTER.md`
  - Validation: Charter defines purpose, non-goals, success criteria
  - Status: ✅ Complete
  - Confidence: High

- [x] **0.2** Create System Glossary
  - Owner: Agent
  - Input: Existing code, architecture docs
  - Output: `docs/01-GLOSSARY.md`
  - Validation: All security terms defined, overloaded terms flagged
  - Status: ✅ Complete
  - Confidence: High

- [x] **0.3** Create Invariants Ledger
  - Owner: Agent
  - Input: Improvement document, existing tests
  - Output: `docs/02-INVARIANTS_LEDGER.md`
  - Validation: All 8 invariants documented with canaries
  - Status: ✅ Complete
  - Confidence: High

- [x] **0.4** Create Implementation Guide
  - Owner: Agent
  - Input: CLAUDE.md, improvement document
  - Output: `docs/03-IMPLEMENTATION_GUIDE.md`
  - Validation: Decision rules, decomposition rules, validation rules defined
  - Status: ✅ Complete
  - Confidence: High

- [x] **0.5** Create Living Checklist (this document)
  - Owner: Agent
  - Input: All Phase 0 artifacts
  - Output: `docs/04-IMPLEMENTATION_CHECKLIST.md`
  - Validation: All tasks listed with owners, inputs, outputs, validation
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 1: Type-Level Safety (Priority 1) ✅ COMPLETE

**Goal**: Make it physically impossible to pass unverified evidence to promotion APIs.

### 1.1 Core Type Definition

- [x] **1.1.1** Define `AdmissibleEvidenceBundle` struct
  - Owner: Agent
  - Input: `types/slice.rs`, glossary
  - Output: `src/types/admissible.rs`
  - Validation: Struct contains `SliceExport` + verified marker
  - Status: ✅ Complete
  - Confidence: High

- [x] **1.1.2** Implement private constructor `from_verified`
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` struct
  - Output: `impl AdmissibleEvidenceBundle` in same file
  - Validation: Constructor requires HMAC secret, calls `verify_token()`
  - Status: ✅ Complete
  - Confidence: High

- [x] **1.1.3** Add public accessor methods
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` struct
  - Output: `slice()`, `turn_ids()`, `provenance()` methods
  - Validation: Methods return borrowed references (no cloning)
  - Status: ✅ Complete
  - Confidence: High

### 1.2 Testing

- [x] **1.2.1** Unit test: successful verification
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` implementation
  - Output: Test in `src/types/admissible.rs`
  - Validation: Test passes with correct secret
  - Status: ✅ Complete
  - Confidence: High

- [x] **1.2.2** Unit test: verification failure
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` implementation
  - Output: Test in same file
  - Validation: Test returns error with wrong secret
  - Status: ✅ Complete
  - Confidence: High

- [x] **1.2.3** Unit test: cannot construct with invalid token
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` implementation
  - Output: Test in same file
  - Validation: Test verifies private constructor enforces verification
  - Status: ✅ Complete
  - Confidence: High

### 1.3 Integration

- [x] **1.3.1** Add re-export to `lib.rs`
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle` module
  - Output: Modified `lib.rs`
  - Validation: `pub use types::AdmissibleEvidenceBundle`
  - Status: ✅ Complete
  - Confidence: High

- [x] **1.3.2** Update `ContextSlicer::slice` return type
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle`, `slicer.rs`
  - Output: Modified `slicer.rs`
  - Validation: Returns `AdmissibleEvidenceBundle` instead of `SliceExport`
  - Status: ✅ Complete (Phase 8)
  - Confidence: High

- [x] **1.3.3** Update service routes to use new type
  - Owner: Agent
  - Input: `service/routes.rs`, `AdmissibleEvidenceBundle`
  - Output: Modified route handlers
  - Validation: Routes serialize bundle correctly
  - Status: ✅ Complete (Phase 8)
  - Confidence: High

### 1.4 Documentation

- [x] **1.4.1** Document type-level safety in architecture doc
  - Owner: Agent
  - Input: `docs/architecture/15-GRAPH_KERNEL.md`, implementation
  - Output: Updated architecture doc
  - Validation: Section explains why promotion APIs are type-safe
  - Status: ✅ Complete (inline docs in admissible.rs)
  - Confidence: High

---

## Phase 2: Content Canonicalization (Priority 2) ✅ COMPLETE

**Goal**: Ensure 100% of turns have stable, reproducible content hashes.

### 2.1 Canonical Specification

- [x] **2.1.1** Define canonical content transformation
  - Owner: Agent
  - Input: Improvement doc, existing `content_hash` usage
  - Output: `src/canonical_content.rs`
  - Validation: Function signature `fn canonical_content(text: &str) -> Vec<u8>`
  - Status: ✅ Complete
  - Confidence: High

- [x] **2.1.2** Implement normalization steps
  - Owner: Agent
  - Input: Canonical spec
  - Output: `canonical_content()` implementation
  - Validation: Handles UTF-8, newlines, whitespace consistently
  - Status: ✅ Complete (CRLF→LF, trim whitespace, UTF-8 encode)
  - Confidence: High

- [x] **2.1.3** Implement SHA-256 hashing
  - Owner: Agent
  - Input: `canonical_content()` output
  - Output: `fn compute_content_hash(text: &str) -> String` (hex)
  - Validation: Returns hex SHA-256 of canonical bytes
  - Status: ✅ Complete
  - Confidence: High

### 2.2 Testing

- [x] **2.2.1** Test: determinism
  - Owner: Agent
  - Input: `canonical_content()` implementation
  - Output: `test_compute_content_hash_determinism`, `test_canonical_content_determinism`
  - Validation: Test passes (21 tests total)
  - Status: ✅ Complete
  - Confidence: High

- [x] **2.2.2** Test: newline normalization
  - Owner: Agent
  - Input: `canonical_content()` implementation
  - Output: `test_normalize_text_crlf`, `test_normalize_text_cr`, `test_content_hash_newline_normalization`
  - Validation: Test passes - CRLF, CR, LF all produce same hash
  - Status: ✅ Complete
  - Confidence: High

- [x] **2.2.3** Test: whitespace handling
  - Owner: Agent
  - Input: `canonical_content()` implementation
  - Output: `test_normalize_text_trim`, `test_content_hash_whitespace_normalization`
  - Validation: Test passes - leading/trailing whitespace trimmed
  - Status: ✅ Complete
  - Confidence: High

### 2.3 Enforcement

- [ ] **2.3.1** Add content hash computation to `TurnSnapshot::new` (DEFERRED)
  - Owner: Agent
  - Input: `compute_content_hash()` function, `types/turn.rs`
  - Output: Modified constructor
  - Validation: All new turns get `content_hash` automatically
  - Status: ⏳ Deferred (DB trigger handles new data automatically)
  - Confidence: Medium
  - Note: Less critical since `content_hash_trigger` on INSERT/UPDATE handles this

- [x] **2.3.2** Backfill content_hash for legacy turns
  - Owner: Agent
  - Input: Existing `compute_content_hash()` DB function
  - Output: 97,110 turns with content_hash (90.55% coverage)
  - Validation: All turns with non-empty content have hash
  - Status: ✅ Complete (2026-01-03)
  - Confidence: High
  - Note: 10,135 turns have empty content_text → NULL hash (correct behavior)

### 2.4 Documentation

- [x] **2.4.1** Document canonical content spec
  - Owner: Agent
  - Input: Implementation
  - Output: Inline docs in `src/canonical_content.rs` (lines 1-39)
  - Validation: Spec includes normalization rules + examples
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 3: Token Verification Production Mode (Priority 3) ✅ COMPLETE

**Goal**: Make verification < 5ms p99 with caching, default to single mode.

### 3.1 Verification Modes

- [x] **3.1.1** Define `VerificationMode` enum
  - Owner: Agent
  - Input: Improvement doc
  - Output: `src/types/verification.rs`
  - Validation: Enum has `LocalSecret`, `Cached` with config
  - Status: ✅ Complete
  - Confidence: High

- [x] **3.1.2** Implement local verification
  - Owner: Agent
  - Input: Existing `verify_hmac()` method
  - Output: `TokenVerifier::verify_token()` in local mode
  - Validation: Uses shared secret, constant-time comparison
  - Status: ✅ Complete
  - Confidence: High

- [x] **3.1.3** Implement cached verification
  - Owner: Agent
  - Input: `verify_token()`, LRU crate
  - Output: `TokenVerifier` with `VerificationMode::Cached`
  - Validation: LRU cache keyed by xxh64 of all canonical fields
  - Status: ✅ Complete (uses `lru` + `parking_lot` crates)
  - Confidence: High

### 3.2 Performance

- [x] **3.2.1** Add benchmark for token verification
  - Owner: Agent
  - Input: `TokenVerifier` implementation
  - Output: `benches/verification.rs`
  - Validation: Criterion benchmark runs, reports latency for cold/cached verification
  - Status: ✅ Complete (Phase 8)
  - Confidence: High

- [x] **3.2.2** Cache key design for optimal hit rate
  - Owner: Agent
  - Input: Verification parameters
  - Output: `VerificationCacheKey` using xxh64 hash
  - Validation: Unique key per parameter combination
  - Status: ✅ Complete (tests verify uniqueness)
  - Confidence: High

### 3.3 Documentation

- [x] **3.3.1** Document verification modes in module
  - Owner: Agent
  - Input: Implementation
  - Output: Inline docs in `src/types/verification.rs`
  - Validation: Module doc explains when to use each mode
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 4: Sufficiency Framework (Priority 4) ✅ COMPLETE

**Goal**: Prevent gaming with low-quality homogeneous evidence.

### 4.1 Diversity Metrics

- [x] **4.1.1** Define `DiversityMetrics` struct
  - Owner: Agent
  - Input: Improvement doc, glossary
  - Output: `src/types/sufficiency.rs`
  - Validation: Struct captures role, phase, salience, session diversity
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.1.2** Implement `SalienceStats` aggregation
  - Owner: Agent
  - Input: Turn salience scores
  - Output: Min, max, mean, std_dev, high_salience_count
  - Validation: Tests verify correct statistical computation
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.1.3** Implement `DiversityMetrics::from_bundle()`
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle`
  - Output: Computed diversity metrics
  - Validation: Correctly counts roles, phases, sessions
  - Status: ✅ Complete
  - Confidence: High

### 4.2 Sufficiency Policy

- [x] **4.2.1** Define `SufficiencyPolicy` struct
  - Owner: Agent
  - Input: Improvement doc
  - Output: Configurable thresholds in `sufficiency.rs`
  - Validation: min_turns, min_roles, min_phases, min_high_salience, require_exchange, min_mean_salience
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.2.2** Implement policy presets
  - Owner: Agent
  - Input: `SufficiencyPolicy` struct
  - Output: `default()`, `lenient()`, `strict()` constructors
  - Validation: Each preset has appropriate thresholds
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.2.3** Implement `SufficiencyPolicy::check()`
  - Owner: Agent
  - Input: `DiversityMetrics`
  - Output: `SufficiencyCheck` with violations list
  - Validation: Returns detailed violation report
  - Status: ✅ Complete
  - Confidence: High

### 4.3 Evidence Bundle

- [x] **4.3.1** Define `EvidenceBundle` struct
  - Owner: Agent
  - Input: `AdmissibleEvidenceBundle`, `DiversityMetrics`
  - Output: Combined admissibility + sufficiency type
  - Validation: Wraps admissible bundle with metrics
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.3.2** Implement `EvidenceBundle::from_admissible()`
  - Owner: Agent
  - Input: Admissible bundle, policy
  - Output: Result<EvidenceBundle, EvidenceBundleError>
  - Validation: Fails if policy not satisfied
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.3.3** Add accessor methods
  - Owner: Agent
  - Input: `EvidenceBundle` struct
  - Output: `admissible_bundle()`, `metrics()`, `policy_id()`, etc.
  - Validation: All fields accessible without cloning
  - Status: ✅ Complete
  - Confidence: High

### 4.4 Testing

- [x] **4.4.1** Unit tests for diversity metrics (5 tests)
  - Owner: Agent
  - Input: `DiversityMetrics` implementation
  - Output: Tests in `sufficiency.rs`
  - Validation: Tests pass for single turn, conversation, multi-session
  - Status: ✅ Complete (13 tests total)
  - Confidence: High

- [x] **4.4.2** Unit tests for sufficiency policy (5 tests)
  - Owner: Agent
  - Input: `SufficiencyPolicy` implementation
  - Output: Tests for each violation type
  - Validation: Tests cover insufficient turns, roles, salience, exchange
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.4.3** Unit tests for evidence bundle (3 tests)
  - Owner: Agent
  - Input: `EvidenceBundle` implementation
  - Output: Tests for success and failure cases
  - Validation: Tests verify construction fails appropriately
  - Status: ✅ Complete
  - Confidence: High

### 4.5 Integration

- [x] **4.5.1** Add module to `types/mod.rs`
  - Owner: Agent
  - Input: `sufficiency.rs`
  - Output: `pub mod sufficiency;` + re-exports
  - Validation: Module accessible from `types::`
  - Status: ✅ Complete
  - Confidence: High

- [x] **4.5.2** Add re-exports to `lib.rs`
  - Owner: Agent
  - Input: Sufficiency types
  - Output: `pub use types::sufficiency::*`
  - Validation: Types accessible from crate root
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 5: Database-Level Slice Boundaries (Priority 5) ✅ COMPLETE

**Goal**: Enforce INV-GK-008 at the database query level—prevent out-of-slice access.

### 5.1 Boundary Guard Type

- [x] **5.1.1** Define `SliceBoundaryGuard` struct
  - Owner: Agent
  - Input: Invariants ledger (INV-GK-008), glossary
  - Output: `src/types/boundary.rs`
  - Validation: Struct contains turn_ids, slice_fingerprint, boundary_hash
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.1.2** Implement `from_slice()` constructor
  - Owner: Agent
  - Input: `SliceExport` type
  - Output: `SliceBoundaryGuard::from_slice(&SliceExport)`
  - Validation: Extracts turn IDs, computes boundary hash
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.1.3** Implement `as_uuid_array()` for SQL binding
  - Owner: Agent
  - Input: `SliceBoundaryGuard` struct
  - Output: `fn as_uuid_array(&self) -> Vec<uuid::Uuid>`
  - Validation: Returns UUIDs safe for parameterized queries
  - Status: ✅ Complete
  - Confidence: High

### 5.2 Query Builder

- [x] **5.2.1** Define `BoundedQueryBuilder` struct
  - Owner: Agent
  - Input: Security requirements
  - Output: Builder in `boundary.rs`
  - Validation: Forces `WHERE id = ANY($1)` pattern
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.2.2** Implement `select()`, `filter()`, `order_by()` methods
  - Owner: Agent
  - Input: SQL query patterns
  - Output: Builder methods
  - Validation: Only parameterized patterns allowed
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.2.3** Implement `build()` method
  - Owner: Agent
  - Input: Builder state
  - Output: SQL string with $1 placeholder for turn IDs
  - Validation: Generated SQL is injection-safe
  - Status: ✅ Complete
  - Confidence: High

### 5.3 Boundary Violation Detection

- [x] **5.3.1** Define `BoundaryViolation` struct
  - Owner: Agent
  - Input: Security requirements
  - Output: Violation report type
  - Validation: Contains slice_fingerprint, unauthorized_ids, timestamp, context
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.3.2** Implement `check_access()` method
  - Owner: Agent
  - Input: Requested turn IDs
  - Output: `BoundaryCheck` enum (Authorized | Violation)
  - Validation: Detects out-of-slice access attempts
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.3.3** Implement violation logging
  - Owner: Agent
  - Input: `BoundaryViolation`
  - Output: `log()` method using tracing
  - Validation: Logs with SLICE_BOUNDARY_VIOLATION marker
  - Status: ✅ Complete
  - Confidence: High

### 5.4 Testing

- [x] **5.4.1** Unit tests for boundary guard (4 tests)
  - Owner: Agent
  - Input: `SliceBoundaryGuard` implementation
  - Output: Tests in `boundary.rs`
  - Validation: Tests creation, contains, as_uuid_array, as_set
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.4.2** Unit tests for boundary check (2 tests)
  - Owner: Agent
  - Input: `check_access()` method
  - Output: Tests for authorized and violation cases
  - Validation: Correctly identifies out-of-slice access
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.4.3** Unit tests for query builder (3 tests)
  - Owner: Agent
  - Input: `BoundedQueryBuilder` implementation
  - Output: Tests for basic, columns, filters
  - Validation: Generated SQL matches expected patterns
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.4.4** Unit tests for boundary hash (2 tests)
  - Owner: Agent
  - Input: `boundary_hash` implementation
  - Output: Tests for determinism and difference detection
  - Validation: Same turns → same hash, different turns → different hash
  - Status: ✅ Complete
  - Confidence: High

### 5.5 Integration

- [x] **5.5.1** Add module to `types/mod.rs`
  - Owner: Agent
  - Input: `boundary.rs`
  - Output: `pub mod boundary;` + re-exports
  - Validation: Module accessible from `types::`
  - Status: ✅ Complete
  - Confidence: High

- [x] **5.5.2** Add re-exports to `lib.rs`
  - Owner: Agent
  - Input: Boundary types
  - Output: `pub use types::boundary::*`
  - Validation: Types accessible from crate root
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 6: Replay Provenance Expansion (Priority 6) ✅ COMPLETE

**Goal**: Capture all parameters needed to exactly reproduce a slice retrieval result.

### 6.1 Embedding Model Reference

- [x] **6.1.1** Define `EmbeddingModelRef` struct
  - Owner: Agent
  - Input: Improvement doc, glossary
  - Output: `src/types/provenance.rs`
  - Validation: Contains model_id, version, dimensions, quantization, deterministic
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.1.2** Implement builder pattern methods
  - Owner: Agent
  - Input: `EmbeddingModelRef` struct
  - Output: `new()`, `with_quantization()`, `non_deterministic()` methods
  - Validation: Fluent API for construction
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.1.3** Implement `to_ref_string()` for unique identification
  - Owner: Agent
  - Input: Model reference
  - Output: Format: `model_id@version:dDIM:qQUANT`
  - Validation: Unique string per model configuration
  - Status: ✅ Complete
  - Confidence: High

### 6.2 Normalization Version

- [x] **6.2.1** Define `NormalizationVersion` struct
  - Owner: Agent
  - Input: Canonical content spec
  - Output: Struct in `provenance.rs`
  - Validation: Contains version, config_hash, features list
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.2.2** Implement `current()` factory
  - Owner: Agent
  - Input: `CANONICAL_CONTENT_VERSION` constant
  - Output: Returns current normalization version
  - Validation: References the actual version constant
  - Status: ✅ Complete
  - Confidence: High

### 6.3 Retrieval Parameters

- [x] **6.3.1** Define `RetrievalParams` struct
  - Owner: Agent
  - Input: RAG++ retrieval API
  - Output: Struct in `provenance.rs`
  - Validation: Contains k, threshold, reranking, max_tokens, policy_version
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.3.2** Implement builder methods
  - Owner: Agent
  - Input: `RetrievalParams` struct
  - Output: `new()`, `with_reranking()`, `with_max_tokens()`, `with_policy_params_hash()`
  - Validation: Fluent API for construction
  - Status: ✅ Complete
  - Confidence: High

### 6.4 Replay Provenance

- [x] **6.4.1** Define `ReplayProvenance` struct
  - Owner: Agent
  - Input: All provenance components
  - Output: Complete provenance type
  - Validation: Contains timestamp, embedding_model, normalization, retrieval_params, graph_snapshot, slice_fingerprint
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.4.2** Implement `is_complete()` validation
  - Owner: Agent
  - Input: `ReplayProvenance` struct
  - Output: `fn is_complete(&self) -> bool`
  - Validation: Checks all required fields are present
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.4.3** Implement `fingerprint()` for comparison
  - Owner: Agent
  - Input: Provenance fields
  - Output: xxh64 hash of canonical provenance string
  - Validation: Deterministic fingerprint
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.4.4** Implement `is_replay_compatible()` comparison
  - Owner: Agent
  - Input: Two provenances
  - Output: `fn is_replay_compatible(&self, other: &Self) -> bool`
  - Validation: Returns true if replay would produce same slice
  - Status: ✅ Complete
  - Confidence: High

### 6.5 Provenance Builder

- [x] **6.5.1** Define `ProvenanceBuilder` struct
  - Owner: Agent
  - Input: `ReplayProvenance` requirements
  - Output: Builder in `provenance.rs`
  - Validation: Optional fields with required field enforcement
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.5.2** Implement builder methods
  - Owner: Agent
  - Input: Builder struct
  - Output: All setter methods + `build()`
  - Validation: `build()` returns `Result<ReplayProvenance, ProvenanceError>`
  - Status: ✅ Complete
  - Confidence: High

### 6.6 Testing

- [x] **6.6.1** Unit tests for embedding model ref (1 test)
  - Owner: Agent
  - Input: `EmbeddingModelRef` implementation
  - Output: Tests in `provenance.rs`
  - Validation: Tests construction and ref_string
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.6.2** Unit tests for normalization version (1 test)
  - Owner: Agent
  - Input: `NormalizationVersion` implementation
  - Output: Tests `current()` returns expected values
  - Validation: Version and features match constants
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.6.3** Unit tests for retrieval params (1 test)
  - Owner: Agent
  - Input: `RetrievalParams` implementation
  - Output: Tests builder pattern
  - Validation: All fields set correctly
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.6.4** Unit tests for provenance builder (2 tests)
  - Owner: Agent
  - Input: `ProvenanceBuilder` implementation
  - Output: Tests for success and missing field error
  - Validation: Builder enforces required fields
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.6.5** Unit tests for fingerprint determinism (1 test)
  - Owner: Agent
  - Input: `fingerprint()` method
  - Output: Test that same inputs → same fingerprint
  - Validation: Determinism verified
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.6.6** Unit tests for replay compatibility (1 test)
  - Owner: Agent
  - Input: `is_replay_compatible()` method
  - Output: Tests same vs different provenances
  - Validation: Correctly identifies compatible provenances
  - Status: ✅ Complete
  - Confidence: High

### 6.7 Integration

- [x] **6.7.1** Add module to `types/mod.rs`
  - Owner: Agent
  - Input: `provenance.rs`
  - Output: `pub mod provenance;` + re-exports
  - Validation: Module accessible from `types::`
  - Status: ✅ Complete
  - Confidence: High

- [x] **6.7.2** Add re-exports to `lib.rs`
  - Owner: Agent
  - Input: Provenance types
  - Output: `pub use types::provenance::*`
  - Validation: Types accessible from crate root
  - Status: ✅ Complete
  - Confidence: High

---

## Phase 7: Incident Response Infrastructure (Priority 7) ✅ COMPLETE

**Goal**: Production-grade metrics, alerting, and quarantine for security violations.

### 7.1 Severity and Incident Types

- [x] **7.1.1** Define `Severity` enum
  - Owner: Agent
  - Input: Security requirements
  - Output: `src/types/incident.rs`
  - Validation: Critical (15min), High (1hr), Medium (4hr), Low (1day) with response times
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.1.2** Define `IncidentType` enum
  - Owner: Agent
  - Input: Invariants ledger (INV-GK-001 through INV-GK-008)
  - Output: Enum variants for each invariant violation
  - Validation: 8 variants mapping to all invariants
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.1.3** Implement `severity()` method on `IncidentType`
  - Owner: Agent
  - Input: `IncidentType` enum
  - Output: `fn severity(&self) -> Severity`
  - Validation: Maps each incident type to appropriate severity
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.1.4** Implement `invariant()` method on `IncidentType`
  - Owner: Agent
  - Input: `IncidentType` enum
  - Output: `fn invariant(&self) -> &'static str`
  - Validation: Returns invariant ID (e.g., "INV-GK-001")
  - Status: ✅ Complete
  - Confidence: High

### 7.2 Incident Struct

- [x] **7.2.1** Define `Incident` struct
  - Owner: Agent
  - Input: Security requirements
  - Output: Struct in `incident.rs`
  - Validation: Contains id, timestamp, incident_type, severity, context, acknowledged
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.2.2** Implement `new()` and type-specific constructors
  - Owner: Agent
  - Input: `Incident` struct
  - Output: `new()`, `slice_boundary_violation()`, `token_verification_failure()`, etc.
  - Validation: Factory methods for each incident type
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.2.3** Implement `acknowledge()` method
  - Owner: Agent
  - Input: `Incident` struct
  - Output: `fn acknowledge(&mut self, by: &str)`
  - Validation: Sets acknowledged_at and acknowledged_by
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.2.4** Implement `alert()` method
  - Owner: Agent
  - Input: `Incident` struct
  - Output: `fn alert(&self)` using tracing
  - Validation: Logs with appropriate level based on severity
  - Status: ✅ Complete
  - Confidence: High

### 7.3 Quarantine System

- [x] **7.3.1** Define `QuarantinedToken` struct
  - Owner: Agent
  - Input: Security requirements
  - Output: Struct in `incident.rs`
  - Validation: Contains slice_fingerprint, token, reason, incident_id, timestamps
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.3.2** Implement `new()` constructor
  - Owner: Agent
  - Input: `QuarantinedToken` struct
  - Output: Constructor with required fields
  - Validation: Sets quarantined_at timestamp
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.3.3** Implement `review()` method
  - Owner: Agent
  - Input: `QuarantinedToken` struct
  - Output: `fn review(&mut self, by: &str, approved: bool)`
  - Validation: Sets reviewed_at, reviewed_by, approved
  - Status: ✅ Complete
  - Confidence: High

### 7.4 SQL Schemas

- [x] **7.4.1** Define `QUARANTINE_TABLE_SCHEMA` constant
  - Owner: Agent
  - Input: `QuarantinedToken` struct
  - Output: SQL CREATE TABLE statement
  - Validation: All fields mapped to appropriate SQL types
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.4.2** Define `INCIDENT_TABLE_SCHEMA` constant
  - Owner: Agent
  - Input: `Incident` struct
  - Output: SQL CREATE TABLE statement
  - Validation: Includes indexes for common queries
  - Status: ✅ Complete
  - Confidence: High

### 7.5 Metrics Interface

- [x] **7.5.1** Define `IncidentMetrics` trait
  - Owner: Agent
  - Input: Prometheus metrics conventions
  - Output: Trait in `incident.rs`
  - Validation: Methods for `record_incident()`, `record_quarantine()`
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.5.2** Implement `NoOpMetrics` default
  - Owner: Agent
  - Input: `IncidentMetrics` trait
  - Output: No-op implementation
  - Validation: Compiles, does nothing
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.5.3** Implement `TestMetrics` for testing
  - Owner: Agent
  - Input: `IncidentMetrics` trait
  - Output: Test implementation with counters
  - Validation: Tracks call counts for verification
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.5.4** Define Prometheus metric name constants
  - Owner: Agent
  - Input: Prometheus naming conventions
  - Output: Constants in `incident.rs`
  - Validation: Names follow `graph_kernel_*` pattern
  - Status: ✅ Complete
  - Confidence: High

### 7.6 Testing

- [x] **7.6.1** Unit tests for severity (1 test)
  - Owner: Agent
  - Input: `Severity` enum
  - Output: Tests response time mapping
  - Validation: Each severity has correct response time
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.6.2** Unit tests for incident type (2 tests)
  - Owner: Agent
  - Input: `IncidentType` enum
  - Output: Tests for severity and invariant mapping
  - Validation: Correct mappings for all variants
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.6.3** Unit tests for incident (2 tests)
  - Owner: Agent
  - Input: `Incident` struct
  - Output: Tests for creation and acknowledgment
  - Validation: Timestamps set correctly
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.6.4** Unit tests for quarantine (2 tests)
  - Owner: Agent
  - Input: `QuarantinedToken` struct
  - Output: Tests for creation and review
  - Validation: Review sets all fields correctly
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.6.5** Unit tests for metrics (2 tests)
  - Owner: Agent
  - Input: `IncidentMetrics` implementations
  - Output: Tests for metric names and TestMetrics
  - Validation: Names correct, TestMetrics tracks calls
  - Status: ✅ Complete
  - Confidence: High

### 7.7 Integration

- [x] **7.7.1** Add module to `types/mod.rs`
  - Owner: Agent
  - Input: `incident.rs`
  - Output: `pub mod incident;` + re-exports
  - Validation: Module accessible from `types::`
  - Status: ✅ Complete
  - Confidence: High

- [x] **7.7.2** Add re-exports to `lib.rs`
  - Owner: Agent
  - Input: Incident types
  - Output: `pub use types::incident::*`
  - Validation: Types accessible from crate root
  - Status: ✅ Complete
  - Confidence: High

---

## Blocking Issues

**None currently**

---

## Phase 8: Last Mile Integration ✅ COMPLETE

**Goal**: Wire security primitives into the hot path—API boundary enforcement, content hash verification, performance benchmarks.

### 8.1 API Boundary Enforcement (INV-GK-003)

- [x] **8.1.1** Change `ContextSlicer::slice()` to return `AdmissibleEvidenceBundle`
  - Owner: Agent
  - Input: `slicer.rs`, `AdmissibleEvidenceBundle`
  - Output: Modified `slice()` return type
  - Validation: Cannot get unverified slice from slicer
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.1.2** Update service routes for new return type
  - Owner: Agent
  - Input: `service/routes.rs`
  - Output: Handlers extract slice from bundle for serialization
  - Validation: Routes still return valid JSON responses
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.1.3** Update batch slicer for new return type
  - Owner: Agent
  - Input: `atlas/batch_slicer.rs`
  - Output: `slice_all()` handles bundles correctly
  - Validation: Atlas tests pass
  - Status: ✅ Complete
  - Confidence: High

### 8.2 Content Hash Verification (INV-GK-004)

- [x] **8.2.1** Add `verify_content_hash()` to `TurnSnapshot`
  - Owner: Agent
  - Input: `types/turn.rs`, `canonical_content.rs`
  - Output: Method that verifies content matches stored hash
  - Validation: Unit tests for valid, mismatch, and missing hash cases
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.2.2** Add `ContentHashError` type
  - Owner: Agent
  - Input: Error requirements
  - Output: Error enum with `Mismatch` variant
  - Validation: Error contains turn_id, stored hash, computed hash
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.2.3** Add `get_turn_with_verified_content()` to PostgresGraphStore
  - Owner: Agent
  - Input: `store/postgres.rs`
  - Output: Method that fetches turn + content and verifies hash
  - Validation: Returns error on mismatch, logs warning for legacy data
  - Status: ✅ Complete
  - Confidence: High

### 8.3 Performance Benchmarks (INV-GK-006)

- [x] **8.3.1** Add criterion benchmark infrastructure
  - Owner: Agent
  - Input: `Cargo.toml`
  - Output: criterion dev-dependency, bench target
  - Validation: `cargo bench` runs
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.3.2** Create verification benchmark
  - Owner: Agent
  - Input: `TokenVerifier` implementation
  - Output: `benches/verification.rs`
  - Validation: Benchmarks cold, cached, and concurrent verification
  - Status: ✅ Complete
  - Confidence: High

### 8.4 Test Updates

- [x] **8.4.1** Update golden tests for new return type
  - Owner: Agent
  - Input: `tests/golden.rs`
  - Output: Tests use `bundle.slice()` pattern
  - Validation: All 13 golden tests pass
  - Status: ✅ Complete
  - Confidence: High

- [x] **8.4.2** Update atlas integration tests
  - Owner: Agent
  - Input: `tests/atlas_integration.rs`
  - Output: Tests converted to async, use Arc wrapping
  - Validation: All 14 integration tests pass
  - Status: ✅ Complete
  - Confidence: High

---

## Completion Tracking

| Phase | Tasks | Completed | Deferred | Status |
|-------|-------|-----------|----------|--------|
| 0 | 5 | 5 | 0 | ✅ Complete |
| 1 | 10 | 10 | 0 | ✅ Complete |
| 2 | 9 | 8 | 1 | ✅ Complete (core) |
| 3 | 6 | 6 | 0 | ✅ Complete |
| 4 | 14 | 14 | 0 | ✅ Complete |
| 5 | 14 | 14 | 0 | ✅ Complete |
| 6 | 18 | 18 | 0 | ✅ Complete |
| 7 | 19 | 19 | 0 | ✅ Complete |
| 8 | 10 | 10 | 0 | ✅ Complete |

**Overall Progress**: 104/105 tasks (99% complete)

**Test Count**: 160 tests passing (131 unit + 14 integration + 13 golden + 2 doc)

**Database Status** (2026-01-03):
- `content_hash` column: ✅ Exists in `memory_turns`
- DB trigger: ✅ `content_hash_trigger` on INSERT/UPDATE
- Legacy backfill: ✅ 97,110 turns with hash (90.55% of 107,245 total)
- Empty content: 10,135 turns with `content_text = ''` → NULL hash (correct)

**Remaining Deferred Item**:
- 2.3.1: Add content hash to `TurnSnapshot::new` (low priority—DB trigger handles this)
