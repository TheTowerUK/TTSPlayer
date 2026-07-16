# M4 Phase 4.5 — Performance and Caching (Implementation Specification)

**Status:** **In progress** — Step 7 complete (2026-07-16); Step 8 closure next
**Milestone:** M4 — User Experience and Platform Integration  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Predecessor:** M4 Phase 4.4 complete — closure `52d0a35`  
**Implementation baseline:** Step 0 audit complete; ADR-014–016 accepted

→ [M4 plan](./m4-plan.md#phase-45--performance-and-caching)  
→ [Caching architecture](../architecture/caching.md)  
→ [Baseline audit (Step 0)](./m4-phase-4.5-baseline-audit.md)  
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs (Accepted 2026-07-14):**

- [ADR-014: Catalogue Revision Cache Invalidation](../architecture/decisions/ADR-014-catalogue-revision-cache-invalidation.md)
- [ADR-015: Artwork and Image Decode Caching](../architecture/decisions/ADR-015-artwork-and-image-decode-caching.md)
- [ADR-016: Search Index and Large-Library Browsing](../architecture/decisions/ADR-016-search-index-and-large-library-browsing.md)

Follow the established M4 cadence: **baseline audit → ADRs → cache architecture → implementation → benchmarks → Windows validation → closure**.

---

## Objective

Keep **large libraries responsive** on Windows desktop through deliberate in-memory caching, bounded memory, deferred search indexing, and efficient artwork decode — without SQLite, disk thumbnail stores, background daemons, or catalogue schema changes.

Phase 4.5 is **performance and caching only**. No new browse features, search pagination, or diagnostics UI (cache health detail remains Phase 4.6).

---

## Architectural principles

### Filesystem and catalogue truth unchanged

- `catalog.json` remains the authoritative library structure.
- Immutable in-memory `Catalog` discipline from 4.3 is preserved.
- Sort/filter/favourites/search presentation semantics unchanged.

### Invalidation follows successful replacement only

Extends [ADR-002](../architecture/decisions/ADR-002-provider-refresh-lifecycle.md) via [ADR-014](../architecture/decisions/ADR-014-catalogue-revision-cache-invalidation.md). Failed refresh must not clear artwork, search index, or mislead the user with empty browse state.

### Measure before and after

Step 0 captures inventory; Steps 6–7 record numbers. Targets below are **acceptance thresholds**, not marketing claims.

---

## Phase steps

| Step | Name | Status |
|---|---|---|
| **0** | Performance baseline audit | ✅ Complete — [audit](./m4-phase-4.5-baseline-audit.md) |
| **1** | Specification + ADRs | ✅ This document + ADR-014–016 |
| **2** | Cache invalidation orchestration | ✅ Complete — `CatalogCacheCoordinator`, app-scoped `SearchService` |
| **3** | Artwork candidate bounds + image decode | ✅ Complete — LRU 500, decode hints, ImageCache budget |
| **4** | Search index lifecycle + startup deferral | ✅ Complete — deferred build, identity guard, concurrency |
| **5** | Large-folder scroll tuning + memory hooks | ✅ Complete — lazy grids tuned, metrics, fixture |
| **6** | Integration tests + micro-benchmarks | ✅ Complete — lifecycle integration + opt-in benchmarks |
| **7** | Windows runtime validation | ✅ Complete — R1–R38 matrix, baseline capture |
| **8** | Closure | **Next** |

**Suggested commit cadence:** invalidation wiring → artwork → search → scroll tuning → tests/benchmarks → harness → docs closure.

---

## Current baseline

*Shipped in M3–M4.4 — do not rebuild.*

| Capability | Location | State |
|---|---|---|
| Catalogue load | `CatalogService` | Bundled / local / HTTP; last-good on failure |
| Artwork resolution | `ArtworkService` | Thumbnail → sidecar → folder art → placeholder; **LRU 500** |
| Artwork decode | `ArtworkImage` | `cacheWidth` / `cacheHeight` from logical surface size |
| Artwork invalidation | `CatalogCacheCoordinator` | `clearCache()` on successful replace |
| Search engine | `SearchService` (app-scoped) | In-memory index; scoring unchanged |
| Search UI | `SearchScreen` | Shared `SearchService` via `Provider` |
| Folder grids | `FolderScreen` | `SliverChildBuilderDelegate` — lazy children |
| Provider refresh | Phase 4.1 | ADR-002 lifecycle |
| Library metadata | `LibraryMetadataRepository` | Validates on catalogue replace |

**Tests today:** `catalog_cache_invalidation_test.dart`, `lru_cache_test.dart`, `artwork_service_lru_test.dart`, `artwork_decode_size_test.dart`, `artwork_image_test.dart`, plus existing artwork and search tests.

---

## Step 3 evidence — artwork cache and decode sizing

| Item | Value |
|---|---|
| **Cache owner** | `ArtworkService` (`LruCache<String, ArtworkCandidate>`) |
| **Production capacity** | **500** entries (`ArtworkService.defaultCacheCapacity`) |
| **Eviction policy** | Least-recently-used on insert; `get` / `putIfAbsent` promote to MRU |
| **Cache key identity** | `library:{id}`, `folder:{id}`, `media:{id}` — entity id, not filename |
| **Flutter ImageCache budget** | **100 MB** (`configureArtworkFlutterImageCache()` at app start) |
| **Decode hints** | `ArtworkImage.logicalDecodeSize` → physical `cacheWidth` / `cacheHeight` via DPR |

### Surfaces using decode hints

| Surface | Sizing strategy |
|---|---|
| Folder / library cards | `CardArtworkBand` — layout constraints |
| Media grid cards | `TtsMediaCard` — `LayoutBuilder` in artwork band |
| Continue Watching | `LayoutBuilder` in hero card artwork |
| Search results | `ArtworkSurfaceSizes.searchResultThumbnail()` (56×84 logical) |
| Favourites rows | `ArtworkSurfaceSizes.favouritesRowThumbnail()` (72×48 logical) |
| Item detail poster | Screen width × 16:9 via `ArtworkSurfaceSizes.itemDetailPoster()` |

### Catalogue refresh behaviour (unchanged from Step 2)

| Event | Artwork cache |
|---|---|
| Successful replacement | Cleared once via `CatalogCacheCoordinator` |
| Failed refresh/rescan | Preserved |

### Test evidence

- `lru_cache_test.dart` — LRU fundamentals (8 tests)
- `artwork_service_lru_test.dart` — capacity bound, identity, clear/re-resolve (6 tests)
- `artwork_decode_size_test.dart` — DPR rounding and surface presets (6 tests)
- `artwork_image_test.dart` — placeholder fallback + ImageCache budget (3 tests)
- `catalog_cache_invalidation_test.dart` — coordinator lifecycle preserved

**Expected outcome:** App-owned artwork candidate entries remain ≤ 500 during session browse; decode memory reduced architecturally by sizing hints — exact RAM not measured in Step 3.

**Limitation:** Placeholder candidates are cached (successful resolution with no file); image decode failures are not negative-cached in `ArtworkService` (handled by `errorBuilder` in `ArtworkImage` only).

---

## Measurable success criteria

### Acceptance thresholds

| Metric | Fixture | Target | Measurement |
|---|---|---|---|
| **Demo catalogue startup** | Bundled 5-item `catalog.json` | No regression **> 10%** vs Step 0 baseline | Step 6 benchmark |
| **Dashboard interactive** | Bundled catalogue | **< 3 s** from `main()` to snapshot ready on dev Windows | Step 6 / 7 |
| **Catalogue parse** | Synthetic 5 000-item JSON | **< 1 s** synchronous parse (document if exceeded) | Step 6 micro-benchmark |
| **Search index build** | 5 000-item catalogue | **< 2 s**; must not block dashboard first paint | Step 6 + 7 |
| **Search open while indexing** | Large fixture | UI shows indexing state; no unhandled exception | Step 7 harness |
| **Artwork candidate cache** | Session browse | Bounded **≤ 500** entries (LRU) | Unit test |
| **Image decode budget** | Desktop session | `ImageCache.maximumSizeBytes` ≤ **100 MB** configured | Unit / manual |
| **Failed refresh** | HTTP/local failure | Last-good catalogue; artwork + search index **unchanged** | Regression test |
| **Successful rescan** | Catalogue replace | Artwork cleared; search index rebuilt; favourites validated | Integration test |
| **Folder scroll** | 500+ item folder | No sustained visible stutter on Windows desktop | Step 7 manual QA |
| **Memory session growth** | Browse + search session | No unbounded growth after cache warm (candidate cap enforced) | Step 7 manual / debug hooks |

### Regression gates (always)

- `flutter test` — all existing tests pass unless intentionally extended.
- `flutter analyze` — no new errors.
- Bundled mock catalogue load path unchanged in behaviour (graceful degradation contract intact).

---

## Step 2 — Cache invalidation orchestration — ✅ complete

**ADR:** [ADR-014](../architecture/decisions/ADR-014-catalogue-revision-cache-invalidation.md)

### Delivered

| Item | Location |
|---|---|
| `CatalogCacheCoordinator` | `lib/services/catalog_cache_coordinator.dart` |
| App-scoped `SearchService` | `main.dart` `Provider<SearchService>` |
| Orchestration wiring | `CatalogService.onCatalogReplaced` → coordinator |
| Search invalidation API | `SearchService.invalidateIndex()`, `onCatalogReplaced()` |
| `SearchScreen` | Resolves shared `SearchService` via `Provider` |
| Tests | `test/catalog_cache_invalidation_test.dart` |

### Behaviour

- Successful replacement: artwork clear → search invalidate + rebuild → favourites validate (async).
- Failed refresh/rescan: last-good catalogue; no coordinator invocation.
- Immediate index rebuild on replace (deferred build deferred to Step 4).

### Tests

- Coordinator unit smoke
- Search identity invalidation
- CatalogService integration: success, failed load, failed rescan, favourites prune

---

## Step 3 — Artwork candidate bounds + image decode — ✅ complete

**ADR:** [ADR-015](../architecture/decisions/ADR-015-artwork-and-image-decode-caching.md)

### Delivered

| Item | Location |
|---|---|
| `LruCache` | `lib/services/artwork/lru_cache.dart` |
| Bounded `ArtworkService` | Default capacity 500; `@visibleForTesting cacheEntryCount` |
| `ArtworkDecodeSize` / `ArtworkSurfaceSizes` | `lib/services/artwork/artwork_decode_size.dart` |
| Decode hints | `ArtworkImage.logicalDecodeSize` → `cacheWidth` / `cacheHeight` |
| Flutter budget | `configureArtworkFlutterImageCache()` in `main.dart` |
| Tests | `lru_cache_test.dart`, `artwork_service_lru_test.dart`, `artwork_decode_size_test.dart`, `artwork_image_test.dart` |

### Unchanged

- Resolution precedence order
- `MediaLocationResolver` at image boundary
- Placeholder on failure
- Step 2 invalidation orchestration

→ [Step 3 evidence](#step-3-evidence--artwork-cache-and-decode-sizing)

---

## Step 4 — Search index lifecycle + startup deferral — ✅ complete

**ADR:** [ADR-016](../architecture/decisions/ADR-016-search-index-and-large-library-browsing.md)

### Pre-change lifecycle (audit, Step 4 entry)

| Stage | Previous behaviour |
|---|---|
| App startup | `SearchService()` created in `main.dart`; no index until first `buildIndex` |
| Search open | `SearchScreen.build()` called `buildIndex(catalog)` on every rebuild — **eager build without query** |
| First query | `_runSearch()` called `buildIndex` then sync `search()` |
| Catalogue replace | `onCatalogReplaced()` → `invalidateIndex()` + **immediate `buildIndex(catalog)`** |
| Failed refresh | Coordinator not invoked; index preserved |
| Identity | `_catalogueIdentity == catalog.catalogueIdentity`; skip rebuild when match and index non-empty |
| Concurrency | None — sync builds could race if called from multiple isolates (not applicable) |

### Delivered

| Item | Location |
|---|---|
| Deferred `ensureIndex` / `searchCatalog` | `lib/features/search/search_service.dart` |
| Invalidate-only `onCatalogReplaced` | Same — no eager rebuild |
| Filter metadata without index | `libraryNamesFor`, `extensionsFor` |
| Async search + stale-query guard | `lib/features/search/search_screen.dart` |
| Test instrumentation | `@visibleForTesting`: `indexBuildCount`, `hasIndex`, `isBuildInFlight`, `simulateBuildFailure` |
| Lifecycle tests | `test/search_service_lifecycle_test.dart` (13 tests) |
| Presentation deferral tests | `test/search_presentation_test.dart` (tests 25–28) |

### Post-change lifecycle

```
Application startup → SearchService created → indexBuildCount = 0
Search open (no query) → no build; filter chips from Catalog
First valid search → ensureIndex → one build → searchCatalog returns results
Later searches (same identity) → reuse index; indexBuildCount unchanged
Successful replacement → invalidate only → indexBuildCount unchanged until next search
First search after replacement → one new build for new identity
Failed refresh → coordinator skipped → index + identity preserved
Concurrent first searches → one shared in-flight build
```

### Unchanged

- Scoring algorithm, filters, `maxResults = 100`
- Search presentation (grouping, context, actions, empty states)
- `CatalogCacheCoordinator` invocation contract (artwork clear → search invalidate → favourites validate)

### Test evidence

| Scenario | Verified outcome |
|---|---|
| `SearchService()` constructor | `indexBuildCount = 0`, `hasIndex = false` |
| Open Search without query | `indexBuildCount = 0` (widget test 25) |
| First valid search | `indexBuildCount = 1` (unit + widget test 26) |
| Second query same catalogue | `indexBuildCount` still 1 |
| `onCatalogReplaced` | `hasIndex = false`; no eager build |
| Catalogue load via coordinator | `catalogueIdentity` null until search |
| Failed refresh with built index | identity + `indexedItemCount` preserved |
| Concurrent first searches | `indexBuildCount = 1` |
| Replacement during in-flight build | stale index not committed |
| Build failure + retry | in-flight cleared; retry succeeds |

**Commit:** `perf(m4): defer and reuse search index`

---

## Step 5 — Large-folder scroll + memory hooks — ✅ complete

### Pre-change audit (Step 5 entry)

| Surface | Widget pattern | Lazy? | Notes |
|---|---|---|---|
| `FolderScreen` | `CustomScrollView` + `SliverChildBuilderDelegate` | Yes | Primary large-collection surface; no scroll tuning |
| Dashboard sections | Horizontal `ListView.separated` | Yes | Capped 8–12 items |
| `LibrariesSection` | `GridView.builder` + `shrinkWrap` | Builder | Bounded library roots only |
| `SearchResultsList` | `ListView.separated` | Yes | Capped at 100; O(n) index scan per row |
| `FavouritesScreen` | `ListView.separated` | Yes | Unbounded but user-curated |
| Dashboard shell | `SliverChildListDelegate` | Eager | Bounded section count |

No `PageStorageKey`, `scrollCacheExtent`, or explicit delegate flags before Step 5.

### Delivered

| Item | Location |
|---|---|
| `FolderPresentationConfig` | `lib/library/folder_presentation_config.dart` |
| `FolderPresentationMetrics` | `lib/library/folder_presentation_metrics.dart` |
| Folder grid tuning | `lib/screens/folder_screen.dart` — `scrollCacheExtent`, `RepaintBoundary`, stable keys, view memoization |
| Search list flatten | `lib/features/search/widgets/search_results_list.dart` — O(1) row lookup |
| Large catalogue factory | `test/support/large_catalog_factory.dart` (default 2000 items) |
| Widget tests | `test/large_folder_presentation_test.dart` (13 tests) |
| Runtime harness | `test/phase_45_windows_runtime_test.dart` (`PHASE_45_RUNTIME=1`) |

### Tuning values

| Setting | Value | Rationale |
|---|---|---|
| `scrollCacheExtent` | `ScrollCacheExtent.pixels(400)` | ~1 media-card row; modest increase over default 250 |
| `addAutomaticKeepAlives` | `true` | Default; explicit for audit |
| `addRepaintBoundaries` | `true` | Delegate + per-card `RepaintBoundary` |
| `addSemanticIndexes` | `true` | Accessibility preserved |
| Item keys | `ValueKey('media-card-{id}')` | Stable identity across rebuilds |
| Scroll storage | `PageStorageKey('folder-scroll:{folderId}')` | Per-folder position when route remounts |
| View memoization | `_FolderBrowseBody` cache | Sort/filter prep once per folder revision |

### Test evidence

| Scenario | Verified outcome |
|---|---|
| 2000-item folder initial build | `mediaCardBuildCount < 50` (not 2000) |
| After scroll | Build count increases; still ≪ total |
| Item detail pop | Scroll offset preserved on same route |
| Child folder push | Child opens at offset 0 |
| Viewport resize while scrolled | No exception; offset valid |
| Settings notify | `viewPreparationCount` unchanged |
| Folder browse | `search.indexBuildCount = 0` |
| 600 artwork identities | `cacheEntryCount ≤ 500` |
| Catalogue replace | View cache invalidates via folder identity |

**Commit:** `perf(m4): tune large-folder browsing`

### Unchanged

- Dashboard carousel caps
- Artwork LRU 500 / ImageCache 100 MB
- Search deferred index lifecycle (Step 4)
- Folder-first navigation semantics

---

## Step 6 — Integration tests + micro-benchmarks — ✅ complete

### Objective

Connect Steps 2–5 unit evidence into end-to-end lifecycle scenarios. Provide deterministic operation-count gates and opt-in informational micro-benchmarks — **no fragile wall-clock pass/fail thresholds** in the normal test suite.

### Pre-Step-6 evidence map (Steps 2–5 — reused, not duplicated)

| Evidence | Source | What it proves |
|---|---|---|
| Coordinator invocation once per successful replace | `catalog_cache_invalidation_test.dart` | Artwork clear → search invalidate → favourites validate |
| Failed load/rescan preserves caches | Same + `CatalogService` integration tests | Last-good catalogue; coordinator not invoked |
| Artwork `cacheEntryCount` ≤ 500 | `artwork_service_lru_test.dart`, `lru_cache_test.dart` | LRU capacity, eviction, entity-scoped keys |
| Flutter `ImageCache` 100 MB budget | `artwork_image_test.dart` | Startup budget configured |
| `SearchService.indexBuildCount` lifecycle | `search_service_lifecycle_test.dart` (13 tests) | Deferred build, identity guard, concurrency |
| Search open without query — zero builds | `search_presentation_test.dart` (tests 25–28) | Presentation deferral |
| `FolderPresentationMetrics` lazy bounds | `large_folder_presentation_test.dart` (13 tests) | Initial builds ≪ total; scroll incremental |
| 2 000-item in-memory factory | `test/support/large_catalog_factory.dart` | Deterministic fixture; no static JSON blob |
| Search result grouping | `search_presentation_test.dart` | Group order and empty states |
| Phase 4.5 Windows runtime harness | `phase_45_windows_runtime_test.dart` (`PHASE_45_RUNTIME=1`) | Observational scroll/search smoke (Step 7 extends) |
| Catalogue load/refresh/rescan | Existing `catalog_service` + provider tests | Last-good semantics baseline |

Step 6 **connects** these components; it does not re-assert every unit invariant.

### Delivered

| Item | Location |
|---|---|
| Integration lifecycle suite | `test/performance_integration_test.dart` (7 tests) |
| Opt-in micro-benchmarks | `test/performance_microbenchmarks_test.dart` (`PHASE_45_BENCHMARK=1`) |
| Benchmark report helper | `test/support/performance_benchmark_report.dart` |
| Search flatten metrics | `lib/features/search/search_presentation_metrics.dart` |
| Extended fixture sizes | `large_catalog_factory.dart` — small **100**, medium **2000**, large **10000** |
| Artwork eviction observability | `LruCache.evictionCount`, `ArtworkService.cacheEvictionCount` |

### Integration lifecycle proven

```text
Initial catalogue active (PERF-A, 2000 items)
  → resolve 600 artwork identities (LRU bounded; evictions > 0)
  → first search (indexBuildCount = 1)
  → repeated searches (indexBuildCount unchanged)
  → successful replace (PERF-B)
  → coordinator: artwork clear once; search invalidate only (no eager rebuild)
  → browse/search new catalogue (one new index build on first search)
  → failed refresh (missing file)
  → last-good PERF-B preserved; caches unchanged
```

Additional groups: search flatten widget integration, large-folder lazy metrics widget integration, failure-path (build retry, replacement during in-flight build, favourites reconciliation failure).

### Deterministic pass/fail gates (operation counts and bounds)

| Assertion | Gate type |
|---|---|
| `clearInvocations` / coordinator callbacks per replace | Deterministic |
| `indexBuildCount` per ADR-016 lifecycle | Deterministic |
| `cacheEntryCount` ≤ 500 under sustained browse | Deterministic |
| `cacheEvictionCount` > 0 beyond capacity | Deterministic |
| `FolderPresentationMetrics` initial builds < total items | Deterministic (structural inequality) |
| `SearchPresentationMetrics.flattenInvocationCount` per list build | Deterministic |
| Catalogue `catalogueIdentity` before/after transitions | Deterministic |
| Failed replacement preserves index + artwork | Deterministic |

### Informational only (not pass/fail)

| Measurement | Notes |
|---|---|
| Micro-benchmark min/median/max/total µs | `Stopwatch`; warm-up + iterations; printed only when `PHASE_45_BENCHMARK=1` |
| Windows runtime harness timings | Machine-specific; Step 7 |
| Process memory / FPS | Explicitly rejected as CI gates |

**Why wall-clock thresholds were rejected:** Parse and index timings vary widely by CPU and CI load; operation-count and bound assertions prove architectural intent without flaky gates.

### Benchmark invocation

```powershell
cd client\ttsplayer
$env:PHASE_45_BENCHMARK='1'
flutter test test/performance_microbenchmarks_test.dart
Remove-Item Env:PHASE_45_BENCHMARK -ErrorAction SilentlyContinue
flutter test   # benchmark reports 1 clean skip (~1)
```

**Warm-up / iteration strategy:** Default 3 warm-up + 10 measure iterations per operation (`PerformanceBenchmarkReport`); artwork sustained insertion uses 1 + 3; large 10k index uses 1 + 3.

### Fixture sizes

| Name | Items | Usage |
|---|---|---|
| Small | 100 | Integration search flatten; benchmark replace identity |
| Medium | 2 000 | Integration lifecycle; folder/search benchmarks |
| Large | 10 000 | Opt-in benchmark only (`search_index_build_large`) |

Stable IDs, identities, folder structure, extensions — generated in memory via `buildLargeCatalog()`; no NAS, network, or multi-megabyte JSON asset.

### Observed benchmark output (dev Windows, informational)

| Operation | n | median |
|---|---|---|
| `search_index_first_build` | 2000 | ~2.1 ms |
| `search_query_warm_index` | 2000 | ~2.1 ms |
| `search_invalidate_only` | 2000 | ~0 µs |
| `search_index_rebuild_after_replace` | 100 | ~95 µs |
| `folder_view_prepare` | 2000 | ~63 µs |
| `folder_view_memoized_reuse` | 2000 | ~2 µs |
| `folder_view_filter_change` | 2000 | ~388 µs |
| `artwork_populate_beyond_capacity` | 600 | ~5.7 ms |
| `artwork_cache_hit` | 600 | ~12 µs (evictions=100) |
| `search_index_build_large` | 10000 | ~11 ms |

Values are local observations only — not SLA claims.

### Test evidence (Step 6 additions)

| File | Tests | Focus |
|---|---|---|
| `performance_integration_test.dart` | 7 | End-to-end lifecycle, flatten, folder lazy, failure paths |
| `performance_microbenchmarks_test.dart` | 4 (+1 skip) | Opt-in timings |

**Focused suite commands:**

```powershell
flutter test test/performance_integration_test.dart
flutter test test/large_folder_presentation_test.dart
flutter test test/search_service_lifecycle_test.dart
flutter test test/artwork_service_lru_test.dart
flutter test test/catalog_cache_invalidation_test.dart
```

### Known limitations

- No isolates for index build; 10k benchmark still runs on test isolate.
- Widget lazy card counts use structural inequalities, not exact viewport-dependent counts.
- Runtime harness not extended in Step 6 — Step 7 owns Windows validation pass.
- No production telemetry or persistent metrics.

**Commit:** `test(m4): add performance integration benchmarks`

---

## Step 7 — Windows runtime validation — ✅ complete

### Harness

| Item | Value |
|---|---|
| File | `test/phase_45_windows_runtime_test.dart` |
| Env var | `PHASE_45_RUNTIME=1` |
| Platform | Windows only (clean skip elsewhere) |
| Optional live catalogue | `PHASE_45_LOCAL_CATALOG` (path to `catalog.json`) |
| Baseline helper | `test/support/phase_45_runtime_baseline.dart` |

```powershell
cd client\ttsplayer
$env:PHASE_45_RUNTIME='1'
flutter test test/phase_45_windows_runtime_test.dart --tags phase45-runtime
```

### Runtime matrix R1–R38

| ID | Area | Status | Automation |
|---|---|---|---|
| R1–R5 | Large-folder lazy open | **Pass** | Widget + metrics |
| R6–R9 | Extended scroll | **Pass** | Widget |
| R10 | Scroll smoothness | **Manual pending** | Desktop `flutter run` |
| R11–R12 | Artwork LRU bounds | **Pass** | `cacheEntryCount`, `cacheEvictionCount` |
| R13–R16 | Sort/filter prep | **Pass** | `FolderPresentationMetrics` |
| R17–R21 | Navigation + replacement | **Pass** | Scroll offset + identity |
| R22–R24 | Window resize | **Pass** | Widget |
| R25–R28 | Search lifecycle | **Pass** | `indexBuildCount` + widget |
| R29–R30 | Catalogue replace / failed refresh | **Pass** | Coordinator + caches |
| R31–R32 | ImageCache budget | **Pass** | Unit |
| R33–R35 | Recovery paths | **Pass** | Service |
| R36 | Search flatten once | **Pass** | `SearchPresentationMetrics` |
| R37–R38 | Optional local catalogue | **Skipped** | Requires `PHASE_45_LOCAL_CATALOG` |

**Manual checkpoints (not CI gates):** R10 scroll smoothness; artwork flicker; resize sharpness; external memory profiler.

### Windows runtime baseline (informational — dev machine)

| Metric | Observed |
|---|---|
| Platform | Windows 11 Pro, build 26200 |
| Dart | 3.12.2 |
| Fixture | Generated 2 000 items |
| Initial media card builds | 9 |
| Post-scroll media card builds | 99 |
| Initial view preparations | 1 |
| Post sort/filter preparations | 4 |
| Search index builds (folder open) | 0 |
| Search index builds (after queries) | 1 |
| Artwork cache peak (scroll) | 99 |
| Artwork cache peak (programmatic) | 500 |
| Artwork evictions | 100 |
| Suite duration | ~18 s |

### Benchmark revalidation (Step 7 vs Step 6 medians)

| Operation | Step 6 | Step 7 | Notes |
|---|---|---|---|
| `search_index_first_build` | 2.13 ms | 2.71 ms | Informational |
| `search_query_warm_index` | 2.07 ms | 2.31 ms | Informational |
| `search_index_build_large` | 10.98 ms | 14.09 ms | Informational |
| `artwork_populate_beyond_capacity` | 5.68 ms | 6.04 ms | Informational |
| Operation counts / bounds | — | — | Unchanged; no regression |

Differences are observational only — not pass/fail gates.

### Step 8 readiness

- [x] R1–R38 matrix documented with pass/skip/manual status
- [x] Runtime harness executed on Windows
- [x] Benchmark revalidated
- [x] Deterministic suites remain green
- [ ] Phase 4.5 definition of done reconciliation (Step 8)
- [ ] `caching.md` accepted at closure (Step 8)

**Commit:** `test(m4): validate performance on Windows`

---

## Step 8 — Closure

- [ ] Definition of done reconciled against measurements
- [ ] `caching.md` updated from planning → implemented/accepted
- [ ] `v0.5.0-dev.md` retrospective + validation table
- [ ] `m4-plan.md` phase marked complete
- [ ] ADR-014–016 implementation notes only (decisions unchanged)

---

## Definition of done (final)

- [ ] ADR-014–016 implemented
- [ ] Measurable targets met or documented with justified exception
- [ ] No regression on bundled catalogue startup (> 10% threshold)
- [ ] Failed refresh preserves caches and last-good catalogue
- [ ] Successful replace invalidates artwork + search index (rebuild deferred until first search)
- [ ] Artwork candidate cache bounded; ImageCache budget configured
- [ ] Search index deferred off dashboard critical path
- [ ] `flutter test` green; `flutter analyze` no new errors
- [ ] Phase 4.5 Windows runtime harness executed (`PHASE_45_RUNTIME=1`)
- [ ] `caching.md` accepted at closure

---

## Out of scope

| Item | Reason |
|---|---|
| SQLite catalogue store | M4 plan exclusion |
| Disk thumbnail cache | ADR-015 rejection |
| Background indexer daemon | Product principles |
| Search pagination / history | Feature scope — 4.3 engine frozen |
| Diagnostics cache health UI | Phase 4.6 |
| CDN / transcoding | Product principles |
| Mobile/tvOS-specific tuning | Desktop-first M4 |

---

## Dependencies

| Phase | Provides |
|---|---|
| 4.1 | `onCatalogReplaced`, last-good refresh |
| 4.2 | Network timeout settings |
| 4.3 | Search presentation, folder grids, immutable catalog |
| 4.4 | Playback unchanged — no interaction required |

**Enables:** Phase 4.6 diagnostics cache health indicators.

---

## Related documents

- [Baseline audit](./m4-phase-4.5-baseline-audit.md)
- [caching.md](../architecture/caching.md)
- [library.md](../architecture/library.md)
- [diagnostics.md](../architecture/diagnostics.md)
- [m4-foundation-complete.md](../release/m4-foundation-complete.md)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-14 | Initial specification; Step 0 audit; ADR-014–016 accepted |
| 2026-07-14 | Step 2 cache invalidation orchestration complete |
| 2026-07-15 | Step 3 artwork LRU + decode sizing complete |
| 2026-07-15 | Step 4 deferred search index lifecycle complete |
| 2026-07-16 | Step 5 large-folder scroll tuning complete (`6ed7b17`) |
| 2026-07-16 | Step 7 Windows runtime validation complete — R1–R38 matrix |
