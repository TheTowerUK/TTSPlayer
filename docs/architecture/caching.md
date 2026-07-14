# Caching and Performance (M4 Phase 4.5 — planning)

**Status:** Specification **accepted** — implementation not started (2026-07-14)  
**Related roadmap phase:** [M4 Phase 4.5 — Performance and Caching](../roadmap/m4-phase-4.5-performance-caching.md)

→ [Provider refresh lifecycle](./decisions/ADR-002-provider-refresh-lifecycle.md)  
→ [Library experience (4.3)](./library.md)  
→ [Diagnostics (4.6)](./diagnostics.md)  
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)

**ADRs (Accepted 2026-07-14; pre-implementation):**

- [ADR-014: Catalogue Revision Cache Invalidation](./decisions/ADR-014-catalogue-revision-cache-invalidation.md)
- [ADR-015: Artwork and Image Decode Caching](./decisions/ADR-015-artwork-and-image-decode-caching.md)
- [ADR-016: Search Index and Large-Library Browsing](./decisions/ADR-016-search-index-and-large-library-browsing.md)

---

## Purpose

Keep large libraries responsive on desktop through **deliberate in-memory caching**, **bounded memory**, **deferred work off the critical startup path**, and **lazy UI rendering** — without introducing SQLite, background indexer daemons, disk thumbnail stores, or catalogue schema changes.

Phase 4.5 refines performance characteristics of existing M3–M4.4 surfaces. It does not add new user-facing features.

---

## Architectural principles

### Catalogue revision is the invalidation anchor

All catalogue-derived caches key off `Catalog.catalogueIdentity` ([`CatalogueInfo.id`](../roadmap/m4-phase-4.5-baseline-audit.md)). When identity changes after a **successful** catalogue replacement, derived caches invalidate. Failed refresh attempts must not invalidate ([ADR-002](./decisions/ADR-002-provider-refresh-lifecycle.md), [ADR-014](./decisions/ADR-014-catalogue-revision-cache-invalidation.md)).

### Three cache domains (4.5)

| Domain | Owner | Lifetime | Invalidation |
|---|---|---|---|
| **Catalogue runtime** | `CatalogService` | Session; last-good on failure | Replace on successful load only |
| **Artwork candidates** | `ArtworkService` | Session; bounded LRU | Clear on catalogue revision |
| **Search index** | `SearchService` (elevated) | Session; per revision | Rebuild on catalogue revision |
| **Image decode** | Flutter `ImageCache` + widget sizing | Session; bounded bytes | Flutter eviction + revision clears candidate paths |

Playback progress, settings, and library metadata are **not** catalogue-derived caches and follow their existing lifecycles.

### Performance work stays off the UI thread where practical

- Catalogue JSON parse remains synchronous today; 4.5 documents baseline and avoids regression.
- Search index build for large catalogues moves to **deferred/background** work ([ADR-016](./decisions/ADR-016-search-index-and-large-library-browsing.md)).
- Filesystem existence probes for artwork may batch or defer; must not block first dashboard paint.

### Lazy rendering is already partial — extend, do not rewrite

`FolderScreen` uses `CustomScrollView` + `SliverChildBuilderDelegate` — child widgets build on demand. Phase 4.5 verifies this remains true under large folders and tunes scroll/cache behaviour; it does not replace folder-first layout or derived sort/filter views.

---

## Current baseline (pre-4.5)

| Area | Today | Risk at scale |
|---|---|---|
| `ArtworkService._cache` | Unbounded `Map`; sync `existsSync` on miss | Memory growth; UI jank on cold grid scroll |
| `ArtworkImage` | `Image.file` / `Image.network` at full resolution | Decode memory spikes |
| `SearchService` | Per-`SearchScreen` instance; full index on first open | Repeated builds; search open blocks on large catalogues |
| `onCatalogReplaced` | Artwork clear + favourites validate | Search index not wired |
| Folder grids | Lazy sliver delegates | Derived `view.items` list materialized per folder (acceptable) |
| Catalogue load | Full in-memory tree | Expected; document parse time |
| Disk persistence | None for catalogue or thumbnails | In scope for 4.5 only as **documented non-goal** |

---

## Target architecture (4.5)

### Invalidation orchestration

`main.dart` (or a thin coordinator) composes catalogue-replacement side effects:

```
CatalogService.replace success
    → ArtworkService.clearCache()
    → SearchService.scheduleRebuild(catalog)   // new
    → LibraryMetadataRepository.validateAgainstCatalog()  // existing
```

Failed loads do not invoke this chain.

### Artwork ([ADR-015](./decisions/ADR-015-artwork-and-image-decode-caching.md))

- Bounded LRU for artwork **candidate** resolution (path discovery results).
- `ArtworkImage` passes decode constraints (`cacheWidth` / `cacheHeight`) derived from layout.
- Desktop `ImageCache.maximumSizeBytes` budget applied at app start.
- Placeholder path remains synchronous; failed loads use `errorBuilder`.

### Search ([ADR-016](./decisions/ADR-016-search-index-and-large-library-browsing.md))

- `SearchService` registered at app root via `Provider`.
- Index rebuild scheduled after catalogue replacement; dashboard not blocked.
- `SearchScreen` consumes shared service; shows indexing state when rebuild in flight.
- Search **engine** (scoring, filters, max 100 results) unchanged.

### Large-folder browse

- Retain `SliverChildBuilderDelegate` grids.
- Tune `cacheExtent` / repaint boundaries where profiling shows benefit.
- No virtualized cross-folder aggregation (filesystem-is-truth).

---

## Boundaries

### In scope

- In-memory bounds and invalidation contracts
- Deferred search index build
- Artwork probe and decode efficiency
- Startup and scroll performance baselines + regression gates
- Phase 4.6 **cache health** hooks (counts only — full panel remains 4.6)

### Out of scope

- SQLite or on-disk catalogue store
- Background indexer daemon or auto-rescan
- CDN / edge caching
- Thumbnail generation or NAS-side transcoding
- Search engine rewrite, pagination UI, or persisted search history
- Scroll position restoration (optional post-4.5)

---

## Validation relationship

| Layer | Role |
|---|---|
| **Step 0 baseline audit** | Capture measurable before-state |
| **Unit / integration tests** | Invalidation, bounds, deferred index, no regression on demo catalogue |
| **Micro-benchmarks** | Parse and index build on synthetic large fixture (test-only) |
| **Phase 4.5 Windows runtime harness** | Scroll smoke, search open while indexing, refresh invalidation |
| **Manual desktop QA** | Subjective 60fps scroll on real large NAS folder |

Gate 0-style capability audit is **not** required — APIs are Flutter/Dart standard library.

---

## Related documents

- [Phase 4.5 specification](../roadmap/m4-phase-4.5-performance-caching.md)
- [Phase 4.5 baseline audit](../roadmap/m4-phase-4.5-baseline-audit.md)
- [M4 plan](../roadmap/m4-plan.md)
