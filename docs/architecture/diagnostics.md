# Diagnostics and Supportability (M4 Phase 4.6)

**Status:** **Implemented / Accepted** — Phase 4.6 closed (2026-07-17)  
**Related roadmap phase:** [M4 Phase 4.6 — Diagnostics and Supportability](../roadmap/m4-phase-4.6-diagnostics-supportability.md)

→ [Provider management](./provider-management.md)  
→ [Settings](./settings.md)  
→ [Caching](./caching.md)  
→ [M3.5 remote fetch errors](../../client/ttsplayer/lib/services/remote_fetch_errors.dart) *(implementation reference)*

**ADRs:**

- [ADR-017: Diagnostics Architecture](./decisions/ADR-017-diagnostics-architecture.md) — **Accepted**
- [ADR-018: Runtime Snapshot Model](./decisions/ADR-018-runtime-snapshot-model.md) — **Accepted**
- [ADR-019: Diagnostics Export and Support Strategy](./decisions/ADR-019-diagnostics-export-support-strategy.md) — **Accepted**

---

## Purpose

Give users and maintainers enough **in-app context** to diagnose catalogue, provider, cache, search, and playback issues without reading logs or source code — by **aggregating runtime state that already exists** in production services.

**Relationship to Phase 4.1 (ADR-003):** The dashboard **Provider Status** panel shows concise operational status and refresh actions. Phase 4.6 adds the **Diagnostics** screen with full detail, cache/search lifecycle, and export — it **does not replace** the 4.1 summary panel.

**Relationship to Phase 4.2 (ADR-005):** Settings holds editable configuration. Diagnostics is read-only and reached from **Settings → Diagnostics & Advanced → View diagnostics**.

**Relationship to Phase 4.5:** Cache bounds and search index lifecycle counters (`cacheEntryCount`, `indexBuildCount`, etc.) are consumed directly — not re-measured.

---

## Ownership

```
Production services
    → DiagnosticsService
        → RuntimeDiagnosticsSnapshot
            → DiagnosticsScreen
            → formatExport()
                → DiagnosticsExportCoordinator
                    → DiagnosticsClipboardWriter
```

| Rule | Detail |
|---|---|
| Aggregation owner | `DiagnosticsService` only |
| Source direction | Production services → diagnostics (never reverse) |
| UI boundary | `DiagnosticsScreen` reads `DiagnosticsService` only — no direct service aggregation |
| Export boundary | `formatDiagnosticsExport()` is the sole text-generation path |
| Clipboard boundary | Receives final redacted plain text only |
| Lifetime | App-scoped `Provider<DiagnosticsService>` at composition root |

### Component map

| Component | Location |
|---|---|
| `DiagnosticsService` | `client/ttsplayer/lib/services/diagnostics/diagnostics_service.dart` |
| `RuntimeDiagnosticsSnapshot` + section DTOs | `runtime_diagnostics_models.dart` |
| Redaction | `diagnostics_redaction.dart` |
| Plain-text formatter | `diagnostics_export_formatter.dart` |
| `DiagnosticsScreen` | `client/ttsplayer/lib/features/settings/diagnostics_screen.dart` |
| UI formatters | `diagnostics_formatters.dart` |
| Section widgets | `widgets/diagnostics_*.dart` |
| Export coordinator | `diagnostics_export_coordinator.dart` |
| Clipboard boundary | `diagnostics_clipboard.dart` |

---

## Snapshot lifecycle

### Open or refresh

```
Open Diagnostics / Refresh diagnostics
    → captureSnapshot()
    → immutable RuntimeDiagnosticsSnapshot
    → DiagnosticsScreen render
```

- One `capturedAt` per snapshot.
- Startup elapsed = `capturedAt − applicationStartedAt` (fixed bootstrap timestamp).
- Refresh keeps the previous snapshot visible while capturing; recoverable refresh failure preserves the prior snapshot.

### Copy (Option A — ADR-019)

```
Copy diagnostics
    → fresh captureSnapshot()
    → formatExport(snapshot)
    → DiagnosticsClipboardWriter.writeText()
    → displayed snapshot updated to match copied output
    → SnackBar confirmation
```

Duplicate Refresh/Copy operations share an in-flight guard.

---

## Seven sections (stable order)

| # | Section | Primary sources |
|---|---|---|
| 1 | Application | `package_info`, platform, startup elapsed, `capturedAt` |
| 2 | Provider | `CatalogService.providerSnapshot`, `MediaProviderConfigService` |
| 3 | Catalogue | `CatalogService.catalog` aggregates (identity, counts, flags) |
| 4 | Cache | `ArtworkService` counters, Flutter `ImageCache` bytes |
| 5 | Search | `SearchService` index lifecycle |
| 6 | Playback | `PlaybackService`, `playback_platform.dart` |
| 7 | Library | `LibraryMetadataRepository` favourite counts |

