# Settings Framework (M4 Phase 4.2)

**Status:** **Implemented / Accepted** — validated on Windows 2026-07-12  
**Related roadmap phase:** [M4 Phase 4.2 — Settings Framework](../roadmap/m4-plan.md#phase-42--settings-framework) *(complete)*

→ [Provider management](./provider-management.md) *(4.1 complete)*  
→ [Phase 4.2 specification](../roadmap/m4-phase-4.2-settings-framework.md)  
→ [Runtime validation results](../roadmap/m4-phase-4.2-settings-framework.md#windows-runtime-validation-2026-07-12)  
→ [Playback](./playback.md) *(4.4 — deferred playback prefs)*  
→ [Diagnostics](./diagnostics.md) *(4.6 — deferred deep detail)*

**ADRs (Accepted):**

- [ADR-004: Settings Storage and Versioning](./decisions/ADR-004-settings-storage-and-versioning.md)
- [ADR-005: Settings Information Architecture](./decisions/ADR-005-settings-information-architecture.md)
- [ADR-006: Settings Validation and Apply Behaviour](./decisions/ADR-006-settings-validation-and-apply-behaviour.md)

---

## Purpose

Provide a **structured, versioned preferences architecture** that evolved the M3.5 provider editor into grouped settings — without duplicating Phase 4.1 provider operational status or rebuilding working provider configuration.

---

## Validated runtime behaviour (2026-07-12)

| Capability | Validated behaviour |
|---|---|
| Versioned envelope | `ttsplayer_settings_v1` JSON in `shared_preferences` |
| Load order | Envelope → legacy `media_provider_config_v1` migration → defaults |
| Legacy dual-read | One-release read of legacy provider key during migration |
| Grouped UI | Single scrollable `SettingsScreen` with General, Library & Providers, Playback (placeholder), Network, Diagnostics |
| Provider editor | Same fields as M3.5 standalone screen; embedded in Library & Providers |
| Network timeout | 5–120 seconds; consumed by `CatalogService` per HTTP fetch |
| Save apply (ADR-006) | Provider/network save does **not** auto-reload catalogue |
| Reset provider | Provider defaults only; other groups unchanged |
| Reset all | Full envelope defaults; playback `position_*` / `duration_*` preserved |
| Unsaved guard | Back/close shows Save / Discard / Cancel when dirty |
| Corrupt recovery | Invalid envelope → defaults; app starts; user can save fresh settings |
| Provider Status | Remains on dashboard only — not duplicated in settings |

**Re-run validation:** `PHASE_42_RUNTIME=1 flutter test test/phase_42_windows_runtime_test.dart --tags phase42-runtime` from `client/ttsplayer`.

---

## Implementation map

| Component | Location |
|---|---|
| Settings envelope model | `client/ttsplayer/lib/models/application_settings.dart` |
| `SettingsRepository` | `client/ttsplayer/lib/services/settings/settings_repository.dart` |
| Grouped settings UI | `client/ttsplayer/lib/features/settings/settings_screen.dart` |
| Provider form widget | `client/ttsplayer/lib/features/settings/widgets/media_provider_settings_form.dart` |
| Section chrome | `client/ttsplayer/lib/features/settings/widgets/settings_section.dart` |
| Provider persistence (transition) | `client/ttsplayer/lib/services/media_access/media_provider_config_service.dart` |
| Timeout consumer | `client/ttsplayer/lib/services/catalog_service.dart` |
| Startup wiring | `client/ttsplayer/lib/main.dart` — `SettingsRepository.initialize()` |

---

## Settings vs non-settings persistence

| Data | Storage | In envelope? |
|---|---|---|
| Provider configuration | Envelope + legacy `media_provider_config_v1` (dual-write transition) | Yes |
| Network timeout | Envelope `network.catalogueFetchTimeoutSeconds` | Yes |
| Last catalogue path | `catalog_path` | No — runtime |
| Resume positions | `position_*` / `duration_*` | No — progress |
| Scan warning dismiss | `scan_warnings_dismissed_*` | No — UI state |
| Indexer paths | `ttsplayer.config.json` | No — filesystem |

---

## Apply behaviour (ADR-006)

Configuration changes do **not** automatically reload the catalogue:

```
Save → configuration updated → Dashboard → Refresh catalogue
```

Provider health, retry, and refresh remain on the dashboard (ADR-003).

---

## Failure handling

- Corrupt envelope → safe defaults; log once; optional user notice
- Failed migration (S13) → defaults; app starts; user can save fresh settings
- Invalid Save → retain last-good on disk (ADR-006)
- Partial migration → preserve valid groups
- Reset all → does not delete playback progress

---

## Transition notes

1. **Provider Save** still writes the legacy `media_provider_config_v1` key via `MediaProviderConfigService` while the envelope is also populated on migration and for network/reset operations. Full envelope-only provider writes are a follow-on cleanup.
2. **Playback** section is informational until Phase 4.4.
3. **Theme / startup route** remain deferred — only dark theme exists today.

---

## Related documents

- [M4 Phase 4.2 implementation spec](../roadmap/m4-phase-4.2-settings-framework.md)
- [provider-management.md](./provider-management.md)
- [library.md](./library.md) — Phase 4.3 follow-on
