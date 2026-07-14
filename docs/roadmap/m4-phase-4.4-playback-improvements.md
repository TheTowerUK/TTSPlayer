# M4 Phase 4.4 — Playback Improvements (Implementation Specification)

**Status:** **Specification accepted (pre-implementation)** — Gate 0 complete · ADRs accepted · **Implementation not started**  
**Milestone:** M4 — User Experience and Platform Integration  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Predecessor:** M4 foundation complete — [snapshot](../release/m4-foundation-complete.md) (Phases 4.1–4.3 closed 2026-07-13)  
**Gate 0 baseline:** commit `f044187`  
**Implementation baseline:** playback unchanged since M3.5; refine only — do not rebuild

→ [M4 plan](./m4-plan.md#phase-44--playback-improvements)  
→ [Gate 0 capability audit](./m4-phase-4.4-gate0-capability-audit.md)  
→ [Playback architecture](../architecture/playback.md)  
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs (Accepted 2026-07-13):**

- [ADR-010: Playback State Extensions](../architecture/decisions/ADR-010-playback-state-extensions.md)
- [ADR-011: Playback Preferences](../architecture/decisions/ADR-011-playback-preferences.md)
- [ADR-012: Track Selection](../architecture/decisions/ADR-012-track-selection.md)
- [ADR-013: Playback Error Taxonomy](../architecture/decisions/ADR-013-playback-error-taxonomy.md)

Follow the M4 cadence for playback:

```
Inventory → Capability Audit (Gate 0 ✅) → ADRs (✅) → Specification (this document) → Implementation
```

**Capability rule:** Implement only what Gate 0 verified. Do not reopen chapters or external subtitle sidecars.

---

## Objective

Make playback **enjoyable and diagnosable** on the M4 foundation — without reimplementing resume, resolver integration, provider/settings behaviour, or catalogue schema.

| Verified (Gate 0) | Deferred |
|---|---|
| Playback speed | Chapters |
| Audio track enumeration & switching | External subtitle sidecars |
| Embedded subtitle enumeration & switching | Streaming architecture changes |
| | Codec expansion |
| | Performance optimisation (4.5) |
| | Diagnostics export (4.6) |

---

## Scope

### In scope

| Area | Detail |
|---|---|
| **Playback speed** | Windows `setRate`; settings default; session override; hidden elsewhere |
| **Embedded audio selection** | Picker when ≥ 2 tracks; Windows only |
| **Embedded subtitle selection** | Picker + Off; Windows only |
| **Keyboard shortcuts** | Desktop player controls (see below) |
| **Resume UX refinement** | Copy/layout polish; preserve `position_*` / `duration_*` keys |
| **Playback error presentation** | Three-layer taxonomy; resolver-aware playback copy |
| **Desktop UX polish** | Control layout, touch targets, buffering presentation |

### Explicitly out of scope

| Item | Reason |
|---|---|
| Chapters | No public `media_kit` Dart API — [Gate 0](./m4-phase-4.4-gate0-capability-audit.md#chapters--decision) |
| External subtitle discovery | Not Gate 0 verified — [ADR-012](../architecture/decisions/ADR-012-track-selection.md) |
| Streaming / HLS / adaptive architecture | M4 constraint |
| Codec expansion / transcoding | Zero-bloat principle |
| Performance optimisation | Phase 4.5 |
| Diagnostics export / deep detail | Phase 4.6 |
| Default audio/subtitle language prefs | No Gate 0 justification — [ADR-011](../architecture/decisions/ADR-011-playback-preferences.md) |
| Provider / catalogue changes | Phases 4.1–4.3 complete |

---

## Architectural principles

### PlaybackService authority ([ADR-010](../architecture/decisions/ADR-010-playback-state-extensions.md))

```
PlayerScreen  →  PlaybackService  →  media_kit | video_player
```

**Player UI reflects `PlaybackService` state; it does not own playback state.**

### Error layers ([ADR-013](../architecture/decisions/ADR-013-playback-error-taxonomy.md))

| Layer | Example (user-facing) |
|---|---|
| Provider | "HTTPS catalogue unavailable" — dashboard only |
| Resolver | Mapped to playback copy in player |
| Playback | "This video could not be played." |

### Unchanged boundaries

- `MediaLocationResolver` contract unchanged
- `catalog.json` / indexer unchanged
- Resume store keys unchanged
- Provider Status remains dashboard-only

---

## Phase steps

| Step | Name | Status |
|---|---|---|
| **0** | Capability Audit | ✅ Complete — [audit](./m4-phase-4.4-gate0-capability-audit.md) (`f044187`) |
| **1** | Specification + ADRs | ✅ This document + ADR-010–013 |
| **2** | PlaybackService extensions | ✅ Complete — service layer + `playback_service_extensions_test.dart` (30 scenarios) |
| **3** | Settings integration | ✅ Complete — default speed in envelope, Settings UI, PlaybackService wiring |
| **4** | Player UI | ✅ Complete — speed/track menus, keyboard shortcuts, error copy, 42 widget tests |
| **5** | Integration audit | ✅ Complete — settings/platform alignment, state coherence, coverage |
| **6** | Windows runtime validation | Not started — matrix below (draft) |
| **7** | Closure | Not started |

---

## Current baseline

*Shipped in M3/M3.5 — do not rebuild.*

| Capability | Location | State |
|---|---|---|
| Dual backend | `playback_platform.dart` | Windows: `media_kit`; else `video_player` |
| Authority | `playback_service.dart` | Resume, seek, preflight; rate/tracks/errors (Step 2) |
| Player UI | `player_screen.dart` | Play/pause, seek, −10/+30, retry, auto-hide overlay |
| Resume | `shared_preferences` `position_*` / `duration_*` | Detail resume + Continue Watching |
| Resolver gate | `play()` → `MediaLocationResolver` | Unresolved → error before init |
| Settings playback group | `PlaybackSettings.defaultPlaybackSpeed` | Persisted in `ttsplayer_settings_v1` (Step 3) |

**Wired (Step 4):** in-player speed, audio/subtitle menus, keyboard shortcuts, ADR-013 error copy.

**Closure item (resolved Step 5):** Settings shows read-only stored preference on unsupported platforms; editable dropdown only when `playbackSpeedSettingsSupported` is true.

**Tests today:** `playback_preflight_test.dart`, `continue_watching_test.dart`, `playback_service_extensions_test.dart`, `playback_settings_integration_test.dart`, `playback_integration_test.dart`, `player_screen_test.dart`, `settings_repository_test.dart`, `settings_screen_test.dart`, `gate0_media_kit_capability_test.dart` (Gate 0 only).

---

## PlaybackService extensions (Step 2) — ✅ complete

Implemented per [ADR-010](../architecture/decisions/ADR-010-playback-state-extensions.md). No `PlayerScreen` or `SettingsRepository` changes in this step.

### Delivered

| Area | Location |
|---|---|
| DTOs | `lib/models/playback/` — `PlaybackAudioTrack`, `PlaybackSubtitleTrack`, `PlaybackErrorKind`, `PlaybackActionResult`, `PlaybackRatePresets` |
| Backend adapter | `lib/services/playback/` — `PlaybackSessionControls`, `MediaKitSessionControls`, `UnsupportedSessionControls` |
| Error mapping | `PlaybackErrorMapper`, `PlaybackErrorMessages` (ADR-013) |
| Service APIs | `playbackRate`, track getters, `setPlaybackRate`, `selectAudioTrack`, `selectSubtitleTrack`, `disableSubtitles` |
| Tests | `test/playback_service_extensions_test.dart` — 30 service-level scenarios |

### New types (`lib/models/` or `lib/services/playback/`)

```dart
class PlaybackAudioTrack {
  final String id;
  final String? title;
  final String? language;
}

class PlaybackSubtitleTrack {
  final String id;
  final String? title;
  final String? language;
}

enum PlaybackErrorKind {
  fileMissing,
  resolverFailed,
  network,
  timeout,
  unsupportedFormat,
  unknown,
}
```

### New getters

| Getter | Notes |
|---|---|
| `playbackRate` | `double` |
| `availableAudioTracks` | Excludes `auto` / `no` |
| `availableSubtitleTracks` | Excludes `auto` / `no` |
| `selectedAudioTrackId` | `String?` |
| `selectedSubtitleTrackId` | `null` or `no` = off |
| `playbackErrorKind` | Set when `errorMessage` set |

### New methods

| Method | Contract |
|---|---|
| `setPlaybackRate(double rate)` | Windows: `setRate`; clamp to allowed presets; notify |
| `selectAudioTrack(String trackId)` | No-op if id invalid |
| `selectSubtitleTrack(String? trackId)` | `null` / off → disable subs |

### Internal work

- Map `media_kit` track streams after `open`; cancel on dispose
- Map resolver/open failures → `PlaybackErrorKind` + [ADR-013](../architecture/decisions/ADR-013-playback-error-taxonomy.md) strings
- Apply settings default rate on successful init (Step 3 dependency injects `SettingsRepository` or rate callback)
- **No** `media_kit` imports in `player_screen.dart`

### Deliverables

- Extended `playback_service.dart`
- Unit tests: rate/session reset, track DTO mapping (mock platform where feasible), error kind mapping

---

## Settings integration (Step 3) — ✅ complete

Implemented per [ADR-011](../architecture/decisions/ADR-011-playback-preferences.md).

### Delivered

| Area | Location |
|---|---|
| Envelope | `playback.defaultPlaybackSpeed` in `ttsplayer_settings_v1` |
| Model | `PlaybackSettings` in `application_settings.dart` |
| Repository | `playbackSettings`, `defaultPlaybackRate`, `savePlaybackSettings`, `saveDefaultPlaybackRate`, `resetPlaybackToDefaults` |
| Settings UI | Playback section dropdown + Save / Reset playback defaults |
| Runtime | `main.dart` wires `defaultPlaybackRateProvider` to `SettingsRepository` |
| Tests | `settings_repository_test.dart` (14 scenarios), `settings_screen_test.dart` (11), `playback_settings_integration_test.dart` (10) |

### Envelope change

```json
"playback": {
  "defaultPlaybackSpeed": 1.0
}
```

### Files

| File | Change |
|---|---|
| `application_settings.dart` | `PlaybackSettings.defaultPlaybackSpeed` + validation |
| `settings_repository.dart` | Load/save/reset playback group |
| `settings_screen.dart` | Playback section — speed preset control |
| `main.dart` | Pass default rate into `PlaybackService` factory or post-init hook |

### Behaviour

- Explicit **Save** only (ADR-006)
- Session override in player does not auto-persist
- Reset all preserves resume keys
- Presets: `0.5`, `0.75`, `1.0`, `1.25`, `1.5`, `2.0`

### Deliverables

- Settings UI + repository tests
- No catalogue auto-reload on save

---

## Player UI (Step 4) — ✅ complete

All controls call `PlaybackService` only ([ADR-010](../architecture/decisions/ADR-010-playback-state-extensions.md), [ADR-012](../architecture/decisions/ADR-012-track-selection.md)).

### Implemented chrome

| Control | Visibility | Action |
|---|---|---|
| Speed selector | `canChangePlaybackRate` | `setPlaybackRate` — session only; presets from `PlaybackRatePresets` |
| Audio track menu | `canSelectAudioTracks` (≥ 2 tracks) | `selectAudioTrack` |
| Subtitle menu | `canSelectSubtitleTracks` (≥ 1 embedded sub) | `selectSubtitleTrack` + **Off** (`disableSubtitles`) |
| Error view | Fatal playback errors | `PlaybackErrorMessages.forKind`; resolver hint toward Provider Status |
| Resume detail copy | Unchanged | Existing `ResumeInfo` logic on `ItemDetailScreen` |

**Layout:** seek bar + time → transport (−10 / play-pause / +30) → Speed · Audio · Subtitles row. Controls pin while paused, buffering, menu open, or error/completed.

### Keyboard shortcuts (player focused)

| Key | Action |
|---|---|
| `Space` | Toggle play/pause |
| `←` / `→` | Seek −10 s / +30 s (match buttons) |
| `Esc` | Stop + pop (match back) |
| `,` / `.` | Decrease / increase speed preset when `canChangePlaybackRate` |
| `a` | Open audio track menu when `canSelectAudioTracks` |
| `s` | Open subtitle menu when `canSelectSubtitleTracks` |

Shortcuts ignored while a popup menu or text field owns focus. Shortcut actions reveal/reset the auto-hide timer.

### Deliverables

- Updated `player_screen.dart` (speed/audio/subtitle menus, keyboard `Focus`, error copy, auto-hide polish)
- `test/player_screen_test.dart` — 42 scenarios with `FakePlaybackSessionControls`

---

## Integration audit (Step 5) — ✅ complete

Cross-cutting audit of Steps 2–4 against ADR-010–013. No new playback capabilities.

### Resolved

| Area | Outcome |
|---|---|
| **Settings / platform** | `playbackSpeedSettingsSupported` in `playback_platform.dart`; unsupported platforms show read-only stored preference; Save disabled |
| **State coherence** | Stale track IDs cleared on sync; `retry()` clears fatal error before re-prepare |
| **Keyboard / menus** | `Esc` closes open popup before exiting player |
| **Watch Again rate** | Retains current session rate (same media session; no `play()` reset) — ADR-010/011 |
| **Coverage** | `playback_integration_test.dart` — rate lifecycle, tracks, errors, resume regression |
| **Gate 0** | Harness unchanged; Step 6 runtime matrix still required for app-level validation |

### Cross-platform settings rule (final)

| Platform | Settings Playback section | Player speed control |
|---|---|---|
| Windows (`playbackSpeedSettingsSupported`) | Editable dropdown + Save | Shown when `canChangePlaybackRate` |
| Other platforms | Read-only stored preference text | Hidden |

Stored Windows preference is never erased when opening Settings on an unsupported platform.

---

## Testing (Step 5) — ✅ complete

| Layer | File(s) | Focus |
|---|---|---|
| Service | `playback_service_extensions_test.dart` | Rate, tracks, error kinds, reset lifecycle |
| Integration | `playback_integration_test.dart` | Rate lifecycle, retry, tracks, errors, resume |
| Settings | `settings_repository_test.dart`, `settings_screen_test.dart` | Platform-aware playback settings |
| Resume regression | `continue_watching_test.dart`, `playback_preflight_test.dart` | Unchanged keys/eligibility |
| Widget | `player_screen_test.dart` | Error view, shortcuts, menus |
| Gate 0 | `gate0_media_kit_capability_test.dart` | Third-party capability audit only (not PlaybackService) |

**Regression:** Phases 4.1–4.3 tests remain green; **501 passed**, 26 skipped (opt-in runtime harnesses).

**Ready for:** Step 7 closure.

---

## Windows runtime validation (Step 6 — ✅ complete)

**Harness:** `client/ttsplayer/test/phase_44_windows_runtime_test.dart`  
**Gate:** `PHASE_44_RUNTIME=1`  
**Pattern:** Phase 4.3 opt-in harness; exercises `PlaybackService` + player UI (not Gate 0 direct `media_kit`)

```powershell
cd client\ttsplayer
$env:PHASE_44_RUNTIME='1'
flutter test test/phase_44_windows_runtime_test.dart --tags phase44-runtime
```

Optional fixtures: `GATE0_LOCAL_URI` / `PHASE_44_LOCAL_URI`, `GATE0_HTTPS_URI`, `GATE0_MULTI_AUDIO_URI`, `GATE0_SUBTITLED_URI` (MKV for track scenarios).

**Harness run (2026-07-14):** 11 passed, 18 skipped, 0 failed. Full suite: **501 passed**, 26 skipped; `flutter analyze` — no new errors (pre-existing infos/warnings only).

### P1–P24 results

| ID | Status | Notes |
|---|---|---|
| **P1** | Skipped → **Manual** | `flutter test` lacks `media_kit_video` platform channel; Gate 0 `Player()` passes — validate on Windows desktop (`flutter run -d windows`) |
| **P2** | Skipped → **Manual** | Same as P1 |
| **P3** | Skipped → **Manual** | Same as P1; includes Watch Again session-rate retention |
| **P4** | Skipped | `GATE0_HTTPS_URI` not configured |
| **P5** | Skipped | `GATE0_MULTI_AUDIO_URI` not configured |
| **P6** | Skipped → **Manual** | Same as P1 + multi-audio MKV fixture |
| **P7** | Skipped | `GATE0_SUBTITLED_URI` set but not an MKV (env points to sample MP4) |
| **P8** | Skipped → **Manual** | Same as P7 + P1 constraint |
| **P9** | Skipped → **Manual** | Same as P7 + P1 constraint |
| **P10** | **Pass** (partial) | Detail resume offer UI ✅; playback-from-saved-position → **Manual** (P1 constraint) |
| **P11** | Skipped → **Manual** | P1 constraint |
| **P12** | **Pass** | `getContinueWatching` eligibility unchanged |
| **P13** | Skipped → **Manual** | P1 constraint |
| **P14** | Skipped → **Manual** | P1 constraint; P14b menu-focus seek ignore same |
| **P15** | Skipped → **Manual** | P1 constraint; Esc popup-first then exit |
| **P16** | **Pass** | Missing-file error copy + Try Again in player UI |
| **P16b** | **Pass** | `retry()` re-prepares after missing file |
| **P17** | **Pass** | Resolver failure playback message + settings hint |
| **P18** | **Pass** | Settings Save persists speed |
| **P19** | **Pass** | Discard reverts draft |
| **P20** | **Pass** | Reset playback/all; resume keys preserved |
| **P21** | **Pass** + **Manual** | Unsupported-platform read-only settings UI ✅; player chrome on non-Windows → manual device QA |
| **P22** | Skipped → **Manual** | P1 constraint |
| **P23** | Skipped → **Manual** | P1 constraint + multi-audio fixture |
| **P24** | Skipped | `GATE0_HTTPS_URI` not configured |

### Manual checkpoints (documented in harness)

- PlaybackService media init through player UI on Windows desktop app
- Dashboard Continue Watching opens player
- Completion clears persisted progress
- Track-enumeration failure non-fatal; SnackBar-only track/rate failures vs fatal errors
- Auto-hide after popup closes
- Successful retry restores playback after transient engine failure

*Phase 4.4 remains open — Step 7 closure next.*

---

## Implementation order

Mirrors Phases 4.2–4.3: **service and settings before UI**.

1. ~~**Step 2 — PlaybackService extensions**~~ — ✅ DTOs, rate, tracks, error kinds, tests
2. ~~**Step 3 — Settings integration**~~ — ✅ envelope, repository, playback section UI, runtime wiring
4. **Step 4 — Player UI** — ✅ speed, track menus, shortcuts, error copy, resume polish
5. **Step 5 — Integration audit** — ✅ settings/platform alignment, state coherence, coverage
4. **Step 5 — Tests** — fill gaps in matrix unit/widget coverage
5. ~~**Step 6 — Runtime validation**~~ — ✅ harness + P1–P24 matrix executed
6. **Step 7 — Closure** — `playback.md` → accepted; release tracker; phase retrospective

**Suggested commit cadence:** service → settings → player UI → tests → harness → docs closure.

---

## Definition of done

- [ ] Gate 0 outcomes unchanged; no chapter or external sub scope creep
- [ ] ADR-010–013 implemented as specified
- [ ] Resume keys and Continue Watching behaviour preserved
- [ ] `PlayerScreen` never imports `media_kit` / `video_player`
- [ ] Windows: speed + embedded track pickers when media provides tracks
- [ ] Non-Windows: controls hidden; no crash
- [ ] Playback errors use three-layer taxonomy; player excludes Provider Status copy
- [ ] `flutter analyze` clean; unit/widget tests green
- [ ] P1–P24 harness pass when `PHASE_44_RUNTIME=1`
- [ ] `playback.md` updated to implemented/accepted at closure

---

## Related documents

- [Gate 0 audit](./m4-phase-4.4-gate0-capability-audit.md)
- [playback.md](../architecture/playback.md)
- [settings.md](../architecture/settings.md)
- [m4-foundation-complete.md](../release/m4-foundation-complete.md)
- [ADR index](../architecture/decisions/README.md)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-13 | Initial planning draft + Gate 0 inventory |
| 2026-07-13 | Gate 0 complete (`f044187`) |
| 2026-07-13 | Specification finalized; ADR-010–013 accepted; validation matrix draft |
