# ADR-011: Playback Preferences

**Status:** Accepted
**Date:** 2026-07-13
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)
**Implemented:** 2026-07-14 (M4 Phase 4.4 Steps 3–5; closure Step 7)
**Milestone:** M4 Phase 4.4
**Authors:** M4 documentation pass

---

## Context

Phase 4.2 reserved the `playback` group in `ttsplayer_settings_v1` with an empty `PlaybackSettings` placeholder ([ADR-004](./ADR-004-settings-storage-and-versioning.md)). Gate 0 verified `media_kit` `setRate` on Windows. Phase 4.4 needs a **default playback speed** preference without conflating settings with resume progress or track session state.

Constraints:

- Explicit **Save** behaviour per [ADR-006](./ADR-006-settings-validation-and-apply-behaviour.md) — no auto-save on every slider tick in settings.
- Reset all settings must **not** delete `position_*` / `duration_*` keys ([ADR-004](./ADR-004-settings-storage-and-versioning.md)).
- Gate 0 did **not** justify default audio or subtitle language preferences — those remain out of scope.
- Non-Windows platforms have no speed API — stored default applies only where `setRate` exists; elsewhere rate stays `1.0`.

---

## Decision

1. **Extend `PlaybackSettings`** in the settings envelope with one M4.4 field:

   ```json
   "playback": {
     "defaultPlaybackSpeed": 1.0
   }
   ```

2. **Allowed values:** `0.5`, `0.75`, `1.0`, `1.25`, `1.5`, `2.0` (discrete presets in settings UI; service clamps invalid stored values to `1.0` on load with a validation warning).

3. **Storage:** `ttsplayer_settings_v1` → `playback.defaultPlaybackSpeed`. Not stored in resume keys or per-item prefs.

4. **Settings UI:** Populate the existing **Playback** section on `SettingsScreen`:
   - **Windows / supported backend** (`playbackSpeedSettingsSupported`): dropdown for default speed; **Save** commits envelope
   - **Unsupported platforms:** read-only display of stored preference; Save playback disabled; preference preserved for future Windows use
   - **Discard** reverts draft on supported platforms only
   - No auto-reload of catalogue (same apply model as ADR-006)

5. **Runtime application:**

   | When | Behaviour |
   |---|---|
   | `play()` succeeds on Windows | Apply `defaultPlaybackSpeed` from `SettingsRepository` unless a **session override** is active |
   | User changes speed in player | Updates session rate via `setPlaybackRate`; does **not** write settings until user explicitly saves a new default (optional in-player "Set as default" is **out of 4.4** unless added in spec Step 4 — spec says settings only for default) |
   | Session override | In-player speed changes persist for the **current playback session** (until `stop()` or successful `play()` of a different item) without mutating saved settings |
   | Non-Windows | Ignore stored default for player API; Settings shows read-only stored value; PlayerScreen hides speed control |

6. **Reset behaviour:**

   | Action | Effect on playback prefs |
   |---|---|
   | Reset playback group (if exposed) | `defaultPlaybackSpeed` → `1.0` |
   | Reset all settings | Same; resume keys untouched |
   | Corrupt playback group in envelope | Fall back to `PlaybackSettings.defaults()` per ADR-004 |

7. **Explicit exclusions:** no default audio track, no default subtitle track, no per-folder speed, no persistence of in-player speed across app restarts (only the settings default applies on next `play()`).

---

## Rationale

- Single scalar preference matches Gate 0 verification scope and avoids unvalidated language-matching logic.
- Session override gives responsive in-player control without violating explicit Save in settings.
- Discrete presets prevent invalid rates and simplify testing.
- Reusing the reserved envelope group avoids a new persistence domain.

---

## Consequences

### Positive

- Consistent with ADR-004/006 patterns.
- Clear separation: settings = default; service = session + application.

### Negative

- Users cannot persist a non-default speed without opening settings (acceptable for 4.4).

### Neutral

- Future phases may add "remember last speed" — requires new ADR.
- **Implementation (Step 5):** `playbackSpeedSettingsSupported` in `playback_platform.dart` with `@visibleForTesting` override; Settings and PlayerScreen both gate on capability.
- **Closure (2026-07-14):** Unsupported platforms show stored default read-only; session override and Watch Again behaviour documented in [playback.md](../playback.md).

---

## Implementation

`PlaybackSettings.defaultPlaybackSpeed` in settings envelope; explicit Save per ADR-006. Step 5 audit added read-only unsupported-platform UI. Validated in settings and integration tests; P18/P19 in Phase 4.4 runtime harness.

---

## Alternatives considered

### Alternative A — Persist last used speed in `shared_preferences`

**Rejected because:** Blurs settings vs session state; not requested; increases migration surface.

### Alternative B — Default audio/subtitle language in settings

**Rejected because:** Gate 0 did not demonstrate need; track lists are per-file and user picks per session ([ADR-012](./ADR-012-track-selection.md)).

---

## Related documents

- [M4 Phase 4.4 specification](../../roadmap/m4-phase-4.4-playback-improvements.md)
- [ADR-004: Settings Storage and Versioning](./ADR-004-settings-storage-and-versioning.md)
- [ADR-006: Settings Validation and Apply Behaviour](./ADR-006-settings-validation-and-apply-behaviour.md)
- [ADR-010: Playback State Extensions](./ADR-010-playback-state-extensions.md)
- [settings.md](../settings.md)
