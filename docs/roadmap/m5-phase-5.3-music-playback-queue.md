# M5 Phase 5.3 — Music Playback and Queue

**Status:** **In progress** — Step 2 complete (2026-07-20); Step 1 complete; Gate 0 complete
**Milestone:** M5 — Music
**Branch:** `m5-development`

→ [M5 plan](./m5-plan.md#phase-53--music-playback-and-queue)
→ [Music architecture](../architecture/music.md)
→ [Playback architecture](../architecture/playback.md)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md)
→ [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md)

---

## Objective

Deliver shared audio playback with a dedicated music player surface (Step 1), then an in-memory playback queue with next/previous transport and automatic completion advancement (Step 2). Persistence, shuffle, repeat, listening history, Continue Listening, and album queue seeding remain deferred.

---

## Step 1 audit — single-track playback (approved)

| Area | Finding |
|---|---|
| **Track selection** | Play actions call `openMusicPlayerScreen(context, track:)` which seeds the queue and pushes `MusicPlayerScreen` |
| **Playback invoke** | `MusicPlaybackQueueController.playCurrent()` → `PlaybackService.play()` |
| **Completion** | `PlaybackService.isCompleted`; replay via `replayCurrent()` |
| **Route close** | `MusicPlayerScreen.dispose()` schedules `onPlayerRouteClosed()` → stop + clear queue |
| **Session replacement** | Single `PlaybackService`; video replaces audio and vice versa |
| **Catalogue lifecycle** | `CatalogCacheCoordinator.onCatalogReplaced` → queue reconciliation |
| **Provider ownership** | `MusicPlaybackQueueController` registered in `main.dart` alongside `PlaybackService` |
| **Tests** | `music_player_screen_test.dart`, `music_player_integration_test.dart`, Windows runtime harness |

**Step 1 commits:** `f1fea36`…`2b4e884`

---

## Step 2 — In-memory queue core (2026-07-20)

### Queue ownership boundary

| Concern | Owner |
|---|---|
| Ordered track list, current index | `MusicPlaybackQueueController` + immutable `PlaybackQueue` |
| Active media transport, position, errors | `PlaybackService` |
| Completion auto-advance | Coordinator listens to `PlaybackService`; guarded by `_advanceInFlight` and `_wasCompleted` |
| Catalogue reconciliation | `CatalogCacheCoordinator` → `reconcileWithCatalog()` |

No second `media_kit.Player`. No persistence. No listening-history writes.

### Model — `PlaybackQueue`

- Audio-only `MediaItem` entries; duplicates allowed (list order preserved)
- `generation` increments on replace/reconcile
- `reconcile(resolvedById)` retains order; refreshes metadata by stable id

### Coordinator — `MusicPlaybackQueueController`

| Operation | Behaviour |
|---|---|
| `seedSingleTrack` | One-item queue; used by all existing play actions |
| `next` | Advance if `hasNext`; no wrap at end |
| `previous` | If position > **4 s** → restart current; else previous item or seek to 0 on first item |
| Completion | Auto-advance when next exists; final item stays completed (replay available) |
| Route close | Stop playback; clear queue |
| Video session | Clears queue when non-audio `currentItem` detected |
| Catalogue replace | Retain items by id; stop if empty; replay current when route active and playback id stale |
| Failed refresh | Queue unchanged (reconcile not invoked) |
| Error on current item | No auto-skip; retry replays current; next/previous still available |

### MusicPlayerScreen (Step 2 UI)

- Previous / next controls with semantic labels
- Disabled when unavailable (one-item queue disables both)
- Optional position indicator `N of M` when length > 1
- No shuffle, repeat, or queue panel

### Tests added

- `playback_queue_test.dart` — model invariants
- `music_playback_queue_controller_test.dart` — coordinator semantics
- Updated widget/integration tests; Windows runtime extended for three-track queue (`PHASE_53_RUNTIME=1`)

### Validation (2026-07-20)

| Suite | Result |
|---|---|
| Flutter | **730 passed**, 12 skipped, 0 failed |
| Windows queue runtime | **2 passed** (three-track transport + one-item disable) |

---

## Deferred (later M5.3 steps)

- Album / artist queue seeding (“Play album”)
- Shuffle and repeat
- Queue panel UI
- `MusicStateRepository` persistence (ADR-022 envelope)
- Continue Listening / recently played
- Background playback / mini-player

---

## Related commits (Step 2)

To be recorded on branch after documentation reconciliation.
