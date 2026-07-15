# ADR-016: Search Index and Large-Library Browsing

**Status:** Accepted — implemented (M4 Phase 4.5 Step 4)
**Date:** 2026-07-14
**Accepted:** 2026-07-14 (specification sign-off)
**Implemented:** 2026-07-15 (deferred index lifecycle)
**Milestone:** M4 Phase 4.5  
**Authors:** M4 documentation pass

---

## Context

Before Phase 4.5 Step 4, `SearchService` was app-scoped (Step 2) but still built its flat index eagerly:

- `SearchScreen.build()` called `buildIndex()` on every rebuild — opening Search triggered a full index build even with no query.
- `CatalogCacheCoordinator` called `onCatalogReplaced()`, which invalidated and **immediately rebuilt** the index on every successful catalogue replacement.
- Large catalogues could block the UI on search open or rescan before the user typed a query.

Folder browse already uses lazy `SliverChildBuilderDelegate` grids; the bottleneck is search index build timing, not folder grid structure.

---

## Decision

1. **Keep `SearchService` app-scoped** — single instance via `Provider` at the composition root (`main.dart`). One shared index eliminates duplicate builds across navigation and wires cleanly to ADR-014 invalidation.

2. **Defer index construction until first qualifying search** — creating the service, wiring it at startup, opening Search without a query, and successful catalogue replacement must **not** perform a full index build.

3. **Catalogue identity contract** — the index is valid only when `_catalogueIdentity == catalog.catalogueIdentity`, where `catalogueIdentity` is `Catalog.catalogueIdentity` (`CatalogueInfo.id`, or `legacy:{generatedAt}` for pre-v2 files). Object identity, list length, or mutable collection references are **not** used for freshness.

4. **Invalidation vs rebuild** — `onCatalogReplaced(Catalog)` (from `CatalogCacheCoordinator` only) calls `invalidateIndex()` and does **not** rebuild. The next `searchCatalog()` for the active catalogue builds once. Failed catalogue refresh does not invoke the coordinator; the last-good index remains valid.

5. **Caller API** — presentation code calls `searchCatalog(catalog, query, filters)`. The service validates identity, ensures the index (build or reuse), prevents duplicate concurrent builds, and executes the query. Widgets do not orchestrate invalidate/build/search manually.

6. **Concurrency** — overlapping first-use searches for the same identity share one in-flight `Future`. Builds capture an invalidation generation; a replacement during an in-flight build does not commit a stale index. Failed builds clear in-flight state and propagate `SearchIndexBuildException` for retry.

7. **Search engine unchanged** — token match, scoring, filters, `maxResults = 100`. No pagination UI in 4.5.

8. **Filter chip metadata** — `libraryNamesFor(catalog)` and `extensionsFor(catalog)` derive from the live `Catalog` when no index exists; after build they reuse indexed metadata.

9. **Large-folder browse** — retain `CustomScrollView` + sliver grids. Phase 4.5 may tune `cacheExtent` and `RepaintBoundary` where profiling warrants. No virtual merged libraries.

---

## Rationale

- Shared service eliminates duplicate index builds and wires cleanly to ADR-014 invalidation.
- Deferred build keeps startup and dashboard paths free of unnecessary O(n) work until the user searches.
- Preserves Phase 4.3 search presentation investment.

---

## Consequences

### Positive

- Application startup and Search open without a query avoid full index construction.
- Tests assert `indexBuildCount`, `hasIndex`, and `isBuildInFlight` deterministically.
- Catalogue replacement invalidates without blocking rescan completion on index rebuild.

### Negative

- First search after open or replacement may show brief latency while the index builds (async `ensureIndex`).
- Shared mutable service requires generation guards for in-flight builds.

### Neutral

- Full index rebuild on each new identity remains O(n); incremental diff deferred beyond 4.5.
- Index build remains synchronous work yielded via `Future.delayed(Duration.zero)` — no isolates in Step 4.

---

## Known limitations

- No background isolate for index construction; very large catalogues may still block briefly on first search.
- No incremental index diff across rescans.
- Filter chips use catalogue-derived metadata before first search; indexed metadata after first build.
- No persistent search history or pagination.

---

## Alternatives considered

### Alternative A — Eager startup or replacement rebuild

**Rejected because:** Adds unnecessary O(n) work to startup and every successful rescan before the user searches.

### Alternative B — Per-screen `SearchService` instances

**Rejected because:** Duplicates index builds, breaks ADR-014 single invalidation path, and was explicitly removed in Step 2.

### Alternative C — SQLite full-text index

**Rejected because:** Explicitly out of M4 scope; large migration.

### Alternative D — On-demand per-query scan without index

**Rejected because:** O(n) per keystroke worse than O(n) once per revision.

### Alternative E — Pagination UI with partial index

**Rejected because:** Product scope is performance, not search feature expansion.

---

## Related documents

- [ADR-014: Catalogue Revision Cache Invalidation](./ADR-014-catalogue-revision-cache-invalidation.md)
- [library.md](../library.md)
- [caching.md](../caching.md)
- [M4 Phase 4.5 specification](../../roadmap/m4-phase-4.5-performance-caching.md)
