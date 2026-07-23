# Music (M5)



**Status:** **In progress** — Phase 5.5 complete (2026-07-23); **Phase 5.6 planning** — [performance / UX hardening](../roadmap/m5-phase-5.6-music-performance-and-ux-hardening.md)

**Related roadmap:** [M5 — Music](../roadmap/m5-plan.md) · [Phase 5.1 spec](../roadmap/m5-phase-5.1-music-catalogue-metadata.md)

**Predecessor baseline:** M4 complete — `v0.5.0`



→ [M5 plan](../roadmap/m5-plan.md)

→ [Playback (M4 accepted)](./playback.md)

→ [Library experience (M4 accepted)](./library.md)

→ [Caching (M4 accepted)](./caching.md)

→ [Diagnostics (M4 accepted)](./diagnostics.md)



**ADRs:**

- [ADR-020: Music Catalogue Schema and Media Kind](./decisions/ADR-020-music-catalogue-schema-and-media-kind.md) — **Accepted** (M5.1)
- [ADR-021: Music Metadata Precedence and Identity](./decisions/ADR-021-music-metadata-precedence-and-identity.md) — **Accepted** (M5.1)

- [ADR-022: Music Queue and Listening State](./decisions/ADR-022-music-queue-and-listening-state.md) — **Accepted** (M5.5)

- [ADR-023: Music Player Surface Architecture](./decisions/ADR-023-music-player-surface-architecture.md) — **Accepted** (M5.3 Step 1–2)



---



## 1. Purpose and scope



M5 adds **music listening** to TTSPlayer: index audio files in the existing folder-tree catalogue, enrich items with optional embedded tags, expose artist/album/track browsing, and provide queue-based audio playback with application-managed listening state.



**In scope (M5 milestone):** catalogue extension, music browsing UI, audio playback and queue, required listening state, search presentation, artwork, performance, diagnostics, release validation.



**Out of scope:** books/comics (M6), multi-device sync, cloud metadata APIs, mobile release, M4 dashboard cosmetic debt, user accounts, transcoding.



---



## 2. Existing M4 platform capabilities reused



| Component | M5 reuse |

|---|---|

| `backend/indexer.py` | Extend with audio extensions and tag extraction |

| `catalog.json` folder tree | Same structure; items gain `media_kind` + optional music fields |

| `CatalogService` | Single load/replace lifecycle; no second catalogue |

| `MediaLocationResolver` | Resolve audio paths to playable URIs |

| `SettingsRepository` | Music preferences (shuffle default, etc.) when needed |

| `LibraryMetadataRepository` | Pattern for favourites; extend or parallel envelope |

| `SearchService` | Extend index fields; same invalidation on catalogue replace |

| `ArtworkService` | Album art from embedded/sidecar/folder rules |

| `CatalogCacheCoordinator` | Same replace → invalidate artwork/search |

| `PlaybackService` | Extend for audio session + queue; preserve video path |

| `DiagnosticsService` | Add music/queue summary sections |

| Provider health / fallback | Unchanged |

| Windows runtime harness pattern | New `PHASE_5x_RUNTIME` matrices |



---



## 3. Music domain terminology



| Term | Meaning |

|---|---|

| **Track** | Single audio file (`MediaItem` with `media_kind: audio`) |

| **Album** | Logical grouping of tracks sharing album identity key (see §5) |

| **Artist** | Performing artist; may differ from album artist |

| **Album artist** | Album-level attribution; drives compilation handling |

| **Compilation** | Album where track artists differ from album artist |

| **Disc** | Physical/logical disc within a multi-disc album |

| **Library** | Top-level configured root or folder branch — same as today |

| **Queue** | Ordered list of track ids for current listening session |

| **Continue Listening** | Resume position for in-progress music tracks (app state) |

| **Recently played** | Chronological music play history (app state) |

| **Unknown artist / album** | Fallback when tags and folder hints absent |



---



## 4. Catalogue and metadata model (M5.1 implemented)