Each section carries `DiagnosticSectionStatus` (`complete`, `partial`, `unavailable`). Nullable fields mean unavailable; `false` and `0` retain distinct semantics.

---

## Failure isolation

| Failure | Behaviour |
|---|---|
| Single source section throws | Section marked unavailable/partial; other sections still render |
| Initial capture throws | Screen-level error + Retry; no raw exception text |
| Refresh throws | Prior snapshot preserved + inline warning |
| Copy capture throws | Prior snapshot preserved; safe SnackBar |
| Copy format/clipboard throws | Prior snapshot preserved; safe SnackBar |

Raw exceptions and stack traces are never displayed or exported.

---

## Non-mutation guarantees

Diagnostics operations (open, refresh, copy) do **not**:

- Reload or refresh the catalogue
- Clear or invalidate artwork caches
- Build or rebuild the search index
- Change playback state or rate
- Save or reset Settings
- Reset diagnostic counters

Verified by integration tests, clipboard tests, and Windows runtime harness D5–D6 non-mutation audit.

---

## Redaction contract

**Never expose in UI or export:**

- Local paths (`Y:\`, `C:\Users`, `/volume1/`, UNC)
- File URIs and full HTTP/HTTPS URLs with paths or query strings
- Credentials, tokens, passwords
- Media titles, filenames, folder names in diagnostics output
- Stack traces and raw exception messages

**Allowed:**

- Truncated catalogue/search identities
- Provider kind and health labels
- Safe HTTPS host summaries (no paths)
- User-readable error categories from `remote_fetch_errors`
- Counts, durations, booleans, capability flags

Redaction is centralized in `diagnostics_redaction.dart` and applied before DTO assembly and export formatting.

---

## Export (ADR-019)

| Item | Status |
|---|---|
| Format | Plain text with stable `=== Section ===` headings |
| Delivery | **Copy diagnostics** → system clipboard |
| Fresh capture | Yes — copy always captures current state |
| Display alignment | Copied text matches on-screen snapshot (Option A) |
| File save | **Deferred** |
| JSON / upload / telemetry / log bundles | **Rejected for v1** |
| Persistence of copied text | None |

---

## Validation

| Layer | Tests |
|---|---|
| Unit | `diagnostics_snapshot_test.dart`, `diagnostics_service_test.dart`, `diagnostics_redaction_test.dart` |
| Widget | `diagnostics_screen_test.dart`, `settings_screen_test.dart` (navigation) |
| Integration | `diagnostics_integration_test.dart` |
| Clipboard | `diagnostics_clipboard_test.dart` |
| Runtime (Windows) | `phase_46_windows_runtime_test.dart` — D1–D10 with `PHASE_46_RUNTIME=1` |

**Evidence (closure):** normal suite **624 passed, 8 skipped**; runtime **10 passed, 1 skipped**; `flutter analyze` **89** existing findings, no new Phase 4.6 errors or warnings.

### Manual release follow-ups (not blockers)

- Narrow/wide Windows layout visual check
- Keyboard focus traversal and scroll
- Snackbar visibility wording
- External Windows clipboard paste into Notepad
- Long identity wrapping and high-DPI layout
- Optional `PHASE_46_LOCAL_CATALOG` live catalogue validation

---

## Out of scope (deferred by design)

- File export to disk
- Sentry / Firebase / automatic upload
- Remote admin console
- Log ring buffer in export
- Reset diagnostic counters UI
- SQLite / persistent diagnostics store
- Hidden developer mode
- JSON primary export

---

## Related documents

- [M4 Phase 4.6 specification](../roadmap/m4-phase-4.6-diagnostics-supportability.md)
- [Phase 4.6 closure record](../roadmap/m4-phase-4.6-diagnostics-supportability.md#step-8--closure-and-definition-of-done-2026-07-17)
- [caching.md](./caching.md)
- [provider-management.md](./provider-management.md)
- [settings.md](./settings.md)
- [TNAS deploy checklist](../deployment/tnas-caddy-deploy-checklist.md)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-16 | Step 1: instrumentation audit, proposed architecture, ADR-017–019 |
| 2026-07-16 | Step 2: data layer implemented; ADR-017–018 accepted |
| 2026-07-17 | Steps 4–5: UI + clipboard export; ADR-019 accepted |
| 2026-07-17 | Step 7: Windows runtime harness D1–D10 |
| 2026-07-17 | Step 8: Phase closed — Implemented / Accepted |
