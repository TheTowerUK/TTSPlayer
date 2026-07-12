# Provider Management (M4 planning)

**Status:** Specification **Accepted** — implementation pending ([Phase 4.1 spec](../roadmap/m4-phase-4.1-provider-management.md))  
**Related roadmap phase:** [M4 Phase 4.1 — Provider Management](../roadmap/m4-plan.md#phase-41--provider-management)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [M3.5 Phase 4 plan](../roadmap/m35-phase-4-plan.md)

**ADRs (Accepted):**

- [ADR-001: Provider Health Model](./decisions/ADR-001-provider-health-model.md)
- [ADR-002: Provider Refresh Lifecycle](./decisions/ADR-002-provider-refresh-lifecycle.md)
- [ADR-003: Provider Status Presentation](./decisions/ADR-003-provider-status-presentation.md)

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
| Artwork cache | Cleared on successful catalogue replacement (`onCatalogReplaced`) |

**Not in baseline (M4.1 deliverables):** structured health model, provider snapshot, Provider Status panel, unified refresh labelling — see [implementation spec](../roadmap/m4-phase-4.1-provider-management.md).

---

## M4.1 target architecture (from ADRs)

| Component | Role |
|---|---|
| `CatalogueProviderHealth` + snapshot | Session-scoped health per provider (ADR-001) |
| `CatalogService.providerSnapshot` | Read-only exposure of attempts and active provider |
| Catalogue refresh | Full provider chain reload; distinct from indexer scan (ADR-002) |
| Provider Status panel | Dashboard section replacing legacy Storage Status (ADR-003) |
| `CatalogueProviderSelector` | **Unchanged** selection order |

---

## Failure handling

- Refresh failure: retain catalogue; show actionable error; offer retry (ADR-002)
- All providers fail: demo or last-good per existing M3.5 rules — no blank catalogue screen
- TLS/certificate errors: reuse M3.5 readable messages; link to diagnostics (Phase 4.6)

---

## Testing considerations

See validation scenarios V1–V10 in [Phase 4.1 spec](../roadmap/m4-phase-4.1-provider-management.md#validation-scenarios).

- Extend `provider_selection_test.dart` for snapshot instrumentation
- Widget tests for Provider Status panel
- Regression: legacy `catalog_path` pref migration path

---

## Decisions (resolved in ADRs)

| Question | Decision (ADR) |
|---|---|
| Health vocabulary | `idle` / `loading` / `success` / `degraded` / `failed` / `skipped` — see ADR-001 |
| `degraded` | Active provider after earlier `failed` in same cycle (`localPreferred`) |
| `skipped` | Config/selector exclusion only — not short-circuit after success |
| Surface location | Dashboard Provider Status panel (ADR-003) |
| Refresh scope | Full provider chain (ADR-002) |
| Health persistence | Session-only (ADR-001) |
| vs Phase 4.6 | Operational summary only; diagnostics detail deferred |

---

## Out of scope

- New provider types (S3, WebDAV, etc.)
- Authentication
- Multi-user provider profiles

---

## Related documents

- [M4 Phase 4.1 implementation spec](../roadmap/m4-phase-4.1-provider-management.md)
- [settings.md](./settings.md) — Phase 4.2 may host navigation entry
- [diagnostics.md](./diagnostics.md) — Phase 4.6 deep detail
