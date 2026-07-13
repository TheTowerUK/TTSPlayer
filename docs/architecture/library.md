# Library Experience (M4 Phase 4.3)

**Status:** Specification **Accepted** (2026-07-13) — Steps 1–4 implemented; browse controls (sort/filter/breadcrumbs) pending  
**Related roadmap phase:** [M4 Phase 4.3 — Library Experience](../roadmap/m4-plan.md#phase-43--library-experience)

→ [Phase 4.3 implementation spec](../roadmap/m4-phase-4.3-library-experience.md)  
→ [Settings (4.2 complete)](./settings.md)  
→ [Provider management (4.1 complete)](./provider-management.md)  
→ [Design system](../design/design-system.md)

**ADRs (Accepted 2026-07-13):**

- [ADR-007: Library Metadata and Favourites](./decisions/ADR-007-library-metadata-and-favourites.md)
- [ADR-008: Library Sorting and Filtering](./decisions/ADR-008-library-sorting-and-filtering.md)
- [ADR-009: Library Navigation and Breadcrumbs](./decisions/ADR-009-library-navigation-and-breadcrumbs.md)

---

## Purpose

Polish browsing, discovery, and navigation on the **existing folder-tree catalogue** — without inventing virtual libraries, hardcoded media categories, or filesystem writes.

### Architectural principles (4.3)

- **Immutable catalogue** — loaded `Catalog` is read-only; sort/filter produce derived views; favourites are external metadata ([spec](../roadmap/m4-phase-4.3-library-experience.md#architectural-principles)).
- **Three persistence domains** — `SettingsRepository` (configuration), `LibraryMetadataRepository` (user metadata), `CatalogService` (runtime catalogue).

---

## Current baseline (M3 + M3.5 + M4.1 + M4.2)

### Navigation and screens

| Capability | State |
|---|---|
| Dashboard | `DashboardScreen` — root; `RouteAware` refresh |
| Folder browse | `FolderScreen` — live `folderPath` resolution; subfolders + items grids |
| Library Manager | `LibraryManagerScreen` — catalogue ops (not browsing) |
| Global Search | `SearchScreen` — in-memory index, score-ranked results |
| Item detail | `ItemDetailScreen` — Play via `MediaItemStatus.isPlayable` |
| Navigation | Imperative `Navigator` pushes; `TtsAppBar` back + Home |

### Dashboard sections (catalogue-driven)

| Section | Data source | Notes |
|---|---|---|
| Libraries | `catalog.libraryFolders` | `LibraryCard` grid |
| Continue Watching | `PlaybackService` + catalogue | Max 8; sort by saved position |
| Recently Added | `MediaItem.addedAt` | Max 12; newest first |
| Featured Folders | `catalog.featuredFolders()` | Max 8; by `totalItems` |

### Folder browse today

- **No** breadcrumbs, sort, or filter controls.
- Subfolders and items in **indexer emission order**.
- Empty folder and missing-folder states exist.
- Hardcoded "Subfolders" section label (structural, not a media category).

### Global Search today

- `SearchService` — token match + scoring; max 100 results.
- `SearchFilters` — library name + extension chips.
- Flat result list; "Browse folder" and item open actions.
- Recent queries — session memory only (max 5).

### Artwork

`ArtworkService` — thumbnail → sidecar → folder art → placeholder. Cache cleared on catalogue replace. Consistent across dashboard, folder, search, detail.

### Persistence (relevant to 4.3)

| Data | Store |
|---|---|
| Configuration | `SettingsRepository` (`ttsplayer_settings_v1`) |
| Playback progress | `PlaybackService` (`position_*`, `duration_*`) |
| Catalogue runtime | `CatalogService` (`catalog_path`, etc.) |
| Favourites | **Step 1 implemented** — `LibraryMetadataRepository` (`ttsplayer_library_metadata_v1`) |

### Provider + settings (unchanged by 4.3)

Phase 4.1 Provider Status and Phase 4.2 grouped settings remain separate from library browse polish.

---

## M4.3 target architecture (from spec + ADRs)

| Component | Role |
|---|---|
| `Catalog.findFolderById` / `findItemById` | Stable id resolution for favourites and navigation |
| `Catalog.ancestorChainForFolder` | Catalogue-driven breadcrumbs (root-to-target inclusive) |
| `Catalog.parentFolderOfItemId` | Containing-folder lookup without path parsing |
| `SettingsRepository.general.libraryBrowse` | Global default sort only (ADR-008) — **Step 3 implemented** |
| `buildLibraryFolderView` | Pure folder-first sort/filter derived views (ADR-008) — **Step 3 implemented** |
| Dashboard Favourites section | First 10 resolved + View all — **Step 4 implemented** |
| `FavouritesScreen` | Full favourites list — **Step 4 implemented** |
| `LibraryMetadataRepository` | Favourites persistence — **Step 1 implemented** (ADR-007) |
| `FolderScreen` | Breadcrumbs + sort/filter controls |
| Dashboard Favourites section | Resolved favourites — app state, not a folder |
| `SearchScreen` | Presentation polish — grouping, clear, keyboard |

---

## Sort and filter (proposed)

See [ADR-008](./decisions/ADR-008-library-sorting-and-filtering.md).

- **Sort:** default (indexer), name asc/desc, added newest/oldest, type — folder-first layout preserved.
- **Filter:** all, folders only, video, images — session-scoped, current folder only.
- **No** modified-date sort — field not in catalogue.
- **No** audio/book filters — not indexed.

---

## Favourites (proposed)

See [ADR-007](./decisions/ADR-007-library-metadata-and-favourites.md).

- Stored at `ttsplayer_library_metadata_v1` — **not** in settings envelope or `catalog.json`.
- Identity: catalogue `id` for items and folders.
- Prune absent ids on **catalogue replacement** only (not on `initialize()` / `load()`); notify listeners once.
- Dashboard section: first 10 + View all; toggles on item/folder surfaces.

---

## Navigation (proposed)

See [ADR-009](./decisions/ADR-009-library-navigation-and-breadcrumbs.md).

- Breadcrumbs from **catalogue hierarchy** — `MediaFolder.name` labels.
- Consistent back/home from dashboard, search, favourites, and deep folders.
- No persisted route stack in 4.3.

---

## Deferred to later phases

| Item | Phase |
|---|---|
| Search index performance / pagination | 4.5 |
| Artwork cache strategy (full) | 4.5 |
| Diagnostics detail, log export | 4.6 |
| Playback prefs UI | 4.4 |
| Ratings, tags, hidden state UI | Post–4.3 |
| Persisted search history, per-folder sort memory | Post–4.3 (open decision) |

---

## Failure handling

- Empty folder / empty filter / no search results — distinct copy and recovery actions.
- Missing artwork — placeholder (never hide item).
- Missing favourite after rescan — silent prune.
- Catalogue/provider errors — direct to Provider Status (4.1), not 4.6 diagnostics.

---

## Testing considerations

- Validation L1–L18 in [Phase 4.3 spec](../roadmap/m4-phase-4.3-library-experience.md#validation-scenarios)
- Regression: folder names from data only; no hardcoded category section headers beyond structural "Subfolders"
- Opt-in Windows runtime harness at closure

---

## Out of scope

- Virtual libraries aggregating across folders
- Filesystem modification
- TMDB metadata
- Image-library viewer ([superseded draft](../roadmap/m4-rich-media-libraries.md))

---

## Related documents

- [M4 Phase 4.3 implementation spec](../roadmap/m4-phase-4.3-library-experience.md)
- [settings.md](./settings.md)
- [M3 library experience](../roadmap/m3-library-experience.md)
