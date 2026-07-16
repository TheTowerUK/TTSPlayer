# Caching and Performance (M4 Phase 4.5)

**Status:** **Implemented / Accepted** — Phase 4.5 closure 2026-07-16
**Related roadmap phase:** [M4 Phase 4.5 — Performance and Caching](../roadmap/m4-phase-4.5-performance-caching.md) (complete)

→ [Provider refresh lifecycle](./decisions/ADR-002-provider-refresh-lifecycle.md)  
→ [Library experience (4.3)](./library.md)  
→ [Diagnostics (4.6)](./diagnostics.md)  
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)

**ADRs (Accepted and implemented):**

- [ADR-014: Catalogue Revision Cache Invalidation](./decisions/ADR-014-catalogue-revision-cache-invalidation.md)
- [ADR-015: Artwork and Image Decode Caching](./decisions/ADR-015-artwork-and-image-decode-caching.md)
- [ADR-016: Search Index and Large-Library Browsing](./decisions/ADR-016-search-index-and-large-library-browsing.md)

---

## Purpose

Keep large libraries responsive on desktop through **deliberate in-memory caching**, **bounded memory**, **deferred work off the critical startup path**, and **lazy UI rendering** — without SQLite, background indexer daemons, disk thumbnail stores, or catalogue schema changes.

Phase 4.5 refines performance characteristics of existing M3–M4.4 surfaces. It does not add new user-facing features.

---

## Cache domains

| Domain | Owner | Scope | Lifetime | Invalidation |
|---|---|---|---|---|
| **Catalogue last-good state** | `CatalogService` | App | Session | Successful replacement only; failed load preserves prior catalogue |
| **Artwork candidates** | `ArtworkService` | App | Session; LRU **500** | `clearCache()` on successful catalogue revision |
| **Flutter decoded-image cache** | Flutter `ImageCache` | Framework | Session; **100 MB** budget | Flutter LRU eviction; **not** cleared on catalogue replacement |
| **Search index** | `SearchService` | App | Session; per `catalogueIdentity` | `invalidateIndex()` on successful revision; rebuild deferred until first qualifying search |
| **Folder presentation view** | `FolderScreen` memoization | Screen | Per folder + sort + filter | New preparation when folder identity, sort, or filter changes; catalogue replacement invalidates via new folder/catalogue identity |
| **Favourites reconciliation** | `LibraryMetadataRepository` | App | Persistent prefs | `validateAgainstCatalog()` on successful replacement (async; failure-safe) |

Playback progress, settings envelope, and scan history are **not** catalogue-derived caches.

---

## Ownership

| Component | Owns | App-scoped? |
|---|---|---|
| `CatalogService` | Loaded `Catalog`, last-good semantics | Yes |
| `CatalogCacheCoordinator` | Invalidation orchestration only — owns no cache data | Yes (composition root) |
| `ArtworkService` | Path-resolution candidate LRU | Yes |
| `ArtworkImage` + Flutter | Decoded pixel cache | Framework (`ImageCache`) |
| `SearchService` | Flat in-memory search index | Yes (`Provider` at root) |
| `FolderScreen` | Memoized `LibraryFolderView` for current browse state | Screen-scoped memo; invalidated by identity change |
| `LibraryMetadataRepository` | Favourite id validation against catalogue | Yes |

---

## Invalidation

### Successful catalogue replacement

```
CatalogService accepts replacement catalogue
    → CatalogCacheCoordinator.onCatalogReplaced(catalog)
        → ArtworkService.clearCache()
        → SearchService.onCatalogReplaced(catalog)   // invalidate only
        → LibraryMetadataRepository.validateAgainstCatalog(catalog)   // async
```

The next qualifying `searchCatalog()` builds one index for the new `catalogueIdentity`. Folder browse memoization is invalidated when the user opens a folder under the new catalogue (new folder/catalogue identity).

### Failed load or rescan

