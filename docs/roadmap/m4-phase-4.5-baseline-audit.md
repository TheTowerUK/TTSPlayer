# M4 Phase 4.5 — Performance Baseline Audit (Step 0)

**Status:** **Complete** — inventory captured 2026-07-14; measurements pending implementation kickoff  
**Milestone:** M4 Phase 4.5 — Performance and Caching  
**Branch:** `m4-development`  
**Predecessor:** M4 Phase 4.4 complete — closure `52d0a35`

→ [Phase 4.5 specification](./m4-phase-4.5-performance-caching.md)  
→ [Caching architecture](../architecture/caching.md)

---

## Purpose

Document the **pre-implementation performance baseline** before Phase 4.5 code changes. Unlike Phase 4.4 Gate 0 (external API capability), this audit inventories **in-app behaviour**, identifies bottlenecks, and defines what to measure during implementation.

Measurements marked **TBD** are captured in Step 6 micro-benchmarks or Step 7 Windows runtime validation on the development machine profile below.

---

## Development profile (reference)

| Attribute | Value |
|---|---|
| Platform | Windows desktop (primary M4 target) |
| Default catalogue | Bundled `assets/mock_data/catalog.json` (**5 items**) |
| Large fixture | Synthetic `test/fixtures/catalog_large.json` — **to be added** in Step 6 (target: 5 000 items) |
| Flutter test | Unit/widget/micro-benchmark — no full desktop scroll profiling |

---

## Inventory — catalogue loading

| Item | Location | Behaviour today |
|---|---|---|
| Startup load | `DashboardScreen.initState` → `CatalogService.loadOnStartup` | Post-frame; blocks dashboard data until complete |
| Parse | `Catalog.fromJson` | Full tree in memory; synchronous |
| Identity | `Catalog.catalogueIdentity` | `CatalogueInfo.id` — stable per file revision |
| Replace hook | `CatalogService._applyCatalog` → `onCatalogReplaced` | Artwork clear + favourites validate only |
| Failed refresh | ADR-002 | Last-good retained; no cache clear |
| HTTP timeout | `SettingsRepository.networkSettings` | 5–120 s; default 15 s |

**Risk:** Large JSON parse on main isolate blocks first interactive frame.

**Measurement (TBD):** Parse time for 5k-item fixture — record in Step 6.

---

## Inventory — artwork

| Item | Location | Behaviour today |
|---|---|---|
| Candidate cache | `ArtworkService._cache` | Unbounded `Map<String, ArtworkCandidate>` |
| Resolution | `forMediaItem` / `forFolder` / `forLibrary` | Sync `File.existsSync` on miss |
| Precedence | thumbnail → sidecar → folder art → placeholder | Unchanged in 4.5 |
| Invalidation | `clearCache()` on `onCatalogReplaced` | Full map clear |
| Decode | `ArtworkImage` | Full-res `Image.file` / `Image.network`; no `cacheWidth` |
| ImageCache | Flutter default | Unbounded byte budget |

**Risk:** Memory growth browsing large folders; decode spikes on poster sidecars.

**Measurement (TBD):** Peak `ImageCache.currentSizeBytes` after scrolling 200 cards — Step 7 manual or test hook.

---

## Inventory — search

| Item | Location | Behaviour today |
|---|---|---|
| Service scope | `SearchScreen` private field | New instance per route |
| Index build | `SearchService.buildIndex` | Sync over `catalog.allItems` |
| Skip rebuild | Same `catalogueIdentity` + non-empty index | Per instance only |
| Query | `search()` | Linear scan of index; max 100 results |
| Presentation | Phase 4.3 | Grouping, context, filters — unchanged |

**Risk:** First search open on large catalogue blocks UI; index not rebuilt on rescan unless user reopens search.

---

## Inventory — folder browse

| Item | Location | Behaviour today |
|---|---|---|
| Layout | `FolderScreen` → `CustomScrollView` | Subfolders + items slivers |
| Grid build | `SliverChildBuilderDelegate` | Lazy per child |
| Derived view | `buildLibraryFolderView` | Sort/filter copy per folder open |
| Scroll state | None persisted | Post-4.5 optional |

**Assessment:** Grid structure is already lazy. 4.5 tunes cache extent / repaint if needed; does not replace layout.

**Measurement (TBD):** Subjective scroll smoothness on 500+ item folder — Step 7 manual QA.

---

## Inventory — dashboard startup

| Step | Work | Blocking? |
|---|---|---|
| 1 | `MediaProviderConfigService.load` | Yes (await) |
| 2 | `SettingsRepository.initialize` | Yes (await) |
| 3 | `LibraryMetadataRepository.initialize` | Yes (await) |
| 4 | `runApp` | — |
| 5 | `CatalogService.loadOnStartup` | Yes (await in post-frame) |
| 6 | `DashboardService.buildSnapshot` | Sync after catalog ready |
| 7 | Section widgets + artwork | Per-card on build |

**Risk:** Steps 1–3 + 5 sequential before dashboard content. Search index not yet built (good).

**Measurement (TBD):** Time from `main()` to dashboard `DashboardSnapshot` ready — bundled catalog — Step 6 benchmark.

---

## Bottleneck summary

| Priority | Area | Issue | 4.5 response |
|---|---|---|---|
| P1 | Search index | Per-screen sync full build | ADR-016 shared + deferred rebuild |
| P2 | Artwork decode | Full-resolution images | ADR-015 decode constraints + ImageCache budget |
| P3 | Artwork candidates | Unbounded map + sync exists | ADR-015 LRU cap |
| P4 | Invalidation | Search not wired to replace | ADR-014 orchestration |
| P5 | Catalogue parse | Large JSON on main isolate | Document baseline; no regression on demo; optional `compute` if benchmark fails target |

---

## Out of scope (confirmed)

- SQLite / disk catalogue cache
- Background indexer daemon
- Thumbnail generation
- Search pagination UI
- Transcoding or CDN

---

## Step 0 exit criteria

- [x] Inventory documented (this file)
- [x] Bottlenecks ranked
- [x] Measurement plan assigned to Steps 6–7
- [ ] Numeric baselines recorded at implementation kickoff (bundled + 5k fixture)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-14 | Initial baseline audit at Phase 4.5 planning |
