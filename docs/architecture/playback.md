# Playback (M4 Phase 4.4)

**Status:** **Step 3 complete** — service extensions + default speed settings shipped; Player UI next  
**Related roadmap phase:** [M4 Phase 4.4 — Playback Improvements](../roadmap/m4-phase-4.4-playback-improvements.md)  
**Gate 0 audit:** [m4-phase-4.4-gate0-capability-audit.md](../roadmap/m4-phase-4.4-gate0-capability-audit.md)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [Path mapping](./path-mapping.md)  
→ [Settings](./settings.md)  
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)

**ADRs (Accepted 2026-07-13):**

- [ADR-010: Playback State Extensions](./decisions/ADR-010-playback-state-extensions.md)
- [ADR-011: Playback Preferences](./decisions/ADR-011-playback-preferences.md)
- [ADR-012: Track Selection](./decisions/ADR-012-track-selection.md)
- [ADR-013: Playback Error Taxonomy](./decisions/ADR-013-playback-error-taxonomy.md)

---

## Purpose

Refine playback UX on top of M3 playback and M3.5 resolver integration — speed, embedded track selection, keyboard shortcuts, resume polish, and playback-layer errors — without reimplementing resume persistence or provider/settings behaviour.

**Cadence:**

```
Inventory → Gate 0 ✅ → ADRs ✅ → Specification ✅ → Step 2 service ✅ → Step 3 settings ✅ → Player UI (next)
```

Capabilities are limited to [Gate 0 verified outcomes](../roadmap/m4-phase-4.4-gate0-capability-audit.md#phase-44-scope-hand-off). Chapters and external subtitle sidecars are deferred.

---

## Architectural principles

### PlaybackService is the single authority ([ADR-010](./decisions/ADR-010-playback-state-extensions.md))

```
PlayerScreen  →  PlaybackService  →  media_kit | video_player
```

**Player UI reflects `PlaybackService` state; it does not own playback state.**

### Three-layer error taxonomy ([ADR-013](./decisions/ADR-013-playback-error-taxonomy.md))

| Layer | Example message | Surface |
|---|---|---|
| Provider | "HTTPS catalogue unavailable" | Dashboard / Provider Status |
| Resolver | (mapped to playback copy in player) | Pre-play boundary |
| Playback | "This video could not be played." | Player error view |

Playback must not duplicate Provider Status diagnostics.

---

## Gate 0 outcomes (complete)

| Capability | Verified | Phase 4.4 |
|---|---|---|
| Playback speed | ✅ | In scope — Windows |
| Audio tracks | ✅ | In scope — Windows |
| Subtitle tracks | ✅ | In scope — embedded, Windows |
| Chapters | ❌ | Post-M4 |

→ [Full audit](../roadmap/m4-phase-4.4-gate0-capability-audit.md)

---

## M4.4 scope (specification)

| In scope | Out of scope |
|---|---|
| Playback speed + settings default | Chapters |
| Embedded audio/subtitle pickers | External subtitle discovery |
| Keyboard shortcuts (desktop) | Streaming architecture |
| Resume UX polish | Codec expansion |
| Playback error presentation | Performance (4.5) |
| Desktop control polish | Diagnostics (4.6) |

---

## PlaybackService extensions (Step 2) — ✅ complete

| Area | Detail |
|---|---|
| State | `playbackRate`, `supportedPlaybackRates`, `canChangePlaybackRate`, track DTO lists, selected ids, `playbackErrorKind` |
| Methods | `setPlaybackRate`, `selectAudioTrack`, `selectSubtitleTrack`, `disableSubtitles` — all return `PlaybackActionResult` |
| Backend | `PlaybackSessionControls` → `MediaKitSessionControls` (Windows) / `UnsupportedSessionControls` (`video_player`) |
| Rate lifecycle | Default from injectable provider on `play()`; session override until `stop()` or new `play()` ([ADR-011](./decisions/ADR-011-playback-preferences.md)) |
| Tracks | Embedded only; reset on new media ([ADR-012](./decisions/ADR-012-track-selection.md)) |
| Errors | `PlaybackErrorMapper` + `PlaybackErrorKind` ([ADR-013](./decisions/ADR-013-playback-error-taxonomy.md)) |
| Tests | `playback_service_extensions_test.dart` (30 scenarios) |

**Not in Step 2:** settings default speed persistence, player UI, keyboard shortcuts.

## Default playback speed settings (Step 3) — ✅ complete

| Area | Detail |
|---|---|
| Storage | `ttsplayer_settings_v1` → `playback.defaultPlaybackSpeed` (ADR-011 field name) |
| Presets | `0.5`, `0.75`, `1.0`, `1.25`, `1.5`, `2.0` via `PlaybackRatePresets` |
| Settings UI | Dropdown + explicit Save / Reset playback defaults on `SettingsScreen` |
| Runtime | `defaultPlaybackRateProvider: () => settingsRepository.defaultPlaybackRate` in `main.dart` |
| Session vs default | Saved default applies on `play()` / `retry()`; session override unchanged until new media |
| Non-Windows | Stored preference ignored at backend; rate stays `1.0` |
| Tests | Repository (14), Settings UI (11), integration (10) |

**Not in Step 3:** PlayerScreen speed control, keyboard shortcuts.

→ [Implementation spec](../roadmap/m4-phase-4.4-playback-improvements.md#settings-integration-step-3--complete)

---

## Current baseline (M3 + M3.5)

| Capability | State |
|---|---|
| `PlaybackService` | Windows: `media_kit` + session controls; other: `video_player` + unsupported controls |
| Resume | `position_*` / `duration_*` in `shared_preferences` |
| Resolver | `MediaLocationResolver` in `play()` |
| Rate / tracks / errors | Service-owned (Step 2) — player UI not wired |
| Default speed | Persisted in settings envelope (Step 3) |
| Player controls | Play/pause, seek, −10/+30, retry, buffering |
| **Not wired** | Speed/track player UI, keyboard shortcuts |

---

## Validation (planned — Step 6)

Draft matrix **P1–P24** in [Phase 4.4 spec](../roadmap/m4-phase-4.4-playback-improvements.md#windows-runtime-validation-step-6--draft-not-executed). Harness: `PHASE_44_RUNTIME=1` (to be created at implementation).

Gate 0 harness (third-party only): `GATE0_MEDIA_KIT=1` → `gate0_media_kit_capability_test.dart`.

---

## Related documents

- [M4 Phase 4.4 implementation spec](../roadmap/m4-phase-4.4-playback-improvements.md)
- [Gate 0 audit](../roadmap/m4-phase-4.4-gate0-capability-audit.md)
- [settings.md](./settings.md)
- [diagnostics.md](./diagnostics.md)
