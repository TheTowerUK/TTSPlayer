# ADR-016: Search Index and Large-Library Browsing

**Status:** Accepted  
**Date:** 2026-07-14  
**Accepted:** 2026-07-14 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.5  
**Authors:** M4 documentation pass

---

## Context

`SearchService` today:

- Lives inside `SearchScreen` (new instance per route)
- Builds a full flat index over `catalog.allItems` synchronously on first `buildIndex`
- Skips rebuild when `catalogueIdentity` matches and index non-empty

Large catalogues block the UI on first search open. Catalogue replacement does not rebuild a shared index because no shared service exists. Folder browse already uses lazy `SliverChildBuilderDelegate` grids; the bottleneck is search index build and dashboard-adjacent eager work, not folder grid structure.

Phase 4.3 explicitly deferred pagination and index performance to 4.5.

---

## Decision

1. **Elevate `SearchService` to app scope** — provide via `Provider` at root (same lifetime as `CatalogService`).

2. **Index rebuild on catalogue revision** per [ADR-014](./ADR-014-catalogue-revision-cache-invalidation.md):
   - Schedule after successful replacement
   - Do not block dashboard first paint
   - Use deferred execution (`scheduleMicrotask`, `Future.microtask`, or `compute` for large catalogues — implementation choice)

3. **Search engine unchanged** — token match, scoring, filters, `maxResults = 100`. No pagination UI in 4.5.

4. **`SearchScreen` behaviour:**
   - Uses injected shared `SearchService`
   - If index rebuild in progress, show non-blocking status (spinner or “Indexing…”) and allow query when ready
   - Empty query / filters unchanged

5. **Large-folder browse** — retain `CustomScrollView` + sliver grids. Phase 4.5 may tune `cacheExtent` and add `RepaintBoundary` on card widgets if profiling warrants. **No** virtual library or cross-folder merged grids.

6. **Synthetic large-catalogue fixture** for tests — generated or committed JSON under `test/fixtures/` or `assets/mock_data/` (test-only) to benchmark parse and index targets. Not shipped as default app catalogue.

---

## Rationale

- Shared service eliminates duplicate index builds and wires cleanly to ADR-014 invalidation.
- Deferred build keeps startup path aligned with “media first” — user can browse folders before index completes.
- Preserves 4.3 search presentation investment.

---

## Consequences

### Positive

- Search open no longer the only index build trigger.
- Tests can assert index state across navigation.

### Negative

- Shared mutable service requires careful `notifyListeners` / status surfacing if index build is async.

### Neutral

- Full index rebuild on each rescan remains O(n); incremental diff deferred beyond 4.5.

---

## Alternatives considered

### Alternative A — SQLite full-text index

**Rejected because:** Explicitly out of M4 scope; large migration.

### Alternative B — On-demand per-query scan without index

**Rejected because:** O(n) per keystroke worse than O(n) once per revision.

### Alternative C — Pagination UI with partial index

**Rejected because:** Product scope is performance, not search feature expansion.

---

## Related documents

- [ADR-014: Catalogue Revision Cache Invalidation](./ADR-014-catalogue-revision-cache-invalidation.md)
- [library.md](../library.md)
- [caching.md](../caching.md)
- [M4 Phase 4.5 specification](../../roadmap/m4-phase-4.5-performance-caching.md)
