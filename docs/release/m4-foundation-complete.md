# M4 — Foundation Complete (Development Snapshot)

**Status:** **Development snapshot** — Phases 4.1–4.3 complete (2026-07-13)  
**Date:** July 2026  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Closure commits:** `2f4482f` (4.1) · `dc303eb` (4.2) · `2f91484` (4.3)  
**Predecessor:** M3.5 complete — tag `m3.5-complete` (2026-07-07)

> **This is not a release, milestone tag, or shipping checkpoint.** It archives the M4 work completed *before playback improvements* — provider visibility, settings, and library experience — in the same spirit as [M3.5 media access snapshot](./m3.5-media-access-complete.md).

→ [M4 plan](../roadmap/m4-plan.md)  
→ [v0.5.0-dev tracker](./v0.5.0-dev.md)  
→ [Release index](./README.md)  
→ [Architecture index](../architecture/README.md)

---

## Summary

M4 Phases **4.1–4.3** establish the **application foundation** on top of the M3.5 provider-neutral media access platform:

- **Operational visibility** — what catalogue provider is active, whether load was degraded, and how to refresh without losing last-good data.
- **Versioned configuration** — grouped settings with safe migration from legacy provider prefs.
- **Library experience** — favourites, catalogue-driven navigation, sort/filter derived views, and search presentation polish — all without mutating the filesystem or `catalog.json`.

Everything in this snapshot is **required before touching playback** (Phase 4.4). Playback resume, speed, subtitles, and track selection remain on the existing `PlaybackService` / `video_player` path unchanged.

---

## Architecture evolution

```
M3
│
├── Dashboard
├── Library Manager
├── Search
├── Playback
│
▼
M3.5
│
├── Provider abstraction
├── HTTPS catalogue
├── Media resolver
│
▼
M4 Foundation          ← this snapshot (Phases 4.1–4.3)
│
├── Provider lifecycle
├── SettingsRepository
├── LibraryMetadataRepository
├── Breadcrumbs
├── Favourites
├── Sort & Filter
└── Search polish
│
▼
M4.4+
│
├── Playback improvements
├── Performance
├── Diagnostics
└── Release
```

---

## Phases complete

| Phase | Focus | Closed | Spec | Architecture |
|---|---|---|---|---|
| **4.1** | Provider Management | 2026-07-12 | [spec](../roadmap/m4-phase-4.1-provider-management.md) | [provider-management.md](../architecture/provider-management.md) |
| **4.2** | Settings Framework | 2026-07-12 | [spec](../roadmap/m4-phase-4.2-settings-framework.md) | [settings.md](../architecture/settings.md) |
| **4.3** | Library Experience | 2026-07-13 | [spec](../roadmap/m4-phase-4.3-library-experience.md) | [library.md](../architecture/library.md) |

