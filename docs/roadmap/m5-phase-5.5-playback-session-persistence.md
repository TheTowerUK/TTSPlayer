# M5 Phase 5.5 — Playback Session Persistence

**Status:** ✅ **COMPLETE** (2026-07-23)
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Predecessor:** Phase 5.4 complete (2026-07-22)
**Closure:** [m5-phase-5.5-closure-report.md](./m5-phase-5.5-closure-report.md)

→ [M5 plan](./m5-plan.md)
→ [Phase 5.4 spec](./m5-phase-5.4-listening-history-continue-listening.md) · [Closure report](./m5-phase-5.4-closure-report.md)
→ [Music architecture](../architecture/music.md#11-application-state-model)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) — **Accepted**

---

## Executive Summary

Phase 5.5 delivers **persistent music playback session state** across application restart — the final open criterion in [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md). The live queue, active track, and in-track position survive exit and cold start; restoration is silent (no autoplay); catalogue replacement prunes stale IDs; lifecycle transitions flush the latest snapshot; diagnostics expose aggregate session fields only.

**Scope realignment note:** The original [M5 plan](./m5-plan.md) listed Phase 5.5 as “Performance, Diagnostics and Runtime Validation.” That work remains valuable and is **deferred** to Phase 5.6 / a dedicated performance pass so that ADR-022 queue persistence shipped first.

---

## Final architecture

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

| Component | Path |
|---|---|
| Session model / policy | `lib/features/music/models/music_playback_session*.dart` |
| Repository | `lib/features/music/services/music_playback_session_repository.dart` |
| Coordinator | `lib/features/music/services/music_playback_session_coordinator.dart` |
| Restorer | `lib/features/music/services/music_playback_session_restorer.dart` |
| Lifecycle observer | `lib/widgets/music_playback_session_lifecycle_observer.dart` |
| Diagnostics | `MusicPlaybackSessionDiagnostics` via `DiagnosticsService` |
| Catalogue hook | `CatalogCacheCoordinator.onCatalogReplaced` |

### Storage key and envelope

| Item | Value |
|---|---|
| Key | `ttsplayer_music_queue_v1` |
| Version | `stateVersion: 1` |
| Fields | `queueTrackIds`, `activeTrackId`, `playbackPositionMs`, `updatedAt` |
| Identity | Catalogue track ID only |

Isolated from `ttsplayer_music_listening_v1`, video `position_*` / `duration_*`, and settings.

### Queue / position persistence timing

| Policy | Value |
|---|---|
| Queue mutation debounce | 250 ms |
| Position throttle | 5 s while playing |
| Seek detection | > 2 s jump → immediate |
| Immediate flush | Active-track change, pause, stop, clear, lifecycle, dispose |

### Catalogue reconciliation

Playable audio IDs only; surviving order preserved; active removed → first survivor + position zero; empty → canonical empty session; runtime replace does **not** rehydrate the live queue.

### Cold-start ordering

Init session repo → load catalogue → reconcile → restore live queue → enable coordinator persistence (no redundant write).

### Deferred seek

`restoredStartPosition` on the queue; applied on next user-initiated `playCurrent` only.

### Lifecycle persistence

`MusicPlaybackSessionLifecycleObserver` flushes on `inactive` / `paused` / `detached` / `hidden` when persistence is enabled; one flush per background transition until `resumed`.

### Diagnostics and redaction

Section **Music Playback Session** — counts and booleans only; no track IDs, titles, paths, or raw JSON.

---

## Implementation steps (complete)

| Step | Deliverable | Commit |
|---|---|---|
| **1** | Repository + envelope | `ace3afe` |
| **2** | Coordinator persistence | `0a58424` |
| **3** | Catalogue reconciliation | `7f7f6d7` |
| **4** | Cold-start restoration | `b150b143` |
| **5** | Lifecycle + diagnostics | `da83b58` |
| **6** | Windows runtime + closure | (this phase) |

Planning baseline: `666648f`.

---

## Validation evidence (Step 6)

### Automated totals

| Suite | Result |
|---|---|
| Focused session unit/widget/wiring | **170 passed** |
| Queue + listening isolation focus | **87 passed** |
| Catalogue invalidation + diagnostics | **46 passed** |
| Dashboard + diagnostics screen | **26 passed** |
| `PHASE_55_RUNTIME=1` Windows harness PS1–PS16 | **16 passed** |
| Default `flutter test` (no runtime env) | **1068 passed**, **13 skipped**, 0 failed |
| Skip gate without `PHASE_55_RUNTIME` | **1 skipped** (named) |
| `flutter analyze` | No new errors (pre-existing infos/warnings only) |
| `git diff --check` | Clean |
| Windows Release build | ✅ `build\windows\x64\runner\Release\ttsplayer.exe` |

### Runtime matrix (PS1–PS16)

| ID | Scenario | Classification | Result |
|---|---|---|---|
| PS1 | Runtime gate + production wiring | Automated runtime | ✅ |
| PS2 | Create persistent queue | Automated runtime | ✅ |
| PS3 | Active-track mutation | Automated runtime | ✅ |
| PS4 | Playback-position persistence (45 s) | Automated runtime | ✅ (±2 s tolerance) |
| PS5 | Lifecycle flush | Automated runtime | ✅ |
| PS6 | Simulated cold restart (pre-restore) | Automated runtime | ✅ |
| PS7 | Cold-start restoration | Automated runtime | ✅ |
| PS8 | No-autoplay guarantee | Automated + manual audible | ✅ |
| PS9 | Deferred position on Play | Automated runtime | ✅ |
| PS10 | Queue transport after restore | Automated runtime | ✅ |
| PS11 | Catalogue reconciliation | Automated runtime | ✅ |
| PS12 | Empty reconciliation | Automated runtime | ✅ |
| PS13 | Diagnostics snapshot/export | Automated runtime | ✅ |
| PS14 | Diagnostics redaction | Automated runtime | ✅ |
| PS15 | Listening/video/settings isolation | Automated runtime | ✅ |
| PS16 | Failure recovery | Automated runtime | ✅ |

**Runtime environment:** Windows 11 Pro 10.0.26200; Dart 3.12.2; MediaKit via `libmpv-2.dll`; isolated `SharedPreferences.setMockInitialValues`; catalogue fixture `PHASE55-RUNTIME` with generated WAV paths under temp dirs.

### Manual Windows validation checklist

Validate on Release binary (`flutter build windows --release`):

1. Start with a clean session (or accept empty restore).
2. Open an album/artist and create a multi-track queue.
3. Select a middle track.
4. Play and seek to a recognisable position (≥30 s, not near end).
5. Pause playback.
6. Close the application normally.
7. Relaunch the application.
8. Confirm queue and current-track selection are restored.
9. Confirm playback does **not** start automatically (no audible output).
10. Press Play.
11. Confirm playback begins from approximately the stored position.
12. Confirm Next and Previous work after restoration.
13. Open Settings → Diagnostics; confirm **Music Playback Session** aggregates.
14. Export diagnostics; confirm no track IDs, titles, artists, albums, filenames, or paths from the session fixture.
15. Confirm video playback/resume still works.
16. Confirm Continue Listening and Recently Played still work.

**Observations (Step 6):** Automated harness covers PS1–PS16 with production repository/coordinator/restorer/queue. Audible no-autoplay and Release UI smoke remain operator-confirmed on the local Windows workstation using the built Release exe (checklist above). Position tolerance documented at ±2 s for MediaKit seek; simulated path used exact 45 000 ms.

---

## Known limitations

- Shuffle / repeat mode are not persisted.
- Prior playing/paused engine state is not restored (by design — no autoplay).
- Runtime catalogue replace reconciles the persisted envelope only; live queue uses existing `reconcileWithCatalog` (does not rehydrate from storage).
- Large-library performance gates remain deferred (original 5.5 performance scope).

## Explicit deferred scope

- Autoplay / restore of playing state
- Shuffle / repeat persistence
- Playlist persistence; favourites redesign
- Video queue persistence
- Phase 5.6 release packaging and original performance-validation realignment
- Mobile-specific lifecycle beyond shared Flutter observer behaviour

---

## Definition of Done

| # | Criterion | Status |
|---|---|---|
| 1 | Versioned playback-session repository | ✅ |
| 2 | Queue mutations persist | ✅ |
| 3 | Active-track changes persist | ✅ |
| 4 | Position persists (throttle + immediate) | ✅ |
| 5 | Lifecycle flush | ✅ |
| 6 | Catalogue reconciliation | ✅ |
| 7 | Cold-start live queue hydrate | ✅ |
| 8 | No autoplay on restore | ✅ |
| 9 | Deferred position on explicit Play | ✅ |
| 10 | Listening history independent | ✅ |
| 11 | Video resume independent | ✅ |
| 12 | Diagnostics aggregate session state | ✅ |
| 13 | Diagnostics redact media identity | ✅ |
| 14 | Persistence failures non-fatal | ✅ |
| 15 | Focused automated tests pass | ✅ |
| 16 | Full Flutter suite passes | ✅ |
| 17 | Windows runtime harness passes | ✅ |
| 18 | Windows Release build succeeds | ✅ |
| 19 | Manual Windows checks documented | ✅ |
| 20 | ADR-022 Accepted | ✅ |
| 21 | Roadmap / architecture current | ✅ |
| 22 | README outside phase commit | ✅ |

**Phase 5.5: COMPLETE.** Next was Phase 5.6 performance hardening (complete 2026-07-24); M5 release closure complete — [m5-complete.md](../release/m5-complete.md).
