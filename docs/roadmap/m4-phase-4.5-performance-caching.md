# M4 Phase 4.5 — Performance and Caching (Implementation Specification)

**Status:** **In progress** — Step 2 complete (2026-07-14); Step 3 next
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
| **3** | Artwork candidate bounds + image decode | **Next** |
| **4** | Search index lifecycle + startup deferral | Planned |
| **5** | Large-folder scroll tuning + memory hooks | Planned |
| **6** | Integration tests + micro-benchmarks | Planned |
| **7** | Windows runtime validation | Planned |
| **8** | Closure | Planned |

**Suggested commit cadence:** invalidation wiring → artwork → search → scroll tuning → tests/benchmarks → harness → docs closure.

---

## Current baseline

*Shipped in M3–M4.4 — do not rebuild.*

| Capability | Location | State |
|---|---|---|
| Catalogue load | `CatalogService` | Bundled / local / HTTP; last-good on failure |
| Artwork resolution | `ArtworkService` | Thumbnail → sidecar → folder art → placeholder |
| Artwork invalidation | `CatalogCacheCoordinator` | `clearCache()` on successful replace |
| Search engine | `SearchService` (app-scoped) | In-memory index; scoring unchanged |
| Search UI | `SearchScreen` | Shared `SearchService` via `Provider` |
| Folder grids | `FolderScreen` | `SliverChildBuilderDelegate` — lazy children |
| Provider refresh | Phase 4.1 | ADR-002 lifecycle |
| Library metadata | `LibraryMetadataRepository` | Validates on catalogue replace |

**Tests today:** `catalog_service_artwork_cache_test.dart`, `search_service_test.dart`, `search_presentation_test.dart`, provider selection and catalogue HTTP tests.

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

## Step 3 — Artwork candidate bounds + image decode

**ADR:** [ADR-015](../architecture/decisions/ADR-015-artwork-and-image-decode-caching.md)

### Deliverables

| Item | Description |
|---|---|
| LRU cache | Replace unbounded `Map` in `ArtworkService` with capped LRU (default 500) |
| `clearCache()` | Clears LRU entirely on revision |
| `ArtworkImage` | `cacheWidth` / `cacheHeight` from layout |
| App init | Set `imageCache.maximumSizeBytes` for desktop |
| Tests | LRU eviction; clear on replace; decode constraints smoke |

### Unchanged

- Resolution precedence order
- `MediaLocationResolver` at image boundary
- Placeholder on failure

---

## Step 4 — Search index lifecycle + startup deferral

**ADR:** [ADR-016](../architecture/decisions/ADR-016-search-index-and-large-library-browsing.md)

### Deliverables

| Item | Description |
|---|---|
| Shared `SearchService` | Injected into `SearchScreen` via `Provider` |
| `scheduleRebuild(Catalog)` | Async/deferred; identity guard |
| Indexing UI | `SearchScreen` shows status while building |
| Dashboard | Does not await index build |
| Tests | Shared identity skip; rebuild on new identity; search works after build |

### Unchanged

- Scoring algorithm, filters, `maxResults = 100`
- Search presentation (grouping, context, actions)

---

## Step 5 — Large-folder scroll + memory hooks

### Deliverables

| Item | Description |
|---|---|
| Scroll tuning | Evaluate `cacheExtent` on folder/dashboard grids; `RepaintBoundary` on cards if profiled |
| Session metrics | Optional debug-only accessors: candidate cache length, index size, image cache bytes |
| Documentation | Record tuning choices in `caching.md` at closure |

### Out of scope

- Pagination UI
- Persisted scroll positions
- Virtual merged libraries

---

## Step 6 — Integration tests + micro-benchmarks

### Test additions

| File / area | Scenarios |
|---|---|
| `catalog_cache_invalidation_test.dart` | Replace vs failed refresh side effects |
| `artwork_service_lru_test.dart` | Cap, eviction, clear |
| `search_service_lifecycle_test.dart` | Deferred build, identity, shared instance |
| `catalog_performance_test.dart` | Parse + index build timing on synthetic fixture (threshold assert or skip in CI) |

### Synthetic fixture

- Add `test/fixtures/catalog_large.json` (or generator) — flat or shallow tree, **~5 000** items, valid schema.
- Not used as default app asset.

---

## Step 7 — Windows runtime validation

### Harness pattern

Mirror 4.1–4.4: opt-in `PHASE_45_RUNTIME=1`, file `test/phase_45_windows_runtime_test.dart`.

### Scenario matrix (prefix **C**)

| ID | Scenario | Expect |
|---|---|---|
| **C1** | Bundled startup | Dashboard loads; no error banner |
| **C2** | Open search before index ready (large fixture env) | Indexing state visible; then search works |
| **C3** | Successful catalogue refresh | Artwork + index invalidated (observable via test hooks) |
| **C4** | Failed refresh | Last-good; index count unchanged |
| **C5** | Folder with many items (fixture or env) | Grid builds; scroll does not throw |
| **C6** | LRU smoke | Candidate count ≤ cap after heavy browse |

**Manual follow-up (not blockers):** subjective 60fps scroll on real NAS folder with sidecars; memory profiler snapshot after extended browse.

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
- [ ] Successful replace invalidates artwork + rebuilds search index
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
