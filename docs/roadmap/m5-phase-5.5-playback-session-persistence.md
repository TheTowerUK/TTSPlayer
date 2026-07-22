# M5 Phase 5.5 — Playback Session Persistence

**Status:** **PLANNING** — specification locked (2026-07-22)
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Predecessor:** Phase 5.4 complete (2026-07-22)

→ [M5 plan](./m5-plan.md)
→ [Phase 5.4 spec](./m5-phase-5.4-listening-history-continue-listening.md) · [Closure report](./m5-phase-5.4-closure-report.md)
→ [Music architecture](../architecture/music.md#11-application-state-model)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md)

---

## Executive Summary

Phase 5.5 delivers **persistent music playback session state** across application restart — the final open criterion in [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) for full ADR acceptance. Today, `MusicPlaybackQueueController` holds an in-memory queue that is lost when the app exits. This phase adds a versioned repository envelope, debounced persistence, cold-start restoration, and catalogue reconciliation — mirroring the patterns established in Phase 5.4 for listening history and in M4 for library metadata.

The phase is **planning-only** at this commit. No production code or tests are modified until implementation begins.

**Scope realignment note:** The original [M5 plan](./m5-plan.md) listed Phase 5.5 as “Performance, Diagnostics and Runtime Validation.” That work remains valuable but is **deferred** to a later M5 increment (likely Phase 5.6 realignment or a dedicated performance pass) so that ADR-022 queue persistence — explicitly deferred from Phase 5.4 — ships first.

---

## Objective

Persist and restore the user's **active music queue session** locally so that:

1. After application restart, the ordered queue, current track index, and in-track position can be recovered when catalogue items still resolve.
2. Stale track IDs are pruned on catalogue replacement without corrupting listening history or video resume keys.
3. Persistence failures never block playback or catalogue loading.
4. ADR-022 can move from **Partially Accepted** to **Accepted** for the queue-persistence acceptance criterion.

---

## Scope

### In scope

| Capability | Description |
|---|---|
| **Session repository** | New versioned JSON envelope in `shared_preferences`, isolated from listening history and video keys |
| **Persisted fields** | Ordered track IDs, current index, optional queue source descriptor, current-track playback position, paused/playing intent flag |
| **Save triggers** | Debounced persistence on queue mutation, index change, position milestones, pause/stop, and app lifecycle exit |
| **Cold-start restore** | After catalogue load, hydrate in-memory queue from persisted envelope when IDs resolve |
| **Catalogue reconciliation** | Prune unavailable IDs; refresh metadata for retained IDs; clear session when no playable tracks remain |
| **Integration** | Wire through `MusicPlaybackQueueController`, `CatalogCacheCoordinator`, and `main.dart` startup order |
| **Diagnostics** | Aggregate session-restored / queue-depth / persistence-warning counts — redacted, no track metadata |
| **Tests** | Unit, integration, and opt-in Windows runtime harness (`PHASE_55_RUNTIME=1`) |
| **Documentation** | Architecture, ADR-022 acceptance update, release notes, index reconciliation |

### Behavioural contracts (approved for planning)

| Contract | Rule |
|---|---|
| Identity | Catalogue `trackId` only — never rematch by title, artist, album, or path |
| Video isolation | Audio queue session must **not** write `position_*` / `duration_*` video resume keys |
| Listening history isolation | Queue persistence is independent of `MusicListeningRepository`; clear-history does not clear queue (5.4 established) |
| Auto-play on cold start | **No** — restored queue is available in memory; user opens player to resume (desktop-first) |
| Empty after prune | If all track IDs stale after reconcile or restore, persist empty envelope and leave queue empty |
| Player route | Persisted session survives restart even if player route was closed before exit — restore queue only; do not force navigation |

---

## Out of Scope

| Item | Notes |
|---|---|
| Shuffle / repeat mode persistence | Phase 5.3 deferred; not required for ADR-022 acceptance |
| Multi-device or cloud sync | M5 explicit exclusion |
| Music favourites envelope extension | ADR-022 deferred; remains `LibraryMetadataRepository` |
| User playlists | Post-M5 |
| Automatic playback on app launch | Poor desktop UX; user-initiated resume only |
| Dashboard or Music landing “restore session” UI | Optional future polish; 5.5 restores controller state only |
| OS media session / lock-screen controls | Post-M5 |
| Scanner / catalogue schema changes | Application state only |
| Listening history threshold or UI changes | Phase 5.4 complete — no regression |
| Large-library performance gates | Deferred from original 5.5 performance scope |
| SQLite or secondary store | `shared_preferences` JSON envelope per existing patterns |

---

## User Experience

### Expected behaviour after implementation

| Scenario | User-visible outcome |
|---|---|
| Play album, exit app mid-track, relaunch | Queue and current track restored; opening Music Player resumes from saved position when user navigates to player |
| Play queue, all tracks removed on rescan | Queue silently empty; no crash; listening history reconciled separately |
| Clear listening history | Queue unchanged (5.4 behaviour preserved) |
| Video session | Unaffected — video resume keys and Continue Watching unchanged |
| Corrupt persisted JSON | App launches; empty queue; recovery logged for diagnostics |
| Persist write failure during playback | Playback continues; warning available in diagnostics |

### Non-goals for UX

- No new settings toggle for “remember queue” in 5.5 — persistence is always on when implemented (local-first default).
- No toast or banner on successful restore — silent hydration unless diagnostics/debug surfaces state.

---

## Design Principles

1. **Filesystem is truth** — persisted IDs resolve against current catalogue only; never invent tracks.
2. **Separate envelopes** — queue session, listening history, and video resume use distinct storage keys and repositories.
3. **Repository owns policy** — controller triggers save/restore; reconciliation logic lives in the session repository (same as 5.4 listening history).
4. **Graceful degradation** — corrupt, unsupported, or partial envelopes load empty with warnings; app remains usable.
5. **Failure isolation** — persistence errors never propagate to playback listeners or block catalogue replacement.
6. **Debounced writes** — avoid excessive `shared_preferences` churn during seek scrubbing (align with 5 s listening throttle philosophy).
7. **Atomic persistence** — write temp + rename or single JSON replace pattern matching listening history and catalogue atomicity expectations.
8. **Testability** — injectable clock, simulate persist failure, deterministic catalogue fixtures.

---

## Architecture

### Component model (planned)

| Component | Responsibility |
|---|---|
| `MusicPlaybackSession` | Immutable value type: queue track IDs, active track ID, position, updated timestamp |
| `MusicPlaybackSessionRepository` | Load/save/clear envelope; `ChangeNotifier` (catalogue reconcile in Step 3) |
| `MusicPlaybackSessionCoordinator` | Observes queue + playback; debounced queue writes; throttled position writes *(Step 2)* |
| `MusicPlaybackQueueController` | Invoke persist on mutation; call restore after catalogue ready; existing `reconcileWithCatalog` delegates to repository policy |
| `CatalogCacheCoordinator` | Trigger session validation after successful catalogue replace (parallel to listening history) |
| `DiagnosticsService` | Read aggregate session flags/counts only |

### Storage key (proposed)

```
ttsplayer_music_queue_v1
```

Separate from:

- `ttsplayer_music_listening_v1` (Phase 5.4)
- `position_*` / `duration_*` (video resume)
- `ttsplayer_library_metadata_v1` (favourites)

### Envelope shape (implemented v1 — Step 1)

```json
{
  "stateVersion": 1,
  "session": {
    "queueTrackIds": ["id-a", "id-b", "id-c"],
    "activeTrackId": "id-b",
    "playbackPositionMs": 142000,
    "updatedAt": "ISO-8601"
  }
}
```

| Field | Notes |
|---|---|
| `session.queueTrackIds` | Ordered catalogue IDs only — not file paths; blank/duplicate IDs normalised on load/save |
| `session.activeTrackId` | Current track identity; falls back to first queue item when absent from queue |
| `session.playbackPositionMs` | Current track position at last persist; `0` when queue empty or no active track |
| `session.updatedAt` | Last persistence timestamp |

**Step 1 scope:** identity fields only — no titles, artwork, queue-source labels, or `wasPlaying`. Those may be evaluated in later integration steps if needed.

### Step 2 coordinator timing (implemented)

| Policy | Value | Behaviour |
|---|---|---|
| Queue mutation debounce | 250 ms | Coalesces rapid `replaceQueue` / add / remove changes |
| Position throttle | 5 s | Periodic position snapshots while playing |
| Seek detection | > 2 s jump | Immediate position persist (not counted as periodic throttle) |
| Immediate flush | — | Active-track change, pause, stop-with-queue, seek, clear, dispose |

Generation tokens prevent stale debounced/throttled writes from overwriting newer immediate snapshots. Timing policy lives in the coordinator — not the repository.

### Step 3 catalogue reconciliation (implemented)

| Rule | Behaviour |
|---|---|
| Integration | `CatalogCacheCoordinator.onCatalogReplaced` → `MusicPlaybackSessionRepository.validateAgainstCatalog` |
| Identity | Playable audio `trackId` only — video/image/non-playable IDs removed |
| Order | Surviving IDs keep persisted relative order |
| Active survives | Preserve `activeTrackId` and `playbackPosition` |
| Active removed | First surviving ID becomes active; position reset to zero |
| Queue empty | Persist canonical empty session |
| No-change | Equivalent reconciled session → no storage write |
| Failure | Catalogue replacement continues; in-memory session unchanged on persist failure |
| Live queue | **Not** hydrated — persisted repository only (Step 4 restores on startup) |

### Startup sequence (planned)

```
main()
  → initialize repositories (settings, metadata, listening, session)
  → load catalogue (CatalogService)
  → sessionRepository.restoreAgainstCatalog(catalog)  // prune stale, hydrate controller
  → attach coordinators / queue controller
  → user opens MusicPlayerScreen → playCurrent(startPosition: restored)
```

Restore runs **after** catalogue is available and **before** user-initiated playback. Exact wiring order to be validated in Step 1 repository audit against `main.dart` dependency graph.

### Dependency diagram

```
CatalogService ──► CatalogCacheCoordinator.onCatalogReplaced
                         ├── MusicListeningRepository.validateAgainstCatalog
                         └── MusicPlaybackSessionRepository.validateAgainstCatalog (new)

MusicPlaybackQueueController ◄── persist / restore ──► MusicPlaybackSessionRepository
         │
         └── PlaybackService (position, play state — read only for persist)
```

---

## Persistence

### Save triggers (planned)

| Event | Persist? | Notes |
|---|---|---|
| Queue replace / seed album / seed artist | Yes (debounced) | Full envelope rewrite |
| Next / previous / completion advance | Yes (debounced) | Index change |
| Pause | Yes (immediate) | Capture position |
| Stop / clear queue | Yes (immediate) | Empty envelope |
| Position tick while playing | Yes (throttled) | Proposed 5 s debounce — match listening coordinator |
| App lifecycle paused / detached | Yes (immediate) | Flush pending debounce |
| Catalogue replace | Via reconcile | Not a direct user save |

### Retention and size

| Limit | Value | Rationale |
|---|---|---|
| Max tracks in persisted queue | Same as in-memory practical cap | Proposed **500** IDs max — document in Step 1; truncate oldest or reject excess |
| Envelope size | Monitor via diagnostics byte estimate | Informational only |

### Corruption and version recovery

Mirror `MusicListeningRepository` contract:

| Condition | In-memory result | Warning | Source blob |
|---|---|---|---|
| Missing / empty key | Empty session | — | — |
| Invalid JSON | Empty session | Yes | Unchanged on read |
| Unsupported `stateVersion` | Empty session | Yes | Unchanged on read |
| Valid v1, unknown track on restore | Skip ID; continue siblings | Optional aggregate count | — |
| All IDs stale | Empty session | Yes | Persist empty on reconcile |

---

## Catalogue Behaviour

### Reconciliation algorithm (planned)

Invoked from `CatalogCacheCoordinator` after **successful** catalogue replacement only (same hook as listening history and favourites):

1. Build audio item map by `MediaItem.id` from new catalogue.
2. For each persisted / in-memory session track ID in order:
   - **Present and playable:** retain ID; optionally refresh snapshot label in envelope only.
   - **Absent or non-playable:** drop ID.
3. Recompute `currentIndex`:
   - If current track ID retained, rebind index to new position in filtered list.
   - If current track dropped, clamp to nearest valid index or empty if none.
4. Persist reconciled envelope when changed; notify listeners once.

**Active playback:** If player route is open and current track removed, follow existing `reconcileWithCatalog` behaviour — stop or advance per controller policy; session repository must not throw.

### Failed catalogue load

Failed catalogue refresh does **not** mutate persisted session (parallel to Phase 5.4 R9 / listening history).

---

## Failure Behaviour

| Failure | Required behaviour |
|---|---|
| Persist write fails | Log; retain in-memory session; set repository warning flag; playback unaffected |
| Restore fails on startup | Empty session; app usable; diagnostics flag |
| Reconcile persist fails | Keep pre-reconcile in-memory session; catalogue replace still succeeds |
| Partial track resolution | Restore playable subset; drop stale IDs |
| Controller dispose during write | Await or cancel in-flight write safely — no crash |

**Contract:** Persistence failure must **never** stop playback or block catalogue loading.

---

## Diagnostics

Extend diagnostics with **aggregate session fields only** (no track IDs, titles, paths, or URLs in export).

### Proposed fields (Music Listening section extension or adjacent “Playback Session” subsection)

| Field | Type | Source |
|---|---|---|
| `sessionRepositoryLoaded` | bool | Repository |
| `hasPersistedSession` | bool | Non-empty envelope on disk |
| `restoredTrackCount` | count | After last restore |
| `persistedTrackCount` | count | Last saved envelope |
| `sessionRecoveryWarningPresent` | bool | Parse/recovery |
| `sessionPersistenceWarningPresent` | bool | Last write failure |
| `lastRestoreSucceeded` | bool | Startup hook |

**Redaction:** Align with [ADR-019](../architecture/decisions/ADR-019-diagnostics-export-support-strategy.md) and Phase 5.4 Music Listening patterns — counts and booleans only.

**Read-only:** Diagnostics capture must not trigger restore, persist, clear, or reconcile side effects.

---

## Validation Strategy

### Automated

| Layer | Focus |
|---|---|
| Unit | Envelope parse/recovery; debounce; index clamp; prune; empty restore; persist failure simulation |
| Unit | Repository `validateAgainstCatalog` — retain, drop, index rebind |
| Integration | Cold-start restore after mock restart; catalogue replace with active session; listening history unchanged |
| Integration | Clear listening history does not clear session; clear session does not clear listening history |
| Regression | Video `position_*` keys untouched; dashboard Continue Watching unchanged |
| Widget | Optional — player shows restored queue length when opened (if UI exposes count) |

### Windows runtime (opt-in)

| Variable | Purpose |
|---|---|
| `PHASE_55_RUNTIME=1` | Gate runtime suite |
| `PHASE_55_AUDIO_FILE` | Optional real playback fixture (reuse 5.3/5.4 convention) |

**Tag:** `phase55-runtime`

**Planned scenarios (R1–R10 matrix to be finalized in Step 2):**

| ID | Scenario |
|---|---|
| R1 | Production wiring — repository initializes; controller hydrates |
| R2 | Persist queue + position; reload repository; restore matches |
| R3 | Cold-start simulation — dispose/recreate against same prefs |
| R4 | Catalogue replace — retain IDs, drop stale, index rebind |
| R5 | Failed catalogue load — session unchanged |
| R6 | Real libmpv playback + persist + restore position |
| R7 | Clear queue clears envelope |
| R8 | Listening history clear does not affect session |
| R9 | Diagnostics counts match repository state |
| R10 | Corrupt envelope — empty restore, no crash |

### Manual QA (Release binary)

- Play album mid-track → exit app → relaunch → open player → verify queue and position.
- Rescan library removing current track → verify graceful empty or truncated queue.
- Video regression smoke unchanged.

---

## Documentation Updates

To be applied during implementation and closure (not in this planning commit):

| Document | Update |
|---|---|
| [m5-plan.md](./m5-plan.md) | Realign Phase 5.5 scope to playback session persistence; relocate performance validation |
| [music.md](../architecture/music.md) | §11 Application state model — queue persistence row |
| [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) | Acceptance scope → **Accepted** when 5.5 DoD met |
| [diagnostics.md](../architecture/diagnostics.md) | Session aggregate fields |
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | Phase 5.5 progress / completion entry |
| [MILESTONES.md](../../MILESTONES.md) · roadmap/release indexes | Phase 5.5 status |
| Phase 5.5 closure report | Post-implementation (pattern: 5.4 closure report) |

---

## Definition of Done

Phase 5.5 is complete when:

### Architecture and persistence

- [ ] `MusicPlaybackSessionRepository` persists versioned session at isolated key `ttsplayer_music_queue_v1`
- [ ] Envelope corruption and unsupported version recovery match listening-history patterns
- [ ] Debounced save on queue mutation and throttled position persist documented and tested
- [ ] Cold-start restore hydrates controller after catalogue load
- [ ] No video `position_*` / `duration_*` writes for audio session (test proof)

### Catalogue lifecycle

- [ ] `validateAgainstCatalog` prunes stale track IDs and rebinds current index
- [ ] Failed catalogue replacement does not mutate persisted session
- [ ] Metadata refresh does not rematch by title/artist/path

### Playback integration

- [ ] `MusicPlaybackQueueController` persists through repository on defined triggers
- [ ] Pause/stop/clear flush pending session state
- [ ] No auto-play on cold start
- [ ] Active playback survives reconcile when current track retained

### Isolation

- [ ] Listening history repository unchanged in semantics; clear history does not clear queue
- [ ] Video Continue Watching regression pass

### Diagnostics

- [ ] Aggregate session fields in diagnostics export — no PII
- [ ] Read-only capture; failure isolation per Phase 4.6

### Validation

- [ ] Unit and integration tests pass
- [ ] `PHASE_55_RUNTIME=1` matrix passes on Windows
- [ ] Release build succeeds; manual restore smoke pass
- [ ] Full Flutter suite green

### Documentation and ADR

- [ ] Architecture and roadmap indexes reconciled
- [ ] **ADR-022 → Accepted** for queue persistence criterion (favourites/playlists remain deferred per ADR scope table)
- [ ] Phase 5.5 closure report published

---

## Architectural Risks

| Risk | Mitigation |
|---|---|
| Persist churn during seek scrubbing | 5 s position throttle; immediate flush on pause/stop |
| Large queue JSON payload | Cap persisted track count; diagnostics size observation |
| Restore before catalogue ready | Strict startup ordering in `main.dart`; restore hook after first successful catalog load |
| Race between listening coordinator flush and session persist | Serialize or ordering contract documented in Step 1 audit |
| Duplicate reconcile in controller and repository | Single policy owner in repository; controller calls repository API |
| User expects auto-play on launch | Document UX contract; no auto-play in 5.5 |
| ADR-022 premature Accepted | Promote only queue-persistence row; favourites/playlists stay deferred |
| m5-plan 5.5 performance scope drift | Explicit realignment note; performance pass scheduled separately |
| `shared_preferences` size limits on desktop | Cap queue length; monitor envelope size in diagnostics |
| Stale session after long offline period | Prune on restore against current catalogue; empty if all stale |

---

## Implementation steps (proposed)

| Step | Deliverable | Proposed commit prefix |
|---|---|---|
| **1** | Repository audit + model/envelope + unit tests | `feat(music): add playback session repository` |
| **2** | Session coordinator persistence hooks | `feat(music): persist playback session` *(complete)* |
| **3** | Catalogue reconciliation integration | `feat(music): reconcile playback session after catalogue update` *(complete)* |
| **4** | Cold-start restore in `main.dart` | `feat(music): restore music queue on startup` |
| **5** | Diagnostics integration | `feat(diagnostics): add playback session summary counts` |
| **6** | Integration test suite | `test(music): add playback session integration suite` |
| **7** | Windows runtime harness | `test(music): add Phase 5.5 Windows runtime harness` |
| **8** | Integration validation + regression | `test(music): validate playback session regression` |
| **9** | Windows runtime execution + manual QA | *(evidence in docs)* |
| **10** | Documentation + ADR-022 acceptance + closure | `docs(m5.5): close playback session persistence phase` |

Do not combine unrelated steps. `README.md` remains unstaged if locally modified.

---

## Related commits (Phase 5.4 baseline)

Phase 5.4 complete — listening history, Continue Listening, reconciliation, clear, diagnostics (`75a4f2a` … `4fdc7ca`). Queue controller in-memory reconcile exists (`reconcileWithCatalog` in `MusicPlaybackQueueController`) — Phase 5.5 adds persistence layer beneath it.

---

## Approved planning decisions (2026-07-22)

| Decision | Resolution |
|---|---|
| Phase 5.5 primary scope | Playback session / queue persistence (ADR-022 open criterion) |
| Original 5.5 performance scope | Deferred — not blocked by this phase |
| Storage | Isolated `shared_preferences` JSON envelope, not catalogue file |
| Cold-start auto-play | **No** — restore queue silently; user opens player |
| ADR-022 at 5.5 closure | **Accepted** for queue persistence only if DoD met |
| Identity | `trackId` only — same as Phase 5.4 |

---

## Open questions (resolve in Step 1 audit)

1. **Coordinator vs inline persist** — separate `MusicPlaybackSessionCoordinator` or methods on queue controller calling repository directly?
2. **Max persisted queue length** — hard cap value (500 proposed) and truncation policy.
3. **Diagnostics placement** — extend Music Listening section vs new ninth section (prefer extend unless export order breaks).
4. **App lifecycle wiring** — `WidgetsBindingObserver` in shell vs repository flush from existing coordinator `onAppLifecyclePaused`.
5. **Phase numbering for performance work** — fold into 5.6 release phase or insert 5.5b — resolve when updating `m5-plan.md`.
