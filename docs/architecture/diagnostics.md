# Diagnostics and Supportability (M4 Phase 4.6)

**Status:** **In progress** — Step 2 data layer implemented (2026-07-16)  
**Related roadmap phase:** [M4 Phase 4.6 — Diagnostics and Supportability](../roadmap/m4-phase-4.6-diagnostics-supportability.md)

→ [Provider management](./provider-management.md)  
→ [Settings](./settings.md)  
→ [Caching](./caching.md)  
→ [M3.5 remote fetch errors](../../client/ttsplayer/lib/services/remote_fetch_errors.dart) *(implementation reference)*

**ADRs:**

- [ADR-017: Diagnostics Architecture](./decisions/ADR-017-diagnostics-architecture.md) — **Accepted**
- [ADR-018: Runtime Snapshot Model](./decisions/ADR-018-runtime-snapshot-model.md) — **Accepted**
- [ADR-019: Diagnostics Export and Support Strategy](./decisions/ADR-019-diagnostics-export-support-strategy.md) — **Proposed**

---

## Purpose

Give users and maintainers enough **in-app context** to diagnose catalogue, provider, cache, search, and playback issues without reading logs or source code — by **aggregating runtime state that already exists** in production services.

**Relationship to Phase 4.1 (ADR-003):** The dashboard **Provider Status** panel shows concise operational status and refresh actions. Phase 4.6 adds the **Diagnostics** screen with full detail, cache/search lifecycle, and export — it **does not replace** the 4.1 summary panel.

**Relationship to Phase 4.2 (ADR-005):** Settings holds editable configuration. Diagnostics is read-only and reached from **Settings → Diagnostics & Advanced → View diagnostics**.

**Relationship to Phase 4.5:** Cache bounds and search index lifecycle counters (`cacheEntryCount`, `indexBuildCount`, etc.) are consumed directly — not re-measured.

---

## Existing instrumentation inventory (Step 1 audit)

### Consume in production diagnostics (no duplicate measurement)

| Owner | Available state | Diagnostics section |
|---|---|---|
| `CatalogService` | `providerSnapshot`, `activeCatalogueProvider`, `lastRefreshedAt`, `lastCatalogueLoadAt`, `catalog`, `catalogueIdentity`, `isLoading`, `errorMessage`, `isUsingFallback`, `isDegradedLoad`, `catalogSource` | Provider, Catalogue |
| `CatalogueProviderSnapshot` | Per-provider health, timestamps, `lastError` (ADR-001) | Provider |
| `MediaProviderConfigService` | Access mode, provider kind, HTTPS host | Provider |
| `ArtworkService` | `cacheEntryCount`, `cacheEvictionCount`, `defaultCacheCapacity` | Cache |
| Flutter `ImageCache` | `maximumSizeBytes`, `currentSizeBytes` | Cache |
| `SearchService` | `catalogueIdentity`, `indexedItemCount`, `hasIndex`, `indexBuildCount`, `isBuildInFlight` | Search |
| `PlaybackService` | `currentItem` (id/title), `playbackErrorKind`, `errorMessage`, `isPlaying`, `isInitializing` | Playback |
| `playback_platform.dart` | `useMediaKitPlayback`, `playbackSpeedSettingsSupported` | Playback |
| `package_info` | Version, build | Application |
| `LibraryMetadataRepository` | Favourite counts | Library |

### Test-only — excluded from production diagnostics

| Source | Reason |
|---|---|
| `FolderPresentationMetrics` | Widget test counters |
| `SearchPresentationMetrics` | Flatten invocation test hook |
| `Phase45RuntimeBaseline` / `PerformanceBenchmarkReport` | Opt-in CI harness |
| `PHASE_45_RUNTIME` / `PHASE_45_BENCHMARK` | Dev/CI env gates |
| `SearchService.simulateBuildFailure` | Test injection |

### Light extension in implementation (Step 2–3)

| Gap | Approach |
|---|---|
| Application startup elapsed | Single bootstrap timestamp in `DiagnosticsService` |
| Library scan stats | Optional read from `ScannerService` if exposed |

---

## Implemented data layer (Step 2)

| Component | Location | Status |
|---|---|---|
| `DiagnosticsService` | `client/ttsplayer/lib/services/diagnostics/diagnostics_service.dart` | ✅ Composition-root wired |
| `RuntimeDiagnosticsSnapshot` + section DTOs | `runtime_diagnostics_models.dart` | ✅ Immutable |
| Redaction | `diagnostics_redaction.dart` | ✅ Centralized |
| Plain-text formatter | `diagnostics_export_formatter.dart` | ✅ No I/O (clipboard deferred) |

**Not yet implemented:** Clipboard copy, file export, `PHASE_46_RUNTIME` harness.

### Diagnostics screen (Step 4)

| Component | Location |
|---|---|
| `DiagnosticsScreen` | `client/ttsplayer/lib/features/settings/diagnostics_screen.dart` |
| Settings entry | `SettingsScreen` → View diagnostics |
| Formatters | `diagnostics_formatters.dart` |
| Widgets | `widgets/diagnostics_*.dart` |

