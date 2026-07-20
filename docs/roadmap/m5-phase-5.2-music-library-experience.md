# M5 Phase 5.2 — Music Library Experience

**Status:** ✅ **COMPLETE** (2026-07-19)
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Closure commit base:** `4ac55a1` — implementation commits `b092ef9`…`4ac55a1`
**Predecessor:** Phase 5.1 complete (2026-07-19) — commit `9824f4e`
**Next phase:** [M5.3 — Music Playback and Queue](./m5-plan.md#phase-53--music-playback-and-queue)

→ [M5 plan](./m5-plan.md#phase-52--music-library-experience)
→ [Music architecture](../architecture/music.md)
→ [ADR-020](../architecture/decisions/ADR-020-music-catalogue-schema-and-media-kind.md)
→ [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md)

**ADRs (unchanged in this phase):**

- ADR-020, ADR-021 — **Accepted** (M5.1)
- ADR-022 (queue/listening state), ADR-023 (player surface) — **Proposed** — not implemented in 5.2

---

## Objective

Deliver the first user-facing **read-only music browsing experience**: artists, albums, and tracks derived from the unified catalogue using M5.1 metadata and grouping keys. No playback, queue, shuffle, repeat, listening history, Continue Listening, playlists, or multi-device sync.

---

## Step 1 — Repository and UI audit (pre-implementation)

Audit completed **2026-07-19** before production changes.

### Navigation and routing

| Area | Finding | Reuse strategy |
|---|---|---|
| **Entry points** | Dashboard `DashboardScreen` → section widgets; Libraries via `FolderScreen` | Add dedicated `MusicSection` on dashboard — not a fake filesystem library |
| **Routing** | Imperative `Navigator.push` + `MaterialPageRoute`; optional `RouteSettings.name` | `music_navigation.dart` helpers mirror folder navigation |
| **Back navigation** | Standard `TtsAppBar` back; Escape on search | Same on all music screens |
| **Windows desktop** | `CustomScrollView` dashboard; keyboard focus on search | ListView/Scrollbar on music screens; no new route table |
| **Scaffold conventions** | `TtsAppBar`, `EmptyState`, `LoadingCard`, `SectionHeader` | Reused throughout music screens |

### Catalogue and state access

| Area | Finding | Reuse strategy |
|---|---|---|
| **Catalogue ownership** | `CatalogService` (ChangeNotifier) + Provider | Music screens `Consumer<CatalogService>` |
| **Replacement lifecycle** | `CatalogCacheCoordinator.onCatalogReplaced` invalidates search + artwork + favourites | Extended to invalidate `MusicLibraryService` |
| **Loading / empty / degraded** | `LoadingCard`, `EmptyState`, dismissible banners | Same patterns on music landing and browse screens |
| **Projection** | No prior derived music views | New `MusicLibraryService` memoised by `catalogueIdentity` |

### Reusable UI

| Component | Reuse |
|---|---|
| `ArtworkImage` / `ArtworkService.forMediaItem` | `MusicArtworkThumbnail` wrapper |
| `EmptyState`, `LoadingCard`, `TtsAppBar` | All music screens |
| `ListView.separated` / `ListView.builder` | Artists, albums, tracks |
| `SearchResultRow` | Extended with Audio kind chip + artist·album subtitle |
| Grid patterns | Album grid on artist detail (existing card spacing) |

### M5.1 model confirmation

| Field / helper | Present | Used in 5.2 |
|---|---|---|
| `mediaKind` / `isAudio` | ✅ | Audio-only projection filter |
| `title` | ✅ | Track display; filename fallback via model |
| `artist`, `album`, `albumArtist` | ✅ | Display + search presentation |
| `trackNumber`, `discNumber` | ✅ | Album track ordering |
| `year`, `genre`, `duration` | ✅ | Album/track metadata rows (nullable) |
| `artistGroupKey`, `albumGroupKey` | ✅ | Grouping authority |
| `normalizeGroupKey` | ✅ | Legacy fallback when keys absent |

### Audit conclusion

Implement a **single derived projection layer** (`MusicLibraryProjection` + `MusicLibraryService`) rather than per-screen ad hoc grouping. Add a **dedicated Music dashboard entry** and **read-only detail screens** that do not reuse video `ItemDetailScreen` (which exposes Play).

---

## Step 2 — Architecture boundaries

| In scope | Out of scope |
|---|---|
| Dashboard Music entry | Playback transport |
| Music landing (Artists / Albums / Tracks) | Queue, shuffle, repeat |
| Artist and album browse + detail | Playlists, favourites for music |
| All-tracks browse + read-only track detail | Continue Listening / Recently Played |
| Deterministic grouping/sorting | Embedded artwork decode |
| Search row presentation for audio | Parallel search index |
| Artwork via existing pipeline | SQLite artist/album store |
| Catalogue replacement safety | ADR-022/023 acceptance |

---

## Derived view model design

```
Catalog (unified)
    └── MusicLibraryService.projectionFor(catalog)  [memoised by catalogueIdentity]
            └── MusicLibraryProjection
                    ├── tracks: List<MediaItem>        (audio only, browse-sorted)
                    ├── artists: List<MusicArtist>     (by artist_group_key)
                    └── albums: List<MusicAlbum>       (by album_group_key)
```

### MusicArtist

- `groupKey` — `artist_group_key`
- `displayName` — lexicographically first non-empty artist/albumArtist among tracks
- `albumCount`, `trackCount`
- `albums` — sorted within artist
- `tracks` — all tracks for artist (browse-sorted)
- `representativeTrack` — first album's representative, else first track by file path

### MusicAlbum

- `groupKey` — `album_group_key` (or derived: `normalize(artist)|normalize(album)|normalize(parent_folder)`)
- `displayTitle`, `displayArtist`, `year`, `genre`, `discCount`
- `tracks` — in-album sort order
- `representativeTrack` — first track by `filePath`

### Track

- Reuses `MediaItem` — no duplicate catalogue store

---

## Sorting rules (deterministic, locale-independent)

### Artists

1. Known artists A–Z (case-insensitive)
2. Unknown Artist last
3. Tie-breaker: `groupKey`

### Albums — browse view

1. Album artist / artist
2. Year ascending (albums with year before albums without)
3. Album title
4. Tie-breaker: `groupKey`

### Albums — within artist

1. Year ascending (with-year before without-year)
2. Album title
3. Tie-breaker: `groupKey`

### Tracks — within album

1. Disc number (missing → 1)
2. Track number (numbered before unnumbered)
3. Title
4. Item `id`

### Tracks — all-tracks browse

1. Title
2. Artist
3. Album
4. Item `id`

---

## Unknown and partial metadata

| Case | Behaviour |
|---|---|
| Unknown Artist | Label `Unknown Artist`; sorted last; still browsable |
| Unknown Album | Label `Unknown Album` |
| Missing year/genre/duration | Omitted from row; item still shown |
| Missing artwork | `ArtworkService` placeholder (existing pipeline) |
| Root-level audio files | Grouped via derived album key including parent folder |
| Same album title, different artists | Separate `album_group_key` buckets |
| Multi-disc albums | Ordered by disc then track number |

---

## Artwork behaviour

Representative selection (deterministic, no new cache):

**Album:** first track by `filePath` within album → `ArtworkService.forMediaItem`

**Artist:** first album's representative track, else first track by path

No embedded artwork decode in 5.2.

---

## Navigation model

```
Dashboard
 └── MusicSection → MusicScreen (landing)
         ├── MusicArtistsScreen → MusicArtistDetailScreen
         ├── MusicAlbumsScreen → MusicAlbumDetailScreen
         └── MusicTracksScreen → MusicTrackDetailScreen (read-only)

Global Search
 └── audio result → MusicTrackDetailScreen (not ItemDetailScreen)
```

Music section hidden when catalogue has zero audio items. Video `FolderScreen` and Continue Watching unchanged.

---

## Search presentation

- `SearchResultRow`: kind chip (`Video` / `Audio` / `Image`); audio subtitle `artist · album`
- `SearchScreen._openResult`: routes `isAudio` to `MusicTrackDetailScreen`
- No parallel search service or re-indexing

---

## Performance

- Lazy projection: built on first access per catalogue identity
- Memoisation in `MusicLibraryService`
- Virtualised lists (`ListView.separated` / `builder`)
- Large fixture: `large_music_catalog_factory.dart` — 100 artists × 10 albums × 20 tracks (20,000 tracks) for projection determinism tests

---

## Test strategy

| Layer | Coverage |
|---|---|
| `music_library_service_test.dart` | Grouping, sorting, collisions, memoisation, large catalogue |
| `music_library_presentation_test.dart` | Landing, navigation, empty state, catalogue replacement |
| `search_presentation_test.dart` | Audio chip, metadata line, read-only navigation |
| `phase_52_windows_runtime_test.dart` | Opt-in `PHASE_52_RUNTIME=1` Windows harness |

---

## Windows runtime strategy

```powershell
cd client\ttsplayer
$env:PHASE_52_RUNTIME='1'
flutter test test/phase_52_windows_runtime_test.dart --tags phase52-runtime
```

Optional: `PHASE_52_LOCAL_CATALOG` for local catalogue validation (not required).

---

## Risks and dependencies

| Risk | Mitigation |
|---|---|
| Large catalogue projection cost | Memoisation; single scan per identity |
| Video detail Play exposed via search | Audio routes to read-only track detail |
| Stale projection after rescan | `CatalogCacheCoordinator` invalidates `MusicLibraryService` |
| ADR-022/023 scope creep | Remain Proposed; no queue/player in 5.2 |

**Dependencies:** M5.1 complete (`9824f4e`).

---

## Definition of Done — closure reconciliation (2026-07-19)

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Navigation/UI patterns audited | **Satisfied** | Step 1 audit in this spec |
| 2 | Phase 5.2 specification exists | **Satisfied** | This document |
| 3 | Projections deterministic | **Satisfied** | `music_library_service_test.dart` — large fixture + repeat builds |
| 4 | Artists by `artist_group_key` | **Satisfied** | `MusicLibraryProjection.build`; service test |
| 5 | Albums by `album_group_key` | **Satisfied** | Projection + collision test |
| 6 | Track ordering deterministic | **Satisfied** | `MusicSorting`; disc/track tests |
| 7 | Dedicated Music entry point | **Satisfied** | `MusicSection` on dashboard |
| 8 | Music landing implemented | **Satisfied** | `MusicScreen`; presentation test |
| 9 | Artists browser | **Satisfied** | `MusicArtistsScreen` |
| 10 | Artist details | **Satisfied** | `MusicArtistDetailScreen` |
| 11 | Albums browser | **Satisfied** | `MusicAlbumsScreen` |
| 12 | Album details | **Satisfied** | `MusicAlbumDetailScreen` |
| 13 | Tracks browser | **Satisfied** | `MusicTracksScreen` |
| 14 | Unknown/partial metadata | **Satisfied** | Mixed fixture; runtime R8 |
| 15 | Artwork via existing pipeline | **Satisfied** | `MusicArtworkThumbnail` → `ArtworkService` |
| 16 | Search presents music safely | **Satisfied** | `search_result_row.dart`; search tests 5b/5c |
| 17 | No playback from browse | **Satisfied** | No play controls; presentation + runtime tests |
| 18 | No queue/shuffle/repeat/playlists | **Satisfied** | Code audit; ADR-022/023 not implemented |
| 19 | Catalogue replacement safe | **Satisfied** | `CatalogCacheCoordinator`; invalidation tests |
| 20 | Large catalogues responsive | **Satisfied** | Memoisation; 20k-track projection test |
| 21 | Windows keyboard/a11y validated | **Satisfied** | Search Semantics; runtime harness |
| 22 | Focused tests pass | **Satisfied** | `music_library_*` tests (17 cases) |
| 23 | Full Flutter suite passes | **Satisfied** | 655 passed at implementation validation |
| 24 | Opt-in runtime validation | **Satisfied** | `phase_52_windows_runtime_test.dart` — 8 scenarios |
| 25 | Video/image compatibility | **Satisfied** | Regression harness updates; no video path changes |
| 26 | Documentation reconciled | **Satisfied** | This closure pass |
| 27 | ADR-022/023 remain Proposed | **Satisfied** | ADR headers unchanged |
| 28 | M5.3 identified as next | **Satisfied** | M5 plan handoff below |

**Phase 5.2: COMPLETE.**

---

## Next phase handoff — M5.3 Music Playback and Queue

M5.3 adds **audio playback and queue** from the read-only browse surfaces delivered in M5.2. Users must be able to play a track and seed a queue from album browse.

**Gate 0 (required before 5.3 implementation):** Verify `media_kit` audio-only playback on Windows — same channel limitations as M4.4 video audit. Document result in Phase 5.3 spec.

**Expected M5.3 scope:**

- Play single track and play album from music browse surfaces
- In-memory queue with next/previous, play/pause, seek
- Shuffle and repeat (policy per ADR-022)
- Player surface per ADR-023 (staged hybrid recommended)
- Video `PlayerScreen` regression unchanged

**Out of scope for M5.3:** listening history, Continue Listening, playlists (M5.4); OS media session controls.

→ [Phase 5.3 scope](./m5-plan.md#phase-53--music-playback-and-queue)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md)
→ [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md)

---

## Implementation files

| Area | Path |
|---|---|
| Projection | `lib/features/music/models/music_library_projection.dart` |
| Service | `lib/features/music/music_library_service.dart` |
| Sorting | `lib/features/music/music_sorting.dart` |
| Screens | `lib/features/music/screens/*.dart` |
| Dashboard entry | `lib/features/dashboard/widgets/music_section.dart` |
| Search | `lib/features/search/widgets/search_result_row.dart`, `search_screen.dart` |
| Cache invalidation | `lib/services/catalog_cache_coordinator.dart` |
| Tests | `test/music_library_*`, `test/phase_52_windows_runtime_test.dart` |
| Large fixture | `test/support/large_music_catalog_factory.dart` |