**Shipped in M5.1** — scanner `0.4.0`, `catalogue_version: 3`. See [Phase 5.1 spec](../roadmap/m5-phase-5.1-music-catalogue-metadata.md).



**Shipped fields on audio items (M5.1)** — all optional except `media_kind` for newly indexed audio:

| Field | Type | Source |
|---|---|---|
| `media_kind` | `video` \| `audio` \| `image` | Indexer from extension |
| `artist` | string | Tags → folder → `Unknown Artist` |
| `album` | string | Tags → folder → `Unknown Album` |
| `album_artist` | string | Tags → artist → folder |
| `title` | string | Tags → filename stem → `Unknown Track` |
| `track_number` | int? | Tags → filename prefix (`NN - `) |
| `disc_number` | int? | Tags |
| `genre` | string? | Tags |
| `year` | int? | Tags (when present) |
| `artist_group_key` | string | Normalised resolved artist |
| `album_group_key` | string | See §5 — collision-safe album grouping |

**Not shipped in M5.1:** `compilation` flag, embedded artwork extraction, `track_title` as separate field (title carries display value).

**Display title precedence:** embedded tag title → filename stem → `Unknown Track`.

**Backward compatibility:** Absent `media_kind` on v2 catalogues: client infers **video**, **audio**, or **image** from file extension. Unknown `media_kind` strings map to `MediaKind.unknown` without crash. Clients tolerate unknown JSON fields.

**Catalogue version:** `catalogue_version: 3` when scanned with indexer ≥ `0.4.0`. Legacy v2 catalogues load without `media_kind`; client infers from extension.

**Terminology:** *Music* is the milestone/product area; catalogue JSON uses **`audio`** as the media-kind value (ADR-020).



---



## 5. Identity and grouping rules (M5.1 implemented)



| Entity | Identity key |

|---|---|

| Track | Path-derived `id` (md5 of file path) — **stable across rescans** |

| Artist browse | `artist_group_key` = normalised resolved `artist` (NFKC casefold, collapsed whitespace) |

| Album browse | `album_group_key` — see formula below |



**Album grouping key (normative, M5.1):**

```text
album_group_key =
  normalize(album_artist or artist)
  + "|"
  + normalize(album)
  + "|"
  + normalize(str(file_path.parent))
```

The parent-folder component scopes unknown albums and shallow layouts so identical album names under different artists or folders do not share one browse bucket.

**Normalisation:** trim whitespace; empty → missing; NFKC casefold and collapsed whitespace for grouping keys; original casing preserved on display fields (`artist`, `album`, `title`).

**Compilation:** When `compilation` is true or album artist matches a various-artists sentinel — **deferred to M5.2+**; not emitted in M5.1 catalogue output.

**Duplicates:** Same album name from different folders remain **separate** (filesystem is truth).



---



## 6. Folder structure versus embedded-tag precedence



| Metadata | Precedence (highest first) |

|---|---|

| Track title | Embedded tag → filename stem |

| Artist | Embedded tag → parent folder name (heuristic) → Unknown Artist |

| Album | Embedded tag → parent folder name → Unknown Album |

| Album artist | Embedded tag → artist → folder heuristic |

| Track/disc numbers | Embedded tag → filename prefix (`NN - `) when recognised |

| Duration | ffprobe → null |

| Year | Embedded tag → null |



**Folder heuristics (M5.1):** `Artist/Album/tracks`, `Album/tracks`, and root-level files — see [Phase 5.1 spec](../roadmap/m5-phase-5.1-music-catalogue-metadata.md). Ambiguous layouts fall back without error.



**Disagreement:** When filename suggests different album than tags, **tags win** for grouping; filename remains available in diagnostics only.



---



## 7. Unknown and incomplete metadata behaviour



- Items **always appear** if indexed and status is playable — never hidden for missing tags.

- UI shows **Unknown Artist** / **Unknown Album** placeholders.

- Search indexes filename and all present tag fields.

- Sort: track number when present, else filename, else title.

