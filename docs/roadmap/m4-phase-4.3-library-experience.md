# M4 Phase 4.3 — Library Experience (Implementation Specification)

**Status:** Specification — **Accepted** (2026-07-13) · Steps 1–3 **implemented** · Phase **not complete**  
**Milestone:** M4 — User Experience and Platform Integration  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Predecessor:** M4 Phase 4.2 complete — closure `dc303eb`

→ [M4 plan](./m4-plan.md#phase-43--library-experience)  
→ [Library architecture](../architecture/library.md)  
→ [Settings (4.2 complete)](../architecture/settings.md)  
→ [Provider management (4.1 complete)](../architecture/provider-management.md)  
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs (Accepted 2026-07-13):**

- [ADR-007: Library Metadata and Favourites](../architecture/decisions/ADR-007-library-metadata-and-favourites.md)
- [ADR-008: Library Sorting and Filtering](../architecture/decisions/ADR-008-library-sorting-and-filtering.md)
- [ADR-009: Library Navigation and Breadcrumbs](../architecture/decisions/ADR-009-library-navigation-and-breadcrumbs.md)

Follow the established M4 cadence: baseline inventory → ADR acceptance → persistence layer → tests → UI consumers → Windows validation → closure.

**Implementation has not started.** First code step mirrors Phase 4.2: `LibraryMetadataRepository` only — no UI.

---

## Objective

Improve **day-to-day library browsing, discovery, navigation, and user-managed metadata** on top of the existing folder-tree catalogue — without changing the filesystem layout, `catalog.json` schema (unless a minimal client-side read helper is required), or provider/settings behaviour from Phases 4.1–4.2.

---

## Architectural principles

### Immutable catalogue (read-only in 4.3)

Phase 4.3 must treat the **loaded catalogue as immutable**. The client reads `catalog.json` (via `CatalogService`); nothing in 4.3 mutates the in-memory `Catalog` / `MediaFolder` / `MediaItem` model or writes back to the catalogue file.

```
catalog.json  →  read-only snapshot in memory
        │
        ├── Sorting   →  produces a sorted *view* (derived list)
        ├── Filtering →  produces a filtered *view* (derived list)
        └── Favourites →  external metadata (LibraryMetadataRepository)
```

- Sort and filter operate on **copies or derived iterables** — never reorder catalogue source lists in place.
- Favourites store **ids only** — resolution against the current catalogue on read.
- Indexer and scanner output remain the sole writers of `catalog.json`.

This reinforces filesystem-is-truth: the app reflects the catalogue; it does not edit it.

### Three persistence domains (M4)

```
SettingsRepository          →  application configuration
LibraryMetadataRepository   →  user metadata (favourites, future ratings/tags)
CatalogService              →  runtime catalogue (load, replace, last-good path)
```

Playback progress (`PlaybackService`) remains a fourth, separate concern — not settings, not library metadata.

Each layer has a single responsibility. Phase 4.3 adds `LibraryMetadataRepository` only; it does not extend `SettingsRepository` with favourites or catalogue content.

### Sort vs filter (independent operations)

| Operation | Meaning | Persistence (4.3) |
|---|---|---|
| **Sort** | Presentation order of the visible set | Global **default** in `SettingsRepository`; in-session override ephemeral |
| **Filter** | Which subset is visible | **Session only** — never persisted |

Sort answers *in what order*; filter answers *which items appear*. They compose (filter then sort within groups) but neither writes the other’s state.

---

## Capability layers (what is what)

| Layer | Owner | Phase | Notes |
|---|---|---|---|
| Folder-tree catalogue | Python indexer + `CatalogService` | M2 / M3.5 | Filesystem is truth |
| Provider visibility + refresh | `CatalogService` + dashboard Provider Status | **4.1 ✅** | Operational, not settings |
| Versioned configuration | `SettingsRepository` | **4.2 ✅** | Providers, network timeout |
| Dashboard discovery sections | `DashboardService` + M3 widgets | M3 | Libraries, CW, Recently Added, Featured |
| Global Search (in-memory index) | `SearchService` | M3 | Score-ranked flat list |
| Artwork resolution | `ArtworkService` | M3 / hotfix | Cache cleared on catalogue replace |
| **Folder sort/filter** | — | **4.3 new** | Derived views over immutable catalogue |
| **Breadcrumbs** | — | **4.3 new** | Catalogue ancestor chain |
| **Favourites** | — | **4.3 new** | `LibraryMetadataRepository` |
| **Search presentation polish** | — | **4.3 new** | Grouping, actions — not engine rewrite |
| **Unified empty/error polish** | — | **4.3 new** | Browse surfaces |
| Pagination / index performance | — | **4.5 deferred** | |
| Diagnostics export / deep detail | — | **4.6 deferred** | Link to Provider Status |

---

## Current baseline

### Already shipped — do not rebuild or mislabel as new work

#### Navigation and screens

| Surface | Location | Behaviour today |
|---|---|---|
| **Dashboard** | `features/dashboard/dashboard_screen.dart` | Root screen; `RouteAware` refreshes on `didPopNext`; `Ctrl+F` → Search; `Escape` → pop |
| **Folder browse** | `screens/folder_screen.dart` | Resolves `folderPath` from live catalogue; subfolder grid + item grid; per-folder rescan menu |
| **Item detail** | `screens/item_detail_screen.dart` | Metadata + Play (`isPlayable` gate) |
| **Global Search** | `features/search/search_screen.dart` | Debounced query; library + extension filter chips |
| **Library Manager** | `features/library_manager/library_manager_screen.dart` | Catalogue ops — refresh, validate, diagnostics — **not** content browsing |
| **Navigation helpers** | `navigation/app_navigator.dart`, `search_navigation.dart`, `settings_navigation.dart` | Imperative `MaterialPageRoute` pushes; `TtsAppBar` back + Home |

There is **no** GoRouter, named routes, breadcrumbs, favourites, folder sort/filter, persisted scroll positions, or persisted navigation stack.

#### Dashboard sections (M3 + M3.5)

| Section | Widget | Data | Limits |
|---|---|---|---|
| **Libraries** | `libraries_section.dart` | `catalog.libraryFolders` | Grid of `LibraryCard`; empty → `EmptyState` |
| **Continue Watching** | `continue_watching_section.dart` | `PlaybackService.getContinueWatching(catalog)` | Max 8; sort by saved **position** desc; → `PlayerScreen` |
| **Recently Added** | `recently_added_section.dart` | Items with `addedAt != null` | Max 12; `addedAt` desc; → `ItemDetailScreen` |
| **Featured Folders** | `featured_folders_section.dart` | `catalog.featuredFolders()` | Max 8; `totalItems` desc, then name; → `FolderScreen` |

Also on dashboard (out of 4.3 scope unless empty-state copy alignment): Overview panel, Quick Search bar, Recent Activity (`ScanHistoryService`), Provider Status (4.1), error banners.

`DashboardService.build()` assembles `DashboardSnapshot`; reload on startup, `didPopNext`, playback resume changes, catalogue replace.

#### Folder browsing

- **Sort:** none — indexer emission order within each section.
- **Filter:** none.
- **Layout:** hardcoded "Subfolders" section label + item grid (`TtsFolderCard`, `TtsMediaCard`).
- **Empty folder:** `EmptyState` — "This folder is empty." + rescan hint.
- **Missing folder after rescan:** `_FolderMissingBody` + "Back to Dashboard".
- **Loading:** `LoadingCard` while `CatalogService.isLoading`.
- **Back:** AppBar back + Home (`popUntil isFirst`).

#### Global Search

| Piece | Location |
|---|---|
| Index | `SearchService` — rebuilt when `catalogueIdentity` changes |
| Algorithm | Token match on `searchBlob`; score: exact title → prefix → contains → path/library hits |
| Result order | Score desc, title asc; max 100 |
| Filters | `SearchFilters` — optional `libraryName`, `extension` (mutually combinable) |
| Recent queries | In-memory only, max 5, **session not persisted** |
| Navigation | Row tap → `ItemDetailScreen`; "Browse folder" → `FolderScreen` |
| Empty states | `search_empty_state.dart` — beforeTyping / noResults / catalogueUnavailable / catalogueEmpty |

#### Artwork

`ArtworkService` — catalogue thumbnail → sidecar → folder art → placeholder. Used by library cards, folder cards, media cards, search rows, item detail. Cache cleared via `CatalogService.onCatalogReplaced` (2026-07-12). **No** artwork-driven sort or Featured ranking changes in 4.3.

#### Catalogue models (sort/filter relevant fields)

**`MediaItem`:** `id`, `title`, `year`, `durationSeconds`, `filePath`, `thumbnailPath`, `sizeBytes`, `status`, `addedAt`, `extension` (getter).

**`MediaFolder`:** `id`, `name`, `path`, `itemCount`, `items`, `subfolders`, `totalItems`, `isEmpty`.

**`Catalog` helpers:** `libraryFolders`, `allItems`, `findItemById`, `findFolderById`, `findFolderByPath`, `parentFolderOf`, `parentFolderOfItemId`, `ancestorChainForFolder`, `featuredFolders`, `catalogueIdentity`, `supportedExtensions`.

**Not in catalogue:** `modified_at`, favourites, user sort prefs, last-played timestamp (Continue Watching uses position keys only).

#### Indexer extension sets (ground truth for type filter)

From `backend/indexer.py` / `constants/supported_extensions.dart`:

- **Video:** `avi`, `m4v`, `mkv`, `mov`, `mp4`
- **Images:** `bmp`, `gif`, `jpeg`, `jpg`, `png`, `tif`, `tiff`, `webp`

No audio or document extensions indexed today.

#### Persistence today

| Key / store | Owner | Category |
|---|---|---|
| `ttsplayer_settings_v1` | `SettingsRepository` | Configuration |
| `media_provider_config_v1` | Legacy dual-read | Configuration |
| `catalog_path`, `catalog_source` | `CatalogService` | Runtime catalogue |
| `scan_warnings_dismissed_catalogue_id` | `CatalogService` | UI dismissal |
| `position_*`, `duration_*` | `PlaybackService` | Playback progress |

**No** favourites, folder sort/filter prefs (except proposed default sort in settings), scroll position, route stack, or persisted search history.

#### Library Manager vs folder browse

| | Library Manager | Folder browse |
|---|---|---|
| Purpose | Catalogue operations | Content discovery |
| Artwork | None | Full card artwork |
| User actions | Refresh, validate, full scan | Open items, drill down, per-folder rescan |

---

## Identified UX gaps (4.3 targets)

1. No breadcrumb or ancestor context in deep folders.
2. No folder-level sort or filter controls.
3. No favourites or user-curated lists.
4. Search results are flat — library/folder context is per-row subtitle only.
5. Empty states vary by surface — not all offer a clear next action.
6. Filtered-empty vs folder-empty not distinguished.
7. Long folder paths rely on app bar title ellipsis only.
8. Keyboard navigation outside dashboard is limited.
9. ~~No `findFolderById` helper for favourite resolution (path lookup exists).~~ **Resolved Step 2** — `findFolderById`, `ancestorChainForFolder`.

---

## Proposed navigation model

See [ADR-009](../architecture/decisions/ADR-009-library-navigation-and-breadcrumbs.md).

### Breadcrumbs

- **Source:** catalogue hierarchy via `Catalog.ancestorChainForFolder(folderId)` (resolve `folderPath` → `MediaFolder.id` when needed).
- **Display:** horizontal scrollable segment row below app bar (or integrated in `TtsAppBar` lower row).
- **Labels:** `MediaFolder.name` only — never invented category names.
- **Tap:** navigate to ancestor folder.
- **Current segment:** non-clickable or styled as active.

### Entry-point consistency

| Source | Lands on | Breadcrumb |
|---|---|---|
| Dashboard Libraries | `FolderScreen(library root)` | Single segment |
| Featured Folders | `FolderScreen(featured path)` | Full ancestry |
| Search "Browse folder" | `FolderScreen(parent path)` | Full ancestry |
| Favourites folder entry | `FolderScreen(folder.path)` | Full ancestry |
| Item detail back | Previous route | Unchanged |

### Back behaviour

- System back / AppBar back: one pop.
- Home: dashboard (existing).
- Breadcrumb ancestor: pop/push per ADR-009 — no duplicate stack entries.

### Scroll restoration

Optional `PageStorageKey(folderPath)` for folder grid — **nice-to-have**; not required for DoD if navigator lifecycle blocks it.

---

## Sorting model

See [ADR-008](../architecture/decisions/ADR-008-library-sorting-and-filtering.md).

| Mode | Key | Primary key |
|---|---|---|
| Default | `default` | Indexer order (**global default**) |
| Name A→Z | `nameAsc` | `name` / `title` ci-asc |
| Name Z→A | `nameDesc` | `name` / `title` ci-desc |
| Recently added | `addedNewest` | `addedAt` desc (items); nulls last |
| Oldest added | `addedOldest` | `addedAt` asc (items); nulls last |
| Type | `type` | Extension category → title |

**Folder-first:** subfolders section always above items section.

**Derived views:** sort produces a new ordered iterable; it does not mutate `MediaFolder.items` or `subfolders` on the catalogue model.

**Persistence:** global default in `SettingsRepository.general.libraryBrowse.defaultSortMode`; in-session override resets on next cold open.

**Controls:** compact dropdown or segmented control in `FolderScreen` header — not in dashboard sections.

**Explicitly excluded:** modified-date sort; cross-folder recursive sort.

---

## Filtering model

See [ADR-008](../architecture/decisions/ADR-008-library-sorting-and-filtering.md).

| Filter | Key | Effect |
|---|---|---|
| All | `all` | Default |
| Folders only | `foldersOnly` | Hide item grid |
| Video | `video` | Items with video extensions only |
| Images | `images` | Items with image extensions only |

- Single active filter; **session-only** (not persisted).
- Scoped to **current folder** non-recursively.
- Subfolders remain visible for Video/Images filters (navigate down to find matches).
- Filter produces a **derived visible subset**; then sort applies within each group.
- **Independent of sort** — changing filter does not alter persisted default sort (ADR-008).

---

## Favourites model

See [ADR-007](../architecture/decisions/ADR-007-library-metadata-and-favourites.md).

### Principles

- Application-owned metadata — **not** filesystem, **not** `catalog.json`, **not** `SettingsRepository`.
- Favourite records store catalogue `id` + `favouritedAt` timestamp.
- Resolution through live `Catalog` on read — never cache `MediaItem` snapshots in prefs.

### UI surfaces

| Surface | Behaviour |
|---|---|
| **Dashboard section** | "Favourites" when ≥1 resolved entry; show **first 10** (`favouritedAt` desc); **View all** → dedicated favourites view with full list |
| **Item detail** | Toggle favourite icon in app bar |
| **Folder screen** | Toggle favourite on folder (app bar or overflow) |
| **Empty** | Section omitted or compact `EmptyState` with hint to star items/folders |

**Not** a virtual library root in the Libraries grid.

### Stale / missing handling

Pruning is **deterministic** and tied to **catalogue replacement** — not folder navigation, search, or dashboard pop events.

```
Catalogue replacement completes (CatalogService)
        ↓
LibraryMetadataRepository.validateAgainstCatalog(catalog)
        ↓
Favourite ids absent from current tree removed from storage
        ↓
Repository notifies listeners once
```

- **Trigger:** successful catalogue replace (same lifecycle as search index rebuild and artwork cache clear).
- **UI:** pruned entries disappear on next read — no blocking dialog.
- **Mid-session:** favourites are not pruned while browsing until the next replacement event.
- **Renamed/moved paths:** new catalogue `id` → old favourite pruned at next replacement (acceptable 4.3 limitation).

### Identity helpers (implementation)

`Catalog.findFolderById(String id)` mirrors `findItemById`. `ancestorChainForFolder(String folderId)` returns root-to-target inclusive chain. `parentFolderOfItemId` resolves containing folder without parsing `file_path`. Duplicate ids: first DFS preorder match wins. Lookup complexity O(F + I) per call; indexing deferred to Phase 4.5.

---

## Search refinement

**Engine unchanged** — `SearchService` scoring, tokenization, and index build stay as-is. Performance work deferred to 4.5.

### 4.3 presentation improvements

| Improvement | Description |
|---|---|
| **Library grouping** | Visual section headers by `libraryName` in results list (client-side group of ranked hits) |
| **Folder context** | Keep subtitle; ensure `parentFolderName` / library visible on all rows |
| **Artwork consistency** | Same `ArtworkImage` / thumb sizing as folder cards (already mostly true) |
| **Playable shortcut** | Optional inline play action on row when `isPlayable` — opens `PlayerScreen` or detail per existing gates |
| **Clear query** | Visible clear button in search field |
| **Empty state** | Distinguish no query / no results / filters too narrow |
| **Keyboard** | Enter submits; Escape pops; filter chips focusable |
| **Navigate to folder** | Retain "Browse folder"; ensure breadcrumb works from search entry |

**Excluded:** fuzzy index rebuild, pagination, query highlighting, persisted recent queries (defer), cross-catalogue federated search.

---

## Empty, loading, and error states

| State | Surface | Message direction | Recovery action |
|---|---|---|---|
| Empty library | Dashboard Libraries | No libraries in catalogue | Link to Settings / Provider Status refresh |
| Empty folder | FolderScreen | No subfolders or items | Rescan hint (existing) |
| No search results | SearchScreen | No matches for query | Clear filters / broaden query |
| No filter matches | FolderScreen | Folder has content but filter hides all | Clear filter chip |
| No favourites | Dashboard | No starred items yet | Hint to favourite from browse |
| Catalogue loading | Folder / Dashboard | Refreshing library | Wait (spinner) |
| Catalogue unavailable | Dashboard / Search | Provider failed | Provider Status refresh — **not** duplicated diagnostics |
| Folder missing | FolderScreen | No longer in catalogue | Back to dashboard (existing) |
| Item missing | ItemDetail | Item not in catalogue | Pop back |
| Favourite pruned | Favourites | Entry removed after catalogue replacement | N/A — not mid-navigation |
| Artwork missing | All cards | Placeholder (existing) | None |
| Item unavailable / missing | Cards / detail | Status badge; Play disabled (existing) | Rescan prompt in subtitle |

Operational provider errors continue to direct users to dashboard **Provider Status** (4.1) — not Phase 4.6 diagnostics.

---

## Persistence requirements

| State | Store | Phase 4.3 |
|---|---|---|
| Provider config, network timeout | `SettingsRepository` | Unchanged |
| Default folder sort mode | `SettingsRepository.general.libraryBrowse` | **New fields** (ADR-008) |
| Active folder filter | Widget / screen state | Session only |
| Favourites | `LibraryMetadataRepository` → `ttsplayer_library_metadata_v1` | **New** (ADR-007) |
| Playback progress | `PlaybackService` keys | Unchanged |
| Catalogue runtime | `CatalogService` keys | Unchanged |
| Search recent queries | — | Session only (unchanged) |
| Scroll positions | — | Optional session `PageStorageKey` only |
| Navigation stack | `Navigator` | Ephemeral |

**Forbidden:** favourites in settings envelope; catalogue model mutation in place; catalogue file writes for user metadata; mixing progress keys with favourite ids.

---

## Accessibility and keyboard behaviour

- Breadcrumb segments: `Semantics` header trail; tooltips with full folder names.
- Sort/filter controls: labels for screen readers; focus order before content grid.
- Favourite toggle: announced state (favourited / not favourited).
- Search: query field labelled; result rows expose title + library + status.
- Windows: `Escape` to pop on folder/search where `Navigator.canPop`; preserve dashboard `Ctrl+F`.
- TV-friendly: existing large tap targets retained; sort/filter chips meet minimum touch target.

---

## Testing strategy

| Layer | Tests |
|---|---|
| **Catalog helpers** | `ancestorChainForFolder`, `findFolderById`, `parentFolderOfItemId` |
| **Sort** | Each mode + tie-break + null `addedAt` + folder-first |
| **Filter** | Each mode + empty-filtered state + extension edge cases |
| **LibraryMetadataRepository** | Save/load, prune on catalogue replace, corrupt JSON recovery |
| **Favourites UI** | Toggle, dashboard section, empty state |
| **Breadcrumbs** | Widget smoke — segment count, tap navigation |
| **Search polish** | Group headers render; clear button; empty states |
| **Regression** | `FolderScreen`, dashboard sections, `provider_selection_test`, settings untouched |
| **Runtime** | Opt-in `phase_43_windows_runtime_test.dart` (`PHASE_43_RUNTIME=1`) at closure |

---

## Implementation order

Mirrors Phase 4.2: **persistence and tests before UI**. UI layers consume repositories and pure functions — they do not define storage shape.

### Phase A — Acceptance

1. ~~**ADR acceptance**~~ — ADR-007–009 **Accepted** (2026-07-13).

### Phase B — Persistence and domain (no UI)

2. ~~**Step 1 — `LibraryMetadataRepository`**~~ *(implemented 2026-07-13)*  
   Metadata model, favourite load/save, `validateAgainstCatalog` on catalogue replacement, corrupt JSON recovery, repository unit tests.  
   **Deliverables:** `library_metadata.dart`, `library_metadata_repository.dart`, `library_metadata_repository_test.dart`; `CatalogService` `onCatalogReplaced(Catalog)` wiring in `main.dart`.  
   **Excluded:** UI, breadcrumbs, sort, filter, search, catalog navigation helpers.

3. ~~**Catalog helper extensions**~~ *(implemented 2026-07-13)* — `ancestorChainForFolder`, `findFolderById`, `parentFolderOfItemId` (pure Dart; read-only over `Catalog`).

4. ~~**Settings envelope extension**~~ *(implemented 2026-07-13)* — `general.libraryBrowse.defaultSortMode` (ADR-008).

5. ~~**Sort/filter domain**~~ *(implemented 2026-07-13)* — `buildLibraryFolderView` + `LibrarySortMode` / `LibraryFilter`; pure functions + unit tests; derived views only.

### Phase C — UI consumers

6. **Favourites UI** — dashboard section (first 10 + View all), item/folder toggles; consumes `LibraryMetadataRepository`.

7. **Breadcrumbs** — widget + `FolderScreen` integration (ADR-009).

8. **Sorting** — controls + persisted default wiring.

9. **Filtering** — session-scoped controls.

10. **Search presentation polish** — grouping, clear query, keyboard.

11. **Empty/loading/error copy alignment** across browse surfaces.

### Phase D — Closure

12. **Windows runtime validation** — L1–L18 harness (`PHASE_43_RUNTIME=1`).

13. **Documentation + phase retrospective + closure**.

**Commit cadence (suggested):** Step 1 repository → catalog helpers → sort/filter pure functions → favourites UI → breadcrumbs → sort UI → filter UI → search polish → closure docs.

### Implementation notes — Step 1 (2026-07-13)

- `LibraryMetadataRepository` at `lib/services/library/library_metadata_repository.dart`; model at `lib/models/library_metadata.dart`.
- Storage key `ttsplayer_library_metadata_v1`; separate item and folder favourite lists (ADR-007).
- `CatalogService.onCatalogReplaced` now receives the replaced `Catalog`; `main.dart` composes artwork cache clear + `validateAgainstCatalog`.
- Prune runs only via explicit `validateAgainstCatalog` after successful replacement — not on navigation.
- No UI, sort, filter, or breadcrumb work in this step.

### Implementation notes — Step 2 (2026-07-13)

- `Catalog.findFolderById`, `ancestorChainForFolder`, `parentFolderOfItemId` in `lib/models/catalog.dart`.
- Ancestor chain is root-to-target **inclusive**; dashboard "Home" is outside the helper (ADR-009).
- DFS preorder for duplicate-id resolution; no path parsing for hierarchy.
- Tests in `test/catalog_lookup_test.dart` (scenarios 1–17).
- `validateAgainstCatalog` hardened: try/catch, `persistenceFailed` result, safe `main.dart` wrapper.
- ADR-007 rationale corrected: prune-on-replacement, not prune-on-load.

### Implementation notes — Step 3 (2026-07-13)

- `general.libraryBrowse.defaultSortMode` in `ApplicationSettings` / `SettingsRepository` (`ttsplayer_settings_v1` unchanged).
- Six sort modes per ADR-008: `default`, `nameAsc`, `nameDesc`, `addedNewest`, `addedOldest`, `type`.
- Session filters: `all`, `foldersOnly`, `video`, `images` — not persisted.
- `buildLibraryFolderView` in `lib/library/library_folder_view.dart` — filter then sort; folder-first; immutable catalogue input.
- Video/image filters retain subfolders (ADR-008).
- Tests: `settings_repository_test.dart` (library browse group), `library_sort_filter_test.dart`.
- No FolderScreen UI, sort/filter controls, or favourites UI in this step.

---

The first implementation prompt must deliver **only**:

| In scope | Out of scope |
|---|---|
| `LibraryMetadataRepository` | `FolderScreen` changes |
| Versioned metadata model (`ttsplayer_library_metadata_v1`) | Breadcrumbs |
| Favourite add/remove/list persistence | Sort / filter UI or logic |
| `validateAgainstCatalog` on catalogue replacement | Search changes |
| Repository unit tests (incl. prune, corrupt recovery) | Dashboard widgets |
| `ChangeNotifier` + `initialize()` lifecycle (mirror `SettingsRepository`) | Catalog helper extensions |

---

## Validation scenarios

Closure harness scenarios **L1–L18** (Windows + automated). Spec persistence scenarios may reuse overlapping IDs in unit tests.

| ID | Scenario | Expected |
|---|---|---|
| **L1** | Open deep folder | Breadcrumb shows catalogue ancestor chain with real folder names |
| **L2** | Tap breadcrumb ancestor | Navigates to that folder; content matches `findFolderByPath` |
| **L3** | App bar Back from subfolder | Returns to parent folder screen |
| **L4** | Home from deep folder | Dashboard; no orphan routes |
| **L5** | Search → Browse folder | Lands on correct folder; breadcrumb matches hierarchy |
| **L6** | Search → Open item | `ItemDetailScreen` for correct item |
| **L7** | Default sort | Matches indexer order; deterministic across reloads |
| **L8** | Name ascending / descending | Correct ci-sort within subfolders and items separately |
| **L9** | Recently added sort | Items with `addedAt` ordered correctly; nulls last; folders sorted by name within section |
| **L10** | Folder-first | Subfolders always render above items for every sort mode |
| **L11** | Video filter | Only video extensions in item grid; subfolders still shown |
| **L12** | Filter empty state | Clear message + clear-filter action when folder has only non-matching items |
| **L13** | Favourite item | Toggle on detail; appears in dashboard Favourites |
| **L14** | Favourite folder | Toggle on folder; appears in dashboard Favourites |
| **L15** | Favourites survive restart | Persisted ids resolve after `LibraryMetadataRepository` reload |
| **L16** | Removed item pruned | After catalogue **replacement** without item, favourite entry gone; not pruned on mere folder navigation |
| **L17** | Continue Watching + Recently Added | Section behaviour unchanged (counts, sort, navigation) |
| **L18** | Local vs HTTP catalogue | Breadcrumbs and sort use catalogue tree — same logic path (HTTP via mock or fixture) |

**Expand at implementation** if platform-specific keyboard or scroll restoration scenarios are added.

---

## Definition of done

- [x] ADR-007, ADR-008, ADR-009 reviewed and **Accepted** (2026-07-13)
- [x] `LibraryMetadataRepository` with versioned favourites persistence and prune-on-replacement
- [x] `SettingsRepository` stores global default sort mode only (no favourites)
- [ ] `FolderScreen` breadcrumbs catalogue-driven per ADR-009
- [ ] Sort and filter controls per ADR-008; folder-first preserved
- [ ] Dashboard Favourites section; toggle on item and folder
- [ ] Search presentation improvements without engine rewrite
- [ ] Empty/loading/error states per table above
- [ ] Continue Watching, Recently Added, Featured Folders, Provider Status **unchanged in behaviour**
- [ ] No virtual libraries; no hardcoded category labels
- [ ] Validation L1–L18 pass (automated + Windows runtime)
- [ ] `flutter analyze` — no new errors in Phase 4.3 scope
- [ ] [library.md](../architecture/library.md) → Implemented / Accepted at closure
- [ ] [v0.5.0-dev.md](../release/v0.5.0-dev.md) updated; phase retrospective added
- [ ] Phase 4.3 **not** marked complete until runtime validation recorded

---

## Documentation outputs

| Document | Action |
|---|---|
| This spec | **Accepted** 2026-07-13 — implementation not started |
| ADR-007–009 | **Accepted** 2026-07-13 |
| [library.md](../architecture/library.md) | Updated for spec alignment — **Implemented** at closure only |
| [m4-plan.md](./m4-plan.md) | 4.3 spec in progress → complete at closure |
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | Track spec + implementation status |
| [decisions/README.md](../architecture/decisions/README.md) | ADR index |

---

## Explicit out of scope (M4.3)

- `catalog.json` schema redesign (except optional read-only client helpers)
- Filesystem modification — rename, move, delete, tag files
- Indexer behaviour changes (unless a blocking bug is found)
- Ratings, tags, hidden-state UI (repository may reserve fields only)
- User accounts or per-profile favourites
- Cloud or cross-device metadata sync
- Virtual libraries ("All Movies", cross-folder aggregates)
- TMDB or external metadata enrichment
- Performance optimisation — pagination, lazy index, background rebuild (Phase 4.5)
- Thumbnail generation pipeline changes
- Playback controls, speed, subtitles (Phase 4.4)
- Detailed diagnostics, log export (Phase 4.6)
- Mobile / TV navigation redesign
- Rich media library expansion ([superseded draft](./m4-rich-media-libraries.md))
- Audio / book / document filters until indexer supports them
- Query term highlighting in search results
- Persisted search history (defer)
- Persisted per-folder sort/filter memory (defer)
- Provider or settings behaviour changes

---

## Resolved decisions

| Topic | Decision |
|---|---|
| **Dashboard favourites** | Show **first 10** on dashboard; **View all** opens dedicated favourites view with full list |

## Open decisions (defer to implementation)

1. **Search grouping** — library headers only vs library + parent folder subheaders?
2. **Sort control placement** — inline header vs overflow menu (desktop width)?
3. **Optional scroll restoration** — include in 4.3 DoD or defer to 4.5?
4. **Settings UI for default sort** — add to Settings → General in 4.3 or use implicit default until user opens sort control?
5. **Image items in Continue Watching** — exclude non-video from CW in 4.3 polish pass? (Currently extension-agnostic if playable.)

### Implementation note (ADR-008)

Global default sort (persisted in `SettingsRepository`) and session filter (ephemeral widget state) are **independent** — changing a filter must not alter the persisted default sort, and changing the default sort must not write filter state.

---

## Related documents

| Document | Purpose |
|---|---|
| [m4-phase-4.2-settings-framework.md](./m4-phase-4.2-settings-framework.md) | Closed settings baseline |
| [m4-phase-4.1-provider-management.md](./m4-phase-4.1-provider-management.md) | Provider status baseline |
| [playback.md](../architecture/playback.md) | Phase 4.4 deferral |
| [diagnostics.md](../architecture/diagnostics.md) | Phase 4.6 deferral |
| [Catalogue principle](../../.cursor/rules/catalogue-principle.mdc) | Folder names from data |
| [Item status model](../../.cursor/rules/item-status-model.mdc) | Playability gates |
