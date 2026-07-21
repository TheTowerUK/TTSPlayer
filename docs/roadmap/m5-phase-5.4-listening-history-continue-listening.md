# M5 Phase 5.4 — Listening History and Continue Listening

**Status:** **PLANNING** — Step 7 complete (2026-07-21)
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Predecessor:** Phase 5.3 complete (2026-07-21)

→ [M5 plan](./m5-plan.md#phase-54--music-state-and-listening-history)
→ [Music architecture](../architecture/music.md#11-application-state-model)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md)
→ [Phase 5.3 spec](./m5-phase-5.3-music-playback-queue.md)

---

## Context and dependencies

Phase 5.3 delivered shared audio playback, an in-memory queue with album/artist seeding, transport controls, and natural completion advancement. Windows Release build and manual validation pass. Audio playback deliberately does **not** write video Continue Watching keys (`position_*`, `duration_*`).

Phase 5.4 adds **persistent music listening history** and user-facing **Continue Listening** / **Recently Played** surfaces without reusing or corrupting video resume state.

| Dependency | Status |
|---|---|
| Phase 5.3 playback + queue | ✅ Complete |
| Catalogue schema v3 / scanner 0.4.0 | ✅ Required for live validation |
| ADR-023 (music player surface) | ✅ Accepted |
| ADR-022 (listening state envelope) | **Partially Accepted** at 5.4 closure — listening history only; queue/favourites deferred |
| `LibraryMetadataRepository` prune pattern (ADR-007) | ✅ Reuse lifecycle |
| `CatalogCacheCoordinator` | ✅ Extension point for reconciliation |

---

## Step 2 — Model and repository (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Policy constants | `client/ttsplayer/lib/features/music/models/music_listening_policy.dart` |
| Immutable record | `client/ttsplayer/lib/features/music/models/music_listening_record.dart` |
| Repository | `client/ttsplayer/lib/features/music/services/music_listening_repository.dart` |
| Unit tests | `client/ttsplayer/test/music_listening_repository_test.dart` |

**Storage key:** `ttsplayer_music_listening_v1` — envelope `{ stateVersion: 1, records: [...] }`.

**Corruption and version recovery:**

| Condition | In-memory result | Warning | Source blob on read |
|---|---|---|---|
| Missing / empty key | Empty history | — | — |
| Invalid JSON | Empty history | Yes | Unchanged |
| Unsupported or missing `stateVersion` | Empty history | Yes (identifies version) | Unchanged |
| Supported v1, malformed record | Valid siblings retained | Per skipped record | Unchanged |
| Supported v1, valid envelope | Records loaded | Only if records skipped | Unchanged |

**Retention:** 100 stored records (newest by `lastPlayedAt`); `recentlyPlayed(limit: 20)` default query cap; Continue Listening query uses 30 s / 2 min near-end rules via `MusicListeningPolicy`.

**Completed replay rule:** On normalization, completed records store `lastPosition: 0`; callers use `replayPosition` (always zero when completed).

**Not yet wired:** UI, catalogue reconciliation, diagnostics.

**Validation:** 35 unit tests; full Flutter suite **784 passed**, 11 skipped.

---

## Step 3 — Music Listening Coordinator (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Policy constants (threshold + throttle) | `client/ttsplayer/lib/features/music/models/music_listening_policy.dart` |
| Coordinator | `client/ttsplayer/lib/features/music/services/music_listening_coordinator.dart` |
| App wiring | `client/ttsplayer/lib/main.dart` — `MusicListeningCoordinator` created after queue controller, registered in `MultiProvider`, `attach()` on startup |
| Unit + integration tests | `client/ttsplayer/test/music_listening_coordinator_test.dart` (16 tests) |

**Integration point:** `MusicListeningCoordinator` listens to **`PlaybackService`** and **`MusicPlaybackQueueController`** as `ChangeNotifier`s. No hooks inside `PlaybackService` video persistence, queue controller logic, repository, or UI widgets.

**Not yet wired:** Continue Listening UI, Recently Played UI, catalogue reconciliation, diagnostics, app lifecycle observer (coordinator exposes `onAppLifecyclePaused()` for future shell wiring).

**Validation:** 16 coordinator tests; full Flutter suite **800 passed**, 11 skipped.

### Event lifecycle and flush table (implemented)

| Event | Source | Flush | Creates sub-15 s record? | Notes |
|---|---|---|---|---|
| Position tick while playing | `PlaybackService` | Throttled (5 s) | No — requires 15 s accumulated listening | Position delta capped per tick; paused/buffering excluded |
| Pause | `PlaybackService` (`isPlaying` false) | Immediate (`force`) | No unless threshold already met or existing record advanced | |
| Stop | `PlaybackService` via queue `clearQueueAndStop` | Immediate | No unless eligible | |
| Route close | `MusicPlaybackQueueController.onPlayerRouteClosed` → queue cleared + stop | Immediate | No unless eligible | |
| Track change (next/previous/replace) | `MusicPlaybackQueueController` | Previous track flushed before new session | No unless eligible | `_beginSession` resets accumulator |
| Queue cleared | `MusicPlaybackQueueController` | Immediate | No unless eligible | |
| Natural completion | `PlaybackService.isCompleted` | Immediate; `completed=true`, `lastPosition=0` | N/A | Session cleared; queue auto-advance awaits `drainPendingWrites()` |
| Retry | `playCurrent` / playback re-init | Prior progress preserved via existing record or in-session max | No unless eligible | |
| App lifecycle pause | `onAppLifecyclePaused()` (future shell) | Immediate | No unless eligible | Not wired in 5.4 Step 3 |
| Coordinator dispose | `dispose()` | No further writes | — | Listeners removed |

### Completed-track replay semantics (implemented)

| Phase | Behaviour |
|---|---|
| Open completed track at position 0 | Record stays `completed=true`; `completedAt` preserved |
| Meaningful replay &lt; 15 s then pause/exit | Still completed; no Continue Listening eligibility |
| Meaningful replay ≥ 15 s | Upsert as incomplete; `completedAt` cleared; `lastPosition` from session max |
| Continue Listening after re-open | Requires `lastPosition >= 30 s` per `MusicListeningPolicy.minResumePosition` |

### Persistence failure isolation

- All writes use `MusicListeningRepository.upsert` result contract — never throw into playback listeners.
- `lastPersistenceWarning` on coordinator surfaces most recent failure for diagnostics.
- Later ticks/flushes retry normally.

---

## Step 4 — Catalogue reconciliation (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Reconciliation API | `MusicListeningRepository.validateAgainstCatalog` |
| Result type | `MusicListeningValidationResult` |
| Coordinator trigger | `CatalogCacheCoordinator.onCatalogReplaced` → `_validateListeningHistory` |
| App wiring | `client/ttsplayer/lib/main.dart` — repository passed to `CatalogCacheCoordinator` |
| Repository tests | `client/ttsplayer/test/music_listening_repository_test.dart` (8 reconciliation tests) |
| Integration tests | `client/ttsplayer/test/catalog_cache_invalidation_test.dart`, `music_listening_coordinator_test.dart` |

**Integration point:** `CatalogCacheCoordinator` only **triggers** reconciliation after successful catalogue replacement (same hook as favourites). Policy lives entirely in `MusicListeningRepository`.

### Reconciliation algorithm

1. Build a map of catalogue **audio** items by `MediaItem.id` (first DFS match wins on duplicates).
2. For each stored listening record:
   - **Absent from map:** remove record.
   - **Present:** retain record; refresh snapshot fields (`title`, `artist`, `album`, `duration`) from catalogue item.
   - **Never touch:** `lastPosition`, `completed`, `completedAt`, `lastPlayedAt`.
3. Persist only when records were removed or snapshot metadata changed; single `notifyListeners` on success.
4. No title/artist/album/path rematching — identity is `trackId` only.

### Failure behaviour

| Condition | Behaviour |
|---|---|
| No changes needed | `changed: false`, no storage write |
| Persist succeeds | `changed: true`, `persisted: true`, in-memory updated |
| Persist fails | In-memory history unchanged; `persistenceFailed: true`; catalogue replacement unaffected |
| Unexpected error | Logged; empty result with warning; no throw to caller |

**Validation:** 8 repository reconciliation tests + 3 coordinator/cache integration tests; full Flutter suite green.

---

## Step 5 — Continue Listening and Recently Played UI (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Presentation helpers | `client/ttsplayer/lib/features/music/music_listening_presentation.dart` |
| Continue Listening carousel | `client/ttsplayer/lib/features/music/widgets/continue_listening_section.dart` |
| Recently Played screen | `client/ttsplayer/lib/features/music/screens/music_recently_played_screen.dart` |
| Music landing integration | `client/ttsplayer/lib/features/music/screens/music_screen.dart` |
| History resume navigation | `client/ttsplayer/lib/features/music/music_navigation.dart` — `openMusicPlayerFromListeningRecord`, `openMusicRecentlyPlayedScreen` |
| Repository provider | `client/ttsplayer/lib/main.dart` — `ChangeNotifierProvider<MusicListeningRepository>` |
| Widget / navigation tests | `client/ttsplayer/test/music_listening_presentation_test.dart` (16 tests) |

### Music landing placement

On `MusicScreen`, after the catalogue summary line and **before** Artists / Albums / Tracks nav tiles:

1. **Continue Listening** — horizontal carousel (hidden when no eligible playable records; no empty-state panel).
2. **Recently Played** — always-visible nav tile (`music_recently_played_tile`) with history count when loaded.

**Not** on the main dashboard — video Continue Watching unchanged.

### Queue-seeding from history

`openMusicPlayerFromListeningRecord` resolves the track strictly by `MusicListeningRecord.trackId`:

1. If the track appears in a projection album → `seedAlbumQueue(album, startTrack: track)`.
2. Otherwise → `seedSingleTrack(track)`.

No artist-queue inference; no snapshot metadata rematching.

### Resume / replay start position

`historyPlaybackStartPosition(record)` in the presentation layer:

| Record state | Start position |
|---|---|
| `completed == true` | `Duration.zero` |
| Incomplete, `lastPosition < 30 s` | `Duration.zero` |
| Incomplete, resume-eligible | `record.lastPosition` |

### Stale / missing catalogue items

| Surface | Behaviour |
|---|---|
| Continue Listening | Omitted via `resolvePlayableListeningEntries` (strict `trackId` lookup) |
| Recently Played | Row shown; tile disabled; no play affordance |
| Navigation | `openMusicPlayerFromListeningRecord` returns `false`; no playback from snapshot |

Snapshot `title` / `artist` / `album` are display fallback only.

### Manual QA checklist (Step 5 — prepared, not signed off)

- [ ] Music landing shows Continue Listening after a resumable track exists
- [ ] Completed tracks do not appear in Continue Listening
- [ ] Recently Played remains accessible with completed-only history
- [ ] Resume opens at saved position
- [ ] Completed replay starts at zero
- [ ] Missing catalogue item is safe (disabled row / hidden carousel card)
- [ ] Long titles and metadata do not overflow
- [ ] Windows mouse and keyboard activation work
- [ ] Existing album/artist/folder navigation remains intact

**Validation:** 16 widget/navigation tests; full Flutter suite **828 passed**, 11 skipped, 0 failed. No clear-history UI, diagnostics, or dashboard changes in this step.

---

## Step 6 — Clear listening history (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Clear result type | `MusicListeningClearResult` / `MusicListeningClearOutcome` in `music_listening_repository.dart` |
| Repository API | `MusicListeningRepository.clearAll()` |
| Confirmation dialog | `client/ttsplayer/lib/features/music/widgets/clear_listening_history_dialog.dart` |
| UI entry point | `MusicRecentlyPlayedScreen` AppBar overflow menu |
| Repository tests | `client/ttsplayer/test/music_listening_repository_test.dart` (7 clear tests) |
| UI + coordinator tests | `music_listening_presentation_test.dart`, `music_listening_coordinator_test.dart` |

### UI placement

**Recently Played screen only** — AppBar `PopupMenuButton` (`music_recently_played_menu`) with **Clear listening history**. Hidden when repository is loading or `storedRecordCount == 0`. Not on Music landing, dashboard, or Settings.

### Confirmation dialog

- **Title:** Clear listening history?
- **Body:** Removes Continue Listening and Recently Played entries; music files, queues, favourites, and video watch history unaffected.
- **Actions:** Cancel | Clear (destructive `AppColors.error` fill)
- Cancel / Escape / dismiss → no change
- Clear disabled with progress indicator while persistence runs

### Repository clear semantics

| Outcome | Behaviour |
|---|---|
| `cleared` | Empty versioned envelope persisted; in-memory records cleared; `notifyListeners()` once |
| `alreadyEmpty` | No persistence write; no notification |
| `persistenceFailed` | In-memory records unchanged; failure result returned (not thrown) |

### Active playback after clear

Clearing history does **not** stop playback, change queue, or reset coordinator session state. The coordinator does not observe repository clears. While paused, clear does not immediately recreate a record. During active playback, a record may be written again only on a subsequent coordinator flush under existing 15 s / 5 s throttle rules (`hadExistingRecord` on the in-memory session).

### Manual QA checklist (Step 6 — prepared, not signed off)

- [ ] Recently Played offers Clear listening history when records exist
- [ ] Confirmation wording clearly explains scope
- [ ] Cancel and Escape preserve history
- [ ] Confirm clears Continue Listening and Recently Played
- [ ] Recently Played navigation remains available
- [ ] Active music continues playing; queue intact
- [ ] Failure shows safe message and preserves records
- [ ] Keyboard navigation and focus work on Windows
- [ ] Video Continue Watching data unchanged

**Validation:** 18 new/extended tests; full Flutter suite **846 passed**, 11 skipped, 0 failed.

---

## Step 7 — Diagnostics integration (2026-07-21)

**Status:** ✅ **Complete**

| Deliverable | Path |
|---|---|
| Snapshot DTO | `MusicListeningDiagnostics` in `runtime_diagnostics_models.dart` |
| Capture | `DiagnosticsService._captureMusicListening()` |
| Export formatter | `=== Music Listening ===` block in `diagnostics_export_formatter.dart` |
| UI section | `DiagnosticsScreen._buildMusicListeningSection()` |
| Repository aggregates | count getters on `MusicListeningRepository` |
| Coordinator observables | `sessionActive`, `pendingWrite`, `persistenceWarningPresent` |
| Tests | `client/ttsplayer/test/diagnostics_music_listening_test.dart` (+ harness/heading updates) |

### Section placement

**Section 7 of 8** — after **Playback**, before **Library**. Export heading: `=== Music Listening ===`.

### Diagnostics fields (counts and booleans only)

| Field | Source |
|---|---|
| `repositoryLoaded` | `MusicListeningRepository.isLoaded` (section null when false) |
| `storedRecordCount` | `storedRecordCount` |
| `continueListeningCount` | `continueListeningCount` (full query, no UI cap) |
| `recentlyPlayedCount` | `recentlyPlayedVisibleCount` (default query cap) |
| `completedRecordCount` | `completedRecordCount` |
| `incompleteRecordCount` | `incompleteRecordCount` |
| `recoveryWarningPresent` | `recoveryWarningPresent` |
| `coordinatorAttached` | `MusicListeningCoordinator.isAttached` |
| `sessionActive` | `sessionActive` |
| `pendingWrite` | `pendingWrite` |
| `persistenceWarningPresent` | `persistenceWarningPresent` |
| `lastPersistenceWarningSummary` | `lastPersistenceWarning` via `_safeErrorSummary` |

**Omitted:** `lastReconciliationFailurePresent` — repository does not retain reconciliation failure history between runs; diagnostics report current state only.

### Privacy / redaction

Never exported: track IDs, titles, artists, albums, paths, URLs, artwork paths, per-record timestamps, raw SharedPreferences payloads, or full exception text that may embed paths. Generic persistence warning text only (`Could not save music listening history.`).

### Failure isolation

| Failure | Behaviour |
|---|---|
| Repository not loaded | Section null → UI/export show Availability/Status Unavailable |
| Repository read throws | Section `unavailable`; other sections complete |
| Coordinator read throws | Section `partial`; repository counts remain |
| Other sections unaffected | Provider, Catalogue, Cache, Search, Playback, Library still render |

### Read-only guarantees

Diagnostics capture does **not** call `initialize`, `load`, `upsert`, `clearAll`, `validateAgainstCatalog`, coordinator flush, or read SharedPreferences directly.

### Manual QA checklist (Step 7 — prepared, not signed off)

- [ ] Settings → Diagnostics displays Music Listening
- [ ] Counts match current listening state
- [ ] Clearing history updates counts after refresh
- [ ] Active playback session state updates after refresh
- [ ] Copy diagnostics contains Music Listening section once
- [ ] No track titles, artists, album names, IDs, paths, or URLs appear
- [ ] Music diagnostics failure does not break other sections
- [ ] Copy-to-clipboard flow remains usable

**Validation:** 14 new tests in `diagnostics_music_listening_test.dart`; full Flutter suite **860 passed**, 11 skipped, 0 failed.

---

## Repository audit findings

### Video Continue Watching — isolation proof

Video resume is owned entirely by `PlaybackService` using per-item SharedPreferences keys:

| Mechanism | Location | Keys / gate |
|---|---|---|
| Position persistence | `PlaybackService._savePosition` | `position_<itemId>` |
| Duration persistence | `PlaybackService._saveDuration` | `duration_<itemId>` |
| Continue Watching query | `PlaybackService.getContinueWatching` | Scans `position_*` keys |
| Eligibility gate | `MediaItem.isContinueWatchingEligible` | `=> isVideo` only |
| Save guards | `_savePosition`, `_saveDuration`, `_clearPosition` | Early return when `!isContinueWatchingEligible` |
| Auto-resume on play | `PlaybackService.play` | Uses saved position only when eligible |
| Throttle + flush | `_onPlaybackTick`, `_flushPosition` | 5 s interval; flush on pause/stop |
| Completion clear | `_onPlaybackTick` when `isCompleted` | `_clearPosition` |
| Resume thresholds | `ResumeInfo` | `minResumePosition` 30 s; `nearEndWindow` 2 min |
| Dashboard assembly | `DashboardService.build` | `playback.getContinueWatching(catalog)` capped at 8 |

**Proof:** Audio items fail `isContinueWatchingEligible` at every persistence entry point. Phase 5.4 must introduce a **separate repository and key namespace** (`ttsplayer_music_listening_v1`). Music progress must **never** call `PlaybackService` video resume helpers or write `position_*` / `duration_*` keys.

### Music playback integration points

| Component | File | Role for 5.4 |
|---|---|---|
| `MusicPlaybackQueueController` | `lib/features/music/services/music_playback_queue_controller.dart` | Track change, completion advance, route close, catalogue reconcile — primary hook for flush/finalize |
| `MusicPlayerScreen` | `lib/features/music/presentation/music_player_screen.dart` | Route lifecycle; accepts optional `startPosition` (not yet wired from history) |
| `music_navigation.dart` | `lib/features/music/music_navigation.dart` | All play entry points; must accept resume-from-history `startPosition` |
| `PlaybackService` | `lib/services/playback_service.dart` | Position/duration/completion signals for audio; **read-only** for music history (no video key writes) |
| `CatalogCacheCoordinator` | `lib/services/catalog_cache_coordinator.dart` | Calls queue + favourites reconcile; **add listening history reconcile** |

### Catalogue replacement lifecycle

`CatalogCacheCoordinator.onCatalogReplaced` currently:

1. Clears artwork cache
2. Rebuilds search index
3. Invalidates music projection
4. Reconciles in-memory queue (`MusicPlaybackQueueController.reconcileWithCatalog`)
5. Prunes favourites (`LibraryMetadataRepository.validateAgainstCatalog`)

Phase 5.4 adds step 6: **`MusicListeningRepository.validateAgainstCatalog`** — prune records whose `trackId` is absent; never mutate catalogue or active queue order except via existing coordinator.

### Stable identifiers

| Identifier | Source | Use |
|---|---|---|
| **Primary** | `MediaItem.id` (path-derived md5) | Record key, reconciliation, resume lookup |
| **Display fallback** | Snapshot fields on record: `title`, `artist`, `album` | UI only — never for catalogue rematching |
| **Grouping keys** | `artist_group_key`, `album_group_key` | Optional on record for artwork/context; re-resolve from catalogue when present |

Path-derived ids are stable across metadata-only rescans (ADR-021). File moves produce new ids — old records are pruned on catalogue replacement (same as favourites).

### Existing repositories and settings

| Store | Key | Contents | 5.4 action |
|---|---|---|---|
| Video resume | `position_*`, `duration_*` | Per-item video progress | **Do not touch** |
| Library metadata | `ttsplayer_library_metadata_v1` | Favourites only | **No change** (favourites out of scope) |
| Settings | `ttsplayer_settings_v1` | Configuration envelope | **No change** — no retention knob in 5.4 |
| Music listening (new) | `ttsplayer_music_listening_v1` | History envelope | **Create** |

`SettingsRepository` has no suitable retention extension point; retention constants live in `MusicListeningRepository` (mirrors `DashboardService.maxContinueWatching` pattern).

### Diagnostics

`DiagnosticsService._captureLibrary` exposes `continueWatchingCount: null` (video count not yet wired). Phase 5.4 adds music summary fields only — counts and envelope version; no track titles, paths, or ids in export.

### ADR-022 assessment

ADR-022 governs music listening state design. M5.3 implemented in-memory queue only. **Approved:** ADR-022 becomes **Partially Accepted** at Phase 5.4 closure when listening history ships. **Not** fully Accepted while queue persistence remains unimplemented. No new ADR required.

---

## Approved decisions (2026-07-21)

| # | Decision | Resolution |
|---|---|---|
| 1 | Continue Listening placement | **Music landing (`MusicScreen`) only** — not main dashboard; video Continue Watching unchanged |
| 2 | Listening thresholds | **15 s** to create/update record; **30 s** minimum saved position to offer resume; completed tracks restart from **0** |
| 3 | Continue Listening vs Recently Played | Continue Listening = **incomplete only**; Recently Played = **incomplete + completed**; one record per `trackId`; most recently played first |
| 4 | Queue persistence | **Explicitly deferred outside Phase 5.4** — no queue serialization or restoration in this phase |
| 5 | ADR-022 status | **Partially Accepted** at 5.4 closure (listening history); full Accepted deferred until queue persistence ships |
| 6 | Retention | **100** stored records; **20** Recently Played UI cap on Music landing (no existing convention overrides — `DashboardService.maxContinueWatching = 8` applies only to video carousel) |

---

## Objectives

1. Persist music listening history in an isolated versioned envelope.
2. Surface **Continue Listening** (incomplete tracks) and **Recently Played** (all listened tracks).
3. Resume partially listened tracks from saved position; replay completed tracks from zero.
4. Reconcile safely on catalogue replacement.
5. Never block playback on persistence failure.
6. Never corrupt video Continue Watching.

---

## In scope

- `MusicListeningRepository` (persistence-only, versioned JSON)
- `MusicListeningRecord` model with identity, position, completion, timestamps, display snapshot
- `MusicListeningCoordinator` — playback event hooks, throttled writes, flush points
- Continue Listening section on **Music landing screen only** (`MusicScreen`) — **not** the main dashboard
- Recently Played list screen (reachable from Music landing)
- Resume from Continue Listening / Recently Played (incomplete → saved position; complete → zero)
- Catalogue replacement reconciliation via `CatalogCacheCoordinator`
- Bounded retention with deterministic eviction
- Clear listening history action (confirmation dialog)
- Diagnostics summary fields (counts only)
- Unit, widget, integration, and Windows runtime tests
- Documentation and phase closure evidence

---

## Out of scope

- User-created playlists, smart playlists
- Favourites changes (remain in `LibraryMetadataRepository`)
- Queue persistence across app restart — **explicitly deferred outside Phase 5.4** (no queue serialization or restoration)
- Main dashboard Continue Listening for music
- Cross-device sync, scrobbling, recommendations
- Play counts (unless needed internally for ordering — not planned)
- Background playback / OS media controls redesign
- Video Continue Watching changes
- Scanner / catalogue schema changes
- Cosmetic redesign unrelated to Continue Listening

---

## Data model

### `MusicListeningRecord` — immutable value type

Each record is an **immutable** value object. Updates replace the entire record (copy-with semantics in the repository layer).

| Field | Type | Required | Notes |
|---|---|---|---|
| `trackId` | string | yes | **Primary identity** — catalogue `MediaItem.id` |
| `title` | string | yes | Display snapshot at last write |
| `artist` | string | yes | Display snapshot at last write |
| `album` | string | yes | Display snapshot at last write |
| `duration` | int? | no | Total seconds when known (playback or catalogue) |
| `lastPosition` | int | yes | Last known position in seconds (`0` when completed) |
| `completed` | bool | yes | Whether track treated as fully listened |
| `completedAt` | DateTime? | no | UTC when marked complete |
| `lastPlayedAt` | DateTime | yes | UTC; drives ordering and deduplication |

**Identity rules:**

- `trackId` is the sole matching key for catalogue lookup, reconciliation, resume, and deduplication.
- Snapshot fields (`title`, `artist`, `album`) are **display fallback only** when rendering between sessions.
- Snapshot metadata must **never** be used to silently remap a missing catalogue item to a different entry (no fuzzy title/artist matching).

**Invariant:** At most **one record per `trackId`**. Re-play updates the existing record (latest `lastPlayedAt` wins).

### Envelope — `ttsplayer_music_listening_v1`

```json
{
  "stateVersion": 1,
  "records": [
    {
      "trackId": "<MediaItem.id>",
      "title": "Oh Yeah",
      "artist": "Example Artist",
      "album": "Singles",
      "duration": 240,
      "lastPosition": 142,
      "completed": false,
      "completedAt": null,
      "lastPlayedAt": "2026-07-21T12:00:00.000Z"
    }
  ]
}
```

### Derived views (not stored separately)

| View | Filter | Sort | Display cap |
|---|---|---|---|
| Continue Listening | `!completed` && resume eligible (`lastPosition >= 30`) | `lastPlayedAt` desc | 8 (UI) |
| Recently Played | All records meeting 15 s listen threshold | `lastPlayedAt` desc | **20 (UI)**; **100 (storage)** |

**Retention audit:** No existing project convention overrides 100/20. Video dashboard caps (`maxContinueWatching = 8`, `maxRecentlyAdded = 12`) apply to different surfaces; music listening uses the approved 100 storage / 20 UI values above.

---

## Persistence and versioning design

- **Storage:** `shared_preferences` string at `ttsplayer_music_listening_v1`
- **Pattern:** Mirror `LibraryMetadataRepository` — `initialize`, `load`, defensive decode, `ChangeNotifier`
- **Version field:** `stateVersion: 1` — records deserialize **only** when `stateVersion == currentStateVersion`
- **Write failure:** Return `success: false`; log debug; **never throw** to playback layer
- **Isolation:** No shared keys with video resume, settings, or library metadata

| Condition | In-memory result | Warning | Source blob on read |
|---|---|---|---|
| Missing / empty key | Empty history | — | — |
| Invalid JSON | Empty history | Yes | Unchanged |
| Unsupported or missing `stateVersion` | Empty history | Yes (identifies version) | Unchanged |
| Supported v1, malformed record | Valid siblings retained | Per skipped record | Unchanged |
| Supported v1, valid envelope | Records loaded | Only if records skipped | Unchanged |

---

## Playback event and write-throttling lifecycle

### Coordinator ownership

New **`MusicListeningCoordinator`** listens to:

- `PlaybackService` (position, duration, completion, playing state) when `currentItem?.isAudio`
- `MusicPlaybackQueueController` (track change, route close, queue replace)

Does **not** modify `PlaybackService` video persistence paths.

### Minimum listen threshold (approved)

A record is **created or updated** only after **15 seconds** of meaningful cumulative playback in the current session for that track. Positions below threshold on flush are discarded (no record).

### Resume threshold (approved)

Resume and Continue Listening eligibility require **`lastPosition >= 30` seconds**. Completed tracks always restart from **0**.

### Write cadence

| Event | Action |
|---|---|
| Position tick while playing | Throttled save every **5 s** (match video `_saveInterval`) |
| Pause | Flush immediately |
| Stop / route close | Flush immediately |
| Track change (next/previous/seed) | Flush **previous** track; reset session accumulator for new track |
| Natural completion | Mark completed, flush, position → 0 |
| Auto-advance to next track | Finalize completed track before advance |
| App pause/detach (where supported) | Best-effort flush via coordinator dispose hook |
| Retry on same track | Continue same session accumulator |
| Queue replacement mid-session | Flush current track; history records unaffected |
| Persistence error | Log; playback continues |

### Session accumulator

Per-track in-memory accumulator tracks whether the 15 s threshold has been met before first persist.

---

## Continue Listening eligibility rules

A record appears in **Continue Listening** when **all** apply:

1. `completed == false`
2. `lastPosition >= 30` (`MusicListeningResumePolicy.minResumePosition`)
3. Remaining time `>= 2 minutes` when duration known (`nearEndWindow`)
4. `trackId` resolves in current catalogue with playable audio status
5. Within storage retention cap

Completed tracks, sub-threshold positions, and near-end positions are **excluded**.

---

## Recently Played rules (approved)

- Contains **both incomplete and completed** tracks that met the 15 s listen threshold
- **One record per `trackId`** — deduplicated; ordered by `lastPlayedAt` descending
- Completed tracks appear in Recently Played but **not** in Continue Listening
- Tapping completed track → play from **beginning** (`lastPosition = 0`)
- Tapping incomplete track → play from **saved position** (via `MusicPlayerScreen.startPosition`)
- Storage capped at **100** records; evict oldest by `lastPlayedAt` after each write
- Music landing UI shows up to **20** entries with **View all** → full Recently Played screen

---

## Resume and completion semantics

| Constant | Value | Rationale |
|---|---|---|
| `minListenThreshold` | 15 s | Create/update record |
| `minResumePosition` | 30 s | Offer resume / Continue Listening |
| `nearEndWindow` | 2 min | Treat as complete; exclude from Continue Listening |
| `completionPositionRatio` | ≥ 95% when duration known | Alternative completion trigger |

**Completed** when any:

- `PlaybackService.isCompleted` fires for the track, or
- Remaining duration `< nearEndWindow`, or
- Position ≥ 95% of known duration

On completion: set `completed: true`, `completedAt: now`, `lastPosition: 0`.

**Replay completed:** User selects from Recently Played → `startPosition: Duration.zero`; record stays completed until new listen session crosses thresholds again (then `completed: false`, position updates).

**Natural completion + queue advance:** Coordinator finalizes completed track **before** `MusicPlaybackQueueController` advances; next track starts fresh unless it has its own history record.

---

## Catalogue replacement reconciliation

On `CatalogCacheCoordinator.onCatalogReplaced`:

```
MusicListeningRepository.validateAgainstCatalog(catalog)
  → drop records whose trackId ∉ catalog audio playable ids
  → retain records whose trackId still resolves (same identity after rescan)
  → persist if changed
  → notifyListeners once
```

- Does not mutate `Catalog` or scanner output
- Does not reorder or corrupt in-memory queue (existing reconcile handles queue)
- **Same valid `trackId` after catalogue replace:** record and `lastPosition` **retained**; resume remains available; **no duplicate record** created (R9)
- Missing items between replacements may remain stored until next replacement (same as favourites — ADR-007)
- Snapshot fields are not used to rematch pruned ids to different catalogue entries

---

## UI and navigation design

### Music landing (`MusicScreen`)

Add sections **above** existing Artists/Albums/Tracks nav tiles:

1. **Continue Listening** — horizontal carousel (reuse `ContinueWatchingSection` layout patterns; music artwork via `MusicArtworkThumbnail`; 1:1 ratio)
2. **Recently Played** — compact horizontal list or second carousel; **View all** → `MusicRecentlyPlayedScreen`

Empty states: hide section when zero eligible entries (not blocking empty prompts on whole screen).

### Recently Played screen

- Full scrollable list, most recent first
- Row: artwork, title, artist · album, relative time, progress indicator when incomplete
- Tap → seed appropriate queue context (single-track seed for history resume — queue context from history is single-track unless user navigates to album/artist play separately)
- App bar action: **Clear history** → confirmation dialog

### Resume wiring

Extend `music_navigation.dart`:

- `openMusicPlayerScreen(..., {Duration? startPosition})`
- `_pushMusicPlayerScreen(..., {Duration? startPosition})` → pass to `MusicPlayerScreen`

Continue Listening / Recently Played tiles call navigation with resolved position.

### Dashboard (approved)

**No** music Continue Listening on the main dashboard in Phase 5.4. Video **Continue Watching** on the dashboard remains unchanged. Music entry path: `MusicSection` → `MusicScreen` where Continue Listening and Recently Played live.

---

## Error handling and failure isolation

| Failure | Behaviour |
|---|---|
| Corrupt JSON on load | Defaults + recovery warning; app continues |
| Persist write fails | Log; in-memory state retained for session; no user blocking dialog |
| Playback while persist fails | Unaffected |
| Item missing from catalogue | Hidden from UI; pruned on next catalogue replace |
| Zero/unknown duration | Completion uses `isCompleted` and near-end only; progress UI omits bar |
| Throttled write during seek storm | Coalesced to 5 s interval |

**Contract:** Persistence failure must **never** stop playback.

---

## Privacy and redaction

Diagnostics export includes:

- `musicListeningRecordCount`
- `musicContinueListeningCount`
- `musicListeningStateVersion`

Does **not** include: track titles, artist names, file paths, ids, or timestamps in export. Align with ADR-019 redaction rules.

---

## Test strategy

| Layer | Focus |
|---|---|
| Unit | Record model, envelope parse/recovery, dedupe, retention eviction, completion math, eligibility filters |
| Unit | Repository save/load/prune; simulate persist failure |
| Unit | Coordinator throttle, flush points, threshold gating, completion on advance |
| Widget | Continue Listening section empty/populated; Recently Played screen; clear history dialog |
| Widget | Resume tile passes `startPosition` |
| Integration | Play → pause → reload → resume position; complete → Recently Played only |
| Integration | Catalogue replace: stale ids pruned; same `trackId` retained (R9); video Continue Watching untouched |
| Regression | `getContinueWatching` unchanged; audio never writes `position_*` |

Fixtures: extend `kCatalogV3QueueSeedingFixture`; dedicated listening history JSON fixtures.

---

## Windows runtime validation matrix

Opt-in: `PHASE_54_RUNTIME=1` → `test/phase_54_music_listening_windows_runtime_test.dart`

| # | Scenario | Pass criteria |
|---|---|---|
| R1 | Play 45 s → pause → exit player | Record exists; `lastPosition` ≈ saved |
| R2 | Re-open from Continue Listening | Resumes when `lastPosition >= 30` |
| R3 | Play to natural completion | `completed`; absent from Continue Listening; present in Recently Played |
| R4 | Replay completed from Recently Played | Starts at 0 |
| R5 | Next track in queue | Previous track flushed; new track independent |
| R6 | Short accidental play (< 15 s) | No record created |
| R7 | Persist failure simulation | Playback continues |
| R8 | Video play after music | No `position_*` keys for audio id; video CW unchanged |
| R9 | Catalogue replacement preserves resume | Play track ≥ 15 s; save resumable position; replace/reload catalogue with same valid `trackId`; record retained; position resumable; no duplicate record; queue and catalogue state valid |

Requires libmpv (same as Phase 5.3 harness).

---

## Manual QA checklist

**Prerequisites:** Scanner 0.4.0 / catalogue schema v3 loaded.

| # | Check |
|---|---|
| 1 | Play track 45+ s → back → appears in Continue Listening |
| 2 | Re-open from Continue Listening → resumes mid-track |
| 3 | Play to end → removed from Continue Listening; appears in Recently Played |
| 4 | Replay completed track from Recently Played → starts at beginning |
| 5 | Recently Played **View all** shows full list |
| 6 | Clear history → both sections empty; confirmation required |
| 7 | Next/previous in queue → each track history independent |
| 8 | Video Continue Watching unchanged after music sessions |
| 9 | Reload catalogue — same `trackId` retained | Record and position survive; resume works; no duplicate (R9) |
| 10 | Reload catalogue — removed track | Stale entry pruned |
| 11 | Release build smoke — no regression to 5.3 playback |

---

## Definition of Done

Phase 5.4 is complete when:

- [ ] `MusicListeningRepository` persists versioned history at isolated key
- [ ] Audio playback never writes video `position_*` / `duration_*` keys (test proof)
- [ ] Continue Listening on `MusicScreen` shows incomplete eligible tracks only
- [ ] Recently Played screen shows incomplete and completed tracks
- [ ] Resume and replay semantics match specification
- [ ] Catalogue replacement prunes stale records via `CatalogCacheCoordinator`
- [ ] Retention cap enforced deterministically
- [ ] Clear history with confirmation works
- [ ] Diagnostics summary fields present; no PII in export
- [ ] Persistence failure does not block playback
- [ ] Unit/widget/integration tests pass
- [ ] `PHASE_54_RUNTIME=1` matrix passes on Windows
- [ ] Manual QA checklist signed off
- [ ] ADR-022 **Partially Accepted** (listening history); not fully Accepted until queue persistence ships
- [ ] Architecture and release docs reconciled
- [ ] Video Continue Watching regression pass

---

## Implementation steps and proposed commit sequence

| Step | Deliverable | Proposed commit prefix | Status |
|---|---|---|---|
| **1** | Planning + approved decisions | `docs(m5.4): complete Phase 5.4 listening history planning` | ✅ |
| **2** | Models + `MusicListeningRepository` + unit tests | `feat(music): add listening history repository` | ✅ |
| **3** | `MusicListeningCoordinator` + playback hooks + unit tests | `feat(music): persist listening progress from playback` | ✅ |
| **4** | Catalogue reconciliation in `CatalogCacheCoordinator` | `feat(music): reconcile listening history on catalogue replace` | ✅ |
| **5** | `MusicScreen` Continue Listening + Recently Played UI + resume navigation | `feat(music): add Continue Listening and Recently Played UI` | ✅ |
| **6** | Clear listening history + confirmation | `feat(music): add clear listening history action` | ✅ |
| **7** | Diagnostics summary fields | `feat(diagnostics): add music listening summary counts` |
| **8** | Integration + widget tests | `test(music): cover listening history and Continue Listening` |
| **9** | Windows runtime harness `PHASE_54_RUNTIME` | `test(music): add Phase 5.4 Windows runtime harness` |
| **10** | Documentation + ADR-022 update + phase closure | `docs(m5.4): close listening history phase` |

Do not combine unrelated steps. README.md remains unstaged.

---

## Risks and deferred work

| Risk | Mitigation |
|---|---|
| Accidental key namespace collision | Code review + test asserting no `position_*` writes for audio |
| Large prefs payload | Cap 100 records; compact snapshot fields |
| Duration unknown at scan | Use MediaKit runtime duration in coordinator |
| Queue context lost on history resume | 5.4 uses single-track seed from history; album/artist context deferred |
| Snapshot remapping | Never match by title/artist; `trackId` only |

### Deferred outside Phase 5.4 (approved)

| Item | Notes |
|---|---|
| **Queue persistence across app restart** | No queue serialization or restoration in 5.4; ADR-022 `queue` section — target 5.5 or post-M5 |
| Music favourites extension | ADR-022 `favourites` section |
| Shuffle / repeat | 5.3 deferred |
| Play counts, playlists, scrobbling | Post-M5 |
| Dashboard-level music Continue Listening | Explicitly excluded — Music landing only |

---

## Related commits (Phase 5.3 baseline)

Phase 5.3 complete — album/artist queue seeding, Windows Release validation, catalogue v3 prerequisite documented (`7c516aa` docs; prior `dfb0496`, `48fa72a`).
