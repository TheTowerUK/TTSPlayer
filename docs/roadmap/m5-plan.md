# M5 — Music

**Status:** **In progress** — Phase 5.3 Gate 0 complete (2026-07-20); Phase 5.2 complete
**Branch:** `m5-development`
**Development version:** `v0.5.0` (M4 release baseline)
**Predecessor:** M4 — tag `v0.5.0` / `m4-complete` (2026-07-19)

→ [Music architecture](../architecture/music.md)
→ [M4 release summary](../release/m4-release-summary.md)
→ [Roadmap principles](./principles.md)
→ [Architecture index](../architecture/README.md)
→ [ADR framework](../architecture/decisions/README.md)

> **Scope note:** M5 adds **audio music libraries** to the existing folder-tree platform. It does not replace video workflows, invent virtual libraries, or introduce multi-device sync. Books and comics remain M6.

---

## Mission

M5 extends TTSPlayer from a polished **video-first personal media application** into a platform that also supports **music listening** — browsing by artist and album, queue-based playback, and application-managed listening state — while preserving:

- Filesystem-driven library structure
- Provider-neutral media access (local, UNC, HTTPS)
- Single catalogue, search, artwork, caching, and diagnostics stack
- Backward-compatible catalogue evolution
- Graceful degradation for missing or inconsistent tags
- Incremental, independently testable sub-phases

---

## Engineering principles (M5)

