# ADR-003: Provider Status Presentation

**Status:** Accepted  
**Date:** 2026-07-12  
**Milestone:** M4 Phase 4.1  
**Authors:** TTSPlayer M4 documentation pass

---

## Context

Provider configuration lives in **Settings** (`MediaProviderSettingsScreen`). Runtime status is split across:

- **Storage Status** dashboard section — legacy Live NAS / Fallback NAS / Demo model
- **Dashboard banners** — demo fallback and generic errors
- **CatalogueSourceChip** — three-way classification not aligned with configured HTTPS URLs

M4 Phase 4.2 will introduce a settings shell. M4 Phase 4.6 will add a **Diagnostics** screen with resolver detail, cache health, TLS context, and optional export. M4.1 must deliver **operational status at a glance** without duplicating 4.6.

Constraints:

- Material 3 built-ins; [design system](../../design/design-system.md) tokens
- TV-friendly tap targets where actions exist
- Dashboard-first navigation

---

## Decision

### 1. Primary surface: evolve Storage Status → **Provider Status**

**Location:** Dashboard, same scroll position as today’s Storage Status section.

**Section title:** `Provider Status`.

**Phase 4.1 content (concise operational status):**

| Element | Source | Max detail |
|---|---|---|
| Active provider | `activeCatalogueProvider` + health badge | One row |
| Access mode | `MediaAccessMode` label | Subtitle |
| Last refreshed | `lastCatalogueLoadAt` | Relative time |
| Catalogue identity | `loadedCatalogueIdentity` | Truncated mono (optional) |
| Provider list | `providerSnapshot.providers` | Health + location + **one-line** error if `failed` |
| **Refresh catalogue** | ADR-002 | Primary action |
| **Provider settings** | Existing settings screen | Secondary action |

### 2. Phase 4.1 vs Phase 4.6 boundary

| Concern | Phase 4.1 (Provider Status panel) | Phase 4.6 (Diagnostics screen) |
|---|---|---|
| Active source | Yes — summary | Yes — full detail |
| Per-provider health | Badge + one-line error | Full attempt history, timestamps |
| Access mode / resolver | Label only | Full `MediaAccessConfig` summary |
| TLS / certificate errors | User-readable one-liner | Full TLS context, trust hints |
| Catalogue stats | Identity only | Item/folder counts |
| Cache health | No | Yes |
| App version / build | No | Yes |
| Export / copy diagnostics | No | Yes |
| Log ring buffer | No | Optional |

Phase 4.1 **must not** implement diagnostics export, resolver dump, or cache panels. A placeholder “Diagnostics” entry may be added in Phase 4.6 when that screen exists.

### 3. Provider row presentation

Each row shows:

- Icon — `folder` (local) or `cloud` (HTTPS)
- Location — path/URL in mono, ellipsized
- Health badge — ADR-001 settled state (during refresh, show `loading`)
- Last error — **one line**, only when `failed`

Active row: `radio_button_checked`. **`skipped`** rows show a muted “Not used in this mode” hint, not an error.

### 4. Legacy NAS/demo layout

Remove fixed Live NAS / Fallback NAS / Demo three-row layout.

- **Demo** — when `isDemoFallback`, show “Demo catalogue (bundled)”
- **Configured providers** — literal paths/URLs from config
- **`isDegradedLoad`** — optional dismissible banner; not blocking

### 5. Dashboard banners

| Condition | Banner |
|---|---|
| `isDemoFallback` | Info — demo in use; Retry refresh |
| Refresh failed, catalogue retained | Error — `lastCycleError` / `errorMessage`; Retry |
| `isDegradedLoad` | Warning (optional, dismissible) |
| Scan / scanner | Unchanged |

### 6. Settings screen (minimal)

- Hint: “Status and refresh are on the dashboard”
- No duplicate refresh button
- Save unchanged — applies on next refresh/startup

### 7. No dedicated Provider Management route

M4.1 does not add a standalone screen or nav entry.

---

## Rationale

- Operational vs diagnostic concerns separated across phases
- Literal path/URL display respects user configuration
- Single refresh entry point on dashboard

---

## Consequences

### Positive

- HTTPS deployments see accurate status
- Phase 4.6 has a clear superset scope — no rework of 4.1 panel

### Negative

- Storage Status refactor touches dashboard tests
- Label change from “Live NAS” (release note)

### Neutral

- Library Manager labels aligned in same implementation pass

---

## Alternatives considered

### Alternative A — Full diagnostics on dashboard in 4.1

**Rejected because:** duplicates 4.6; clutters browse-first dashboard.

### Alternative B — Provider status only in Settings

**Rejected because:** hidden during normal browsing.

### Alternative C — Dedicated Provider Management screen

**Rejected because:** extra navigation for MVP.

---

## Related documents

- [M4 Phase 4.1 specification](../../roadmap/m4-phase-4.1-provider-management.md)
- [ADR-001: Provider Health Model](./ADR-001-provider-health-model.md)
- [ADR-002: Provider Refresh Lifecycle](./ADR-002-provider-refresh-lifecycle.md)
- [Diagnostics planning (Phase 4.6)](../diagnostics.md)
- [Design system](../../design/design-system.md)
