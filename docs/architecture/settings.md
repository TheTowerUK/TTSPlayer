# Settings Framework (M4 planning)

**Status:** Planning — M4 Phase 4.2  
**Related roadmap phase:** [M4 Phase 4.2 — Settings Framework](../roadmap/m4-plan.md#phase-42--settings-framework)

→ [Provider management](./provider-management.md)  
→ [M3.5 provider settings UI](../../client/ttsplayer/lib/features/settings/media_provider_settings_screen.dart) *(implementation reference)*

---

## Purpose

Evolve fragmented settings entry points into a **structured, versioned preferences architecture** without rebuilding working M3.5 provider configuration.

---

## Current baseline (M3 + M3.5)

| Area | State |
|---|---|
| Media provider settings | `MediaProviderSettingsScreen` — catalogue paths, HTTPS URLs, access mode, media base URL |
| `MediaProviderConfigService` | Persists provider list via `shared_preferences` |
| Settings navigation | `settings_navigation.dart` — limited entry routing |
| Playback resume | `PlaybackService` + `shared_preferences` per item |
| Library roots / scan | Library Manager and scanner integration from M3 |
| General app preferences | Ad hoc keys in `shared_preferences`; no unified schema version |

**Not in baseline:** grouped settings sections, playback preference UI, library defaults UI, debug toggles, migration framework.

---

## M4 goals

| Section | Intent |
|---|---|
| **General** | Theme, startup behaviour, about/version link |
| **Library** | Default sort, scan reminders, library visibility hints |
| **Playback** | Resume behaviour, default speed (when Phase 4.4 ships controls) |
| **Network** | Evolve existing provider settings; TLS hints |
| **Debug** | Verbose logging toggle, diagnostics entry (Phase 4.6) |

Plus: **versioned settings schema**, migration on upgrade, reset-to-defaults.

---

## Proposed responsibilities

| Layer | Role |
|---|---|
| Settings schema | Documented key map + `settings_version` integer |
| Settings service | Read/write groups; migrate legacy keys |
| Settings shell | Navigable sections; TV-friendly targets where applicable |
| Provider settings | Embedded or linked from Network section — not duplicated |

---

## Data / state considerations

- Continue `shared_preferences` for M4 — SQLite deferred unless ADR approves
- Provider config keys from M3.5 must migrate transparently
- Reset must not delete playback position history without confirmation

---

## Failure handling

- Corrupt or unknown settings version: fall back to defaults; log once; surface in diagnostics
- Partial migration: preserve unmigrated keys; document in release notes

---

## Testing considerations

- Migration tests: simulate M3.5 prefs blob → M4 schema
- Widget tests: each section renders; back navigation works
- Regression: provider settings still save and load after restructure

---

## Open decisions

1. **Single `SettingsService` vs per-domain notifiers?**
2. **Playback prefs** — stored with playback service or central settings?
3. **Debug section** — hidden behind flag or always visible for personal app?

---

## Out of scope

- Cloud sync of preferences
- Multi-profile settings
- Remote settings API

---

## Related documents

- [provider-management.md](./provider-management.md)
- [playback.md](./playback.md)
- [diagnostics.md](./diagnostics.md)