- Missing artwork → neutral placeholder ([graceful degradation](../.cursor/rules/graceful-degradation.mdc) principle).



---



## 8. Artwork ownership and fallback rules



Reuse `ArtworkService` pipeline (ADR-015). Proposed precedence for **album art**:



1. Embedded picture in audio file (first front cover)

2. Sidecar in same folder (`cover.jpg`, `folder.jpg`, `album.jpg` — align with existing sidecar rules)

3. Parent folder image sidecar

4. Neutral music placeholder (1:1 per [design-system](../design/design-system.md))



**Per-track vs per-album:** Cache key includes album identity + source path to avoid cross-album bleed. Embedded art decoded through existing LRU budget.



---



## 9. Music library navigation model



Music browsing is a **derived view** over catalogue items — not new filesystem folders.



```

Dashboard / Libraries

    └── Library folder (filesystem)

            └── [Music entry when audio items detected]

                    ├── Artists

                    ├── Albums

                    └── Tracks (flat list scoped to library branch)

    Artist detail → Albums by artist → Album detail → Track list → Play

    Album detail → Track list → Play album

    Search → Music results → detail/play

```



**Coexistence with video:** Mixed folders may offer both **Browse folders** (existing `FolderScreen`) and **Browse music** when audio items exist. Do not hide video items in folder view.



**Dashboard:** Optional **Recently Played** / **Continue Listening** music rows — separate from video Continue Watching (different state keys).



---



## 10. Playback and queue architecture options



| Option | Description | Assessment |

|---|---|---|

| **A — Shared adaptive player** | One `PlayerScreen` adapts video vs audio layout | Risk: video complexity; queue UI cramped |

| **B — Dedicated music player** | Separate `MusicPlayerScreen`; shared `PlaybackService` | Clear UX; some duplication |

| **C — Staged hybrid** *(recommended)* | Extend `PlaybackService` with queue + audio mode; dedicated music player UI; video keeps existing screen | Balances reuse and clarity |



**Recommendation (5.0):** **Option C — staged hybrid** per ADR-023.



```

Music UI  ─┐

Video UI  ─┼→  PlaybackService  →  MediaLocationResolver  →  media_kit (Windows)

           │         ↑

           └──  QueueController (new, owned by service or collaborator)

```



- Queue: ordered track ids, current index, shuffle/repeat state

- `playTrack`, `playAlbum`, `enqueue`, `next`, `previous`, `seek`

- Video `play(item)` path unchanged for `media_kind: video`



**Background/minimized playback:** Document expectation for Windows desktop (audio continues when navigating) — OS media controls deferred post-M5 unless Gate 0 proves trivial.



---



## 11. Application state model



Separate from `catalog.json` and separate from video resume keys where policies differ.



| State | Storage | Owner | Status |
|---|---|---|---|
| Video resume | `shared_preferences` `position_*`, `duration_*` | `PlaybackService` | ✅ Implemented (M4) |
| Video Continue Watching | Derived from video resume | Dashboard | ✅ Implemented |
| Music listening history | `ttsplayer_music_listening_v1` | `MusicListeningRepository` + `MusicListeningCoordinator` | ✅ Step 5 (persistence + playback + reconcile + UI) |
| Music Continue Listening | Derived from listening history | `MusicScreen` only (not dashboard) | ✅ Step 5 — `ContinueListeningSection` |
| Music Recently Played | Same envelope | `MusicRecentlyPlayedScreen` + landing nav tile | ✅ Step 5 |
| Music favourites | `LibraryMetadataRepository` or future extension | Repository | Deferred |
| Queue persistence | `ttsplayer_music_queue_v1` | `MusicPlaybackSessionRepository` + coordinator + restorer | ✅ Phase 5.5 — silent cold-start restore; no autoplay |
| Play counts / playlists | — | — | Deferred |



**Isolation rule:** Audio items set `isContinueWatchingEligible => false`. Music progress must never write video `position_*` keys. See [Phase 5.4 spec](../roadmap/m5-phase-5.4-listening-history-continue-listening.md).