1. **Architecture before implementation** — document cross-layer behaviour and ADRs before code.
2. **Documentation before code** — each sub-phase begins with an updated architecture note or ADR where decisions are non-obvious.
3. **Filesystem and media files remain the source of truth** for what content exists and where it lives.
4. **Embedded metadata enriches; it does not replace** folder structure. Absent, inconsistent, or malformed tags must not block indexing or playback.
5. **User state is application-managed** — favourites, playlists, play history, queue, and listening progress live outside `catalog.json`.
6. **Reuse M4 infrastructure** — provider, settings, `MediaLocationResolver`, `SearchService`, `ArtworkService`, cache invalidation, diagnostics, and Windows runtime harness patterns.
7. **No parallel systems** — no second catalogue, search service, artwork cache, provider chain, or diagnostics pipeline for music.
8. **Video behaviour must not regress** — music work must not break existing folder browsing, Continue Watching, or video playback.
9. **Music UI may differ from video UI** where the content model genuinely requires it (album grid vs folder grid).
10. **Record significant decisions as ADRs** — see [proposed ADR list](#proposed-adrs-m50-assessment).

### Explicit exclusions (M5 milestone)

| Exclusion | Notes |
|---|---|
| Multi-device synchronization | Document future compatibility only |
| Mobile platform release | Windows-first; parity where practical later |
| Books, comics, documents | M6 |
| M4 dashboard cosmetic debt | Deferred unless explicitly pulled into M5 scope |
| TMDB / MusicBrainz / external metadata APIs | Out of scope unless later approved |
| Cloud accounts, transcoding, virtual libraries | Out of scope |

---

## Phase structure

Implement in order unless a documented dependency allows parallel documentation work during planning. Each sub-phase defines objective, scope, out-of-scope, dependencies, definition of done, validation, and documentation outputs.

| Sub-phase | Focus | Status |
|---|---|---|
| **5.0** | Planning and Architecture | ✅ Complete (2026-07-19) |
| **5.1** | Music Catalogue and Metadata | ✅ Complete (2026-07-19) — [spec](./m5-phase-5.1-music-catalogue-metadata.md) |
| **5.2** | Music Library Experience | ✅ Complete (2026-07-19) — [spec](./m5-phase-5.2-music-library-experience.md) |
| **5.3** | Music Playback and Queue | ✅ Complete (2026-07-21) — [spec](./m5-phase-5.3-music-playback-queue.md) |
| **5.4** | Music State and Listening History | **Active (planning)** — [spec](./m5-phase-5.4-listening-history-continue-listening.md) |
| **5.5** | Performance, Diagnostics and Runtime Validation | Planned |
| **5.6** | Release and Documentation | Planned |

---

### Phase 5.0 — Planning and Architecture

**Status:** ✅ **COMPLETE** (2026-07-19)

**Objective:** Define M5 scope, terminology, catalogue implications, playback architecture options, application state, diagnostics, validation strategy, and milestone Definition of Done.

**Scope:**

- This roadmap document and [music.md](../architecture/music.md)
- Proposed ADRs for durable cross-layer decisions
- Index updates (`MILESTONES.md`, architecture/release/roadmap indexes)
- Risk register and open questions

**Out of scope:**

- Production code, tests, scanner changes, schema implementation, UI, playback implementation

**Dependencies:** M4 complete (`v0.5.0`).

**Definition of done:**

- [x] `m5-plan.md` and `music.md` reviewed and linked from indexes
- [x] Sub-phases 5.1–5.6 defined with scope, out-of-scope, and phase DoD
- [x] Proposed ADRs authored for genuine decision areas (not Accepted)
- [x] Milestone-level DoD drafted
- [x] Risks and open questions recorded
- [x] No production code changed

#### Phase 5.0 closure — Definition-of-done reconciliation (2026-07-19)

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | M5 milestone scope defined | **Satisfied** | Mission, exclusions, milestone DoD |
| 2 | M5 principles documented | **Satisfied** | Engineering principles § |
| 3 | Phases 5.0–5.6 defined | **Satisfied** | Phase structure table |
| 4 | Every phase has scope, out-of-scope, DoD | **Satisfied** | §5.0–5.6 sections |
| 5 | Music architecture Planned / Proposed | **Satisfied** | [music.md](../architecture/music.md) status |
| 6 | M4 platform reuse identified | **Satisfied** | [music.md](../architecture/music.md) §2; Dependencies table |
| 7 | Catalogue and metadata implications documented | **Satisfied** | [music.md](../architecture/music.md) §4–§7; ADR-020–021 |
| 8 | Identity, precedence, artwork, grouping, playback, queue, state, search, cache, diagnostics, compatibility, migration covered | **Satisfied** | [music.md](../architecture/music.md) §5–§20 |
| 9 | Risks and dependencies documented | **Satisfied** | Risks §; Dependencies on M4 § |
| 10 | Testing and Windows runtime strategies documented | **Satisfied** | [music.md](../architecture/music.md) §19; phase validation sections |
| 11 | Durable decisions have Proposed ADRs | **Satisfied** | ADR-020–023 **Proposed** |
| 12 | No production implementation | **Satisfied** | Docs-only commits |
| 13 | Indexes and milestone references reconciled | **Satisfied** | MILESTONES, roadmap, architecture, release indexes |
| 14 | M5.1 identified as next active phase | **Satisfied** | Handoff § below |

**Phase 5.0: COMPLETE.** Next M5 phase: **5.1 Music Catalogue and Metadata**.

#### Next phase handoff — M5.1 Music Catalogue and Metadata

Phase 5.1 begins with a **focused repository and scanner audit** before production implementation. The audit validates:

- Current `catalog.json` schema and `MediaItem` parser behaviour
- `catalogue_version` compatibility handling in `CatalogService`
- Scanner extension sets (`SUPPORTED_EXTENSIONS`) and audio-extension gap
- Path-derived `id` generation (stable identity)
- Metadata extraction options (`ffprobe`, tag libraries) and **standard-library-only** constraint implications
- Existing fixtures and test factories for catalogue parsing
- Video and image backward compatibility on mixed catalogues
- Unknown or missing metadata behaviour (graceful degradation)
- Whether proposed **`catalogue_version: 3`** and **`media_kind`** should be **Accepted** as specified in ADR-020
- Deterministic grouping and identity rules proposed in ADR-021

Phase 5.1 produces an implementation specification and accepts ADR-020/021 when implementation boundaries are locked — not during 5.0 closure.

→ [Phase 5.1 scope](#phase-51--music-catalogue-and-metadata)

**Documentation outputs:**

- [music.md](../architecture/music.md)
- Proposed ADRs ADR-020–023
- Updated milestone indexes

---

### Phase 5.1 — Music Catalogue and Metadata

**Status:** ✅ **COMPLETE** (2026-07-19) — [Phase 5.1 spec](./m5-phase-5.1-music-catalogue-metadata.md)

**Objective:** Extend the scanner and catalogue model to represent music items with optional embedded-tag metadata while retaining backward compatibility for video and image libraries.

**Scope (delivered):**

- `media_kind` classification: **video**, **audio**, **image** on catalogue items
- Optional music metadata fields: artist, album, album artist, title, track number, disc number, genre, year (when tagged), `artist_group_key`, `album_group_key`
- Stable item `id` (path-derived, unchanged)
- Scanner tag extraction via **ffprobe** with folder-derived fallbacks
- `catalogue_version: 3`, scanner `0.4.0` (ADR-020 **Accepted**)
- Missing/incomplete tag behaviour — filename stem, folder names, “Unknown Artist/Album”
- Artwork sidecar rules extended for audio folders (embedded artwork pipeline deferred)
- Atomic catalogue writes preserved

**Out of scope (confirmed):**

- Music UI surfaces (5.2)
- Queue or listening state (5.3–5.4)
- External metadata APIs
- SQLite or secondary catalogue store

**Dependencies:** Phase 5.0 complete; [ADR-020](../architecture/decisions/ADR-020-music-catalogue-schema-and-media-kind.md), [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md) — **Accepted**.

**Definition of done:**

- [x] Supported audio extensions defined and documented (`.mp3`, `.m4a`, `.aac`, `.flac`, `.wav`, `.ogg`, `.opus`, `.wma`)
- [x] `catalog.json` schema extension documented with backward compatibility proof
- [x] Indexer emits `media_kind` and optional music fields; video/image items unchanged
- [x] Client parses new fields; unknown fields ignored; video browse/play unchanged
- [x] Unit tests for indexer and `MediaItem` parsing
- [x] ADR-020, ADR-021 **Accepted**

**Validation (2026-07-19):**

- Python scanner/metadata tests: **27 passed**
- Flutter music-focused tests: **12 passed**
- Flutter full suite: **636 passed**, **8 skipped**

#### Phase 5.1 closure — Definition-of-done reconciliation (2026-07-19)

| # | Criterion | Verdict |
|---|---|---|
| 1 | Catalogue and scanner audited | **Satisfied** |
| 2 | Catalogue version 3 implemented and documented | **Satisfied** |
| 3 | Version 2 catalogues remain compatible | **Satisfied** |
| 4 | Media kind explicit and safely parsed | **Satisfied** |
| 5 | Supported audio extensions documented and tested | **Satisfied** |
| 6 | Metadata extraction with graceful per-file failure | **Satisfied** |
| 7 | Precedence and fallback deterministic | **Satisfied** |
| 8 | Track identity stable across metadata-only rescans | **Satisfied** |
| 9 | Artist grouping keys deterministic | **Satisfied** |
| 10 | Album grouping keys deterministic and collision-safe | **Satisfied** |
| 11 | Missing/corrupt metadata handled safely | **Satisfied** |
| 12 | Video and image behaviour compatible | **Satisfied** |
| 13 | Search indexes audio metadata | **Satisfied** |
| 14 | Continue Watching excludes audio | **Satisfied** |
| 15 | Artwork, favourites, diagnostics, caches tolerate mixed media | **Satisfied** |
| 16 | Scanner tests cover music and regressions | **Satisfied** |
| 17 | Dart tests cover catalogue v2 and v3 | **Satisfied** |
| 18 | Full relevant test suites pass | **Satisfied** |
| 19 | ADR-020 and ADR-021 Accepted | **Satisfied** |
| 20 | ADR-022 and ADR-023 remain Proposed | **Satisfied** |
| 21 | No music UI, queue, playback surface, or listening state | **Satisfied** |
| 22 | Documentation and indexes reconciled | **Satisfied** |
| 23 | M5.2 identified as next active phase | **Satisfied** |

**Phase 5.1: COMPLETE.** Next M5 phase: **5.2 Music Library Experience**.

#### Next phase handoff — M5.2 Music Library Experience

M5.2 delivers **read-only music browsing** over the M5.1 catalogue foundation. Views are derived from `artist_group_key`, `album_group_key`, and track metadata — not filesystem invention.

**In scope:** music entry/navigation; artist, album, and track browse surfaces; sorting and grouping; metadata and artwork placeholder presentation; unknown/partial-metadata states; search presentation for music results.

**Out of scope:** playback queue; shuffle/repeat; MusicPlayerScreen; listening history; Continue Listening; playlists; multi-device sync.

→ [Phase 5.2 scope](#phase-52--music-library-experience)

---

### Phase 5.2 — Music Library Experience

**Status:** ✅ **COMPLETE** (2026-07-19)

**Objective:** Deliver dedicated music browsing surfaces that reflect how users think about music (artists, albums, tracks) without breaking filesystem-driven Libraries.

**Scope (delivered):**

- Dashboard `MusicSection` entry when catalogue contains audio
- **Artists**, **Albums**, **Tracks** views derived via `MusicLibraryProjection`
- Artist detail and album detail screens (read-only)
- Read-only track detail from tracks list and global search
- Unknown artist / unknown album honest labels
- Music-aware search presentation (`Audio` kind chip, artist·album subtitle)
- Album/artist artwork via existing `ArtworkService` pipeline
- Memoised projection + virtualised lists; large-catalogue test fixture

**Out of scope (confirmed not delivered):**

- Playback, queue, shuffle, repeat (5.3)
- Playlists, listening history, Continue Listening (5.4)
- Replacing video `FolderScreen` for mixed folders
- Embedded artwork decode
- ADR-022/023 acceptance

**Dependencies:** Phase 5.1 complete.

**Definition of done:**

- [x] User can browse music by artist, album, and track from dashboard entry point
- [x] Album and artist detail screens show artwork, metadata, and track list (no play controls)
- [x] Unknown/incomplete metadata does not hide items
- [x] Music search results appear in global search with clear media context
- [x] Video folder browsing unchanged on regression
- [x] Widget and service tests for primary music screens
- [x] Opt-in Windows runtime harness (`PHASE_52_RUNTIME=1`)

#### Phase 5.2 closure — Definition-of-done reconciliation (2026-07-19)

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Read-only music browse from dashboard | **Satisfied** | `MusicSection`, `MusicScreen` |
| 2 | Derived artist/album/track views | **Satisfied** | `MusicLibraryProjection` |
| 3 | Grouping by M5.1 keys | **Satisfied** | Service tests |
| 4 | No playback or queue introduced | **Satisfied** | Code + widget tests |
| 5 | Search music presentation | **Satisfied** | `SearchResultRow`, search tests |
| 6 | Catalogue replacement safe | **Satisfied** | `CatalogCacheCoordinator` |
| 7 | Tests and runtime harness | **Satisfied** | 655 suite pass; `PHASE_52_RUNTIME` |
| 8 | ADR-022/023 remain Proposed | **Satisfied** | ADR status |
| 9 | Documentation reconciled | **Satisfied** | Phase spec + indexes |
| 10 | M5.3 identified as next | **Satisfied** | Handoff below |

**Phase 5.2: COMPLETE.** Next M5 phase: **5.3 Music Playback and Queue**.

#### Next phase handoff — M5.3 Music Playback and Queue

**Gate 0:** Verify `media_kit` audio-only playback on Windows before queue implementation (see [music.md](../architecture/music.md) §19).

M5.3 adds play track, play album, queue next/previous, seek, shuffle, and repeat from music browse surfaces. ADR-022 and ADR-023 should be **Accepted** when those decisions are implemented — not before.

→ [Phase 5.2 specification](./m5-phase-5.2-music-library-experience.md)
→ [Phase 5.3 scope](#phase-53--music-playback-and-queue)

---

### Phase 5.3 — Music Playback and Queue

**Status:** ✅ **COMPLETE** (2026-07-21)

**Objective:** Audio-focused playback using the existing `PlaybackService` foundation — play track, play album, queue, next/previous, seek, shuffle, repeat.

#### Gate 0 — Windows audio capability (complete 2026-07-20)

**Verdict:** **PASSED** — shared `PlaybackService` supports audio-only sessions without mandatory `VideoController`. WAV local playback verified; HTTPS and MP3 rows optional via env/ffmpeg.

**Deliverables:** `PlaybackSessionMode`, media-kind-aware init, `playback_audio_gate_test.dart`, `phase_53_audio_gate_windows_runtime_test.dart` (`PHASE_53_AUDIO_GATE=1`).

**Recommendation:** Outcome A (shared service) + dedicated `MusicPlayerScreen` (ADR-023 staged hybrid). ADR-022/023 remain **Proposed**.

→ [Phase 5.3 specification](./m5-phase-5.3-music-playback-queue.md)

**Scope (planned):**

- Play single track and play album (queue seed)
- In-memory queue with next/previous, play/pause, seek
- Shuffle and repeat modes (document policy)
- Playback rate policy for music (may differ from video — ADR-011 extension or music-specific default)
- Unavailable track handling in queue (skip vs stop — document)
- Error recovery aligned with [ADR-013](../architecture/decisions/ADR-013-playback-error-taxonomy.md)
- Player surface decision per [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md) — **staged hybrid recommended in 5.0** (shared service, dedicated music player UI)

**Out of scope:**

- Background OS media session / lock-screen controls (document as future)
- Cross-device queue sync
- Gapless playback (defer unless Gate 0 proves feasible)
- Video player regression work unrelated to shared service extraction

**Dependencies:** Phase 5.2 complete (minimum: track list → play); [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md).

**Definition of done:**

- [x] User can play a track and an album from music browsing surfaces
- [x] Queue next/previous and seek work for local and HTTPS paths via resolver
- [ ] Shuffle/repeat behaviour documented and tested *(deferred post-5.3)*
- [x] Video playback from `PlayerScreen` unchanged on regression
- [x] Service-layer tests for queue lifecycle

**Validation expectations:**

- Unit tests for queue controller logic
- Windows desktop manual QA for audio playback (media_kit audio path)
- Document `flutter test` limitations for media init (same as 4.4)

---

### Phase 5.4 — Music State and Listening History

**Status:** **PLANNING** — [Phase 5.4 spec](./m5-phase-5.4-listening-history-continue-listening.md)

**Objective:** Persistent music listening history and Continue Listening / Recently Played — isolated from video Continue Watching.

**Scope (5.4 increment — see spec for detail):**

| Capability | 5.4 target |
|---|---|
| Recently played (music) | **Required** |
| Continue Listening (resume position) | **Required** |
| Completed-track policy | **Required** |
| Clear listening history | **Required** |
| Catalogue replacement reconciliation | **Required** |
| Favourite tracks / albums / artists | **Deferred** (out of 5.4 scope) |
| Queue persistence across app restart | **Deferred outside Phase 5.4** — no queue serialization or restoration (ADR-022 queue section) |
| Play counts | **Defer** |
| User playlists | **Defer** |

**Out of scope:**

- Video Continue Watching changes
- Favourites changes
- Queue persistence across app restart — **explicitly deferred outside Phase 5.4**
- Main dashboard music Continue Listening
- Multi-device history sync
- Scanner / schema changes

**Dependencies:** Phase 5.3 complete; [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) (**Partially Accepted** at 5.4 closure — listening history only).

**Definition of done:**

- [ ] `MusicListeningRepository` at isolated key; video keys untouched
- [ ] Continue Listening and Recently Played on **Music landing only** (not dashboard)
- [ ] Resume (30 s threshold) and replay (completed from 0) semantics implemented
- [ ] Catalogue replacement prune + same-`trackId` retention (R9)
- [ ] Retention: 100 stored / 20 UI cap; clear history with confirmation
- [ ] Diagnostics summary counts only
- [ ] ADR-022 **Partially Accepted** — not fully Accepted until queue persistence ships
- [ ] Windows runtime (incl. R9) + manual QA pass

---

### Phase 5.5 — Performance, Diagnostics and Runtime Validation

**Objective:** Music-specific performance, cache behaviour, diagnostics, and Windows runtime harness coverage.

**Scope (planned):**

- Large music catalogue indexing and client parse performance
- Search index build cost with audio items
- Artwork cache pressure (many album thumbnails)
- Lazy loading for artist/album lists
- Queue size limits and memory
- Catalogue replacement → stale queue/history reconciliation
- Diagnostics sections: music library counts, queue depth, last error (redacted)
- Windows runtime harness `PHASE_5x_RUNTIME` scenarios (pattern from M4)

**Out of scope:**

- New telemetry or upload pipelines
- Micro-benchmark gates that flake in CI

**Dependencies:** Phases 5.1–5.4 feature-complete.

**Definition of done:**

- [ ] Deterministic tests for catalogue replace → music state prune
- [ ] Diagnostics snapshot includes music/queue summary fields
- [ ] Windows runtime matrix executed and recorded
- [ ] No regression in Phase 4.x harness suites

---

### Phase 5.6 — Release and Documentation

**Objective:** Close M5 with the same release discipline as M4 — audit, regression, manual QA, release summary, version and tags.

**Scope:**

- Cross-phase documentation reconciliation
- Full `flutter test` and analyze reporting
- Manual Windows QA checklist (music-specific + video regression)
- Release summary document (pattern: [m4-release-summary.md](../release/m4-release-summary.md))
- Version bump and tags — **version TBD** at closure (do not assume in 5.0)

**Out of scope:**

- New feature work
- M4 cosmetic fixes unless release blockers

**Dependencies:** Phases 5.1–5.5 complete.

**Definition of done:**

- [ ] Milestone DoD reconciled
- [ ] ADRs Accepted where implemented
- [ ] Release documentation complete
- [ ] Video regression checklist pass
- [ ] Tags applied per release discipline

---

## Milestone Definition of Done (M5)

M5 is complete when:

- [ ] Music audio files are indexed with `media_kind` and optional tag metadata
- [ ] Client loads mixed catalogues without breaking video/image libraries
- [ ] User can browse music by artist, album, and track
- [ ] User can play tracks and albums with queue next/previous
- [ ] Shuffle and repeat behave as documented
- [ ] Required listening state works (favourites, recently played, Continue Listening, queue persistence per ADR-022)
- [ ] Music appears in search with appropriate presentation
- [ ] Album artwork uses existing cache pipeline
- [ ] Large music libraries remain usable (performance acceptance criteria in 5.5 spec)
- [ ] Diagnostics expose music/queue summary without secrets
- [ ] Automated tests pass; Windows runtime harnesses pass
- [ ] Manual Windows QA complete
- [ ] Architecture docs and ADRs reconciled
- [ ] Release documentation and tags complete
- [ ] **No regressions** to existing video folder browse, Continue Watching, playback, provider, or settings behaviour

---

## M5 ADRs

| ADR | Title | Status |
|---|---|---|
| [ADR-020](../architecture/decisions/ADR-020-music-catalogue-schema-and-media-kind.md) | Music Catalogue Schema and Media Kind | **Accepted** (M5.1) |
| [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md) | Music Metadata Precedence and Identity | **Accepted** (M5.1) |
| [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) | Music Queue and Listening State | **Partially Accepted** (M5.4 — listening history) |
| [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md) | Music Player Surface Architecture | **Accepted** (M5.3) |

No additional ADRs proposed for M5.0. Settings changes (e.g. music default shuffle) can extend ADR-011 in Phase 5.3 spec if needed.

---

## Risks

| Risk | Mitigation (planned) |
|---|---|
| Inconsistent or missing music tags | Precedence rules (ADR-021); folder/filename fallbacks; never hide items |
| Duplicated albums/artists (tag normalization) | Case-folding and display normalization rules; document ambiguity |
| Compilation albums | `album artist` vs `artist` rules; “Various Artists” bucket |
| Multi-disc releases | Disc number + album identity key |
| Filename vs tag disagreement | Document precedence; no silent overwrite of user-visible title |
| Stable identity across rescans | Path-derived `id`; metadata changes do not change id |
| Large libraries and artwork volume | Reuse LRU artwork cache; lazy UI; 5.5 performance gates |
| Queue restoration after catalogue changes | Prune unavailable tracks; ADR-022 policies |
| Unsupported audio formats | Indexer `unsupported` / omit policy; clear client messaging |
| Platform playback capabilities | Gate 0 audio audit before 5.3; Windows-first |
| Video workflow regressions | Parallel regression harness; video manual QA in 5.6 |
| Premature multi-device coupling | Explicitly out of scope; state keys local-only |

---

## Dependencies on M4 platform

| M4 capability | M5 reuse |
|---|---|
| `CatalogService` + provider fallback | Single catalogue load path |
| `MediaLocationResolver` | Audio file URIs local/HTTPS |
| `SettingsRepository` | Music preferences envelope (future) |
| `LibraryMetadataRepository` | Pattern for favourites — extend or sibling repo |
| `SearchService` | Extend index + presentation |
| `ArtworkService` + cache coordinator | Album art |
| `PlaybackService` | Extend for audio queue — do not fork |
| `DiagnosticsService` | Extend snapshot sections |
| Windows runtime harness pattern | `PHASE_5x_RUNTIME` |

---

## Cross-phase constraints

| Constraint | Rationale |
|---|---|
| No second catalogue file | Single `catalog.json` remains source of scanned truth |
| No invented top-level “Music” library | Folder names from filesystem only |
| No MusicBrainz in M5 | Local-first; tags from files |
| Continue Watching (video) unchanged | Separate listening state namespace |
| Atomic catalogue writes | M2+ invariant preserved |

---

## Delivery cadence

Each sub-phase follows the M4 lifecycle:

1. **Plan** — update phase spec section and architecture doc
2. **Document architecture** — accept ADRs when decisions lock
3. **Implement** — focused commits per sub-phase
4. **Test** — unit/widget tests; `flutter analyze`
5. **Hardware/runtime validation** — Windows; HTTPS when network behaviour changes
6. **Update documentation** — architecture status, release tracker
7. **Commit and close** — do not start next phase until DoD met

---

## Related documents

| Document | Purpose |
|---|---|
| [music.md](../architecture/music.md) | M5 architecture (5.1 catalogue complete) |
| [m5-phase-5.1-music-catalogue-metadata.md](./m5-phase-5.1-music-catalogue-metadata.md) | Phase 5.1 closure spec |
| [m4-release-summary.md](../release/m4-release-summary.md) | Predecessor milestone |
| [library.md](../architecture/library.md) | Video library UX baseline |
| [playback.md](../architecture/playback.md) | Playback authority model |
| [caching.md](../architecture/caching.md) | Artwork and search lifecycle |
| [design-system.md](../design/design-system.md) | Card ratios; music 1:1 noted for future |
