//! Graph Kernel REST Service
//!
//! Exposes the Graph Kernel as a REST API for slice-conditioned retrieval.
//!
//! ## Endpoints
//!
//! - `POST /api/slice` - Construct a context slice around an anchor
//! - `POST /api/slice/batch` - Batch slice construction
//! - `POST /api/verify_token` - Verify an admissibility token
//! - `GET /api/policies` - List registered policies
//! - `POST /api/policies` - Register a new policy
//! - `GET /health` - Detailed service health check
//! - `GET /health/live` - Liveness probe
//! - `GET /health/ready` - Readiness probe
//! - `GET /health/startup` - Startup probe

pub mod middleware;
pub mod routes;
pub mod state;

pub use middleware::{metrics_middleware, record_slice_metrics, record_token_verification};
pub use routes::{create_router, AppState};
pub use state::{ServiceState, PolicyRegistry, PolicyRef};

