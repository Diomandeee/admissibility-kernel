//! Graph storage backends.

pub mod memory;

#[cfg(feature = "postgres")]
pub mod postgres;

use async_trait::async_trait;
use crate::types::{TurnId, TurnSnapshot, Edge};

/// Trait for graph storage backends.
///
/// Implementations must guarantee deterministic ordering of results.
/// All methods are async to support async database access.
#[async_trait]
pub trait GraphStore: Send + Sync {
    /// Error type for store operations.
    type Error: std::error::Error + Send + Sync;

    /// Fetch a turn by ID.
    async fn get_turn(&self, id: &TurnId) -> Result<Option<TurnSnapshot>, Self::Error>;

    /// Fetch multiple turns by ID.
    async fn get_turns(&self, ids: &[TurnId]) -> Result<Vec<TurnSnapshot>, Self::Error>;

    /// Fetch parent turn IDs (ordered by TurnId for determinism).
    async fn get_parents(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;

    /// Fetch child turn IDs (ordered by TurnId for determinism).
    async fn get_children(&self, id: &TurnId) -> Result<Vec<TurnId>, Self::Error>;

    /// Fetch sibling turn IDs (same parent, ordered by salience desc then TurnId).
    async fn get_siblings(&self, id: &TurnId, limit: usize) -> Result<Vec<TurnId>, Self::Error>;

    /// Fetch edges between a set of turns.
    async fn get_edges(&self, turn_ids: &[TurnId]) -> Result<Vec<Edge>, Self::Error>;
}

pub use memory::InMemoryGraphStore;

#[cfg(feature = "postgres")]
pub use postgres::PostgresGraphStore;

