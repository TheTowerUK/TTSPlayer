# M5 Phase 5.3 — Music Playback and Queue

**Status:** **In progress** — Gate 0 complete (2026-07-20); full queue implementation **not started**
**Milestone:** M5 — Music
**Branch:** `m5-development`
**Predecessor:** Phase 5.2 complete (2026-07-19) — commit `b2eb063`

→ [M5 plan](./m5-plan.md#phase-53--music-playback-and-queue)
→ [Music architecture](../architecture/music.md)
→ [Playback architecture](../architecture/playback.md)
→ [ADR-022](../architecture/decisions/ADR-022-music-queue-and-listening-state.md) — **Proposed**
→ [ADR-023](../architecture/decisions/ADR-023-music-player-surface-architecture.md) — **Proposed**

---

## Objective

Deliver audio playback and in-memory queue from music browse surfaces while preserving video playback. **Gate 0** verifies that `media_kit` and `PlaybackService` support audio-only sessions on Windows before queue, shuffle, repeat, or dedicated music UI are built.

---

## Step 1 — Repository audit (2026-07-20)

See [Gate 0 findings](#gate-0-findings-summary) below. Baseline commit: `b2eb063`.

### Video-specific assumptions identified

1. Mandatory `VideoController` on every media_kit init (fixed in Gate 0 for audio)
2. `isReady` required video controller (fixed for audio)
3. Width/height listeners for all sessions (skipped for audio)
4. `aspectRatio` 16:9 default (1:1 for audio sessions)
5. `PlayerScreen` as sole play surface — video layout and copy
6. Error messages reference "video"
7. Embedded subtitle / multi-audio track UI (video containers)
8. Fullscreen immersive chrome
9. Shared position keys (Continue Watching mitigated via `isContinueWatchingEligible`)

---

## Step 2 — Gate 0 validation matrix

| ID | Scenario | Result |
|---|---|---|
| L1 | Local WAV | ✅ |
| L2 | Local MP3 (ffmpeg) | ⏭ Optional — skip if ffmpeg absent |
| N1 | HTTPS audio | ⏭ Optional — `PHASE_53_HTTPS_URI` |
| P1–P7 | Load, play, pause, seek, position, completion, replay, stop | ✅ |
| P8–P9 | Video ↔ audio session switch | ✅ (stub + runtime) |
| S1 | Continue Watching video-only | ✅ |
| S2 | No queue/shuffle/repeat | ✅ |

---

## Step 3 — Audio fixture strategy

Runtime-generated fixtures in `test/support/audio_gate_fixtures.dart`:

| Fixture | Format | Duration | SR | Ch | Method | Committed |
|---|---|---|---|---|---|---|
| gate_tone.wav | PCM 16-bit WAV | 2 s | 44100 | mono | Dart sine | No |
| gate_tone.mp3 | MP3 | 2 s | 44100 | mono | ffmpeg | No |
| corrupt.mp3 | invalid | — | — | — | random bytes | No |

---

## Step 4 — Gate 0 production changes

- `PlaybackSessionMode` + `playbackSessionModeFor(MediaItem)`
- `PlaybackService`: `sessionMode`, `requiresVideoSurface`, `isAudioSession`
- Audio init: `Player` without `VideoController`
- Completion tick: no position save after completed
- `stop()`: clears test simulation state

---

## Gate 0 findings summary

**Verdict: PASSED** (optional MP3/HTTPS rows documented).

| Question | Answer |
|---|---|
| Local audio playable? | ✅ WAV via media_kit |
| HTTPS audio? | Resolver supports; runtime row optional |
| Transport reliable? | ✅ play/pause/seek/position/duration/completion |
| Formats at runtime? | WAV confirmed; MP3 via ffmpeg optional |
| Resolver for audio? | ✅ Unchanged |
| Shared PlaybackService safe? | ✅ With session mode |
| Refactor before queue? | Kind-neutral errors + MusicPlayerScreen (M5.3) |
| Player surface? | Dedicated music screen, shared service (ADR-023 hybrid) |
| ADR acceptance? | **Not yet** — basic audio ≠ queue/player decisions |

### Architecture recommendation

- **Service:** Outcome **A** — shared `PlaybackService`, media-kind-aware
- **UI:** Dedicated **`MusicPlayerScreen`**, not mode-switched `PlayerScreen`

ADR-022 and ADR-023 remain **Proposed**.

---

## Next implementation steps

1. ~~Play affordance on music detail → `MusicPlayerScreen`~~ ✅ Step 1 (2026-07-20)
2. In-memory queue (next/previous, album seed) — **Step 2**
3. ~~Kind-neutral playback errors~~ ✅ Step 1
4. Accept ADR-023 when music player ships; ADR-022 when queue persists

---

## Step 1 — Single-track playback (2026-07-20)

**Status:** ✅ Implemented (not phase closure)

### Audit refinements (Gate 0 → Step 1)

| Area | Decision |
|---|---|
| `PlaybackService.sessionMode` | Derived from `currentItem`; audio sessions skip `VideoController` |
| `requiresVideoSurface` / `isAudioSession` | UI gate for video-only chrome |
| Audio readiness | `isReady` when `_mediaKitPlayer` initialised (no video controller) |
| Lifecycle ownership | Shared singleton `PlaybackService`; screen `dispose()` calls `stop()` |
| Route ownership | Dedicated `MusicPlayerScreen` — not mode-switched `PlayerScreen` |
| Auto-play on enter | **Yes** — matches `PlayerScreen` (`autoPlay: true` default) |
| Route close | **Stop session** — `dispose()` + explicit back both call `stop()` (no background playback until mini-player contract) |
| Progress persistence | **Suppressed for audio** — `_savePosition` / `_saveDuration` skip non-video items; Continue Watching remains video-only |
| Error copy | Shared `PlaybackErrorMessages` uses kind-neutral "media" wording |
| Artwork | Reuses `MusicArtworkThumbnail` → `ArtworkService` / `ArtworkImage` (square, not stretched) |

### Production deliverables

- `lib/features/music/presentation/music_player_screen.dart` — single-track player UI
- `openMusicPlayerScreen()` in `music_navigation.dart`
- Play affordances: track detail, album/artist/all-tracks rows, search audio play icon
- Tests: `music_player_screen_test.dart`, `music_player_integration_test.dart`
- Runtime: `phase_53_music_player_windows_runtime_test.dart` (`PHASE_53_RUNTIME=1`)

### Explicitly deferred (Step 2+)

Queue model, album play-all seeding, next/previous, shuffle, repeat, listening history, Continue Listening, playlists, background/mini-player, playback-rate on music surface, M5.4 listening persistence.

---

## Harness

```powershell
cd client\ttsplayer
flutter build windows
$env:PHASE_53_AUDIO_GATE='1'
flutter test test/phase_53_audio_gate_windows_runtime_test.dart --tags phase53-audio-gate

$env:PHASE_53_RUNTIME='1'
flutter test test/phase_53_music_player_windows_runtime_test.dart --tags phase53-runtime
```