```
Failed load or rescan
    → last-good catalogue retained
    → coordinator not invoked
    → artwork, search index, and favourites state preserved
```

---

## Bounds and lifecycle

| Cache | Bound / rule |
|---|---|
| Artwork candidate LRU | **500** entries; entity-scoped keys (`library:`, `folder:`, `media:` + id); MRU on hit; LRU eviction on insert at capacity |
| Flutter `ImageCache` | **100 MB** via `configureArtworkFlutterImageCache()` at app start; not broadly cleared on catalogue replacement |
| Search index | Deferred until first qualifying query; one shared in-flight build per identity; generation guard prevents stale publish |
| Folder view | Memoized until folder identity, sort, or filter changes |
| Scroll state | `PageStorageKey('folder-scroll:{folderId}')` per folder; child and unrelated folders do not share offsets |
| Folder grid | Lazy `SliverChildBuilderDelegate`; `scrollCacheExtent` 400 px; `RepaintBoundary` per card |

### Search lifecycle (summary)

1. App startup → `SearchService` created → **no index build**
2. Open Search without query → **no build**
3. First qualifying search → **one build**
4. Repeated searches (same identity) → **reuse**
5. Successful catalogue replacement → **invalidate only**
6. First search after replacement → **one new build**
7. Failed refresh → **index preserved**

### Artwork lifecycle (summary)

- Resolution precedence unchanged (thumbnail → sidecar → folder art → placeholder).
- `cacheWidth` / `cacheHeight` from logical surface size × device pixel ratio.
- Placeholder candidates may be cached; decode failures use `errorBuilder` only (no negative decode cache in `ArtworkService`).

---

## Evidence

| Layer | Files / harness | Gate type |
|---|---|---|
| Coordinator invalidation | `catalog_cache_invalidation_test.dart` | Deterministic |
| Artwork LRU | `lru_cache_test.dart`, `artwork_service_lru_test.dart` | Deterministic |
| Decode sizing | `artwork_decode_size_test.dart`, `artwork_image_test.dart` | Deterministic |
| Search lifecycle | `search_service_lifecycle_test.dart`, `search_presentation_test.dart` | Deterministic |
| Large-folder lazy browse | `large_folder_presentation_test.dart` | Deterministic |
| End-to-end lifecycle | `performance_integration_test.dart` | Deterministic |
| Micro-benchmarks | `performance_microbenchmarks_test.dart` (`PHASE_45_BENCHMARK=1`) | **Informational only** |
| Windows runtime | `phase_45_windows_runtime_test.dart` (`PHASE_45_RUNTIME=1`) | Deterministic + manual R10 |

```powershell
# Opt-in benchmarks (informational timings)
$env:PHASE_45_BENCHMARK='1'
flutter test test/performance_microbenchmarks_test.dart

# Opt-in Windows runtime (R1–R38)
$env:PHASE_45_RUNTIME='1'
flutter test test/phase_45_windows_runtime_test.dart
```

### Manual release follow-ups (not CI gates)

- Subjective scroll smoothness (R10)
- Fast-scroll artwork flicker
- Image sharpness after viewport resize
- Process memory via external profiler
- Optional live catalogue (`PHASE_45_LOCAL_CATALOG`) for R37–R38

Wall-clock micro-benchmark and runtime durations are **observational** — not pass/fail gates in the normal test suite.

---

## Out of scope (Phase 4.5)

- SQLite or on-disk catalogue store
- Background indexer daemon
- Disk thumbnail cache
- Search pagination UI or persisted search history
- Diagnostics cache health **UI** (Phase 4.6 may read counts)
- CDN / transcoding
- Background isolates for index build

---

## Related documents

- [Phase 4.5 specification](../roadmap/m4-phase-4.5-performance-caching.md)
- [Phase 4.5 baseline audit](../roadmap/m4-phase-4.5-baseline-audit.md)
- [M4 plan](../roadmap/m4-plan.md)
- [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)