**Prune on catalogue replace:** `CatalogCacheCoordinator.onCatalogReplaced` invokes `MusicListeningRepository.validateAgainstCatalog` after successful replacement — same lifecycle as favourites (ADR-007). Removes records whose `trackId` is absent from catalogue audio items; refreshes snapshot metadata for retained tracks; never rematches by title/artist/path.

**Implementation (Step 2):** `MusicListeningRecord` is an immutable value type (`trackId` identity; display snapshots only). `MusicListeningRepository` mirrors `LibraryMetadataRepository` patterns — `SharedPreferences`, versioned envelope, defensive decode, `ChangeNotifier`, `simulatePersistFailure` for tests. Records load only when `stateVersion == 1`; unsupported or missing versions recover to empty history with a warning and leave the stored blob unchanged on read. No video key access.

**Implementation (Step 3):** `MusicListeningCoordinator` owns playback lifecycle observation — 15 s creation threshold, 5 s write throttle, flush on pause/stop/track change/completion/route close. Wired in `main.dart` after `MusicPlaybackQueueController`; listens to `PlaybackService` + queue controller; writes only through `MusicListeningRepository`. `MusicPlaybackQueueController.pendingListeningWriteDrain` awaits coordinator writes before natural-completion auto-advance. Dependency direction: coordinator → repository; coordinator → playback/queue (read-only observation). Does not modify video `position_*` / `duration_*` keys. Exposes `lastPersistenceWarning`, `drainPendingWrites()`, and `onAppLifecyclePaused()` for future diagnostics/shell integration.

**Implementation (Step 4):** `MusicListeningRepository.validateAgainstCatalog(Catalog)` owns reconciliation policy. `CatalogCacheCoordinator` triggers it after successful replacement only; failures are logged and never block catalogue loading. Returns `MusicListeningValidationResult` with retained/removed counts and persistence status. Listening state (`lastPosition`, `completed`, timestamps) is never reset on reconcile.

**Implementation (Step 5):** Presentation consumes `MusicListeningRepository` via `Consumer2` on `MusicScreen` and `MusicRecentlyPlayedScreen`. `music_listening_presentation.dart` resolves catalogue items strictly by `trackId` (`MusicLibraryProjection.findTrackById`); snapshot fields are display fallback only. `openMusicPlayerFromListeningRecord` seeds album queue when the track maps to a projection album, otherwise a one-track queue; start position comes from `historyPlaybackStartPosition`. Stale records are hidden from Continue Listening and disabled on Recently Played. No dashboard Continue Listening; video Continue Watching unchanged.

**Implementation (Step 6):** `MusicListeningRepository.clearAll()` returns `MusicListeningClearResult` — persists an empty versioned envelope before mutating in-memory state; `alreadyEmpty` is a no-op without notification; persistence failure preserves records. UI: Recently Played AppBar menu → `ClearListeningHistoryDialog` → snackbar acknowledgement. Clearing does not stop playback, alter queues, or touch video resume keys / favourites. The coordinator may recreate history on a later normal flush while a track is playing.

**Implementation (Step 7):** Diagnostics integration via `MusicListeningDiagnostics` (M4 Phase 4.6 patterns). `DiagnosticsService` reads aggregate counts and coordinator flags only — no record-level metadata, no SharedPreferences access, no load/persist/clear/reconcile side effects. Section appears after Playback and before Library in screen and export order.

**Implementation (Step 8):** Integration suite `phase_54_listening_history_integration_test.dart` validates end-to-end listening lifecycle (I1–I16) using production components with `Phase54TestClock` and playback stubs. Cross-instance persistence reload, catalogue reconciliation via `CatalogCacheCoordinator`, history launch navigation, and regression guards for video CW keys, favourites, search, and dashboard boundaries.

