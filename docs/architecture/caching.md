# Caching and Performance (M4 Phase 4.5 — planning)

**Status:** **In progress** — Steps 2–7 implemented (2026-07-16)
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
| **Artwork candidates** | `ArtworkService` | Session; bounded LRU (**500**) | Clear on catalogue revision |
| **Search index** | `SearchService` (app-scoped) | Session; per revision; **deferred build** (Step 4 ✅) |
| **Image decode** | Flutter `ImageCache` + `ArtworkImage` | Session; **100 MB** budget | Flutter eviction; decode sized per surface |

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
| `ArtworkService._cache` | **LRU 500** entries; sync `existsSync` on miss | Bounded; re-probe after eviction |
| `ArtworkImage` | `cacheWidth` / `cacheHeight` from `logicalDecodeSize` | Decode memory bounded per surface |
| Flutter `ImageCache` | **100 MB** budget at startup | Separate from candidate cache |
| `SearchService` | App-scoped `Provider`; shared across screens | Step 2 ✅ |
| `onCatalogReplaced` | `CatalogCacheCoordinator` — artwork, search, favourites | Step 2 ✅ |
| Folder grids | Lazy sliver delegates | Derived `view.items` list materialized per folder (acceptable) |
| Catalogue load | Full in-memory tree | Expected; document parse time |
| Disk persistence | None for catalogue or thumbnails | In scope for 4.5 only as **documented non-goal** |

---

## Target architecture (4.5)

### Invalidation orchestration (Step 2 — implemented)

`CatalogCacheCoordinator` at the app composition root (`main.dart`):

```
CatalogService successful replacement
    → CatalogCacheCoordinator.onCatalogReplaced(catalog)
        → ArtworkService.clearCache()
        → SearchService.onCatalogReplaced(catalog)  // invalidate only; rebuild on first search
        → LibraryMetadataRepository.validateAgainstCatalog()  // async
```

Failed loads do not invoke this chain ([ADR-002](./decisions/ADR-002-provider-refresh-lifecycle.md), [ADR-014](./decisions/ADR-014-catalogue-revision-cache-invalidation.md)).

### Artwork ([ADR-015](./decisions/ADR-015-artwork-and-image-decode-caching.md)) — Step 3 implemented

- `LruCache` in `ArtworkService` — default **500** entries; keys `library:`, `folder:`, `media:` + entity id.
- `ArtworkImage.logicalDecodeSize` → physical decode pixels via device pixel ratio.
- `configureArtworkFlutterImageCache()` — **100 MB** Flutter `ImageCache` budget.
- Placeholder and `errorBuilder` paths unchanged.

### Large-folder browse — Step 5 implemented

- `FolderScreen` retains lazy `SliverChildBuilderDelegate` grids.
- `scrollCacheExtent: ScrollCacheExtent.pixels(400)` on folder `CustomScrollView`.
- Per-card `RepaintBoundary`, stable `ValueKey`s, `PageStorageKey` per folder id.
- `FolderPresentationMetrics` — test-only build and view-prep counters.
- `buildLargeCatalog()` factory for in-memory stress fixtures (not shipped).
- `SearchPresentationMetrics` — test-only flatten counter (Step 6).
- Search results list pre-flattens grouped rows (no per-index O(n) scan).

### Step 6 — integration and benchmarks (implemented)

| Layer | Role |
|---|---|
| `performance_integration_test.dart` | End-to-end lifecycle: catalogue replace, LRU, search, failure paths |
| `performance_microbenchmarks_test.dart` | Opt-in `PHASE_45_BENCHMARK=1`; informational `Stopwatch` timings |
| `large_catalog_factory.dart` | Small 100 / medium 2000 / large 10000 in-memory fixtures |

**Deterministic gates:** coordinator callback counts, `indexBuildCount`, `cacheEntryCount` ≤ 500, lazy folder build inequalities, flatten-once-per-build.

**Informational only:** micro-benchmark min/median/max printed to stdout; not pass/fail.

```powershell
$env:PHASE_45_BENCHMARK='1'
flutter test test/performance_microbenchmarks_test.dart
```

### Step 7 — Windows runtime validation (implemented)

Opt-in `PHASE_45_RUNTIME=1` on Windows exercises R1–R38: lazy folder open, scroll, sort/filter, navigation, resize, search lifecycle, catalogue replace/fail, LRU bounds, recovery paths. Optional `PHASE_45_LOCAL_CATALOG` for live catalogue smoke.

Runtime timings and baseline metrics are **informational only** — printed via `Phase45RuntimeBaseline` at suite end.

```powershell
$env:PHASE_45_RUNTIME='1'
flutter test test/phase_45_windows_runtime_test.dart
```

### Search ([ADR-016](./decisions/ADR-016-search-index-and-large-library-browsing.md)) — Step 4 implemented

- Shared `SearchService` registered at app root via `Provider`.
- Index build **deferred** until first qualifying `searchCatalog()` call.
- `onCatalogReplaced` invalidates only; does not eagerly rebuild.
- `searchCatalog(catalog, query, filters)` ensures index, handles concurrency, executes query.
- Filter chips use `libraryNamesFor` / `extensionsFor` from `Catalog` before first build.
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
| **Unit / integration tests** | Invalidation, bounds, deferred index, lifecycle integration (Step 6) |
| **Micro-benchmarks** | Opt-in `PHASE_45_BENCHMARK=1`; informational timings on 100/2000/10000 fixtures |
| **Phase 4.5 Windows runtime harness** | Scroll, search, replace smoke; `PHASE_45_RUNTIME=1` (Step 7 ✅) |
| **Manual desktop QA** | Subjective 60fps scroll on real large NAS folder |

Gate 0-style capability audit is **not** required — APIs are Flutter/Dart standard library.

---

## Related documents

- [Phase 4.5 specification](../roadmap/m4-phase-4.5-performance-caching.md)
- [Phase 4.5 baseline audit](../roadmap/m4-phase-4.5-baseline-audit.md)
- [M4 plan](../roadmap/m4-plan.md)
