# M5 Phase 5.1 — Music Catalogue and Metadata

**Status:** ✅ **COMPLETE** (2026-07-19)
**Milestone:** M5 — Music
**Branch:** `m4-development`
**Development version:** `v0.5.0` (M4 release baseline)
**Predecessor:** Phase 5.0 complete (2026-07-19)
**Next phase:** [M5.2 — Music Library Experience](./m5-plan.md#phase-52--music-library-experience)

→ [M5 plan](./m5-plan.md#phase-51--music-catalogue-and-metadata)
→ [Music architecture](../architecture/music.md)
→ [ADR-020](../architecture/decisions/ADR-020-music-catalogue-schema-and-media-kind.md)
→ [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md)

**ADRs (Accepted):**

- [ADR-020: Music Catalogue Schema and Media Kind](../architecture/decisions/ADR-020-music-catalogue-schema-and-media-kind.md)
- [ADR-021: Music Metadata Precedence and Identity](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md)

---

## Objective

Extend the scanner and catalogue model to represent music items with optional embedded-tag metadata while retaining backward compatibility for video and image libraries. No music UI, queue, playback surface, or listening-state scope in this phase.

---

## Step 1 — Repository and scanner audit (pre-implementation baseline)

Audit completed **2026-07-19** before production changes. Findings below reflect the M4-complete / M5.0-planning codebase.

### Catalogue schema and parser

| Area | Finding |
|---|---|
| **Catalogue version** | `catalogue_version: 2` in scanner and bundled fixtures |
| **Top-level structure** | `generated_at`, `total_items`, `sources`, `catalogue` block, `scan`, `folders`, optional `warnings` |
| **Media item fields** | `id`, `title`, `year`, `duration_seconds`, `file_path`, `thumbnail_path`, `size_bytes`, `status`, optional `added_at` — no `media_kind`, no music fields |
| **Missing / unknown fields** | Dart `MediaItem.fromJson` reads known keys only; unknown JSON keys ignored safely |
| **Version validation** | Permissive: `CatalogueInfo.catalogueVersion` defaults to `1` if absent; no hard reject for v2 |
| **Compatibility** | No migration layer — client parses whatever fields exist |
| **Item identity** | `md5(normalized path)` via `path_id()` / stable path string |
| **Folder identity** | Same path-derived md5 on folder `path` |
| **Media-type assumptions** | Extension sets in `SupportedExtensions`; video playback and Continue Watching implicitly video-only via file extension / folder browse; search indexed title + file path only |

### Scanner (`backend/indexer.py`)

| Area | Finding |
|---|---|
| **Audio extensions** | **None** — video + image only before M5.1 |
| **Allowlists** | `_VIDEO_EXTENSIONS`, `_IMAGE_EXTENSIONS`, union `SUPPORTED_EXTENSIONS` |
| **Sidecar exclusions** | Named artwork sidecars + stem-matched images beside **video** stems |
| **Metadata extraction** | `ffprobe` for duration only (subprocess, stdlib) |
| **Path normalisation** | `normalize_path()` — `normcase` + `normpath` |
| **Ordering** | Sorted `iterdir()` — folders after files, case-insensitive name |
| **Item ID** | `hashlib.md5(path.encode())` |
| **Folder grouping** | Recursive folder tree; root-level files grouped under root-named node |
| **Atomic writes** | Temp file + rename (`write_atomic`) |
| **Schema version emission** | `CATALOGUE_VERSION = 2`, `SCANNER_VERSION = "0.3.x"` |
| **Tests** | `test_indexer.py` — extensions, sidecars, library rescan merge, `added_at` |

### Flutter application

| Area | Finding |
|---|---|
| **Models** | `MediaItem` immutable; no music fields; status via `MediaItemStatus.fromString` with safe default |
| **Fixtures** | Bundled mock catalog v2; test factories in `large_catalog_factory.dart`, diagnostics harness |
| **Search** | Blob = title + folder names + file path segments |
| **Artwork** | Sidecar discovery keyed on video stems + named sidecars |
| **Playback** | Video-oriented `PlaybackService`; Continue Watching all indexed items with resume state |
| **Diagnostics** | Aggregate counts only — no media-kind breakdown |
| **Risk points** | Continue Watching would include audio once indexed; search would not index artist/album without extension |

### Audit conclusion

ADR-020 direction validated: bump to **catalogue version 3**, add explicit **`media_kind`**, optional music metadata on items, single unified catalogue, client-side v2 inference — **no migration file**. ADR-021 precedence and grouping keys implementable via scanner module + `ffprobe` tags without new pip dependencies.

---

## Step 2 — Catalogue design (implemented)

| Decision | Implementation |
|---|---|
| **Catalogue version** | Scanner emits `catalogue_version: 3`; client loads v2 and v3 |
| **Media kind** | JSON string `video` \| `audio` \| `image`; Dart enum `MediaKind` + `unknown` |
| **Legacy v2** | Missing `media_kind` inferred from file extension (`inferMediaKind`) |
| **Music fields** | Optional: `artist`, `album`, `album_artist`, `track_number`, `disc_number`, `genre`, `year` (when tagged), `artist_group_key`, `album_group_key` |
| **Track identity** | Unchanged path-derived `id` |
| **Unified catalogue** | No parallel music catalogue |

**Terminology:** *Music* is the milestone and product area; catalogue JSON and Dart enums use **`audio`** as the media-kind value for indexed music files (ADR-020).

---

## Step 3 — Metadata extraction (implemented)

| Topic | Choice |
|---|---|
| **Dependency** | **ffprobe** (already used for duration) — JSON tag output via subprocess |
| **Why** | Stdlib-only scanner rule; mature tag coverage; same binary as video duration |
| **Formats indexed** | `.mp3`, `.m4a`, `.aac`, `.flac`, `.wav`, `.ogg`, `.opus`, `.wma` |
| **Windows** | Same subprocess path as existing ffprobe duration calls |
| **Failure behaviour** | Per-file try/except; fallback metadata from folder/filename; scan continues |
| **Playback note** | All listed formats are catalogued; guaranteed playback is **M5.3** scope |
| **Licensing** | ffprobe/ffmpeg external binary — unchanged from M4 video stack |

Module: `backend/music_metadata.py`

---

## Step 4 — Metadata precedence and fallback (implemented)

See [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md) for normative rules.

**Folder layouts supported:**

```text
Music/Artist/Album/track.mp3     → artist folder + album folder
Music/Album/track.mp3            → album folder only (artist from tags or Unknown Artist)
Music/track.mp3                  → root-level; artist/album from tags or Unknown
```

**Normalisation:** trim whitespace; empty → missing; integer/year parsing without locale; multi-value tags use first non-empty value.

**Deferred to later phases:** compilation / Various Artists sentinel (ADR-021 §4) — not required for catalogue emission in 5.1.

---

## Step 5 — Deterministic identity (implemented)

| Entity | Rule |
|---|---|
| **Track** | `id = md5(file_path)` — unchanged; metadata edits do not change id |
| **Artist grouping** | `artist_group_key = normalize(resolved artist)` — NFKC casefold, collapsed whitespace |
| **Album grouping** | `album_group_key = normalize(album_artist or artist) + "\|" + normalize(album) + "\|" + normalize(parent_folder_path)` |

The third component (`normalize(str(file_path.parent))`) scopes unknown albums and shallow layouts so identical album display names under different artists or folders do not collide.

**Implementation reference:** `backend/music_metadata.py` — `build_music_metadata()`.

---

## Step 6–8 — Implementation summary

### Scanner (`indexer.py`)

- `SCANNER_VERSION = "0.4.0"`, `CATALOGUE_VERSION = 3`
- Audio extensions in `SUPPORTED_EXTENSIONS`
- `make_item()` emits `media_kind`; audio items merge `music_metadata.build_music_metadata()`
- Artwork sidecar logic extended for audio folders
- Images skip duration probe; video/audio retain duration ffprobe

### Flutter

- `lib/models/media_kind.dart` — central enum
- `lib/utils/media_kind_inference.dart` — legacy inference
- `MediaItem` — optional music fields + `isContinueWatchingEligible` (video only)
- `SearchService` — indexes artist/album/album_artist/genre for audio items
- `PlaybackService.getContinueWatching` — skips non-video items

### Out of scope (confirmed not implemented)

Music library UI, artist/album screens, queue, MusicPlayerScreen, playlists, shuffle, repeat, Continue Listening, listening history, embedded artwork extraction pipeline, compilation flag, media-kind diagnostics counts.

---

## Step 9–10 — Fixtures and tests

| Suite | Coverage |
|---|---|
| `backend/test_music_metadata.py` | Normalisation, precedence, grouping collision |
| `backend/test_indexer.py` (`MusicIndexingTests`) | Extensions, scan tree, sidecars, v3 constant |
| `test/music_catalog_compatibility_test.dart` | v2/v3 parse, inference, unknown kind |
| `test/music_service_compatibility_test.dart` | Search, Continue Watching, artwork, favourites, diagnostics |
| `test/supported_extensions_sync_test.dart` | Dart/Python extension parity |

Legacy v2 fixtures retained in `test/support/music_catalog_fixtures.dart`.

---

## Step 11 — Validation results

**Environment:** Windows 10, Python 3.x, Flutter test runner (2026-07-19)

| Layer | Result |
|---|---|
| Python `test_indexer.py` + `test_music_metadata.py` | **27 passed**, 0 failed |
| Flutter focused music tests | **12 passed** |
| Flutter full suite | **636 passed**, **8 skipped**, 0 failed |

**Deferred runtime validation:** Opt-in scan of personal music library not required for phase completion.

---

## Phase 5.1 Definition of Done — closure reconciliation (2026-07-19)

| # | Criterion | Status |
|---|---|---|
| 1 | Current catalogue and scanner behaviour was audited | ✅ |
| 2 | Catalogue version 3 is implemented and documented | ✅ |
| 3 | Version 2 catalogues remain compatible | ✅ |
| 4 | Media kind is explicit and safely parsed | ✅ |
| 5 | Supported audio extensions are documented and tested | ✅ |
| 6 | Music metadata extraction is implemented with graceful per-file failure | ✅ |
| 7 | Metadata precedence and fallback rules are deterministic | ✅ |
| 8 | Track identity remains stable across metadata-only rescans | ✅ |
| 9 | Artist grouping keys are deterministic | ✅ |
| 10 | Album grouping keys are deterministic and collision-safe | ✅ |
| 11 | Missing and corrupt metadata are handled safely | ✅ |
| 12 | Existing video and image behaviour remains compatible | ✅ |
| 13 | Search tolerates and indexes audio metadata | ✅ |
| 14 | Continue Watching excludes audio items | ✅ |
| 15 | Artwork, favourites, diagnostics, caches, and catalogue replacement tolerate mixed media | ✅ |
| 16 | Scanner fixtures and tests cover music and regression behaviour | ✅ |
| 17 | Dart fixtures and tests cover catalogue versions 2 and 3 | ✅ |
| 18 | Full relevant scanner and Flutter test suites pass | ✅ |
| 19 | ADR-020 and ADR-021 are Accepted | ✅ |
| 20 | ADR-022 and ADR-023 remain Proposed | ✅ |
| 21 | No music UI, queue, playback surface, or listening-state scope was introduced | ✅ |
| 22 | Documentation and indexes are reconciled | ✅ |
| 23 | M5.2 is identified as the next active phase | ✅ |

**Phase 5.1: COMPLETE.**

---

## Next phase handoff — M5.2 Music Library Experience

M5.2 builds **read-only music browsing** over the catalogue foundation established in M5.1. Artist, album, and track views are **derived** from catalogue metadata and grouping keys — not new filesystem nodes.

**Expected M5.2 scope:**

- Music entry point and navigation
- Artist, album, and track browsing
- Derived artist and album views using `artist_group_key` and `album_group_key`
- Sorting and grouping for browse surfaces
- Metadata presentation (including partial and unknown metadata)
- Empty and unknown-metadata honest states
- Artwork placeholder behaviour via existing `ArtworkService`
- Search integration appropriate to music browsing (presentation over existing index)

**Explicitly out of M5.2 scope** (unless a later plan amendment says otherwise):

- Playback queue
- Shuffle and repeat
- MusicPlayerScreen
- Listening history and Continue Listening
- Playlists
- Multi-device synchronisation

→ [Phase 5.2 scope](./m5-plan.md#phase-52--music-library-experience)

---

## Implementation commits

| Commit | Message |
|---|---|
| `6e646ba` | `docs(m5): record music catalogue audit findings` |
| `dadf4cc` | `feat(catalogue): add media kind and music metadata model` |
| `a32a1a3` | `feat(scanner): index music metadata in catalogue v3` |
| `5d722ed` | `test(m5): cover music catalogue metadata and compatibility` |
| `b83dabb` | `docs(m5): reconcile music catalogue architecture and ADRs` |