**Runtime validation (Step 9):** Opt-in Windows harness `PHASE_54_RUNTIME=1` exercises production `MusicListeningRepository`, coordinator, queue, diagnostics, and `CatalogService` paths. Threshold scenarios use `Phase54TestClock` + `mediaKitInitOverride` (documented test boundary); R5 validates real libmpv playback separately. Confirms diagnostics export includes **Music Listening** as the eighth section (after Playback, before Library) with count-only redaction.

**Closure (Step 10, 2026-07-22):** Phase 5.4 complete — [closure report](../roadmap/m5-phase-5.4-closure-report.md). ADR-022 remains **Partially Accepted** (queue persistence deferred). Release binary smoke passed; full validation **898 passed** / 12 skipped (default suite).

**Implementation (Phase 5.5 Step 4, 2026-07-22):** `MusicPlaybackSessionRestorer` hydrates `MusicPlaybackQueueController` after catalogue load via `DashboardScreen` bootstrap. Persisted session reconciles through `MusicPlaybackSessionRepository.validateAgainstCatalog` before track resolution against catalogue + `MusicLibraryProjection`. `MusicPlaybackQueueController.restoreSession` replaces the queue atomically and stores `restoredStartPosition` for deferred seek on the next user-initiated `playCurrent` — no autoplay or navigation. `MusicPlaybackSessionCoordinator` defers persistence until `enablePersistenceAfterColdStartRestore` to avoid overwriting stored state with an empty startup queue. Runtime catalogue replacement continues to reconcile the persisted envelope only (Step 3); it does not rehydrate the live queue.

**Implementation (Phase 5.5 Step 5, 2026-07-22):** `MusicPlaybackSessionLifecycleObserver` wraps the application shell and flushes session state on background lifecycle transitions via `MusicPlaybackSessionCoordinator.onAppLifecyclePaused()`. Duplicate events within one background transition are suppressed until `AppLifecycleState.resumed`. Lifecycle writes are blocked until cold-start restore enables persistence. Aggregate playback-session diagnostics are exposed through `DiagnosticsService` and the plain-text export as section **Music Playback Session** — counts and flags only.

**Closure (Phase 5.5 Step 6, 2026-07-23):** Windows runtime harness PS1–PS16 (`PHASE_55_RUNTIME=1`) validated production repository, coordinator, restorer, queue, lifecycle flush, catalogue reconciliation, diagnostics redaction, and isolation. ADR-022 **Accepted**. → [Phase 5.5 closure](../roadmap/m5-phase-5.5-closure-report.md)

**Final playback-session flow:**

```
Playback/queue events
        ↓
MusicPlaybackSessionCoordinator
        ↓
MusicPlaybackSessionRepository
        ↓
ttsplayer_music_queue_v1

Application startup
        ↓
Catalogue load and reconciliation
        ↓
MusicPlaybackSessionRestorer
        ↓
Live queue restored without autoplay
        ↓
Deferred position applied on explicit Play
```


---



## 12. Search and indexing implications



Extend existing `SearchService` — **no second index**.



**Additional indexed fields:** artist, album, album artist, genre, track title, filename.



**Presentation:** Result type badge (Music vs Video); navigate to music detail or play.



**Performance:** Index build counted in diagnostics; defer rebuild on catalogue replace (ADR-016 pattern).



**Filtering:** Phase 5.2 may add music-only filter in search UI; engine remains unified.

**M5.2 implemented:** `SearchResultRow` shows `Audio` kind chip and `artist · album` subtitle; `SearchScreen` routes audio hits to `MusicTrackDetailScreen` (not video `ItemDetailScreen`). **M5.3 Step 1:** separate play action opens `MusicPlayerScreen`.



### Phase 5.2 — Derived music library views (implemented)



Client-side projection over the unified catalogue — no second store:



| Component | Role |

|---|---|

| `MusicLibraryProjection` | Builds artists, albums, tracks from `Catalog.allItems` where `isAudio` |

| `MusicLibraryService` | Memoises projection by `catalogueIdentity`; invalidated on catalogue replace |

| `MusicSorting` | Deterministic locale-independent ordering |

| Dashboard `MusicSection` | Entry when audio count > 0 |

