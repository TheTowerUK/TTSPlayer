# Diagnostics and Supportability (M4 planning)

**Status:** Planning — M4 Phase 4.6  
**Related roadmap phase:** [M4 Phase 4.6 — Diagnostics and Supportability](../roadmap/m4-plan.md#phase-46--diagnostics-and-supportability)

→ [Provider management](./provider-management.md)  
→ [M3.5 remote fetch errors](../../client/ttsplayer/lib/services/remote_fetch_errors.dart) *(implementation reference)*

---

## Purpose

Give users and maintainers enough **in-app context** to diagnose catalogue, provider, resolver, and network issues without reading logs or source code.

---

## Current baseline (M3 + M3.5)

| Capability | State |
|---|---|
| Dashboard banners | Catalogue fallback and error summaries via `dashboard_banners.dart` |
| `CatalogService` error messages | Dismissible banner; preserves last-good catalogue |
| Readable TLS/network errors | `remote_fetch_errors.dart` |
| Storage status section | Dashboard visibility of catalogue source class |
| Debug logging | Ad hoc `debugPrint` — no unified diagnostics screen |
| Version info | `pubspec.yaml` version; not surfaced in structured UI |

**Not in baseline:** dedicated diagnostics screen, export bundle, cache health, resolver config summary.

---

## M4 goals

Diagnostics screen (reachable from Settings) showing:

| Field | Source |
|---|---|
| Active catalogue provider | `CatalogService` / selector |
| Catalogue path or URL | Active provider config |
| Access mode | `localPreferred` / `httpRequired` |
| Resolver media base URL | `MediaProviderConfig` |
| Catalogue item/folder counts | Loaded `Catalog` |
| Last refresh time | `CatalogService` session metadata |
| Cache health | Phase 4.5 cache layer when implemented |
| App version / build | `package_info` or pubspec |
| Last error | Last provider attempt failure |
| Optional export | Plain-text summary for support |

---

## Proposed responsibilities

| Component | M4.6 role |
|---|---|
| Diagnostics screen | Read-only aggregation |
| `CatalogService` | Expose diagnostic DTO or getters |
| `MediaProviderConfigService` | Non-secret config summary |
| Export action | Clipboard or file save — no passwords or tokens |

---

## Data / state considerations

- Export must **redact** nothing that isn't already on device; no secret transmission
- Diagnostics are read-only — actions (retry) link to Phase 4.1 provider management
- Cache stats depend on Phase 4.5 implementation

---

## Failure handling

- Diagnostics screen itself must never throw — show "unavailable" per field
- Export failure: toast with retry

---

## Testing considerations

- Widget smoke: diagnostics renders with mock `CatalogService`
- Snapshot of export format (stable headings)

---

## Open decisions

1. **Export format** — plain text vs JSON?
2. **Log ring buffer** — include last N log lines in export?
3. **TNAS-specific hints** — link to deploy checklist when HTTPS errors detected?

---

## Out of scope

- Sentry / Firebase crash reporting
- Automatic upload to vendor
- Remote admin console

---

## Related documents

- [settings.md](./settings.md)
- [provider-management.md](./provider-management.md)
- [TNAS deploy checklist](../deployment/tnas-caddy-deploy-checklist.md)
