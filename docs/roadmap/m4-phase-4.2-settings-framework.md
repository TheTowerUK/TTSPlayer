# M4 Phase 4.2 — Settings Framework (Implementation Specification)

**Status:** **Complete** (2026-07-12) · Windows runtime validation **Pass**  
**Milestone:** M4 — User Experience and Platform Integration  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Predecessor:** M4 Phase 4.1 complete — commit `2f4482f`  
**Implementation baseline:** commits `7ae607c`–`896a8e7` · closure `dc303eb`

→ [M4 plan](./m4-plan.md#phase-42--settings-framework)  
→ [Settings architecture](../architecture/settings.md)  
→ [Provider management (4.1 complete)](../architecture/provider-management.md)  
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs (Accepted 2026-07-12):**

- [ADR-004: Settings Storage and Versioning](../architecture/decisions/ADR-004-settings-storage-and-versioning.md)
- [ADR-005: Settings Information Architecture](../architecture/decisions/ADR-005-settings-information-architecture.md)
- [ADR-006: Settings Validation and Apply Behaviour](../architecture/decisions/ADR-006-settings-validation-and-apply-behaviour.md)

Follow the established M4 cadence: envelope model → persistence → migration → validation → UI shell → provider integration → testing → Windows validation → closure.

---

## Objective

Evolve the existing M3.5 provider settings screen and scattered preference keys into a **coherent, versioned settings framework** with grouped sections, safe migration, validation, and reset behaviour — without rebuilding working provider configuration or altering Phase 4.1 provider lifecycle semantics.

---

## Current baseline

### Already shipped (do not rebuild)

| Layer | Component | What it does today |
|---|---|---|
| **Provider config** | `MediaProviderConfig` | Ordered catalogue providers + `MediaAccessConfig` |
| **Persistence** | `MediaProviderConfigService` | `media_provider_config_v1` JSON in `shared_preferences` |
| **UI** | `SettingsScreen` + `MediaProviderSettingsForm` | Grouped settings; provider fields embedded in Library & Providers |
| **Validation** | `MediaProviderConfig.validate()`, `RemoteUrlSecurity` | Blocks invalid saves; `httpRequired` rejects plain HTTP |
| **Navigation** | `settings_navigation.dart`, app bar | Opens grouped `SettingsScreen` |
| **Catalogue state** | `CatalogService` | `catalog_path`, `catalog_source`, scan-warning dismissal |
| **Resume data** | `PlaybackService` | Per-item `position_*`, `duration_*` keys |
| **Provider status** | Dashboard Provider Status panel (4.1) | Active provider, refresh, retry — **not settings** |
| **Scanner** | `ttsplayer.config.json`, `ScannerService` | Filesystem indexer config — not in app prefs |
| **Theme** | `AppTheme.dark` in `main.dart` | Single dark theme; **no persisted theme mode** |
| **HTTP timeout** | `SettingsRepository` → `CatalogService` | User-configurable 5–120 seconds (default 15) |

### M4.2 framework work (to implement)

| Deliverable | Description |
|---|---|
| Settings envelope + migration | ADR-004 `ttsplayer_settings_v1` |
| `SettingsRepository` | Load, migrate, validate, save, reset groups (persistence layer — not a runtime service) |
| `SettingsScreen` shell | Grouped sections per ADR-005 |
| Provider section integration | Refactor existing form into Library & Providers |
| Network section | Persist catalogue fetch timeout (first network pref) |
| Diagnostics section | App version, reset settings |
| Unsaved-change handling | ADR-006 |
| Tests + migration scenarios | S1–S13 |

### Persistence layer naming

Use **`SettingsRepository`** for the load/save/migrate/validate component — not `SettingsService`.

TTSPlayer `*Service` types (`CatalogService`, `PlaybackService`, `ArtworkService`) own **runtime behaviour** and long-lived app state. Settings persistence is a **repository-style** concern: read/write versioned configuration, migrate legacy keys, validate drafts, and expose snapshots to consumers. Runtime services read configuration from the repository; they do not embed preference I/O.

`MediaProviderConfigService` may remain as a thin adapter during migration, delegating to `SettingsRepository` for the provider slice, or be folded into the repository in a later refactor step — implementation choice, not a spec change.

### Explicitly deferred (later phases)

| Item | Phase | Reason |
|---|---|---|
| Theme mode toggle | Post–4.2 / optional | Only dark theme exists today |
| Startup route preference | Post–4.2 | App always opens dashboard; no route memory |
| Playback speed / subtitles / audio track prefs | 4.4 | No user-facing controls or APIs yet |
| Sort order, library visibility | 4.3 | Library experience scope |
| Full diagnostics, logs, TLS detail, cache health | 4.6 | ADR-003 / diagnostics architecture |
| Cloud sync, accounts | Out of scope | Product rules |

---

## Existing settings inventory

Keys and models currently touching `shared_preferences` or user-editable configuration.

| Key / pattern | Owner | Default | UI today | Runtime consumer | M4.2 disposition |
|---|---|---|---|---|---|
| `media_provider_config_v1` | `MediaProviderConfigService` | `MediaProviderConfig.defaults()` | `MediaProviderSettingsScreen` | `CatalogService`, `MediaLocationResolver`, startup | **Migrate** into envelope `libraryProviders`; dual-read one release |
| `catalog_path` | `CatalogService` | none | None (internal) | Provider chain legacy prepend, last-good path | **Remain** — runtime catalogue state, not user settings |
| `catalog_source` | `CatalogService` | none | None | Source classification (`bundled` / local / remote) | **Remain** — runtime state |
| `scan_warnings_dismissed_catalogue_id` | `CatalogService` | none | Dismiss on banner | Scan warning banner visibility | **Remain** — UI dismissal state |
| `position_{itemId}` | `PlaybackService` | 0 | None | Resume offer, Continue Watching | **Remain** — playback progress, not settings |
| `duration_{itemId}` | `PlaybackService` | none | None | Resume near-end logic | **Remain** — playback progress |
| *(none)* | `CatalogService` | 15 seconds | None | HTTP catalogue fetch timeout | **Add** `network.catalogueFetchTimeoutSeconds` in envelope |
| `ttsplayer.config.json` | Python indexer / Library Manager | repo template | Library Manager read-only summary | `ScannerService`, indexer | **Remain filesystem** — not app settings envelope |

### `MediaProviderConfig` fields (inside `media_provider_config_v1`)

| Field | Default (desktop) | Validated |
|---|---|---|
| `catalogueProviders[]` | `Y:\Media\catalog.json`, UNC catalogue path, optional HTTPS | Yes — at least one provider; URL rules per mode |
| `mediaAccess.mediaRoots[]` | `Y:\Media`, UNC, `/volume1/Media` | Yes — non-empty |
| `mediaAccess.httpMediaBaseUrl` | null (optional) | Yes — HTTPS rules when set |
| `mediaAccess.mode` | `localPreferred` | Yes — enum |

---

## Problems and gaps

1. **Fragmentation** — Provider settings are isolated; no general/network/diagnostics grouping.
2. **No schema version** — Cannot migrate safely as new prefs are added.
3. **Dual entry vocabulary** — App bar “Settings” vs dashboard “Settings” vs provider-only screen.
4. **Configuration vs status** — Risk of duplicating Provider Status in settings (addressed in ADR-005).
5. **Hardcoded network timeout** — Operational tuning requires code change.
6. **No unified reset** — Provider reset exists; full settings reset does not.
7. **Unsaved navigation** — Provider screen does not guard back navigation with dirty form (gap for 4.2).

---

## Proposed information architecture

See [ADR-005](../architecture/decisions/ADR-005-settings-information-architecture.md).

```
SettingsScreen (scroll)
├── General
├── Library & Providers    ← evolved MediaProviderSettingsScreen
├── Playback               ← deferred placeholders / links to 4.4
├── Network
└── Diagnostics & Advanced
```

**Dashboard (unchanged from 4.1):** Provider Status panel — active provider, refresh, retry, operational errors.

---

## Settings categories (M4.2 scope)

### General

| Setting | M4.2 | Notes |
|---|---|---|
| Theme mode | **Deferred** | `AppTheme.dark` only; add when light/theme tokens exist |
| Startup screen / restore last location | **Deferred** | No navigation stack persistence today |
| Confirmations (destructive reset) | **Implement** | Confirm before full settings reset |

### Library & Providers

Evolve existing provider editor — **same fields**, grouped layout:

| Control | Maps to | Behaviour |
|---|---|---|
| Access mode | `mediaAccess.mode` | `localPreferred` / `httpRequired` radio |
| Local catalogue paths | `catalogueProviders` (local) | Dynamic list |
| HTTPS catalogue URL | `catalogueProviders` (http) | Single field |
| Local media roots | `mediaAccess.mediaRoots` | Dynamic list |
| HTTP media base URL | `mediaAccess.httpMediaBaseUrl` | Single field |
| Save | `MediaProviderConfigService.save` | Validates; no auto catalogue reload |
| Reset to defaults | `resetToDefaults` | Provider defaults only |
| Validation status | inline errors + warnings | Same as today |
| Status link | navigation | “See dashboard for active provider and refresh.” |

**Not in this section:** provider health badges, retry, refresh catalogue, item counts (dashboard).

### Playback

| Setting | M4.2 | Notes |
|---|---|---|
| Resume behaviour thresholds | **Deferred** | Hardcoded in `ResumeInfo` (`minResumePosition`, `nearEndWindow`) |
| Default playback speed | **Deferred → 4.4** | No speed API exposed in UI |
| Preferred subtitle language | **Deferred → 4.4** | No subtitle track selection |
| Preferred audio language | **Deferred → 4.4** | No multi-audio UI |

Section renders short copy: “Playback preferences will be added in Phase 4.4” — **no non-functional controls**.

### Network

| Setting | M4.2 | Default | Notes |
|---|---|---|---|
| Catalogue fetch timeout (seconds) | **Implement** | 15 | Maps to `CatalogService` timeout; bounds e.g. 5–120 |
| Retry policy | **Deferred** | — | Provider chain retry is full-chain refresh (ADR-002); no separate policy yet |
| Secure transport | **Read-only display** | from access mode | Explain `httpRequired` enforcement; not a separate toggle |

**Must not weaken** `httpRequired` HTTPS rejection (`RemoteUrlSecurity`).

### Diagnostics & Advanced

| Item | M4.2 | Notes |
|---|---|---|
| App version / build | **Implement** | `package_info_plus` already in pubspec |
| Reset all settings | **Implement** | Envelope defaults; confirm dialog; preserves playback progress |
| Debug / verbose logging | **Deferred → 4.6** | No supported flag today |
| Export logs / TLS detail | **Deferred → 4.6** | |

---

## Persistence model

See [ADR-004](../architecture/decisions/ADR-004-settings-storage-and-versioning.md).

### Envelope sketch (v1)

```json
{
  "settingsVersion": 1,
  "general": {},
  "libraryProviders": {
    "providerConfig": { "... MediaProviderConfig JSON ..." }
  },
  "network": {
    "catalogueFetchTimeoutSeconds": 15
  },
  "playback": {},
  "diagnostics": {}
}
```

Storage key: `ttsplayer_settings_v1`

### Migration flow

```
App start → SettingsRepository.load()
  → if ttsplayer_settings_v1 valid → use
  → else if media_provider_config_v1 valid → migrate → write envelope
  → else defaults
  → legacy provider key left readable one release (dual-read)
```

### Atomic save

Validate entire draft → single `setString` on success → notify listeners. Failed validation leaves prior blob untouched.

### Corrupt recovery

| Failure | Behaviour |
|---|---|
| Invalid JSON | Ignore envelope; attempt legacy migration; else defaults |
| Unknown `settingsVersion` | Use known fields; log; defaults for unknown groups |
| Invalid provider group | Provider defaults; other groups preserved if valid |
| Partial write interrupted | Previous string remains (platform atomicity) |

### Reset scopes

| Action | Scope |
|---|---|
| Provider Reset | `libraryProviders` defaults; legacy key cleared |
| Reset all settings | Full envelope defaults; legacy provider key cleared |
| Neither | Touches `catalog_path`, resume keys, or scanner config file |

---

## Validation and reset behaviour

See [ADR-006](../architecture/decisions/ADR-006-settings-validation-and-apply-behaviour.md).

- **Save:** blocked when any blocking error in dirty groups.
- **Warnings:** shown; Save allowed except when errors present.
- **httpRequired + http://:** Save blocked (existing rule).
- **Reset:** immediate apply to form; persisted on confirm for provider reset; full reset after confirmation dialog.
- **Post-save catalogue:** user refreshes from dashboard or restarts app — not automatic.

---

## UI behaviour

### Layout

- Desktop-first vertical scroll; max content width consistent with dashboard cards.
- Section headers (`SectionHeader` style) + one-line description per section.
- Long paths/URLs: monospace, multiline fields, ellipsis in read-only summaries.

### Save / feedback

- Save button disabled while saving or when no changes.
- Success: brief snackbar “Settings saved.”
- Failure: inline error list at section top (existing provider pattern).

### Unsaved changes

- Back navigation / app bar back: dialog if dirty (Save / Discard / Cancel).

### Keyboard & accessibility

- Tab order follows visual order within section.
- Save and Reset are focusable; section headers are semantic headings.
- Validation errors associated with fields (aria / `InputDecoration.errorText`).

### Window size

- Must scroll without overflow at 900×600 and 900×420 (same class as dashboard scroll tests).

### Boundaries

- No Provider Status duplication.
- No Phase 4.6 diagnostics panels.

---

## Error handling

| Scenario | Required behaviour |
|---|---|
| Save with invalid URL/path | Inline errors; nothing persisted |
| Corrupt stored envelope | Safe defaults; optional one-line snackbar “Settings were reset to defaults due to a storage error.” |
| Migration from legacy provider key fails | Provider defaults; user can re-enter |
| Save I/O failure | Error snackbar; retain in-memory draft |
| Timeout pref out of range | Field validation error |

---

## Testing strategy

| Layer | Tests |
|---|---|
| Migration | S3, S4, S8, S9 — pure Dart |
| Validation | S5, S6, S7 — reuse provider config tests patterns |
| SettingsRepository | Load/save/reset/corrupt recovery; S13 failed migration |
| Widget | Settings sections render; unsaved dialog (S11) |
| Regression | All existing `media_provider_settings_screen_test.dart`, `media_provider_config_test.dart`, `provider_selection_test.dart` |
| Integration | Provider save → resolver update → manual refresh still separate |

Runtime validation after implementation: configure → restart → confirm persistence (mirrors 4.1 closure pattern).

---

## Implementation order

1. **Inventory + envelope model** — Dart types mirroring JSON groups; no UI.
2. **`SettingsRepository`** — load, migrate, validate, save, reset (ADR-004).
3. **Validation layer** — centralize group validators; delegate provider to existing code.
4. **`SettingsScreen` shell** — empty sections with headings.
5. **Library & Providers integration** — extract/refactor existing form widgets.
6. **Network timeout** — wire to `CatalogService` constructor/config.
7. **Diagnostics** — version + reset all.
8. **Unsaved-change guard** — `PopScope` unsaved-change dialog.
9. **Navigation update** — app bar + dashboard link to settings shell.
10. **Tests** — S1–S13.
11. **Windows runtime validation** — configure → restart → persistence smoke (mirrors 4.1 closure).
12. **Documentation closure** — update release tracker; mark phase complete.

---

## Definition of done

- [x] ADR-004, ADR-005, ADR-006 reviewed and **Accepted** (2026-07-12)
- [x] `SettingsRepository` loads/saves versioned envelope with migration from `media_provider_config_v1`
- [x] `SettingsScreen` with all M4.2 sections present (Playback may be informational only)
- [x] Library & Providers parity with former standalone provider screen behaviour
- [x] Network catalogue timeout configurable within bounds
- [x] Diagnostics shows version; reset all settings with confirmation
- [x] Unsaved-change handling on back navigation
- [x] Provider health/refresh **not** duplicated in settings
- [x] `httpRequired` HTTPS rules unchanged
- [x] Validation scenarios S1–S13 pass (automated + Windows runtime closure)
- [x] `flutter analyze` — no new errors in Phase 4.2 scope (pre-existing findings unchanged)
- [x] [settings.md](../architecture/settings.md) → Implemented / Accepted
- [x] [v0.5.0-dev.md](../release/v0.5.0-dev.md) Phase 4.2 updated

---

## Windows runtime validation (2026-07-12)

**Harness:** `client/ttsplayer/test/phase_42_windows_runtime_test.dart` (opt-in: `PHASE_42_RUNTIME=1 flutter test test/phase_42_windows_runtime_test.dart --tags phase42-runtime`)

**Shared environment**

| Field | Value |
|---|---|
| Date | 2026-07-12 |
| OS | Windows 10.0.26200 (25H2) |
| Build mode | Flutter test harness (debug); UI smoke via widget tests |
| App version | `0.4.0-dev.1+1` (`pubspec.yaml`) |
| Git commit | `896a8e7` (implementation baseline) |
| Local catalogue | `Y:\Media\catalog.json` — reachable (S11) |

Closure scenarios **S1–S13** below exercise persistence, settings UI, and catalogue apply behaviour. Spec [validation scenarios](#validation-scenarios) (same IDs, different focus) are covered by `settings_repository_test.dart`, `settings_screen_test.dart`, and `catalog_service_timeout_test.dart`.

### Scenario results

| ID | Configuration | Steps | Expected | Observed | Result | Notes |
|---|---|---|---|---|---|---|
| **S1** | Fresh install | No prefs → `SettingsRepository.initialize()` | Defaults loaded | `SettingsLoadSource.defaults`; provider + network defaults | **Pass** | Runtime harness |
| **S2** | Legacy migration | `media_provider_config_v1` only → initialize | Envelope created | `legacyMigration`; `ttsplayer_settings_v1` written | **Pass** | Runtime harness |
| **S3** | Settings UI | Open `SettingsScreen` | Provider fields editable; no standalone provider route | Library & Providers section; `save_settings`; no `open_provider_settings` | **Pass** | Widget smoke |
| **S4** | Timeout persist | Save 45s → new repository session | Timeout retained | `catalogueFetchTimeoutSeconds` == 45 after restart simulation | **Pass** | Runtime harness |
| **S5** | Invalid timeout | Enter 999 → Save network | Rejected inline | `network_validation_errors` shown; value not saved | **Pass** | Widget smoke |
| **S6** | Reset provider | Custom provider + network 60s → `resetProviderToDefaults()` | Provider defaults only | Provider defaults; network still 60 | **Pass** | Runtime harness |
| **S7** | Reset all | Custom settings + `position_*` keys → reset all | Envelope defaults; resume preserved | Full envelope defaults; `position_*` / `duration_*` untouched | **Pass** | Runtime harness |
| **S8** | Settings restart | Save provider + network → new session | Both groups survive | Envelope load; local path + 30s timeout | **Pass** | Runtime harness |
| **S9** | Unsaved changes | Edit timeout → Close | Dialog shown | `Unsaved changes` dialog | **Pass** | Widget smoke |
| **S10** | Provider Status | Render dashboard panel after settings work | Panel unchanged | `PROVIDER STATUS`, Refresh catalogue, Settings actions | **Pass** | Widget smoke |
| **S11** | Provider save | Load local catalogue → provider save | No automatic refresh | `catalogPath` and `lastRefreshedAt` unchanged | **Pass** | Windows + local catalog |
| **S12** | Timeout + refresh | 5s timeout → refresh fails → 120s → refresh | New timeout active | First refresh times out; second succeeds with identity `PHASE42-RUNTIME` | **Pass** | Mock HTTP + `refreshCatalogue()` |
| **S13** | Corrupt JSON | Invalid envelope, no legacy | Defaults; no crash | `defaults` source; recovery warning; save succeeds | **Pass** | Runtime harness |

**Automated regression (post-validation):** `flutter test` — **197 passed**, **1 skipped** (Phase 4.1 runtime harness opt-in); `flutter analyze` — no new Phase 4.2 errors (pre-existing infos/warnings only).

### Implementation notes (2026-07-12)

- Standalone `MediaProviderSettingsScreen` removed; provider editor lives in `MediaProviderSettingsForm` inside `SettingsScreen`.
- **Dual-write transition:** provider Save still writes `media_provider_config_v1` via `MediaProviderConfigService`; network and envelope writes use `SettingsRepository`. Migration reads legacy into envelope on first load.
- Reset all calls both `SettingsRepository.resetAllToDefaults()` and `MediaProviderConfigService.resetToDefaults()`.
- `CatalogService` resolves HTTP timeout from `SettingsRepository.networkSettings` per fetch; no auto-reload on settings save (ADR-006).
- Playback section is informational placeholder for Phase 4.4.

---

## Validation scenarios

| ID | Scenario | Expected |
|---|---|---|
| **S1** | Upgrade with only `media_provider_config_v1` | Config loads; envelope written; provider fields unchanged |
| **S2** | Fresh install | Defaults; no migration errors |
| **S3** | Legacy `catalog_path` pref + provider config | Catalogue startup order unchanged (M3.5 / V8 regression) |
| **S4** | Valid local-only provider Save | Persists; resolver roots updated; catalogue unchanged until refresh |
| **S5** | Valid HTTPS provider Save | Same as S4; HTTPS URLs stored |
| **S6** | Invalid path/URL Save | Blocked; inline errors; prior config on disk |
| **S7** | `httpRequired` + plain HTTP URL | Save blocked with rejection message |
| **S8** | Reset provider defaults | Form and storage match `MediaProviderConfig.defaults()` |
| **S9** | Corrupt envelope JSON | App starts; settings defaults; no crash |
| **S10** | Partial migration (valid provider, invalid network group) | Provider preserved; network defaults |
| **S11** | Unsaved changes → back | Dialog; Discard reverts; Save persists |
| **S12** | Provider Save then dashboard Refresh | Catalogue reload uses new config; last-good retained if refresh fails |
| **S13** | Failed migration — corrupt `ttsplayer_settings_v1` (invalid JSON) with no valid legacy key | App starts normally; settings defaults loaded; warning logged once; no crash; user can Save new valid settings |

**S13 note:** Distinct from S9 (corrupt envelope with possible legacy fallback). S13 covers the case where the envelope is unreadable and no migratable legacy provider config exists — the path users hit after a bad write or manual prefs corruption.

---

## Documentation outputs

| Document | Action |
|---|---|
| This spec | **Complete** 2026-07-12 — Windows runtime validation recorded |
| ADR-004–006 | **Accepted** 2026-07-12 |
| [settings.md](../architecture/settings.md) | **Implemented / Accepted** |
| [m4-plan.md](./m4-plan.md) | 4.2 complete → **Phase 4.3 planning** |
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | Phase 4.2 complete; Phase 4.3 planning |

---

## Explicit out of scope (M4.2)

- Rebuilding provider lifecycle (Phase 4.1 complete)
- User accounts, cloud sync, multi-profile
- Detailed diagnostics screen (Phase 4.6)
- Non-functional playback toggles
- Weakening HTTPS / `httpRequired` rules
- SQLite preference store
- Scanner/indexer config editor in settings (remains Library Manager + `ttsplayer.config.json`)
- Theme engine / light mode
- Virtual libraries or filesystem layout changes

---

## Related documents

| Document | Purpose |
|---|---|
| [m4-phase-4.1-provider-management.md](./m4-phase-4.1-provider-management.md) | Closed provider status layer |
| [playback.md](../architecture/playback.md) | Phase 4.4 playback prefs |
| [diagnostics.md](../architecture/diagnostics.md) | Phase 4.6 deep detail |
| [SettingsScreen](../../client/ttsplayer/lib/features/settings/settings_screen.dart) | Grouped settings UI |
| [MediaProviderSettingsForm](../../client/ttsplayer/lib/features/settings/widgets/media_provider_settings_form.dart) | Provider editor widget |
