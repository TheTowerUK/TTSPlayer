# ADR-004: Settings Storage and Versioning

**Status:** Accepted  
**Date:** 2026-07-12  
**Accepted:** 2026-07-12 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.2  
**Authors:** M4 documentation pass

---

## Context

TTSPlayer persists user-editable configuration through ad hoc `shared_preferences` keys introduced across M2–M4.1:

- `media_provider_config_v1` — structured JSON for provider configuration (M3.5)
- Legacy catalogue keys (`catalog_path`, `catalog_source`) — last-good catalogue state (M2)
- Per-item playback keys (`position_*`, `duration_*`) — resume progress, not preferences (M2)
- UI dismissal keys (`scan_warnings_dismissed_catalogue_id`) — session-ish banner state (M3)

Phase 4.2 introduces a **settings framework** without breaking M3.5 provider saves or catalogue startup behaviour. We need a durable persistence contract: version field, migration, corrupt-value recovery, and clear separation between **user settings**, **runtime catalogue state**, and **playback progress data**.

Constraints:

- Continue `shared_preferences` for M4.2 (no SQLite unless a future ADR approves)
- Windows desktop is the primary target
- Offline-first; no cloud sync
- Atomic-enough saves: a invalid draft must never overwrite a valid stored configuration

---

## Decision

1. Introduce a **versioned settings envelope** stored at `ttsplayer_settings_v1` containing:
   - `settingsVersion` (integer, starts at `1`)
   - `general`, `libraryProviders`, `network`, `playback`, `diagnostics` group objects (only groups with M4.2 fields are populated initially)

2. **Embed** the existing `MediaProviderConfig` JSON shape inside `libraryProviders.providerConfig` rather than inventing a second provider schema.

3. **Dual-read migration (one release):**
   - On load: if `ttsplayer_settings_v1` exists and validates → use it.
   - Else if `media_provider_config_v1` exists and validates → migrate into envelope; write envelope; keep legacy key readable but stop writing to it.
   - Else → defaults.

4. **Do not migrate** into the envelope:
   - `catalog_path` / `catalog_source` (runtime catalogue state — `CatalogService`)
   - `position_*` / `duration_*` (playback progress — `PlaybackService`)
   - `scan_warnings_dismissed_catalogue_id` (UI dismissal — `CatalogService`)

5. **Corrupt or partial envelope:** discard envelope group(s) that fail validation; fall back to defaults for that group; log once; never crash startup.

6. **Reset to defaults:** clears user settings groups in the envelope and removes `media_provider_config_v1`; does **not** delete playback progress keys unless the user confirms a separate destructive action (Phase 4.2 UI may scope reset to settings only).

7. **Save atomicity:** validate the full draft envelope in memory; write one JSON string to `ttsplayer_settings_v1` only when valid. Provider configuration continues to use the same validation rules as today (`MediaProviderConfig.validate()`).

8. **Implementation naming:** the persistence component is `SettingsRepository` (load/migrate/save/reset), distinct from runtime `*Service` types that consume configuration.

---

## Rationale

- A single envelope gives one migration entry point while preserving the proven M3.5 provider JSON structure inside it.
- Dual-read avoids silent loss for users who upgrade mid-cycle before the new settings repository runs.
- Keeping catalogue and resume keys separate prevents settings reset from wiping browsing state or watch progress accidentally.
- One-key JSON write matches current `MediaProviderConfigService.save()` behaviour and is sufficient for personal-scale preference size.

---

## Consequences

### Positive

- Documented schema version and migration path for future phases (4.4 playback prefs, 4.6 debug flags).
- Provider keys remain backward compatible during transition.
- Testable load/migrate/reset paths.

### Negative

- Temporary duplication: envelope + legacy provider key during dual-read window.
- Envelope grows over time; requires discipline to keep groups cohesive.

### Neutral

- Scanner configuration remains in `ttsplayer.config.json` (filesystem), not in app settings envelope.

---

## Alternatives considered

### Alternative A — Keep independent keys forever

**Rejected because:** No unified reset, versioning, or migration story; Phase 4.2 goal is coherence.

### Alternative B — SQLite for all preferences

**Rejected because:** Out of MVP scope; `shared_preferences` sufficient for M4.2 volume; adds migration complexity without user request.

### Alternative C — Replace provider JSON with flattened keys

**Rejected because:** Rebuilds working M3.5 persistence; high regression risk for minimal gain.

---

## Related documents

- [M4 Phase 4.2 specification](../../roadmap/m4-phase-4.2-settings-framework.md)
- [ADR-005: Settings Information Architecture](./ADR-005-settings-information-architecture.md)
- [ADR-006: Settings Validation and Apply Behaviour](./ADR-006-settings-validation-and-apply-behaviour.md)
- [settings.md](../settings.md)
- [provider-management.md](../provider-management.md)