| Browse screens | Artists, albums, tracks + read-only detail surfaces |



Grouping authority: `artist_group_key` and `album_group_key` from M5.1 (ADR-021). Legacy items without keys derive keys using the same normalisation formula as the scanner fallback.



## 13. Cache and performance implications



| Area | Consideration |

|---|---|

| Catalogue size | Live NAS ~42k audio / ~122k total items — client parse must stay O(n) single pass |

| Artist/album indexes | `MusicLibraryService` memoises projection by identity; deepen indexes / remove repeated work in **Phase 5.6** |

| Artwork | Many small images — respect existing LRU / image-cache policy; harden fallbacks in 5.6 |

| Queue | Cap max persisted queue length — `MusicPlaybackSessionPolicy.maxPersistedTrackIds` (500) |

| UI lists | Lazy `ListView`/`GridView`; rebuild and scroll hardening in 5.6 |

| Catalogue replace | Invalidate projection; prune listening/session state; invalidate artwork/search |



**Phase 5.6 (in progress):** [Music library performance, scale and UX hardening](../roadmap/m5-phase-5.6-music-performance-and-ux-hardening.md) — Step 2 baselines recorded (1,010 / 10,010 / 40,010 audio; MP3 projection median ~148 ms informational). Step 3 next: evidence-gated projection indexing.



---



## 14. Diagnostics and supportability



Extend `RuntimeDiagnosticsSnapshot` (no secrets):



| Field (proposed) | Example |

|---|---|

| Audio item count | `1240` |

| Album count (derived) | `86` |

| Queue length | `12` |

| Queue persistence | `enabled` — `ttsplayer_music_queue_v1` (M5.5) |

| Last playback error kind | `backendFailed` (redacted detail) |



Clipboard export adds **Music** section. Redaction rules unchanged (ADR-019).



---



## 15. Provider and media-access compatibility



Audio files use the **same** catalogue paths and resolver as video:



- Local: `file://`

- HTTPS: ranged streaming via Caddy



No audio-specific provider type. Provider failure surfaces via existing Provider Status — not music-specific banners.



---



## 16. Backward compatibility



| Scenario | Behaviour |

|---|---|

| Old catalogue (no `media_kind`) | Client infers from extension |

| Old client, new catalogue | Unknown fields ignored by old clients if any |

| Mixed library scan | Video/image items unchanged |

| Bundled mock catalogue | Update mock when 5.1 ships; until then video-only mock valid |



---



## 17. Migration and schema-version considerations



1. Bump `CATALOGUE_VERSION` in indexer when music fields ship.

2. Client checks `catalogue_version` — if unsupported, banner + retain last-good (existing pattern).

3. No migration of user state required for M5 launch (new keys).

4. Full rescan populates music metadata; library rescans merge branch per existing indexer rules.



---



## 18. Error and degraded-state behaviour



| Failure | Behaviour |

|---|---|

| Tag read fails | Emit item with folder/filename fallbacks; log warning in indexer |

| Unsupported audio codec | `status: unavailable` or skip at index — document in 5.1 |

| Playback init fails | ADR-013 taxonomy; skip to next queue item if policy allows |

| Missing file in queue | Remove on play attempt; notify user |

| Catalogue replace mid-play | Pause; prune queue; offer restart |



---



## 19. Testing and Windows runtime strategy



| Layer | Approach |

|---|---|

| Indexer | Fixture libraries: flat, tagged, tagless, compilation, multi-disc |

| Models | Parse tests for optional fields |

| Derived views | Unit tests for album/artist grouping keys |

| Queue | Service tests with fake session controls |

| UI | Widget tests for music browse screens |

| Integration | Catalogue replace → state prune |

| Windows runtime | `PHASE_51_RUNTIME` … `PHASE_55_RUNTIME` opt-in gates (mirrors M4); **5.2:** `PHASE_52_RUNTIME=1` → `test/phase_52_windows_runtime_test.dart`; **5.4:** `PHASE_54_RUNTIME=1` → `test/phase_54_listening_history_windows_runtime_test.dart` |

