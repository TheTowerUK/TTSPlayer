# ADR-014: Catalogue Revision Cache Invalidation

**Status:** Accepted  
**Date:** 2026-07-14  
**Accepted:** 2026-07-14 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.5  
**Authors:** M4 documentation pass

---

## Context

TTSPlayer holds several **derived** in-memory structures from the loaded `Catalog`:

- `ArtworkService` candidate cache (sidecar / folder art resolution)
- `SearchService` flat search index (per Phase 4.5 elevation)
- `LibraryMetadataRepository` favourite id validation (already on replace)

[ADR-002](./ADR-002-provider-refresh-lifecycle.md) requires that failed catalogue refresh preserves last-good catalogue and **does not** clear artwork cache. Phase 4.5 adds search index rebuild and formalises a single invalidation contract so new caches do not each invent their own trigger.

`Catalog.catalogueIdentity` (`CatalogueInfo.id`) already identifies a catalogue file revision.

---

## Decision

1. **`catalogueIdentity` is the sole revision key** for derived caches. Compare identity before skipping rebuild.

2. **Invalidate only on successful catalogue replacement** in `CatalogService` — the same moment `onCatalogReplaced` fires today. Never on:
   - failed HTTP/local load
   - validation-only reads
   - navigation or settings save

3. **Mandatory invalidation side effects** on successful replacement:

   | Consumer | Action |
   |---|---|
   | `ArtworkService` | `clearCache()` (existing) |
   | `SearchService` | schedule full index rebuild for new identity |
   | `LibraryMetadataRepository` | `validateAgainstCatalog()` (existing) |

4. **Orchestration** lives at the app composition root (`main.dart` callback or a dedicated coordinator type). Individual services do not call each other directly.

5. **No disk-persisted catalogue or thumbnail cache** in Phase 4.5. Session caches only.

6. **Phase 4.6 diagnostics** may read cache entry counts and last rebuild timestamp — not part of 4.5 UI.

---

## Rationale

- Extends ADR-002 without changing provider refresh semantics users rely on.
- One revision key avoids stale search results after rescan while favourites still resolve.
- Central orchestration prevents duplicate hooks when a fourth cache appears later.

---

## Consequences

### Positive

- Predictable invalidation story for tests and runtime harness.
- Failed refresh keeps artwork and search usable against last-good catalogue.

### Negative

- Full search rebuild on every successful replace — acceptable for 4.5 scale targets; incremental index diff deferred.

### Neutral

- `catalog.json` schema unchanged; identity must remain stable per indexer contract.
- **Implementation (Step 2):** `CatalogCacheCoordinator` at composition root; `SearchService` app-scoped; synchronous invalidate + rebuild on replace.

---

## Implementation

Wired in M4 Phase 4.5 Step 2 (`main.dart`, `catalog_cache_coordinator.dart`). Regression tests in `catalog_cache_invalidation_test.dart`. Step 6 end-to-end lifecycle in `performance_integration_test.dart`.

---

## Alternatives considered

### Alternative A — Time-based or TTL cache expiry

**Rejected because:** Filesystem truth is rescan-driven; TTL would serve stale sidecars after NAS changes without catalogue reload.

### Alternative B — Invalidate on any refresh attempt

**Rejected because:** Violates ADR-002; user loses cached artwork during transient network failure.

### Alternative C — Disk-persisted catalogue snapshot

**Rejected because:** Out of M4 scope; migration and corruption surface too large for 4.5.

---

## Related documents

- [ADR-002: Provider Refresh Lifecycle](./ADR-002-provider-refresh-lifecycle.md)
- [caching.md](../caching.md)
- [M4 Phase 4.5 specification](../../roadmap/m4-phase-4.5-performance-caching.md)
