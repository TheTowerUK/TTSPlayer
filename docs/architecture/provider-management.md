# Provider Management (M4 Phase 4.1)

**Status:** **Implemented / Accepted** — validated on Windows 2026-07-12  
**Related roadmap phase:** [M4 Phase 4.1 — Provider Management](../roadmap/m4-plan.md#phase-41--provider-management) *(complete)*

→ [Media access abstraction](./media-access-abstraction.md)  
→ [Phase 4.1 specification](../roadmap/m4-phase-4.1-provider-management.md)  
→ [Runtime validation results](../roadmap/m4-phase-4.1-provider-management.md#windows-runtime-validation-2026-07-12)

**ADRs (Accepted):**

- [ADR-001: Provider Health Model](./decisions/ADR-001-provider-health-model.md)
- [ADR-002: Provider Refresh Lifecycle](./decisions/ADR-002-provider-refresh-lifecycle.md)
- [ADR-003: Provider Status Presentation](./decisions/ADR-003-provider-status-presentation.md)

---

## Purpose

Define how users **see, understand, and act on** catalogue provider state after M3.5 delivered the underlying provider architecture. M4.1 is a management and visibility layer — not a second implementation of network access.

---

## Validated runtime behaviour (2026-07-12)

| Capability | Validated behaviour |
|---|---|
| Session provider snapshot | `idle` / `loading` / `success` / `degraded` / `failed` / `skipped`; not persisted |
| `localPreferred` chain | Legacy pref → configured providers; short-circuit leaves later providers `idle` |
| Degraded fallback | Later configured provider succeeds after earlier `failed`; distinct from demo fallback (`isUsingFallback`) |
| Demo fallback | All providers fail on cold start → bundled catalogue; failed records; no active configured provider |
| `httpRequired` | Local providers `skipped`; HTTP-only attempts |
| Catalogue refresh | `refreshCatalogue()` = full eligible provider chain reload (not filesystem scan) |
| Failed refresh | Last-good catalogue, `lastCatalogueLoadAt`, and artwork cache preserved |
| TLS errors | Readable handshake/certificate messages; no insecure bypass |
| Dashboard panel | Provider Status replaces Storage Status; refresh / retry / settings actions |
| Indexer integration | Library rescan rewrites `catalog.json`; subsequent refresh updates snapshot |

**Re-run validation:** `PHASE_41_RUNTIME=1 flutter test test/phase_41_windows_runtime_test.dart --tags phase41-runtime` from `client/ttsplayer`.

---

## Implementation map

| Component | Location |
|---|---|
| `CatalogueProviderHealth` + snapshot | `client/ttsplayer/lib/models/catalogue_provider_snapshot.dart` |
| `CatalogService` instrumentation | `client/ttsplayer/lib/services/catalog_service.dart` |
| Skipped provider detection | `client/ttsplayer/lib/services/media_access/catalogue_provider_selector.dart` |
| Provider Status panel | `client/ttsplayer/lib/features/dashboard/widgets/provider_status_section.dart` |
| Degraded vs demo banners | `client/ttsplayer/lib/features/dashboard/widgets/dashboard_banners.dart` |
| Runtime validation harness | `client/ttsplayer/test/phase_41_windows_runtime_test.dart` |

**Removed:** `StorageStatusSection` (legacy Live NAS / Fallback NAS / Demo chip UI).

**Unchanged:** `CatalogueProviderSelector` ordering; M3.5 demo fallback semantics; artwork cache clear on successful replacement only.

---

## Failure handling

- Refresh failure: retain catalogue; show actionable error; offer retry (ADR-002)
- All providers fail on startup: demo or last-good per M3.5 rules — no blank catalogue screen
- TLS/certificate errors: M3.5 readable messages; deep diagnostics deferred to Phase 4.6

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

## Out of scope (delivered in later M4 phases)

- Settings framework restructure (Phase 4.2)
- Full diagnostics export (Phase 4.6)
- New provider types, authentication, transcoding

---

## Related documents

- [M4 Phase 4.1 implementation spec](../roadmap/m4-phase-4.1-provider-management.md)
- [settings.md](./settings.md) — Phase 4.2 follow-on
- [diagnostics.md](./diagnostics.md) — Phase 4.6 deep detail