---

```
Composition root (main.dart)
    CatalogService, ArtworkService, SearchService,
    PlaybackService, MediaProviderConfigService,
    SettingsRepository, LibraryMetadataRepository
              │
              ▼ (read-only observation)
    DiagnosticsService
              │
              ├── buildSnapshot() → RuntimeDiagnosticsSnapshot (ADR-018)
              └── formatExport()  → plain text (ADR-019)

Settings → Diagnostics & Advanced → DiagnosticsScreen
              │
              ├── Grouped read-only sections
              └── Copy to clipboard (primary)
```

**Ownership rules:**

- `DiagnosticsService` depends on production services — **never** the reverse.
- No circular dependencies.
- Snapshot build is synchronous where possible.

### DTO ownership (ADR-018)

| Type | Responsibility |
|---|---|
| `RuntimeDiagnosticsSnapshot` | Root immutable DTO + `capturedAt` |
| `ApplicationDiagnostics` | Version, build, platform, startup elapsed |
| `ProviderDiagnostics` | Active provider, health rows, refresh timestamps |
| `CatalogueDiagnostics` | Identity, counts, loading/error flags |
| `CacheDiagnostics` | Artwork LRU + Flutter image cache bytes |
| `SearchDiagnostics` | Index state, build count, in-flight |
| `PlaybackDiagnostics` | Engine, capabilities, session, errors |
| `LibraryDiagnostics` | Favourite counts, metadata version |

---

## Redaction contract

**Never expose in UI or export:**

- Raw `file_path`, UNC paths, NAS mount paths
- Full HTTPS URLs with path segments
- Passwords, tokens, certificate files
- Stack traces

**Allowed:**

- Truncated catalogue/search identity hashes
- Provider kind labels (local / https)
- HTTPS hostname (+ port)
- User-readable error messages from `remote_fetch_errors`
- Counts and durations

---

## User experience (design only — not implemented)

### Entry

Extend **Settings → Diagnostics & Advanced**:

- Retain existing version display and reset actions.
- Add **View diagnostics** → `DiagnosticsScreen`.
- Subtitle: read-only runtime state for troubleshooting.

### Diagnostics screen

| Element | Behaviour |
|---|---|
| Layout | Scrollable sections mirroring ADR-018 DTOs |
| Primary action | Copy to clipboard (`formatExport`) |
| Secondary (optional) | Save `.txt` on Windows |
| Reset counters | **Not in v1** (ADR-019) |
| Hidden developer section | **Rejected for v1** |

### Dashboard unchanged

Provider Status panel (ADR-003) retains refresh/retry; no cache/search detail added there.

---

## Export strategy (ADR-019)

- **Format:** Plain text with stable `=== Section ===` headings
- **Delivery:** Clipboard primary; optional file save on Windows
- **JSON / upload / telemetry:** Out of scope
- **Log ring buffer:** Deferred
- **TLS hints:** Optional link to TNAS deploy checklist when error pattern matches

---

## Runtime validation (Step 7 — design)

Opt-in: `PHASE_46_RUNTIME=1` in `test/phase_46_windows_runtime_test.dart`

| ID | Scenario |
|---|---|
| D1 | Open Diagnostics from Settings — no exception |
| D2 | Snapshot populated with loaded catalogue |
| D3 | Provider section matches `providerSnapshot` |
| D4 | Cache section after browse — count ≤ 500 |
| D5–D6 | Search lifecycle before/after first query |
| D7 | Playback idle capabilities shown |
| D8 | Copy to clipboard — non-empty stable headings |
| D9 | Export — no path leakage |
| D10 | Failed catalogue load — error + prior identity preserved |

---

## Testing considerations

| Layer | Focus |
|---|---|
| Unit | `buildSnapshot`, `formatExport`, redaction helpers |
| Widget | `DiagnosticsScreen` sections, copy action, Settings navigation |
| Integration | Wired harness — counts match live services |
| Runtime | `PHASE_46_RUNTIME=1` matrix D1–D10 |
| Failure paths | Null catalogue, search build failure, export still renders |

---

## Out of scope

- Sentry / Firebase / automatic upload
- Remote admin console
- Log ring buffer in export
- Reset diagnostic counters UI
- `FolderPresentationMetrics` in production UI
- Performance micro-benchmark UI
- SQLite / persistent diagnostics store

---

## Related documents

- [M4 Phase 4.6 specification](../roadmap/m4-phase-4.6-diagnostics-supportability.md)
- [caching.md](./caching.md) — cache health UI deferred from 4.5
- [provider-management.md](./provider-management.md)
- [settings.md](./settings.md)
- [TNAS deploy checklist](../deployment/tnas-caddy-deploy-checklist.md)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-16 | Step 1: instrumentation audit, proposed architecture, ADR-017–019 |
| 2026-07-17 | Step 4: Diagnostics screen UI + Settings navigation |
