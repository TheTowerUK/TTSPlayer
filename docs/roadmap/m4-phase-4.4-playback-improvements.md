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
| **4** | Player UI | Not started |
| **5** | Tests | Not started |
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

**Not wired:** track/speed player UI, keyboard shortcuts.

**Tests today:** `playback_preflight_test.dart`, `continue_watching_test.dart`, `playback_service_extensions_test.dart`, `playback_settings_integration_test.dart`, `settings_repository_test.dart`, `settings_screen_test.dart`, `gate0_media_kit_capability_test.dart` (Gate 0 only).

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

## Player UI (Step 4)

All controls call `PlaybackService` only ([ADR-010](../architecture/decisions/ADR-010-playback-state-extensions.md), [ADR-012](../architecture/decisions/ADR-012-track-selection.md)).

### New / updated chrome

| Control | Visibility | Action |
|---|---|---|
| Speed selector | Windows only | `setPlaybackRate` — presets match settings |
| Audio track menu | Windows + ≥ 2 tracks | `selectAudioTrack` |
| Subtitle menu | Windows + ≥ 1 embedded sub | `selectSubtitleTrack` + Off |
| Error view | Always | Primary message from service; no provider diagnostics |
| Resume detail copy | Polish only | Preserve existing `ResumeInfo` logic |

### Keyboard shortcuts (Windows desktop, player focused)

| Key | Action |
|---|---|
| `Space` | Toggle play/pause |
| `←` / `→` | Seek −10 s / +30 s (match buttons) |
| `Esc` | Stop + pop (match back) |
| `,` / `.` | Decrease / increase speed preset (Windows only) |
| `a` | Open audio track menu when available |
| `s` | Open subtitle menu when available |

Use `Shortcuts` / `Actions` or `Focus` with `KeyboardListener` — consistent with dashboard `Ctrl+F` pattern.

### Deliverables

- Updated `player_screen.dart` (+ small private widgets if needed)
- Widget smoke tests with mocked `PlaybackService`

---

## Testing (Step 5)

| Layer | File(s) | Focus |
|---|---|---|
| Service | `playback_service_*_test.dart` | Rate, tracks, error kinds, reset lifecycle |
| Settings | `settings_repository_test.dart` | `defaultPlaybackSpeed` round-trip |
| Resume regression | `continue_watching_test.dart`, `playback_preflight_test.dart` | Unchanged keys/eligibility |
| Widget | `player_screen_test.dart` (new or extended) | Error view, shortcuts invoke service mocks |
| Gate 0 | `gate0_media_kit_capability_test.dart` | Unchanged — third-party verification only |

**Regression:** Phases 4.1–4.3 tests remain green; no changes to catalogue/library/search behaviour.

---

## Windows runtime validation (Step 6 — draft, not executed)

**Harness (to create at implementation):** `test/phase_44_windows_runtime_test.dart`  
**Gate:** `PHASE_44_RUNTIME=1`  
**Pattern:** Phase 4.3 opt-in harness

### Draft validation matrix

| ID | Scenario | Expected | Fixture |
|---|---|---|---|
| **P1** | Default speed on play | Rate matches settings default | Local MP4 |
| **P2** | In-player speed change | Session rate updates; settings unchanged until Save | Local MP4 |
| **P3** | Speed survives pause/seek | Rate holds after pause + seek | Local MP4 |
| **P4** | HTTPS speed (optional) | `setRate` on HTTPS stream | TNAS HTTPS MP4 |
| **P5** | Audio track enumeration | ≥ 2 tracks listed in UI | Multi-audio MKV |
| **P6** | Audio track switch | Selected track id updates in service | Multi-audio MKV |
| **P7** | Subtitle enumeration | Embedded subs listed | Subtitled MKV |
| **P8** | Subtitle select | Subtitle track active | Subtitled MKV |
| **P9** | Subtitle off | `SubtitleTrack.no()` equivalent | Subtitled MKV |
| **P10** | Resume from detail | Resume offer + seek to saved position | Item with saved position |
| **P11** | Start over | Plays from zero; prefs updated on progress | Item with saved position |
| **P12** | Continue Watching | Section populates; opens player | Dashboard |
| **P13** | Keyboard play/pause | Space toggles playback | Local MP4 |
| **P14** | Keyboard seek | Arrow keys seek | Local MP4 |
| **P15** | Keyboard back | Esc stops and pops | Local MP4 |
| **P16** | Missing file error | Playback-layer copy; not provider banner | Missing path item |
| **P17** | Resolver failure copy | Playback message; no Provider Status text | Misconfigured HTTPS |
| **P18** | Settings speed Save | Persists; applies on next play | Settings screen |
| **P19** | Settings Discard | Reverts unsaved speed draft | Settings screen |
| **P20** | Reset all settings | Default speed restored; resume keys remain | Settings + prefs check |
| **P21** | Non-Windows omission | Speed/track controls absent (document/manual) | Platform note |
| **P22** | Stop clears session | Track lists empty; rate reset | Player stop |
| **P23** | New item clears prior tracks | No stale track ids | Two different files |
| **P24** | HTTPS playback regression | Open, seek, play | TNAS HTTPS MP4 |

*Execute at Step 6 closure — not before implementation.*

---

## Implementation order

Mirrors Phases 4.2–4.3: **service and settings before UI**.

1. ~~**Step 2 — PlaybackService extensions**~~ — ✅ DTOs, rate, tracks, error kinds, tests
2. ~~**Step 3 — Settings integration**~~ — ✅ envelope, repository, playback section UI, runtime wiring
3. **Step 4 — Player UI** — speed, track menus, shortcuts, error copy, resume polish
4. **Step 5 — Tests** — fill gaps in matrix unit/widget coverage
5. **Step 6 — Runtime validation** — implement harness; run P1–P24
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
