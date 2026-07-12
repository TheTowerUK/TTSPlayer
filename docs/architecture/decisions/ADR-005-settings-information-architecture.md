# ADR-005: Settings Information Architecture

**Status:** Accepted  
**Date:** 2026-07-12  
**Accepted:** 2026-07-12 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.2  
**Authors:** M4 documentation pass

---

## Context

Today, provider configuration lives on a standalone `MediaProviderSettingsScreen` opened from the app bar and dashboard Provider Status panel. Operational provider health, retry, and catalogue refresh live on the dashboard (ADR-003). Phase 4.2 must unify entry points into a **coherent settings framework** without duplicating provider status or Phase 4.6 diagnostics.

Platform: Windows desktop first; TV-friendly tap targets remain a design constraint for future surfaces.

---

## Decision

1. **Single settings route** — `SettingsScreen` with vertically scrollable **grouped sections** (not a multi-level settings tree for M4.2).

2. **Section order and IDs:**

   | Section | Purpose |
   |---|---|
   | General | App-level preferences supported in M4.2 |
   | Library & Providers | Evolved `MediaProviderSettingsScreen` fields |
   | Playback | Placeholder/deferred controls only where not yet implemented |
   | Network | Timeout and transport-related prefs not duplicated in provider form |
   | Diagnostics & Advanced | Version display, reset settings, optional existing debug flags |

3. **Configuration vs operational status:**
   - Settings sections are **editable configuration** only.
   - Provider health, active source, last refresh, retry, and refresh catalogue remain on the **dashboard Provider Status panel** (ADR-003).
   - Library & Providers section includes a short link: “See dashboard for active provider and refresh.”

4. **Navigation pattern (desktop):**
   - App bar **Settings** opens `SettingsScreen` (replaces direct push to provider-only screen).
   - Dashboard Provider Status **Settings** action navigates to `SettingsScreen` scrolled/focused to Library & Providers (optional deep link parameter — implementation detail).
   - Back returns to prior route; unsaved changes handled per ADR-006.

5. **Extensibility:** New categories append as new sections with stable section IDs; no hardcoded “Movies/TV” style groupings — filesystem-driven product rules unchanged.

6. **Phase 4.6 boundary:** No resolver dump, TLS certificate detail, log export, or cache health in M4.2 settings. Diagnostics section may link forward when Phase 4.6 ships.

---

## Rationale

- One scrollable screen matches current provider settings UX and avoids premature route proliferation on desktop.
- Separating configuration (settings) from operational status (dashboard) preserves ADR-003 and prevents two sources of truth for provider health.
- Embedding provider fields avoids rebuilding a working editor.

---

## Consequences

### Positive

- Clear user mental model: configure in Settings; operate/monitor on Dashboard.
- Provider settings code can be refactored into section widgets incrementally.

### Negative

- Long settings page; requires good section headings and scroll affordances.

### Neutral

- `MediaProviderSettingsScreen` may remain as an implementation file renamed/wrapped until refactor completes.

---

## Alternatives considered

### Alternative A — Multi-route settings hub (General / Network / … as separate screens)

**Rejected for M4.2 because:** Adds navigation depth without enough settings volume yet; can revisit if sections grow substantially.

### Alternative B — Merge provider status into settings

**Rejected because:** Conflicts with ADR-003; duplicates refresh lifecycle; worse dashboard UX.

### Alternative C — Keep provider settings standalone forever

**Rejected because:** Fails Phase 4.2 objective of a unified framework.

---

## Related documents

- [ADR-003: Provider Status Presentation](./ADR-003-provider-status-presentation.md)
- [ADR-004: Settings Storage and Versioning](./ADR-004-settings-storage-and-versioning.md)
- [ADR-006: Settings Validation and Apply Behaviour](./ADR-006-settings-validation-and-apply-behaviour.md)
- [M4 Phase 4.2 specification](../../roadmap/m4-phase-4.2-settings-framework.md)
