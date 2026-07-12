# ADR-006: Settings Validation and Apply Behaviour

**Status:** Accepted  
**Date:** 2026-07-12  
**Accepted:** 2026-07-12 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.2  
**Authors:** M4 documentation pass

---

## Context

`MediaProviderSettingsScreen` today uses **explicit Save** with field-level validation errors and non-blocking security warnings. Invalid configs are not written. Provider configuration changes do not automatically reload the catalogue — users refresh from the dashboard (Phase 4.1 / ADR-002). Phase 4.2 extends settings to multiple groups and must define consistent apply, reset, and unsaved-change behaviour.

---

## Decision

1. **Explicit Save per settings screen session** — no auto-save on every keystroke. Each section may share one screen-level Save bar or one Save per section; implementation may use a **single Save** at the bottom of `SettingsScreen` that persists all dirty groups that validate.

2. **Field-level validation** — reuse existing validators:
   - `MediaProviderConfig.validate()` / `securityWarnings()`
   - `RemoteUrlSecurity` rules — **plain HTTP rejected when `httpRequired`** (non-negotiable)
   - Path/URL non-empty rules where required

3. **Invalid Save** — show inline error list; do not persist; retain last-good stored settings in memory and on disk.

4. **Unsaved changes** — when navigating back with dirty fields, show a dismissible dialog: Save / Discard / Cancel. Cancel keeps user on settings.

5. **Reset to defaults:**
   - **Library & Providers:** same semantics as today’s Reset — clears `media_provider_config_v1` and restores `MediaProviderConfig.defaults()`; after envelope migration, clears provider slice of envelope to defaults.
   - **Full settings reset (Diagnostics section):** restores all M4.2 settings groups to defaults; does not clear playback progress keys without separate confirmation.
   - Reset does **not** automatically reload catalogue.

6. **Provider configuration apply vs catalogue reload:**
   - Saving provider settings updates persisted config and notifies `MediaProviderConfigService`.
   - `MediaLocationResolver` is refreshed from new `mediaAccess` on save (today’s expectation via provider listener / main wiring — implementation must preserve).
   - **Catalogue reload is a separate user action** — dashboard **Refresh catalogue** or next app startup (`loadOnStartup`). This preserves last-good catalogue if new config points at missing paths (ADR-002 / graceful degradation).

7. **Network timeout preference** — when added, takes effect on next HTTP catalogue fetch (no retroactive cancel of in-flight request).

8. **Warnings vs errors** — HTTPS warnings on plain HTTP in `localPreferred` display as warnings; Save allowed. Errors block Save.

---

## Rationale

- Matches proven M3.5 provider settings behaviour; minimizes regression risk.
- Separating config save from catalogue reload prevents destructive blank states when users experiment with paths.
- Unsaved-change guard avoids accidental loss of long path edits on desktop.

---

## Consequences

### Positive

- Predictable Save/Reset semantics across sections.
- Aligns with Phase 4.1 provider refresh lifecycle.

### Negative

- Users must know to refresh catalogue after provider changes — mitigated by dashboard link and optional post-save hint banner (non-blocking).

### Neutral

- Immediate-apply toggles (e.g. future theme) may be added later per-group if ADR is updated.

---

## Alternatives considered

### Alternative A — Auto-save on blur

**Rejected because:** Long forms with partial invalid states; harder to batch validation; worse UX for multi-path edits.

### Alternative B — Auto-reload catalogue on provider Save

**Rejected because:** Violates last-good retention; surprising on large catalogues; ADR-002 refresh is user-initiated.

### Alternative C — Per-field immediate persist

**Rejected because:** Increases corrupt-partial-write risk; complicates migration.

---

## Related documents

- [ADR-002: Provider Refresh Lifecycle](./ADR-002-provider-refresh-lifecycle.md)
- [ADR-004: Settings Storage and Versioning](./ADR-004-settings-storage-and-versioning.md)
- [ADR-005: Settings Information Architecture](./ADR-005-settings-information-architecture.md)
- [M4 Phase 4.2 specification](../../roadmap/m4-phase-4.2-settings-framework.md)
