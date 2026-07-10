# Provider Management (M4 planning)

**Status:** Planning — M4 Phase 4.1  
**Related roadmap phase:** [M4 Phase 4.1 — Provider Management](../roadmap/m4-plan.md#phase-41--provider-management)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [M3.5 Phase 4 plan](../roadmap/m35-phase-4-plan.md)

---

## Purpose

Define how users **see, understand, and act on** catalogue provider state after M3.5 delivered the underlying provider architecture. M4.1 is a management and visibility layer — not a second implementation of network access.

---

## Current baseline (M3.5 complete)

| Capability | State |
|---|---|
| `MediaProviderConfig` / `MediaProviderConfigService` | Persisted provider list (local paths, HTTPS catalogue URLs, access modes) |
| `CatalogueProviderSelector` | Startup provider ordering and selection |
| `CatalogService` | Local file load, HTTP catalogue load, provider iteration, fallback |
| Automatic fallback | Failed provider attempts retain last-good catalogue; dismissible banner |
| `MediaLocationResolver` | Local and HTTP serving providers wired into playback and artwork |
| HTTPS enforcement | `localPreferred` warns on HTTP; `httpRequired` rejects plain HTTP |
| Settings UI | `MediaProviderSettingsScreen` — add/edit/remove providers |
| Readable errors | `remote_fetch_errors.dart` — TLS, timeout, network messages |

**Not in baseline:** unified provider health dashboard, explicit retry/refresh affordance, consolidated active-provider indicator outside settings.

---

## M4 goals

- Single coherent **provider management** surface (may extend settings or dashboard)
- **Active catalogue provider** always visible
- **Explicit refresh and retry** without full app restart
- **Health states**: idle, loading, success, degraded (fallback), failed
- Preserve M3.5 selection order and fallback semantics

---

## Proposed responsibilities

| Component | M4.1 role |
|---|---|
| `CatalogService` | Expose last attempt result per provider; support targeted refresh |
| `CatalogueProviderSelector` | Unchanged selection logic unless ADR approves UX-driven reorder |
| Provider management UI | Status, active provider, refresh/retry actions |
| Dashboard banners | Align with provider management vocabulary |

---

## Data / state considerations

- Provider attempt history may be **in-memory** for session diagnostics; persistence optional
- Last-good catalogue remains authoritative until a successful refresh replaces it
- Active provider identity must be derivable from `CatalogService` without duplicating config

---

## Failure handling

- Refresh failure: retain catalogue; show actionable error; offer retry
- All providers fail: demo or last-good per existing M3.5 rules — no blank catalogue screen
- TLS/certificate errors: reuse M3.5 readable messages; link to diagnostics (Phase 4.6)

---

## Testing considerations

- Extend `provider_selection_test.dart` patterns for refresh and status
- Widget tests for active-provider display and retry button
- Regression: legacy `catalog_path` pref migration path

---

## Open decisions

1. **Surface location** — dedicated Provider screen vs dashboard section vs settings subsection?
2. **Refresh scope** — full provider list retry vs active provider only?
3. **Health persistence** — session-only vs last-known status across restarts?

Record decisions in ADRs when implementation begins.

---

## Out of scope

- New provider types (S3, WebDAV, etc.)
- OAuth or API keys
- Per-user provider profiles

---

## Related documents

- [settings.md](./settings.md) — Phase 4.2 may host navigation entry
- [diagnostics.md](./diagnostics.md) — Phase 4.6 deep detail
