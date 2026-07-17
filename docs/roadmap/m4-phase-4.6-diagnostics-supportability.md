# M4 Phase 4.6 — Diagnostics and Supportability (Implementation Specification)

**Status:** **Complete** — closed Step 8 (2026-07-17)
**Milestone:** M4 — User Experience and Platform Integration
**Branch:** `m4-development`
**Development version:** `v0.5.0-dev`
**Closure commit:** Step 8 (2026-07-17)
**Predecessor:** M4 Phase 4.5 complete — closure `0ae4da9`

→ [M4 plan](./m4-plan.md#phase-46--diagnostics-and-supportability)
→ [Diagnostics architecture](../architecture/diagnostics.md)
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs:**

- [ADR-017: Diagnostics Architecture](../architecture/decisions/ADR-017-diagnostics-architecture.md) — **Accepted** (Step 2)
- [ADR-018: Runtime Snapshot Model](../architecture/decisions/ADR-018-runtime-snapshot-model.md) — **Accepted** (Step 2)
- [ADR-019: Diagnostics Export and Support Strategy](../architecture/decisions/ADR-019-diagnostics-export-support-strategy.md) — **Accepted** (Step 5)

Follow the established M4 cadence: **instrumentation audit → ADRs → architecture → aggregation service → UI → export → tests → Windows validation → closure**.

---

## Objective

Improve application **supportability** by exposing internal runtime state that **already exists** within the application — catalogue provider health, cache bounds, search lifecycle, playback capabilities, and catalogue summary — in a read-only Diagnostics experience reachable from Settings.

Phase 4.6 **consumes** existing instrumentation. It does not introduce parallel monitoring systems, background telemetry daemons, or duplicate measurement logic.

---

## Architectural principles

### Read-only aggregation

Diagnostics **observes** production services. It does not mutate settings, caches, catalogue state, or playback. Operational actions (refresh catalogue, retry provider) remain on the dashboard Provider Status panel (ADR-003).

### No sensitive data

Exports and UI must not include personal filesystem paths, credentials, certificate material, or full media library paths. Use classification labels, truncated identities, hostnames, and counts.

### Dashboard vs Settings vs Diagnostics

| Surface | Role |
|---|---|
| **Dashboard Provider Status** (4.1) | Operational summary + refresh/retry |
| **Settings** (4.2) | Editable configuration |
| **Diagnostics screen** (4.6) | Deep read-only introspection + export |

### Reuse Phase 4.5 hooks

Promote selected `@visibleForTesting` counters to **diagnostics-facing getters** on existing owners (`ArtworkService`, `SearchService`) rather than adding parallel counters. Test-only presentation metrics (`FolderPresentationMetrics`, `SearchPresentationMetrics`) remain **out of production diagnostics**.

---

## Phase steps

| Step | Name | Status |
|---|---|---|
| **0** | Instrumentation audit | ✅ (Step 1) |
| **1** | Specification + ADRs | ✅ Step 1 |
| **2** | Snapshot model + `DiagnosticsService` | ✅ Step 2 |
| **3** | Production getter promotion on cache/search owners | ✅ Merged into Step 2 |
| **4** | Diagnostics screen UI (Settings entry) | ✅ Step 4 |
| **5** | Clipboard export + support bundle | ✅ Step 5 |
| **6** | Documentation / release hardening | ✅ Merged into Step 8 closure |
| **7** | Windows runtime harness (`PHASE_46_RUNTIME=1`) | ✅ Step 7 |
| **8** | Closure | ✅ Step 8 |

**Suggested commit cadence:** snapshot model → UI → clipboard wiring → runtime harness → docs closure.

---

## Step 2 — Data layer implementation (2026-07-16)

### Code ownership

| Path | Role |
|---|---|
| `lib/services/diagnostics/diagnostics_service.dart` | Sole aggregation boundary |
| `lib/services/diagnostics/runtime_diagnostics_models.dart` | Immutable section DTOs + `RuntimeDiagnosticsSnapshot` |
| `lib/services/diagnostics/diagnostics_redaction.dart` | Identity truncation + sensitive-text stripping |
| `lib/services/diagnostics/diagnostics_export_formatter.dart` | Pure `formatDiagnosticsExport()` (no I/O) |
| `lib/services/diagnostics/diagnostic_section_status.dart` | `DiagnosticSectionStatus` enum |

### Public API

```dart
Future<RuntimeDiagnosticsSnapshot> captureSnapshot()
String formatExport(RuntimeDiagnosticsSnapshot snapshot)
```

- Async for `package_info_plus` cache on first capture only.
- `applicationStartedAt` fixed at composition root (`main.dart`); `startupElapsed = capturedAt - applicationStartedAt`.
- No persistence, subscriptions, or service mutation.

### Promoted production getters

| Service | Getters |
|---|---|
| `ArtworkService` | `cacheEntryCount`, `cacheCapacity`, `cacheEvictionCount` |
| `SearchService` | `indexBuildCount`, `hasIndex`, `isBuildInFlight` (existing `catalogueIdentity`, `indexedItemCount`) |

### Unavailable-value strategy

- `DiagnosticSectionStatus` per section: `complete`, `partial`, `unavailable`.
- Nullable typed fields — `null` means unavailable at field level; `false`/`0` retain distinct meaning.
- Playback session fields `null` when no active session (not `false`).
- `CatalogueDiagnostics?` null when no catalogue loaded; `LibraryDiagnostics?` null when metadata repo not initialized.
- Section mapping uses per-section try/catch — one failing source does not suppress others.

### Redaction

- Catalogue/search identity: scanner ids (`CatalogueInfo.id`, `legacy:{generatedAt}`) are safe; `redactIdentity()` truncates to 12 chars + `…` for defence in depth.
- Provider rows: kind + health labels only — **no** `definition.location`, hostnames, or paths.
- Errors: `redactSensitiveText()` strips drive/UNC/Unix paths, `file://`, HTTP(S) URLs, credentials, stack traces.
- Playback: item id truncated; **no** title, path, or resolver URI.

### Plain-text formatter

`formatDiagnosticsExport()` implemented in Step 2. Clipboard delivery implemented in Step 5 (ADR-019 **Accepted**). File export deferred.

### Composition root

`DiagnosticsService` registered as `Provider<DiagnosticsService>.value` in `main.dart` after `PlaybackService` construction. No UI consumer yet.

### Tests added (32)

- `test/diagnostics_snapshot_test.dart`
- `test/diagnostics_redaction_test.dart`
- `test/diagnostics_service_test.dart`
- `test/diagnostics_integration_test.dart`
- `test/support/diagnostics_test_harness.dart`

**Validation:** **606 passed**, **7 skipped**, **0 failed** (normal suite); `flutter analyze` **89** issues (unchanged baseline).

---

## Step 4 — Diagnostics screen UI (2026-07-17)

### Navigation

Settings → **Diagnostics & Advanced** → **View diagnostics** (`Key('view_diagnostics')`) pushes `DiagnosticsScreen` without discarding unsaved Settings state.

### Screen ownership

| Path | Role |
|---|---|
| `lib/features/settings/diagnostics_screen.dart` | Read-only diagnostics UI |
| `lib/features/settings/diagnostics_formatters.dart` | Presentation formatting helpers |
| `lib/features/settings/widgets/diagnostics_section.dart` | Section heading + status banner |
| `lib/features/settings/widgets/diagnostics_value_row.dart` | Label/value rows |
| `lib/features/settings/widgets/diagnostics_status_banner.dart` | Partial/unavailable banner |

### Snapshot lifecycle

1. Screen opens → loading (`Collecting diagnostics…`)
2. `DiagnosticsService.captureSnapshot()` on first frame
3. Immutable snapshot displayed
4. **Refresh diagnostics** (app bar + footer button) captures new snapshot; previous snapshot stays visible during refresh
5. Refresh failure keeps prior snapshot + inline warning

No clipboard, file export, or counter reset in Step 4.

### Tests added (18)

- `test/diagnostics_screen_test.dart` — loading, sections, refresh, redaction, async safety
- `test/settings_screen_test.dart` — navigation, unsaved-changes preservation

---

## Step 5 — Clipboard export (2026-07-17)

### ADR-019

**Accepted** — clipboard is the primary v1 support-delivery mechanism; file export deferred.

### Copy lifecycle (Option A)

1. User selects **Copy diagnostics**
2. Duplicate requests blocked via shared in-flight guard with Refresh
3. `DiagnosticsExportCoordinator` captures fresh snapshot → `formatExport()` → clipboard
4. Displayed snapshot updated to match copied output
5. SnackBar: *Diagnostics copied to clipboard.*

### Components

| Path | Role |
|---|---|
| `diagnostics_clipboard.dart` | `DiagnosticsClipboardWriter` + Flutter implementation |
| `diagnostics_export_coordinator.dart` | Capture → format → clipboard orchestration |
| `diagnostics_screen.dart` | Copy footer action + feedback |

### Tests added (17)

- `test/diagnostics_clipboard_test.dart` — coordinator, copy lifecycle, redaction, races, integration

**Validation:** **624 passed**, **7 skipped**; `flutter analyze` **89** issues (baseline maintained).

---

## Step 7 — Windows runtime validation (2026-07-17)

### Harness

| File | Role |
|---|---|
| `test/phase_46_windows_runtime_test.dart` | D1–D10 matrix (`@Tags(['phase46-runtime'])`) |
| `test/support/phase_46_runtime_harness.dart` | Production `DiagnosticsService` wiring + recording clipboard |
| `test/support/phase_46_runtime_baseline.dart` | Informational timing observations |

```powershell
$env:PHASE_46_RUNTIME='1'
flutter test test/phase_46_windows_runtime_test.dart --tags phase46-runtime
```

Optional: `$env:PHASE_46_LOCAL_CATALOG='path\to\catalog.json'` (skips when unset).

### D1–D10 results (Windows, automated)

| ID | Scenario | Classification |
|---|---|---|
| D1 | Settings → View diagnostics | Automated pass |
| D2 | Initial snapshot — seven sections | Automated pass |
| D3 | Provider diagnostics + redaction | Automated pass |
| D4 | Catalogue/library counts | Automated pass |
| D5 | Cache non-mutation | Automated pass |
| D6 | Search before/after query | Automated pass |
| D7 | Playback inactive baseline | Automated pass |
| D8 | Clipboard export (recording writer) | Automated pass |
| D9 | Redaction + failure isolation | Automated pass |
| D10 | Refresh, lifecycle, stability | Automated pass |

**Manual follow-ups:** narrow/wide layout, keyboard focus, external Windows clipboard paste, high-DPI.

**Runtime validation:** **10 passed**, **1 skipped** (optional live catalogue); normal suite **624 passed**, **8 skipped** (+1 harness gate skip).

Phase 4.6 remains open pending Step 8 closure.

---

## Step 1 — Existing instrumentation audit

### Consume directly (no new measurement logic)

| Source | Already available | Diagnostics use |
|---|---|---|
| `CatalogService` | `providerSnapshot`, `activeCatalogueProvider`, `lastRefreshedAt`, `lastCatalogueLoadAt`, `catalog`, `catalogueIdentity`, `isLoading`, `errorMessage`, `isUsingFallback`, `isDegradedLoad`, `catalogSource` | Provider + catalogue sections |
| `CatalogueProviderSnapshot` | Per-provider health, timestamps, `lastError` (ADR-001) | Provider detail |
| `MediaProviderConfigService` | Access mode, provider count, HTTPS host (redacted) | Provider config summary |
| `ArtworkService` | `cacheEntryCount`, `cacheEvictionCount`, `defaultCacheCapacity` | Cache health (promote getters from `@visibleForTesting`) |
| `SearchService` | `catalogueIdentity`, `indexedItemCount`, `hasIndex`, `indexBuildCount`, `isBuildInFlight` | Search lifecycle (promote selected getters) |
| Flutter `ImageCache` | `maximumSizeBytes`, `currentSizeBytes` | Decode cache budget (read framework state) |
| `PlaybackService` | `currentItem` id/title only, `playbackErrorKind`, `errorMessage`, session rate, track counts, `isInitializing`, `isPlaying` | Playback session summary |
| `playback_platform.dart` | `useMediaKitPlayback`, `playbackSpeedSettingsSupported` | Platform capabilities |
| `SettingsScreen` | `package_info` version/build | Application section |
| `LibraryMetadataRepository` | Favourite counts (if exposed) | Library metadata summary |
| `ScannerService` | Last scan status (if available) | Optional scanner hint |

### Test-only — do not expose in production diagnostics

| Source | Reason |
|---|---|
| `FolderPresentationMetrics` | Widget test counters; not session truth |
| `SearchPresentationMetrics` | Flatten invocation test hook |
| `SearchService.simulateBuildFailure` | Test injection only |
| `Phase45RuntimeBaseline` / `PerformanceBenchmarkReport` | Opt-in harness; not app runtime |
| `PHASE_45_BENCHMARK` / `PHASE_45_RUNTIME` harnesses | CI/dev only |

### Partial / extend lightly

| Gap | Step 2–3 approach |
|---|---|
| Application startup time | Record once in `DiagnosticsService` or app bootstrap — single timestamp |
| Last successful catalogue identity transition | Derive from `CatalogService` loaded identity + `lastRefreshedAt` |
| Favourites prune count on replace | Optional read from `LibraryMetadataRepository` last validation result if added |
| Log ring buffer | **Deferred** — out of 4.6 unless ADR-019 scope expands |

---

## Proposed architecture

### Ownership (ADR-017)

```
main.dart (Provider tree)
    ├── CatalogService          ─┐
    ├── ArtworkService           │
    ├── SearchService            ├── observed by DiagnosticsService (read-only)
    ├── PlaybackService          │
    ├── MediaProviderConfigService│
    ├── SettingsRepository       │
    └── LibraryMetadataRepository┘

DiagnosticsService
    → buildSnapshot() → RuntimeDiagnosticsSnapshot (immutable DTO)
    → formatExport()  → plain-text support bundle (ADR-019)

DiagnosticsScreen (Settings → Diagnostics & Advanced → Open diagnostics)
    → Consumer<DiagnosticsService> or one-shot snapshot on open
```

**Rules:**

- `DiagnosticsService` depends on existing services via constructor injection or `Provider` reads — **never** the reverse.
- No circular dependencies: production services must not import diagnostics types.
- Snapshot build is **synchronous** where possible; optional `Future` only for `package_info` already cached in Settings.

### Core types (ADR-018)

| Type | Responsibility |
|---|---|
| `DiagnosticsService` | Composition-root aggregator; `RuntimeDiagnosticsSnapshot buildSnapshot()` |
| `RuntimeDiagnosticsSnapshot` | Root immutable DTO + `capturedAt` timestamp |
| `ApplicationDiagnostics` | Version, build, platform, startup elapsed |
| `ProviderDiagnostics` | Active provider, access mode, snapshot summary, last refresh |
| `CatalogueDiagnostics` | Identity, source kind, folder/item counts, loading/error flags |
| `CacheDiagnostics` | Artwork entries/capacity/evictions; Flutter image cache bytes |
| `SearchDiagnostics` | Index built, identity, item count, build count, in-flight |
| `PlaybackDiagnostics` | Platform capabilities, session item, error kind, track summary |
| `LibraryDiagnostics` | Favourite counts, metadata repo version |

---

## User experience (design only)

### Entry point

Extend **Settings → Diagnostics & Advanced** (ADR-005):

- Retain version display and reset actions (existing).
- Add **“View diagnostics”** navigation to `DiagnosticsScreen`.
- Optional subtitle: “Read-only runtime state for troubleshooting.”

### Diagnostics screen

| Element | Behaviour |
|---|---|
| Layout | Scrollable grouped sections mirroring snapshot DTOs |
| Actions | **Copy to clipboard** (primary); optional **Export** save dialog (Windows) |
| Reset counters | **Not in v1** — `indexBuildCount` is lifetime diagnostic; no user-facing reset unless ADR-019 revises |
| Editing | None — clearly labelled “Diagnostics (read-only)” |
| Errors | Per-field “Unavailable” if source null; screen never throws |

### Hidden developer section

**Rejected for 4.6 v1.** Test-only metrics and opt-in benchmark hooks stay in test harnesses. Revisit only if a persisted `DiagnosticsSettings` debug flag is explicitly requested later.

---

## Data model summary (ADR-018)

### Application

| Field | Source | Redaction |
|---|---|---|
| `appVersion` | `package_info` | None |
| `buildNumber` | `package_info` | None |
| `platform` | `Platform.operatingSystem` | None |
| `startupElapsed` | App bootstrap timestamp | Duration only |

### Providers

| Field | Source | Redaction |
|---|---|---|
| `accessMode` | `MediaAccessConfig` | Label only |
| `activeProviderKind` | local / https | No path/URL |
| `activeProviderHost` | HTTPS host only | No path, query, credentials |
| `providerHealth` | ADR-001 enum | Per-provider rows: kind + health + one-line error |
| `lastRefreshAt` | `CatalogService.lastRefreshedAt` | ISO timestamp |

### Catalogue

| Field | Source | Redaction |
|---|---|---|
| `catalogueIdentity` | `Catalog.catalogueIdentity` | Truncated hash/id |
| `sourceKind` | demo / live / degraded | Classification |
| `folderCount` | `Catalog` | Count |
| `itemCount` | `Catalog.totalItems` | Count |
| `isLoading` | `CatalogService.isLoading` | Bool |
| `lastError` | `CatalogService.errorMessage` | User-readable text only |

### Artwork cache

| Field | Source |
|---|---|
| `candidateCount` | `ArtworkService.cacheEntryCount` |
| `candidateCapacity` | `ArtworkService.defaultCacheCapacity` (500) |
| `evictionCount` | `ArtworkService.cacheEvictionCount` |
| `imageCacheBudgetBytes` | `ImageCache.maximumSizeBytes` |
| `imageCacheCurrentBytes` | `ImageCache.currentSizeBytes` |

### Search

| Field | Source |
|---|---|
| `hasIndex` | `SearchService.hasIndex` |
| `catalogueIdentity` | `SearchService.catalogueIdentity` |
| `indexedItemCount` | `SearchService.indexedItemCount` |
| `indexBuildCount` | `SearchService.indexBuildCount` |
| `isBuildInFlight` | `SearchService.isBuildInFlight` |

### Playback

| Field | Source | Redaction |
|---|---|---|
| `engine` | media_kit vs video_player | Label |
| `speedSettingsSupported` | `playbackSpeedSettingsSupported` | Bool |
| `sessionItemId` | `PlaybackService.currentItem?.id` | Id only, no path |
| `sessionItemTitle` | title | Display title |
| `errorKind` | `PlaybackErrorKind?` | Taxonomy label |
| `errorMessage` | user-readable | No stack traces in export |

### Libraries / metadata

| Field | Source |
|---|---|
| `favouriteItemCount` | `LibraryMetadataRepository` |
| `favouriteFolderCount` | same |

**Never expose:** raw `file_path`, UNC paths, NAS mount paths, full HTTPS URLs with paths, passwords, tokens, certificate files.

---

## Runtime validation strategy (Step 7 — design)

Opt-in harness: `PHASE_46_RUNTIME=1`, file `test/phase_46_windows_runtime_test.dart`.

### Matrix prefix **D** (proposed)

| ID | Scenario | Expect |
|---|---|---|
| D1 | Open Diagnostics from Settings | Screen renders; no exception |
| D2 | Snapshot populated with loaded catalogue | Item/folder counts > 0 |
| D3 | Provider section shows active health | Matches `CatalogService.providerSnapshot` |
| D4 | Cache section after browse | `candidateCount` ≤ 500 |
| D5 | Search section before first query | `hasIndex` false or identity null |
| D6 | Search section after query | `hasIndex` true; `indexBuildCount` ≥ 1 |
| D7 | Playback idle state | No error; capabilities shown |
| D8 | Copy to clipboard | Non-empty text; stable headings |
| D9 | Export format | Required sections present; no path leakage |
| D10 | Failed catalogue load | Last-good preserved; diagnostics show error + prior identity |

Manual: reproduce HTTPS/TLS failure; confirm readable provider error in diagnostics without certificate dump.

---

## Test strategy

### Unit tests

- `RuntimeDiagnosticsSnapshot` serialization / `formatExport` stable headings
- Redaction helpers — paths stripped from sample inputs
- `DiagnosticsService.buildSnapshot()` with mocked providers

### Widget tests

- `DiagnosticsScreen` renders all sections with mock snapshot
- Copy action invokes clipboard with expected prefix lines
- Unavailable fields show fallback copy
- Navigation from Settings section

### Integration tests

- Wired app harness: load catalogue → open diagnostics route → counts match `CatalogService`
- After artwork browse: cache count > 0 and ≤ capacity
- After search: search diagnostics reflect index build

### Runtime validation

- `PHASE_46_RUNTIME=1` matrix D1–D10 on Windows
- Skips cleanly when env unset (normal suite +1 skip)

### Failure-path validation

- Catalogue load failure: diagnostics show `lastError` without clearing snapshot build
- Search build failure + retry: `isBuildInFlight` clears; diagnostics remain renderable
- Diagnostics screen build when `catalog == null`: degraded but non-throwing

---

## Definition of done (Phase 4.6 final)

- [x] ADR-017–019 accepted at closure
- [x] `DiagnosticsService` aggregates existing runtime state without circular dependencies
- [x] Production diagnostics getters promoted on `ArtworkService` and `SearchService` (no duplicate counters)
- [x] `DiagnosticsScreen` reachable from Settings → Diagnostics & Advanced
- [x] Read-only grouped sections for application, provider, catalogue, cache, search, playback, library
- [x] Copy-to-clipboard support bundle (plain text per ADR-019)
- [x] No personal filesystem paths or secrets in UI or export
- [x] Dashboard Provider Status unchanged in role (ADR-003 boundary preserved)
- [x] Unit + widget + integration tests pass
- [x] `PHASE_46_RUNTIME=1` harness executed on Windows
- [x] `diagnostics.md` updated to implemented/accepted
- [x] `flutter test` green; `flutter analyze` no new Phase 4.6 errors
- [x] No remote telemetry, crash reporting, or log upload

---

## Step 8 — Closure and definition-of-done (2026-07-17)

### Objective

Reconcile every planned requirement, ADR, and definition-of-done criterion; classify manual/optional follow-ups; mark Phase 4.6 complete. Documentation-only — no new diagnostics features.

### Step reconciliation

| Step | Verdict |
|---|---|
| **0–1** Planning + ADRs | **Satisfied** — scope, exclusions, ADR-017–019 authored before implementation |
| **2** Data layer | **Satisfied with evidence** — `90aad3e`; seven DTOs, redaction, formatter, ADR-017–018 accepted |
| **3** Getter promotion | **Merged into Step 2** — `ArtworkService` / `SearchService` production getters |
| **4** Diagnostics UI | **Satisfied with evidence** — `9de717a`; Settings navigation, seven sections, refresh lifecycle |
| **5** Clipboard export | **Satisfied with evidence** — `eae1a62`; ADR-019 accepted; Option A copy lifecycle |
| **6** Documentation hardening | **Merged into Step 8** — architecture + roadmap closure |
| **7** Windows runtime | **Satisfied with evidence** — `f50fa73`; D1–D10 automated; 10 passed / 1 skipped |
| **8** Closure | **This step** |

### Definition-of-done reconciliation

| Criterion | Verdict | Evidence |
|---|---|---|
| ADR-017–019 accepted and implemented | **Satisfied with evidence** | ADRs + Steps 2, 5, 8 |
| Diagnostics aggregation boundary | **Satisfied with evidence** | `DiagnosticsService` sole owner |
| Immutable snapshot model | **Satisfied with evidence** | `RuntimeDiagnosticsSnapshot` |
| Seven sections | **Satisfied with evidence** | UI + export + runtime D2 |
| Settings navigation | **Satisfied with evidence** | D1, `settings_screen_test.dart` |
| Read-only Diagnostics screen | **Satisfied with evidence** | Step 4 |
| Refresh | **Satisfied with evidence** | Non-mutating; D10 |
| Clipboard copy | **Satisfied with evidence** | Step 5; D8 |
| Redaction contract | **Satisfied with evidence** | `diagnostics_redaction_test.dart`, D9 |
| No path/credential/URL/stack leakage | **Satisfied with evidence** | Redaction + runtime tests |
| Partial failure isolation | **Satisfied with evidence** | D9, section status model |
| Complete failure recoverable | **Satisfied with evidence** | Retry UI + tests |
| Search not built by diagnostics | **Satisfied with evidence** | D6, integration tests |
| Artwork cache not cleared | **Satisfied with evidence** | D5 non-mutation audit |
| Catalogue not reloaded | **Satisfied with evidence** | Integration + runtime audit |
| Playback unchanged | **Satisfied with evidence** | Runtime non-mutation audit |
| Duplicate operations blocked | **Satisfied with evidence** | D8, clipboard tests |
| Windows runtime matrix | **Satisfied with evidence** | D1–D10 pass |
| Normal test suite green | **Satisfied with evidence** | 624 passed, 8 skipped |
| Architecture docs accepted | **Satisfied** | `diagnostics.md` Implemented/Accepted |
| No unresolved blocker | **Satisfied** | See overflow classification below |

### Settings-row overflow (Step 7 observation)

| Investigation | Finding |
|---|---|
| Reproduces in widget test? | Yes — ~6.5 px `RenderFlex` overflow at `settings_screen.dart:553` |
| Affected control | **Pre-existing footer Row** with Save playback / Save network buttons — **not** the View diagnostics `ListTile` |
| Introduced by Phase 4.6? | **No** — Row existed before Step 4 (`9de717a` added only the diagnostics `ListTile` above) |
| Supported Windows app layout? | **Not reproduced** in runtime harness functional pass; overflow tied to constrained test viewport (~768 px content width) |
| User-visible clipping? | Not observed in D1 navigation success; Flutter test reports layout overflow only |

**Classification:** **Existing baseline issue** — document for optional Settings layout follow-up; **not a Phase 4.6 blocker**.

### Manual and optional follow-ups

| Item | Classification |
|---|---|
| Narrow/wide layout, keyboard, scroll, Snackbar, high-DPI | **Manual release follow-up** |
| External Windows clipboard paste | **Manual release follow-up** |
| `PHASE_46_LOCAL_CATALOG` | **Optional validation** — skipped when unset |
| File export | **Deferred by design** (ADR-019) |
| Settings footer button Row overflow in narrow test viewport | **Existing baseline issue** |

### Final evidence

| Suite | Result |
|---|---|
| Normal `flutter test` | **624 passed, 8 skipped, 0 failed** |
| Runtime `PHASE_46_RUNTIME=1` | **10 passed, 1 skipped, 0 failed** (not rerun at closure — docs-only) |
| `flutter analyze` | **89** existing warning/information findings; no new Phase 4.6 errors or warnings |
| `git diff --check` | Clean |

### Commits

| Step | Hash |
|---|---|
| 1 Planning | `83cb3f9` |
| 2 Data layer | `90aad3e` |
| 4 UI | `9de717a` |
| 5 Clipboard | `eae1a62` |
| 7 Runtime | `f50fa73` |
| 8 Closure | *(this commit)* |

**Phase 4.6: COMPLETE.** Next M4 phase: **4.7 Release and Documentation**.

---

## Out of scope

| Item | Reason |
|---|---|
| Sentry / Firebase / automatic upload | Product principles |
| Remote admin console | Out of M4 |
| Log ring buffer in export | Deferred — adds new collection infrastructure |
| Reset diagnostic counters UI | No production counters designed for reset in 4.6 v1 |
| `FolderPresentationMetrics` in UI | Test-only hooks |
| Performance micro-benchmark UI | Remains opt-in test harness |
| TNAS deploy wizard | Link only in export footer optional |
| SQLite / persistent diagnostics store | Session snapshot only |

---

## Dependencies

| Phase | Provides |
|---|---|
| 4.1 | Provider health model, Provider Status panel |
| 4.2 | Settings shell, Diagnostics & Advanced section |
| 4.5 | Cache bounds, search lifecycle, test evidence patterns |

**Enables:** Phase 4.7 release validation and support documentation.

---

## Related documents

- [diagnostics.md](../architecture/diagnostics.md)
- [caching.md](../architecture/caching.md)
- [provider-management.md](../architecture/provider-management.md)
- [settings.md](../architecture/settings.md)
- [m4-phase-4.5-performance-caching.md](./m4-phase-4.5-performance-caching.md)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-16 | Step 1 planning specification; ADR-017–019 proposed |
| 2026-07-16 | Step 2: `DiagnosticsService`, snapshot DTOs, redaction, formatter; ADR-017–018 accepted |
| 2026-07-17 | Step 5: Clipboard export + ADR-019 accepted; 17 new tests |
| 2026-07-17 | Step 8: Phase closed — definition-of-done reconciled |
