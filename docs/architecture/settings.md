# Settings Framework (M4 Phase 4.2)

**Status:** Specification **Accepted** (2026-07-12) — implementation ready to begin  
**Related roadmap phase:** [M4 Phase 4.2 — Settings Framework](../roadmap/m4-plan.md#phase-42--settings-framework)

→ [Provider management](./provider-management.md) *(4.1 complete)*  
→ [Playback](./playback.md) *(4.4 — deferred playback prefs)*  
→ [Diagnostics](./diagnostics.md) *(4.6 — deferred deep detail)*

**ADRs (Accepted 2026-07-12):**

- [ADR-004: Settings Storage and Versioning](./decisions/ADR-004-settings-storage-and-versioning.md)
- [ADR-005: Settings Information Architecture](./decisions/ADR-005-settings-information-architecture.md)
- [ADR-006: Settings Validation and Apply Behaviour](./decisions/ADR-006-settings-validation-and-apply-behaviour.md)

---

## Purpose

Evolve fragmented settings entry points into a **structured, versioned preferences architecture** without rebuilding working M3.5 provider configuration or duplicating Phase 4.1 provider operational status.

---

## Current baseline (M3 + M3.5 + M4.1)

| Area | State |
|---|---|
| Media provider settings | `MediaProviderSettingsScreen` — catalogue paths, HTTPS URLs, access mode, media base URL |
| `MediaProviderConfigService` | Persists `media_provider_config_v1` via `shared_preferences` |
| Settings navigation | `settings_navigation.dart` — opens provider screen directly |
| Provider operational status | Dashboard Provider Status panel (4.1) — refresh, retry, health |
| Playback resume | Per-item `position_*` / `duration_*` keys — **progress data, not settings** |
| Catalogue runtime state | `catalog_path`, `catalog_source` — **not user settings** |
| Scanner config | `ttsplayer.config.json` on disk — indexer / Library Manager |
| Theme | `AppTheme.dark` fixed — no persisted theme mode |
| HTTP catalogue timeout | 15s constant in `CatalogService` — not user-configurable |

**Not in baseline:** versioned settings envelope, grouped settings shell, unified reset, unsaved-change guard, network timeout preference UI.

---

## M4.2 target architecture (from spec + ADRs)

| Component | Role |
|---|---|
| `ttsplayer_settings_v1` envelope | Versioned JSON blob (ADR-004) |
| `SettingsRepository` | Load, migrate, validate, save, reset — **persistence layer** |
| `SettingsScreen` | Scrollable grouped sections (ADR-005) |
| Library & Providers section | Evolved provider editor — same fields as today |
| Network section | Catalogue fetch timeout |
| Diagnostics section | Version display, reset all settings |
| Provider status | Remains on dashboard only (ADR-003) |

Runtime services (`CatalogService`, `PlaybackService`, etc.) **consume** settings snapshots from the repository; they do not own preference I/O.

### Settings vs non-settings persistence

| Data | Storage | In envelope? |
|---|---|---|
| Provider configuration | `media_provider_config_v1` → envelope | Yes |
| Network timeout | new | Yes |
| Last catalogue path | `catalog_path` | No — runtime |
| Resume positions | `position_*` | No — progress |
| Scan warning dismiss | `scan_warnings_dismissed_*` | No — UI state |
| Indexer paths | `ttsplayer.config.json` | No — filesystem |

---

## M4.2 settings categories (summary)

| Section | M4.2 deliverable |
|---|---|
| **General** | Destructive-reset confirmation only; theme/startup deferred |
| **Library & Providers** | Full provider editor parity + dashboard status link |
| **Playback** | Informational placeholder — controls deferred to 4.4 |
| **Network** | Catalogue fetch timeout; read-only secure transport note |
| **Diagnostics & Advanced** | Version, reset all settings |

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
- Reset all → does not delete playback progress without separate confirm

---

## Testing considerations

See validation scenarios S1–S13 in [Phase 4.2 spec](../roadmap/m4-phase-4.2-settings-framework.md#validation-scenarios).

- Migration tests from `media_provider_config_v1`
- S13 failed migration recovery (corrupt envelope, no legacy key)
- Provider validation regression (`media_provider_settings_screen_test.dart`)
- Widget tests for settings shell and unsaved dialog

---

## Open decisions (implementation)

1. **Post-save hint** — optional snackbar reminding user to refresh catalogue from dashboard?
2. **Deep link to Library & Providers** — query param vs default scroll position when opened from dashboard.
3. **Legacy key removal timing** — dual-read for one release; exact removal version at implementation close.

---

## Out of scope

- Cloud sync, accounts, multi-profile
- Phase 4.6 diagnostics detail
- Non-functional playback controls
- Weakening `httpRequired` HTTPS enforcement

---

## Related documents

- [M4 Phase 4.2 implementation spec](../roadmap/m4-phase-4.2-settings-framework.md)
- [provider-management.md](./provider-management.md)
- [Existing settings UI](../../client/ttsplayer/lib/features/settings/media_provider_settings_screen.dart)
