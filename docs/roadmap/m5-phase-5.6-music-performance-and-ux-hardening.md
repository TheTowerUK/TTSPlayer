# M5 Phase 5.6 — Music Library Performance, Scale and UX Hardening

**Status:** ✅ **COMPLETE** (2026-07-24) — [Closure report](./m5-phase-5.6-closure-report.md)
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Predecessor:** Phase 5.5 complete (2026-07-23) — ADR-022 **Accepted**
**Step 2 commit:** `34dc00d` — `test(music): add large-library performance baselines`
**Step 3 commit:** `5a5e1bb` — `perf(music): optimise library projection`
**Step 4 commit:** `6b1574d` — `perf(music): harden search and library rendering`
**Step 5 commit:** `ce65b94` — `fix(music): harden artwork and library states`
**Step 6a commit:** `004e33c` — `test(music): validate large-library runtime`
**Step 6b commit:** `314c796` — `docs(m5.6): close music performance hardening phase`

→ [M5 plan](./m5-plan.md)
→ [Phase 5.6 closure](./m5-phase-5.6-closure-report.md)
→ [Phase 5.5 closure](./m5-phase-5.5-closure-report.md)
→ [Music architecture](../architecture/music.md#13-cache-and-performance-implications)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) — Accepted (no change required for 5.6 planning)

---

## Executive Summary

Phase 5.6 hardens the existing music experience against **realistic library scale** before broader feature work (playlists, favourites redesign, shuffle/repeat persistence).

Live NAS catalogue context (validated M5.3/5.5 era):

| Metric | Approx. value |
|---|---|
| Total media items | 121,819 |
| Audio items | 42,283 |
| Folders | 23,042 |

The phase establishes measurable baselines, removes avoidable repeated computation and rebuilds, improves loading/empty/error/artwork-fallback behaviour, and validates large-library behaviour with deterministic fixtures (and optional live catalogue). It does **not** expand music feature scope.

**Scope realignment note:** The original [M5 plan](./m5-plan.md) listed Phase 5.6 as “Release and Documentation.” That release-closure work remains required for M5 milestone completion but is **deferred** until after this performance/UX hardening pass. Performance/scale work deferred from the original Phase 5.5 title is **absorbed here**.

**Step 2 (2026-07-23):** Deterministic 1k/10k/40k fixtures and informational MP1–MP18 baselines recorded. No production optimisation yet.

**Step 3 (2026-07-23):** Evidence-gated projection indexes, one-pass grouping keys, immutable ordered collections, and cached representative / album-order track lists. See Step 3 section below.

---

## Objective

Ensure the music library remains responsive, predictable, and visually stable against a large mixed-media catalogue by:

1. Establishing measurable performance baselines for projection, browsing, filtering, search, and navigation.
2. Removing avoidable repeated computation and unnecessary widget rebuilding.
3. Improving loading, empty, error, and artwork-fallback behaviour.
4. Validating large-library performance with representative and (optional) live catalogue data.
5. Preserving all Phase 5.1–5.5 functional behaviour (playback, listening history, session persistence, mixed-media isolation).

---

## Scope

### 1. Performance baseline

Deterministic baselines for:

| Area | Operations |
|---|---|
| Projection | Catalogue→music projection; artist/album/track grouping; list/detail construction |
| Discovery | Search filtering; sorting; Continue Listening / Recently Played projection |
| UI | Initial music-screen render; artist/album/track navigation |
| Session | Queue hydration from large catalogue; playback-session reconciliation |

Each baseline records: fixture size, item counts, elapsed duration, operation classification, informational target, and blocking threshold **only where justified**.

Measurements are **informational by default**. Avoid fragile micro-benchmarks that fail on normal CI timing variance.

### 2. Large-catalogue fixtures

Deterministic generated fixtures representing at least:

| Fixture | Target scale |
|---|---|
| Small | ~1,000 audio tracks |
| Medium | ~10,000 audio tracks |
| Large | ~40,000 audio tracks |

Required variation: artists, album artists, albums, discs, track numbers, years, missing/fallback metadata, duplicate titles, compilations, artwork presence/absence, mixed audio/video/image entries.

Fixtures must be **generated or compact** — do not commit large media files or oversized catalogue JSON.

Optional live path: `PHASE_56_LOCAL_CATALOG`. Default automated suite must not depend on NAS availability.

**Existing starting point:** `test/support/large_music_catalog_factory.dart` (legacy ~20k). **Step 2 deliverable:** `test/support/phase_56_large_music_catalog_fixture.dart` with explicit 1k/10k/40k profiles.

### 3. Projection efficiency

Review `MusicLibraryProjection`, `MusicLibraryService`, and consumers for repeated work:

- Repeated catalogue scans, media-kind checks, normalization, group-key generation
- Repeated sorting, list copying, map construction, track-ID lookup
- Projection rebuild during navigation; unnecessary mutable↔immutable conversion

**Preferred ownership:**

```text
Catalogue loaded or replaced
        ↓
Music projection built once
        ↓
Indexed artist/album/track structures retained
        ↓
Music screens consume stable projections
```

**Current baseline (pre-optimisation):** `MusicLibraryService` already memoises by `catalogueIdentity` and invalidates on replace. Linear `findTrackById` / `findArtistByGroupKey` / `findAlbumByGroupKey` scans remain. Optimise only against measured repeated work — no blind rewrites.

### 4. Search and filtering

Validate music search at scale over approved fields: title, artist, album artist (where applicable), album.

Review: debounce, normalization, case-insensitive matching, diacritics, whitespace, empty queries, rapid query replacement, stale-result prevention, ordering, result limits / incremental rendering if needed.

Do **not** introduce FTS, DB indexing, or a new search engine unless in-memory behaviour is proven inadequate and an ADR documents the decision.

### 5. Widget rebuild and navigation

Measure and reduce unnecessary rebuilds across music home, artist/album lists and detail, track rows, Continue Listening, Recently Played, queue surfaces, artwork widgets.

Check: projection rebuild inside `build()`, per-frame sorting/derived lists, overly broad listenables, playback-state rebuild of unrelated rows, unstable keys, scroll loss, navigation-triggered duplicate catalogue work.

Use focused widget instrumentation or test counters. No production logging that leaks media identity.

### 6. List rendering and scrolling

Ensure large lists use appropriate lazy rendering (artists, albums, tracks, queue, search, Recently Played, Continue Listening).

Required: no eager full-list widget construction; stable row keys; no duplicates; scroll retention where expected; no prolonged freeze on first paint; artwork must not block scrolling; Windows mouse-wheel and keyboard remain correct.

Add virtualisation/pagination only if Flutter lazy lists are insufficient.

### 7. Artwork handling

Harden: embedded/catalogue/folder artwork; missing/corrupt/unsupported; repeated references; cache reuse; placeholder and layout stability; no stretched album art.

Respect existing global image-cache policy. Do not add a second unrelated artwork cache without an ADR.

### 8. Loading, empty, and failure states

Deterministic behaviour for: catalogue loading; empty library; no artists/albums; empty album/artist; no search results; catalogue load failure; malformed metadata; unavailable artwork; queue unavailable; partially restored playback session.

No blank screens or indefinite progress indicators. Errors remain actionable and consistent with existing patterns.

### 9. Mixed-media isolation

At scale: video/image items never appear as tracks; mixed folders do not corrupt album grouping; unknown kinds fail safely; video Continue Watching and image browsing unchanged; catalogue diagnostics remain correct.

### 10. Performance diagnostics

Extend diagnostics **only where useful**, with aggregate redacted fields such as:

- total audio / artist / album counts
- projection available; projection build duration; last projection warning present
- live catalogue item count
- search result count only if a stable diagnostic owner exists

**Never export:** titles, artists, albums, track IDs, paths, URIs, search queries, raw catalogue entries.

### 11. Runtime validation

Opt-in Windows harness:

| Gate | Value |
|---|---|
| Tag | `phase56-runtime` |
| Env | `PHASE_56_RUNTIME=1` |
| Optional live | `PHASE_56_LOCAL_CATALOG` |

Validate representative large-library navigation and performance using production projection/UI where practical. Unset live path → skip without failing deterministic scenarios.

---

## Out of Scope

| Item | Notes |
|---|---|
| Playlists / playlist persistence | Post-5.6 |
| Favourites / favourites redesign | Post-5.6 |
| Shuffle / repeat (modes or persistence) | Post-5.6 |
| Queue persistence redesign | 5.5 complete — no redesign |
| Autoplay / restore prior playing state | Forbidden |
| Lyrics, equaliser, gapless, crossfade | Out |
| Smart recommendations / cloud music | Out |
| Metadata editing / enrichment / art downloads | Out |
| Database migration | Out unless ADR-justified |
| Mobile-specific music UI | Out |
| Video queue persistence | Out |
| Major dashboard / visual redesign | Out |
| M5 release tagging / version bump | Deferred release-closure phase |

---

## Architecture Principles

### Build once, consume many times

```text
Catalogue generation N
        ↓
Music projection generation N
        ↓
Stable indexed structures
        ↓
Multiple UI consumers
```

### Catalogue remains authoritative

Projection is derived state — never a second catalogue or independent metadata truth.

### Stable identity

- Media item: `trackId`
- Artist grouping: normalized artist key
- Album grouping: normalized album-artist/artist + album key

Performance work must not silently alter grouping semantics (ADR-021).

### Playback isolation

UI/projection optimisation must not change queue order, transport, listening-history writes, playback-session persistence, deferred restored position, or the no-autoplay guarantee.

### Evidence before optimisation

Every material optimisation documents: observed issue → previous behaviour → change → measured result → regression coverage.

### ADR threshold

No ADR for routine implementation detail. A new ADR is required only for substantial changes such as:

- Long-lived projection caching beyond current identity memoisation
- Background-isolate projection
- Persistent / database-backed music indexing or search
- A second artwork-cache architecture

---

## Current Architecture Snapshot (Step 1 audit)

| Component | Path | Notes for 5.6 |
|---|---|---|
| `MusicLibraryService` | `lib/features/music/music_library_service.dart` | Memoises by `catalogueIdentity`; `invalidate()` on replace |
| `MusicLibraryProjection` | `lib/features/music/models/music_library_projection.dart` | Build once per identity; linear find* helpers |
| Search | `SearchService` + music presentation | Unified index; music fields already indexed |
| Artwork | `ArtworkService` + Flutter `ImageCache` | Existing LRU / budget policy |
| Listening / session | Phase 5.4 / 5.5 repositories | Preserve; include large-catalogue reconcile scenarios |
| Large fixture starter | `test/support/large_music_catalog_factory.dart` | Legacy ~20k |
| Phase 5.6 fixtures | `test/support/phase_56_large_music_catalog_fixture.dart` | **Step 2** — 1k/10k/40k + variation |
| Baseline harness | `test/music_library_large_catalog_baseline_test.dart` | **Step 2** — MP1–MP18 informational |

---

## Step 2 — Fixtures and measurement (complete 2026-07-23)

### Fixture profiles (exact)

| Profile | Grid | +compilations | +sentinels | Exact audio | Artists* | Albums* |
|---|---|---|---|---|---|---|
| small | 50×4×5 = 1,000 | +5 | +5 | **1,010** | 58 | 208 |
| medium | 100×10×10 = 10,000 | +5 | +5 | **10,010** | 108 | 1,008 |
| large | 200×20×10 = 40,000 | +5 | +5 | **40,010** | 208 | 4,008 |
| mixed | small audio | +5 | +5 | **1,010** | 58 | 208 |

\*Projected counts after grouping (includes Unicode artists, sentinels, compilations). Mixed also adds 25 video + 25 image items (excluded from music projection).

**Generator:** in-memory, deterministic IDs (`p56-aNNN-bNN-tNN`), no committed JSON/media. Variation: missing metadata, compilations, duplicate titles, Unicode/diacritics, whitespace, artwork presence/absence, mixed media.

### Measurement method

- `Stopwatch` monotonic timing
- 1 untimed warm-up + 3 timed samples; **median** reported
- Fixture generation timed separately from projection
- Classification: **informational** (correctness assertions blocking)
- Environment caveat: Windows 11 Pro / Dart 3.12.2 workstation — timings are machine-local

### MP1–MP18 results (Step 2 workstation)

| ID | Result | Median (ms) | Classification |
|---|---|---|---|
| MP1 | ✅ 1,010 audio projection | **5** | informational |
| MP2 | ✅ 10,010 audio projection | **30** | informational |
| MP3 | ✅ 40,010 audio projection | **148** | informational |
| MP4 | ✅ mixed exclusion exact | **2** | informational |
| MP5 | ✅ missing metadata fallback | — | correctness |
| MP6 | ✅ compilation grouping | — | correctness |
| MP7 | ✅ repeated consistency | **3** | informational |
| MP8 | ✅ catalogue replace | **3** | informational |
| MP9 | ✅ empty query → `[]` | **0** | informational |
| MP10 | ✅ title sentinel | **4** | informational |
| MP11 | ✅ artist sentinel | **4** | informational |
| MP12 | ✅ album sentinel | **5** | informational |
| MP13 | ✅ sequential replace (sync) | — | correctness; async stale → Step 4 |
| MP14 | ✅ absent sentinel empty | **4** | informational |
| MP15 | ✅ lazy artists (11/58 mounted) | **525** (pump) | informational |
| MP16 | ✅ lazy albums (11/208 mounted) | **104** (pump) | informational |
| MP17 | ✅ lazy tracks scroll | — | correctness |
| MP18 | ✅ projection reused; scroll not retained on pump replace | — | baseline documented |

**Search index build (medium):** ~25–43 ms (informational, separate from query samples).

**Memoisation:** identity hit ≈ **0 ms**; cold rebuild after invalidate (medium) median ≈ **28–48 ms**.

**Optional live catalogue:** skipped (`PHASE_56_LOCAL_CATALOG` unset).

### Current memoisation behaviour (documented)

| Behaviour | Evidence |
|---|---|
| Cache key | `Catalog.catalogueIdentity` |
| Reuse | Same identity → `identical` projection instance |
| Invalidation | `MusicLibraryService.invalidate()` on catalogue replace |
| Still rebuilds | Full `MusicLibraryProjection.build` on cold miss; linear `findTrackById` / `findArtistByGroupKey` / `findAlbumByGroupKey` |

### Step 3 evidence — repeated work / bottlenecks

1. **Linear lookup scans** on `findTrackById` / artist / album keys (O(n) per call) — hot path for session restore and UI.
2. **Cold projection rebuild** ~30–150 ms depending on scale after invalidate.
3. **`MusicAlbumDetailScreen` eagerly spreads all track tiles** into `ListView(children:)` — not lazy (Step 4 candidate).
4. **Screens call `projectionFor` inside `Consumer` build** — cheap when memoised; ensure identity stability.
5. **SearchScreen async stale discard** not exercised by sync `SearchService` — Step 4 widget coverage.

### Step 3 optimisation evidence table

| Evidence | Existing behaviour | Proposed change | Expected benefit |
|---|---|---|---|
| Repeated `findTrackById` / artist / album linear scans (session restore, detail screens, listening presentation) | O(n) per lookup | Stable `trackId` / `artistGroupKey` / `albumGroupKey` maps on projection | Constant-time lookup |
| Artist + album grouping recomputed keys twice per item | Two `normalizeGroupKey` / effective-key calls per audio item | Derive keys once per item into local maps during build | Lower projection string work |
| Albums-within-artist sorted twice (bucket loop + artist build) | Duplicate `compareAlbumsWithinArtist` | Sort once in `albumsByArtist`; reuse ordered list | Reduced sort work |
| `representativeTrack` re-sorted by path on every artwork request | O(k log k) per access | Cache at album construction | Cheaper artwork / tile leading |
| `tracksInAlbumOrder` rebuilt on every queue-seed / playability check | Fresh list allocation per call | Cache at artist construction | Cheaper queue seeding |
| Exposed lists were mutable plain `List`s | Consumers could mutate derived state | `List.unmodifiable` on projection / album / artist collections | Immutable derived state |
| Catalogue identity already keyed by `catalogueInfo.id` | Sufficient (not item-count) | Keep `Catalog.catalogueIdentity`; replace projection atomically on identity change | No stale indexes after rescan |

### Rejected / deferred optimisations

| Idea | Why rejected in Step 3 |
|---|---|
| Inverted search indexes / token DB | No Step 2 proof of need beyond linear search; reserved for Step 4 if measured |
| Background isolates for projection | Cold rebuild already ~30–150 ms; complexity not justified |
| Persistent projection disk cache | Violates derived-state / catalogue-authority rules |
| Speculative `trackId → artist/album` reverse maps | No current consumer beyond group-key lookups already indexed |
| New product-facing sort modes | Explicitly out of scope |

### Proposed thresholds (for Steps 3–6)

| Category | Policy |
|---|---|
| Informational | Continue reporting medians; no CI fail on timing alone |
| Watch | Projection median > **2×** recorded Step 2 median on same class of machine |
| Blocking regression | Only after Step 3+ with documented tolerance; suggested starting relative gate: **no worse than 150% of controlled baseline median** once repeatability shown |
| Correctness | Always blocking |

Suggested absolute **watch** bands (Windows workstation class, not CI hard gates yet):

| Operation | Step 2 median | Watch if |
|---|---|---|
| MP1 projection | ~5 ms | > 25 ms |
| MP2 projection | ~30 ms | > 100 ms |
| MP3 projection | ~148 ms | > 500 ms |
| Medium search query | ~4–7 ms | > 50 ms |

---

### Projection

| ID | Scenario |
|---|---|
| MP1 | 1,000-track projection |
| MP2 | 10,000-track projection |
| MP3 | 40,000-track projection |
| MP4 | Mixed-media projection |
| MP5 | Missing metadata projection |
| MP6 | Compilation grouping |
| MP7 | Repeated projection consistency |
| MP8 | Catalogue-generation replacement |

### Search and filtering

| ID | Scenario |
|---|---|
| MP9 | Empty-query behaviour |
| MP10 | Title search |
| MP11 | Artist search |
| MP12 | Album search |
| MP13 | Rapid query replacement |
| MP14 | No-results behaviour |

### Rendering and navigation

| ID | Scenario |
|---|---|
| MP15 | Artist list initial render |
| MP16 | Album list initial render |
| MP17 | Large track-list scrolling |
| MP18 | Navigation and scroll-state retention |

Additional runtime scenarios may cover artwork, diagnostics, queue hydration, session reconciliation, and optional live catalogue validation.

---

## Performance Measurement Policy

### Informational metrics (default)

- Elapsed milliseconds
- Item / group counts
- Items per millisecond (where meaningful)
- Relative improvement vs recorded Step 2 baseline

### Hard thresholds

Adopt only when: environment is controlled; threshold maps to a real usability need; CI variance will not cause false failures; target is documented here after Step 2.

**Suggested Windows workstation targets (non-binding until Step 2):**

| Scale | Expectation |
|---|---|
| 1,000-track projection | Effectively immediate |
| 10,000-track projection | No visible prolonged block |
| 40,000-track projection | Completes within a user-tolerable startup/loading interval |
| Search query update | No prolonged UI freeze |
| Visible list interaction | Smooth for normal mouse-wheel and keyboard use |

Exact numeric thresholds are **recorded after Step 2**, not invented in planning.

### Regression gates

| Gate type | Policy |
|---|---|
| Correctness | Always blocking |
| Performance | Blocking only when regression is material, baseline is repeatable, and allowed variance is documented |

---

## Testing Strategy

| Layer | Focus |
|---|---|
| Unit | Projection correctness at each size; grouping identity; ordering; duplicates; mixed-media exclusion; missing metadata; search normalization; rapid query; catalogue replace; lookup indexes; diagnostics aggregates |
| Widget | Lazy rows; loading/empty/error/no-results; scroll retention; stable keys; navigation; playback rebuild isolation; artwork placeholders |
| Performance | Deterministic generated catalogues; separate correctness vs informational timing vs approved hard gates |
| Regression | Projection, screens, search, artwork, queue, listening history, playback session, dashboard, diagnostics, mixed-media |
| Runtime | Release build; 40k projection; navigation; search; artwork fallback; queue from large library; session restore; diagnostics redaction; optional live catalogue |

Full default `flutter test` must pass without NAS or `PHASE_56_RUNTIME`.

---

## Implementation Steps

| Step | Deliverable | Proposed commit |
|---|---|---|
| **1** | Planning + baseline definition (this document) | `docs(m5.6): plan music performance and UX hardening` |
| **2** | Large fixtures + measurement harness; initial baselines | `test(music): add large-library performance baselines` |
| **3** | Projection/indexing optimisation from measured issues | `perf(music): optimise library projection` |
| **4** | Search + list rendering hardening | `perf(music): harden search and library rendering` |
| **5** | Artwork + loading/empty/error + mixed-media states | `fix(music): harden artwork and library states` |
| **6a** | Windows runtime harness | `test(music): validate large-library runtime` |
| **6b** | Docs closure + release-note update | `docs(m5.6): close music performance hardening phase` |

Do not combine unrelated steps. `README.md` remains unstaged if locally modified.

---

## Definition of Done

Phase 5.6 is complete when:

1. Deterministic 1k, 10k, and ≈40k audio fixtures exist.
2. Projection baselines are recorded.
3. Projection correctness passes at all supported fixture sizes.
4. Repeated catalogue scans in normal music navigation are eliminated or justified.
5. Artist, album, and track lookup remain correct.
6. Search remains correct and responsive at large-library scale.
7. Rapid query replacement cannot publish stale results.
8. Large music lists render lazily.
9. Music navigation does not unnecessarily rebuild the full projection.
10. Scroll behaviour is stable.
11. Artwork fallback is stable.
12. Artwork loading does not block list interaction.
13. Loading, empty, no-result, and failure states are covered.
14. Mixed-media isolation remains correct.
15. Queue creation from large libraries remains correct.
16. Playback-session restoration remains correct.
17. Listening history remains correct.
18. Diagnostics remain redacted.
19. Focused test suites pass.
20. Full Flutter test suite passes.
21. Windows runtime harness passes.
22. Windows Release build succeeds.
23. Optional live-catalogue results are documented when available.
24. Performance results and tolerances are documented.
25. Architecture and roadmap documents are current.
26. README remains outside Phase 5.6 commits.

Any failed mandatory item blocks closure.

---

## Risks

| Risk | Mitigation |
|---|---|
| Premature optimisation | Baseline first; optimise only observed repeated work; before/after evidence |
| Timing-test instability | Informational reporting by default; generous tolerances; correctness separate from timing |
| Projection cache staleness | Catalogue-generation ownership; atomic replace; replacement tests |
| Excessive memory from indexing | Index IDs/references; avoid duplicating metadata; drop obsolete projections |
| UI coupling | Keep grouping/indexing below UI; widgets consume stable models |
| Scope creep into features | Hard exclusions list; reject playlists/favourites/shuffle in reviews |
| Original 5.6 release work drift | Explicit deferral; M5 milestone DoD still requires release closure after 5.6 |

---

## Deferred Scope After Phase 5.6

- Playlists; favourites redesign
- Shuffle and repeat modes / persistence
- Advanced queue editing; lyrics; advanced metadata; smart recommendations
- Mobile music experience
- Persistent database indexing (only if future scale requires ADR)
- Video queue persistence
- **M5 release and documentation closure** (original Phase 5.6 title) — after performance hardening

These are not prerequisites for Phase 5.6 completion.

---

## Documentation Updates (this step and later)

| Document | Step 1 | Closure |
|---|---|---|
| This roadmap | Create | Mark complete |
| [m5-plan.md](./m5-plan.md) | Realign 5.6 scope | Status ✅ |
| [music.md](../architecture/music.md) | Pointer / planning note | Performance results |
| [diagnostics.md](../architecture/diagnostics.md) | — | Only if metrics added |
| Active M5 release notes | Progress entry | Completion entry |
| [MILESTONES.md](../../MILESTONES.md) · roadmap indexes | Phase 5.6 next / planning | Complete; next = release closure |
| Phase 5.6 closure report | — | Publish at Step 6 |

---

## Approved Planning Decisions (2026-07-23)

| Decision | Resolution |
|---|---|
| Phase 5.6 primary scope | Music library performance, scale, and UX hardening |
| Original 5.6 release/docs scope | Deferred until after this phase |
| Feature expansion | Explicitly out of scope |
| Measurement policy | Informational first; hard gates only after Step 2 baselines |
| Fixture strategy | Generated 1k/10k/≈40k; optional live via env; no large assets in git |
| First implementation activity | Step 2 — fixtures and measurement harness (no production optimisation unless required for measurement) |

---

## Step 3 — Projection and indexing optimisation (complete 2026-07-23)

### Projection lifecycle (final)

```text
Catalogue generation N
        ↓
MusicLibraryService resolves catalogueIdentity
        ↓
MusicLibraryProjection.build once
        ↓
Ordered tracks / artists / albums + lookup indexes retained
        ↓
Screens and services reuse generation N projection

Catalogue generation N+1 (identity change or invalidate)
        ↓
Old projection dropped from service cache (immutable but unused)
        ↓
New projection built atomically
```

- Catalogue remains metadata authority; projection is never persisted.
- Memoisation key: `Catalog.catalogueIdentity` (`catalogueInfo.id` or `legacy:$generatedAt`).
- Duplicate track IDs: **first** browse-ordered occurrence wins (matches prior linear scan).

### Indexes owned by projection

| Index | Type | Semantics |
|---|---|---|
| Track | `trackId → MediaItem` | Audio only; first-wins duplicates; unknown → null |
| Artist | `artistGroupKey → MusicArtist` | Unknown key → null |
| Album | `albumGroupKey → MusicAlbum` | Unknown key → null |

### Before / after (Windows workstation, flutter test, 1 warm-up + 3 samples → median)

| Scenario | Step 2 median | Step 3 median | Δ | Notes |
|---|---|---|---|---|
| MP1 projection (1,010) | 5 ms | 5 ms | 0% | Neutral |
| MP2 projection (10,010) | 30 ms | 32 ms | +7% | Neutral (within tolerance) |
| MP3 projection (40,010) | 148 ms | 177 ms | +20% | Mild cold-build cost from indexes + cached fields; **within 150% gate**; not blocking |
| MP8 replace | (correctness) | 2 ms | — | Stale IDs cleared |
| MEMO-HOT | 0 ms | 0 ms | — | Unchanged |
| MEMO-COLD (medium) | 28–48 ms | 31 ms | — | Neutral |
| 10k track hits (large) | O(n) linear (unmeasured Step 2) | **~328 µs** | Material | Index path |
| 10k track misses (large) | O(n) | **~844 µs** | Material | Index path |
| 10k artist lookups (large) | O(n) | **~155 µs** | Material | Index path |
| 10k album lookups (large) | O(n) | **~299 µs** | Material | Index path |

Environment: Windows desktop, `flutter test`, Dart VM (informational; not Release runtime).

### Remaining bottlenecks for later steps

| Bottleneck | Owner |
|---|---|
| Artwork fallback UX / missing-poster polish | Step 5 |
| Formal Windows runtime closure | Step 6 |

### Step 3 completion status

**Complete** for projection/indexing scope. Phase 5.6 remains **IN PROGRESS** (Steps 4–6 pending).

---

## Step 4 — Search and list rendering hardening (complete 2026-07-23)

### Evidence → change

| Evidence | Existing behaviour | Change | Benefit |
|---|---|---|---|
| MP13 / Step 2 note on async stale discard | Screen already had generation; clear/filter paths could race debounce | Single `_runSearchNow` cancels debounce; dispose bumps generation | Latest query owns publish; no post-dispose publish |
| MP17 album-detail eager spread | `ListView(children: ...map)` | `CustomScrollView` + `SliverList` builders | Bounded mounted track tiles |
| MP18 scroll not retained | `Key` only; pumped replacements lost offset | `PageStorageKey` on browse lists + Navigator push/pop | Scroll retained on back |
| Browse lists already lazy / no PlaybackService listen | Confirmed | Rebuild-isolation tests | Proof position ticks do not rebuild lists |
| Search matching contract | Token AND over index blob | Unchanged; results `List.unmodifiable` | Immutable published results |

### Search matching contract (preserved)

Covers title, filename, path, library/parent, extension, and for audio: artist, album, albumArtist, genre. Case-insensitive; `/`→`\`; whitespace token AND; no diacritic folding; cap 100; empty/whitespace → `[]`.

### Search lifecycle (final)

```text
Search query
    ↓
single debounce owner (SearchScreen, 150ms) OR immediate _runSearchNow
    ↓
generation/token captured
    ↓
SearchService index (catalogue allItems) + optional debug delay
    ↓
latest-generation + mounted check
    ↓
immutable published results
```

Debounce interval **unchanged** at 150ms.

### UI consumption

```text
Stable projection
    ↓
lazy list surfaces (ListView.separated / SliverList)
    ↓
CatalogService Consumer only (no playback-position listen on browse)
    ↓
stable row keys (artist/album groupKey, track id)
```

### MP9–MP18 Step 4 notes

| ID | Result |
|---|---|
| MP9–MP12, MP14 | Contracts preserved; timings informational (~0–5 ms search medians) |
| MP13 | Deferred A vs fast C via `debugSearchDelay`; screen owns publish |
| MP15–MP16 | Lazy mount unchanged (~11 tiles) |
| MP17 | Tracks list lazy; album/artist detail now SliverList |
| MP18 | Scroll offset retained via PageStorageKey (e.g. 900→900) |

### Remaining for Step 5

Artwork fallback UX, missing-poster polish, any residual empty/error presentation polish.

### Step 4 completion status

**Complete** for search/list hardening. Phase 5.6 remains **IN PROGRESS** (Steps 5–6 pending).

---

## Step 5 — Artwork and UI-state hardening (complete 2026-07-23)

### Artwork precedence (unchanged)

```text
MediaItem.thumbnailPath (if file exists)
    ↓
Stem / named sidecar beside the media file
    ↓
Folder art in the media directory
    ↓
MediaPlaceholder (music visual kind)
```

No embedded-tag extraction and no remote artwork download. Artist/album tiles use `representativeTrack` through the same pipeline.

### Fit and layout policy

- Music thumbs are **square** fixed `SizedBox(size×size)` + `ClipRRect`
- Images use **`BoxFit.cover`** (no stretch)
- Placeholders are centred icons in the **same layout box**
- Decode hints use `ArtworkSurfaceSizes.musicSquareThumbnail(size)` (not portrait search thumbs)
- `ArtworkImage` fills via `SizedBox.expand` so load/placeholder do not shift text

### Cache ownership

| Layer | Owner |
|---|---|
| Candidate resolution LRU | `ArtworkService` (capacity 500; cleared on catalogue replace) |
| Pixel decode cache | Global Flutter `PaintingBinding.imageCache` (ADR-015, 100 MiB) |

No second artwork cache introduced.

### Loading / empty / error matrix

| State | Presentation |
|---|---|
| Loading (no catalog yet) | `LoadingCard` — `music_catalog_loading` |
| Catalog load failure | `EmptyState` + Retry — `music_catalog_load_error` (path/URL redacted) |
| No catalog | `EmptyState` — `music_catalog_missing` |
| Empty audio library | `EmptyState` — `music_library_empty` |
| Empty artists/albums/tracks | Dedicated empty states with subtitles |
| Invalid artist/album route | Missing empty state + Back |
| Album/artist empty sections | Inline muted copy under section headers |
| Degraded reload (prior catalog kept) | Non-blocking banner — `music_catalog_degraded_banner` |

### Partial metadata

Track rows use `MusicConstants` via `musicDisplayTitle` / `Artist` / `Album` (whitespace → unknown). Grouping/sort unchanged.

### Diagnostics

No new aggregate fields (existing artwork LRU + image-cache metrics remain sufficient).

### Step 5 completion status

**Complete** for artwork/UI-state scope.

### Step 6 completion status

**Complete** (2026-07-24) — Windows runtime P56-RT1–RT20 + phase closure. → [Closure report](./m5-phase-5.6-closure-report.md)

---

## Open Questions (resolved / remaining)

1. ~~Exact track counts for 1k/10k/40k profiles~~ — **resolved:** 1,010 / 10,010 / 40,010 audio.
2. Whether projection build should expose a timed diagnostic field — **deferred** (not required for 5.6 closure; aggregates remain informational in test baselines).
3. ~~Whether linear `findTrackById` becomes a map index in Step 3~~ — **done** (Step 3).
4. ~~Numeric Windows workstation thresholds~~ — **proposed** in Step 2 section (watch bands); remain informational.
5. Naming of the post-5.6 M5 release-closure phase — still open for M5 release work.
6. ~~Whether Step 4 should add search-specific indexes~~ — **deferred**; linear indexed scan + cap 100 sufficient at measured scale.

---

## Next Step Handoff — Step 6

**Step 6 — Formal Windows runtime validation and Phase 5.6 closure**

Run controlled Windows runtime scenarios against large-library / live catalogue where available; publish closure report; do not expand feature scope.

Expected commit pattern: follow phase plan (`test` / `docs`).