| Manual QA | Play local + HTTPS audio; video regression checklist in 5.6 |



**Gate 0 (before 5.3 queue):** ✅ **Complete** (2026-07-20) — see [M5.3 spec](../roadmap/m5-phase-5.3-music-playback-queue.md).

**M5.3 Step 3 (contextual seeding):** ✅ **Complete** (2026-07-20) — album/artist **Play** actions seed multi-track queues using projection ordering; track play in album/artist detail seeds full group at selected index; ungrouped contexts remain single-track. See [playback.md](./playback.md#m53-step-3--contextual-queue-seeding-2026-07-20).

**Live NAS catalogue (2026-07-21):** Music requires scanner **≥ 0.4.0** and catalogue **schema v3** (`media_kind`, optional music tags). A stale v0.3.3/v2 catalogue will not surface audio correctly — rescan and reload the app. Validated: 42,283 audio items indexed; `01 Oh Yeah.mp3` classified as audio with grouping keys. See [v0.5.0-dev release notes](../release/v0.5.0-dev.md#live-nas-catalogue--stale-v2-issue-resolved-2026-07-21).



---



## 20. Security and privacy considerations



- No upload of play history or tags.

- Diagnostics export excludes full paths (existing redaction).

- HTTPS audio uses same TLS rules as video.

- Embedded tags may contain free text — treat as untrusted display strings (no HTML rendering).



---



## 21. Deferred capabilities



| Capability | Target |

|---|---|

| User-defined playlists | Post-M5 or late M5 if scheduled |

| Play counts | Post-M5 |

| Gapless playback | Investigate; defer default |

| OS media session / taskbar controls | Post-M5 |

| MusicBrainz / external enrichment | Out of scope unless approved |

| Cross-folder “virtual album” merge | Out of scope |

| M4 dashboard card consistency | Deferred UX debt |

| Lyrics | Out of scope |



---



## 22. Open questions requiring ADRs



| Question | ADR |

|---|---|

| Schema shape and version bump | ADR-020 |

| Tag vs folder precedence and grouping keys | ADR-021 |

| Queue persistence and prune rules | ADR-022 |

| Dedicated vs shared player UI | ADR-023 |

| Exact audio extension list | Phase 5.1 spec (may amend ADR-020) |

| Shuffle algorithm (true shuffle vs Fisher-Yates) | Phase 5.3 spec |

| Resume threshold for Continue Listening | Phase 5.4 spec |



---



## 23. Initial architecture recommendation



1. **Single catalogue** — extend items with `media_kind` and optional music fields; bump `catalogue_version`.

2. **Indexer tag extraction** — ffprobe/metadata pass with graceful fallback; standard library only on scanner.

3. **Derived music views** — artist/album indexes built client-side from items (no invented catalogue folders).

4. **Staged hybrid player** — extend `PlaybackService` + new music player screen; leave video `PlayerScreen` intact.

5. **Application state repository** — extend metadata repository pattern for favourites, history, queue persistence.

6. **Reuse search/artwork/cache/diagnostics** — extend, do not duplicate.

7. **Windows-first validation** — Gate 0 audio audit before queue implementation; runtime harness per phase.

8. **Strict video regression** — parallel harness execution through M5.



---



## Related documents



| Document | Role |

|---|---|

| [M5 plan](../roadmap/m5-plan.md) | Phase breakdown and DoD |

| [ADR-020](./decisions/ADR-020-music-catalogue-schema-and-media-kind.md) | Schema proposal |

| [ADR-021](./decisions/ADR-021-music-metadata-precedence-and-identity.md) | Metadata rules |

| [ADR-022](./decisions/ADR-022-music-queue-and-listening-state.md) | State and queue |

| [ADR-023](./decisions/ADR-023-music-player-surface-architecture.md) | Player UI |

| [Item status model](../../.cursor/rules/item-status-model.mdc) | Status values for unavailable audio |