**Not started:** Phases 4.4–4.7 (see [Remaining roadmap](#remaining-roadmap-44–47)).

---

## Major architectural decisions

Nine ADRs accepted during foundation work. Full index: [decisions/README.md](../architecture/decisions/README.md).

| ADR | Title | Phase | Decision in brief |
|---|---|---|---|
| [ADR-001](../architecture/decisions/ADR-001-provider-health-model.md) | Provider Health Model | 4.1 | Per-provider health states and attempt snapshots on catalogue load |
| [ADR-002](../architecture/decisions/ADR-002-provider-refresh-lifecycle.md) | Provider Refresh Lifecycle | 4.1 | Refresh preserves last-good catalogue; failed refresh does not clear cache |
| [ADR-003](../architecture/decisions/ADR-003-provider-status-presentation.md) | Provider Status Presentation | 4.1 | Operational status on dashboard — separate from settings configuration |
| [ADR-004](../architecture/decisions/ADR-004-settings-storage-and-versioning.md) | Settings Storage and Versioning | 4.2 | `ttsplayer_settings_v1` envelope with migration from `media_provider_config_v1` |
| [ADR-005](../architecture/decisions/ADR-005-settings-information-architecture.md) | Settings Information Architecture | 4.2 | Grouped `SettingsScreen`; Library & Providers, Network, Diagnostics |
| [ADR-006](../architecture/decisions/ADR-006-settings-validation-and-apply-behaviour.md) | Settings Validation and Apply | 4.2 | Validate-then-save; unsaved-change guards; settings save does not auto-refresh catalogue |
| [ADR-007](../architecture/decisions/ADR-007-library-metadata-and-favourites.md) | Library Metadata and Favourites | 4.3 | `ttsplayer_library_metadata_v1`; prune on catalogue **replacement** only |
| [ADR-008](../architecture/decisions/ADR-008-library-sorting-and-filtering.md) | Library Sorting and Filtering | 4.3 | Immutable catalogue; derived views; global default sort; session-only filters |
| [ADR-009](../architecture/decisions/ADR-009-library-navigation-and-breadcrumbs.md) | Library Navigation and Breadcrumbs | 4.3 | Catalogue ancestor chain; `FolderScreen.fromFolder`; route identity by folder id |

### Cross-cutting principles (4.1–4.3)

```
catalog.json  →  read-only snapshot in memory (Phase 4.3)
        │
        ├── Provider chain + snapshot  →  CatalogService (4.1)
        ├── Configuration            →  SettingsRepository (4.2)
        ├── User metadata            →  LibraryMetadataRepository (4.3)
        ├── Sort / filter views      →  buildLibraryFolderView (4.3)
        └── Playback progress        →  PlaybackService (unchanged — 4.4 next)
```

- **Filesystem is truth** — no virtual libraries, hardcoded categories, or catalogue writes from the client.
- **Configuration ≠ status** — Provider Status (4.1) and Settings (4.2) stay separate surfaces.
- **Graceful degradation** — last-good catalogue, distinct empty/error states, Provider Status for operational failures.

---

## New persistence repositories

| Repository | Storage key | Owner phase | Responsibility |
|---|---|---|---|
| [`SettingsRepository`](../../client/ttsplayer/lib/services/settings/settings_repository.dart) | `ttsplayer_settings_v1` | 4.2 | Provider config slice, network timeout, reset groups; migration from legacy prefs |
| [`LibraryMetadataRepository`](../../client/ttsplayer/lib/services/library/library_metadata_repository.dart) | `ttsplayer_library_metadata_v1` | 4.3 | Favourites (item + folder ids); `validateAgainstCatalog` on catalogue replacement |

**Unchanged persistence domains** (explicitly not folded into settings):

| Data | Store | Notes |
|---|---|---|
| Playback progress | `PlaybackService` (`position_*`, `duration_*`) | Continue Watching — 4.4 may add UI only |
| Runtime catalogue path | `CatalogService` (`catalog_path`, `catalog_source`) | Operational state, not user settings |
| Legacy provider config | `media_provider_config_v1` | Dual-read during migration; settings envelope is canonical |

---

## Runtime services and integration points

No new long-lived `*Service` types were introduced in 4.1–4.3. Foundation work **extends existing runtime services** and adds pure domain helpers:

| Component | Phase | Role |
|---|---|---|
| **`CatalogService`** | 4.1, 4.2 | `CatalogueProviderSnapshot`; refresh lifecycle; HTTP timeout from `SettingsRepository`; `onCatalogReplaced` callback |
| **`MediaProviderConfigService`** | 4.2 | Reads/writes provider slice via settings envelope (dual-write transition) |
| **`ArtworkService`** | 4.1 | Cache cleared on successful catalogue replacement via `onCatalogReplaced` |
| **`PlaybackService`** | — | **Unchanged** in foundation phases |
| **`SearchService`** | 4.3 | **Engine unchanged** — index, scoring, filters; presentation-only polish |
| **`DashboardService`** | — | **Unchanged** — Continue Watching / Recently Added regression-verified in 4.3 |

### New domain and navigation modules (4.3)

| Module | Path | Purpose |
|---|---|---|
| `buildLibraryFolderView` | `lib/library/library_folder_view.dart` | Pure sort/filter derived views over immutable `MediaFolder` |
| `folder_navigation.dart` | `lib/navigation/` | `openFolderScreen`, breadcrumb ancestor navigation |
| `catalogueFolderContext` | `lib/library/folder_display_context.dart` | Hierarchy labels for search (no raw paths) |
| `groupSearchResultsByLibrary` | `lib/features/search/search_result_grouper.dart` | Lightweight library grouping for search UI |

### Catalogue model helpers (4.3)

`Catalog.findFolderById`, `ancestorChainForFolder`, `parentFolderOfItemId` — read-only hierarchy resolution without path parsing.

---

## Delivered by phase

### Phase 4.1 — Provider Management

- Dashboard **Provider Status** panel (replaces legacy Storage Status vocabulary)
- Per-provider health badges and refresh/retry actions
- `CatalogService` instrumentation without changing M3.5 selection order or fallback semantics
- Opt-in Windows runtime harness: **V1–V10** (`PHASE_41_RUNTIME=1`)

### Phase 4.2 — Settings Framework

- Versioned **`SettingsRepository`** with legacy migration
- Grouped **`SettingsScreen`** (Library & Providers, Network, Diagnostics)
- Configurable catalogue fetch timeout (5–120 s, default 15)
- Reset provider / reset all (playback keys preserved)
- Opt-in Windows runtime harness: **S1–S13** (`PHASE_42_RUNTIME=1`)

### Phase 4.3 — Library Experience

- **`LibraryMetadataRepository`** and favourites UX (dashboard section, full view, toggles)
- Catalogue-driven **breadcrumbs** and aligned folder entry points
- **FolderScreen** sort menu (six modes) and session filter chips
- **Search** presentation: library grouping, context labels, clear query, empty states
- Unified **empty/error copy** across browse surfaces
- Opt-in Windows runtime harness: **L1–L25** (`PHASE_43_RUNTIME=1`)

---

## Validation summary

**Shared validation host (2026-07-12 / 2026-07-13)**

| Field | Value |
|---|---|
| OS | Windows 10.0.26200 |
| Flutter | 3.44.4 stable |
| App version | `0.4.0-dev.1+1` |
| Local catalogue | `Y:\Media\catalog.json` — 81 326 items |
| HTTPS catalogue | `https://ttsplayer.local:8443/catalog.json` — HTTP 200, trusted TLS |
| Provider mode | `localPreferred` (defaults) |

### Phase 4.1 — V1–V10

| Result | Scenarios |
|---|---|
| **Pass** (10/10) | Local first, HTTPS fallback, failed refresh retention, demo fallback, `httpRequired`, loading guard, artwork cache on replace, legacy pref, indexer integration, TLS failure readability |

→ [Full table](../roadmap/m4-phase-4.1-provider-management.md#windows-runtime-validation-2026-07-12)

### Phase 4.2 — S1–S13

| Result | Scenarios |
|---|---|
| **Pass** (13/13) | Fresh install, legacy migration, settings UI, timeout persist, validation reject, reset provider, reset all, restart persistence, unsaved dialog, provider status regression, no auto-refresh on save, timeout on refresh, corrupt envelope recovery |

→ [Full table](../roadmap/m4-phase-4.2-settings-framework.md#windows-runtime-validation-2026-07-12)

### Phase 4.3 — L1–L25

| Result | Scenarios |
|---|---|
| **Pass** (25/25) | Breadcrumbs, back/home, search navigation, sort/filter, favourites persist/prune, dashboard regression, local+HTTPS consistency, search states, layout at 900×420 |

→ [Full table](../roadmap/m4-phase-4.3-library-experience.md#windows-runtime-validation-2026-07-13)

### Automated regression (foundation closure)

| Check | Result |
|---|---|
| `flutter test` | **360 passed**, **3 skipped** (4.1 / 4.2 / 4.3 runtime harnesses opt-in) |
| `flutter analyze` | No new foundation-phase errors (pre-existing info/warnings only) |

### Runtime harness commands

```powershell
cd client\ttsplayer
$env:PHASE_41_RUNTIME = '1'
flutter test test/phase_41_windows_runtime_test.dart --tags phase41-runtime

$env:PHASE_42_RUNTIME = '1'
flutter test test/phase_42_windows_runtime_test.dart --tags phase42-runtime

$env:PHASE_43_RUNTIME = '1'
flutter test test/phase_43_windows_runtime_test.dart --tags phase43-runtime
```

---

## Lessons learned

Synthesized from phase retrospectives in [v0.5.0-dev.md](./v0.5.0-dev.md).

### What went well

- **Spec-first + ADR acceptance before code** kept each sub-phase bounded and reviewable.
- **Repository-first persistence** (settings, then library metadata) reduced UI integration risk.
- **Incremental instrumentation** of `CatalogService` (4.1) avoided rewriting the M3.5 provider chain.
- **Immutable catalogue discipline** (4.3) — sort, filter, favourites, and search presentation never mutate `Catalog` in memory.
- **Opt-in Windows runtime harnesses** (`PHASE_41_RUNTIME`, `PHASE_42_RUNTIME`, `PHASE_43_RUNTIME`) became the standard closure gate and are worth reusing in 4.4+.
- **Catalogue hierarchy helpers** unified breadcrumbs, search context, and favourites resolution without path parsing.

### Lessons to carry forward

- Draw a hard line between **operational status** (dashboard) and **configuration** (settings) early — prevents duplicated diagnostics UI.
- **Settings save must not auto-refresh catalogue** — users expect explicit refresh; document in ADR-006.
- **Favourites prune only on catalogue replacement** — not on navigation or mere reload.
- **Search engine vs presentation** — scoring and index stayed stable; UI polish shipped without 4.5 performance work.
- **Widget-test keyboard shortcuts** need explicit focus — validate primary actions in harness; confirm Escape manually on Windows where needed.
- **Filter-empty contract** — `LibraryFolderView.isEmpty` requires both subfolders and items empty after filter; leaf folders are the right harness fixture.

---

## Remaining roadmap (4.4–4.7)

Foundation complete. Next work begins at **Phase 4.4 — Playback Improvements**.

| Phase | Focus | Depends on | Status |
|---|---|---|---|
| **4.4** | Playback Improvements | 4.2 ✅ | Planned — resume UX, speed, subtitles, audio tracks |
| **4.5** | Performance and Caching | 4.1–4.3 | Planned — search index, artwork cache strategy, pagination |
| **4.6** | Diagnostics and Supportability | 4.1, 4.2, 4.5 | Planned — detail panels, log export (not duplicating Provider Status) |
| **4.7** | Release and Documentation | 4.1–4.6 | Planned — milestone closure, `m4-complete` / `v0.5.0` |

→ [M4 master plan](../roadmap/m4-plan.md)

### Explicitly deferred past foundation

| Item | Target phase |
|---|---|
| Playback speed / subtitles / audio track UI | 4.4 |
| Search pagination and index performance | 4.5 |
| Full diagnostics export | 4.6 |
| Persisted search history, per-folder sort memory | Post–4.3 (open) |
| Scroll restoration for folder grids | Post–4.3 (optional) |
| Theme mode toggle | Post–4.2 (optional) |
| Virtual libraries / TMDB / filesystem writes | Out of scope |

---

## Implementation checkpoint (4.1–4.3)

| Phase | Key implementation commits |
|---|---|
| **4.1** | `abfe5e5`–`2f4482f` |
| **4.2** | `7ae607c`–`896a8e7`; closure `dc303eb` |
| **4.3** | `3815946` (metadata) → `db1be9a` (search polish); harness `8775d2e`; closure `2f91484` |

---

## What this snapshot is not

| | |
|---|---|
| **Not a git tag** | No `m4-foundation-complete` tag implied — archive document only |
| **Not `m4-complete`** | Phases 4.4–4.7 remain; playback not yet improved |
| **Not a semver release** | Application version remains `v0.5.0-dev` until 4.7 |
| **Not playback-ready** | Resume/speed/subtitles are Phase 4.4 scope |

When M4 ships, this document remains the historical record of **foundation work** — the boundary between *platform + library UX* and *playback polish*.

---

## Related documents

| Document | Purpose |
|---|---|
| [v0.5.0-dev.md](./v0.5.0-dev.md) | Active development tracker and per-phase retrospectives |
| [m3.5-media-access-complete.md](./m3.5-media-access-complete.md) | Prior milestone snapshot (media access platform) |
| [provider-management.md](../architecture/provider-management.md) | 4.1 implemented architecture |
| [settings.md](../architecture/settings.md) | 4.2 implemented architecture |
| [library.md](../architecture/library.md) | 4.3 implemented architecture |
| [playback.md](../architecture/playback.md) | 4.4 planning (next) |
