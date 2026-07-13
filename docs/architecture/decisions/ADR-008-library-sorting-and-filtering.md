# ADR-008: Library Sorting and Filtering

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.3  
**Authors:** M4 documentation pass

---

## Context

`FolderScreen` today renders subfolders and items in **indexer emission order** with no user controls. Global Search already supports optional library and extension filters (`SearchFilters`) and score-based result ordering — but folder browsing does not.

Phase 4.3 must add sort and filter controls **without**:

- Inventing metadata fields absent from `catalog.json` (no modified-date sort)
- Creating cross-library virtual views
- Applying destructive filters that hide catalogue knowledge permanently
- Classifying media by heuristics unsupported by the indexer (no "Movies" type inference)

Available catalogue fields for sorting:

| Entity | Fields |
|---|---|
| `MediaFolder` | `name`, `path`, `itemCount`, `totalItems` |
| `MediaItem` | `title`, `filePath`, `extension`, `addedAt`, `status`, `sizeBytes`, `year` |

The indexer does **not** emit `modified_at`. `added_at` is first-seen-in-catalogue timestamp (ISO-8601), not filesystem mtime.

Supported extensions today (indexer + client): **video** (`.mp4`, `.mkv`, `.mov`, `.m4v`, `.avi`) and **images** (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff`). No audio or document indexing in the current scanner.

---

## Decision

### Sort modes (folder browse)

| Mode | Key | Behaviour |
|---|---|---|
| Default (filesystem) | `default` | Indexer emission order — **default** and fallback when sort field missing |
| Name A→Z | `nameAsc` | `name` / `title` case-insensitive ascending |
| Name Z→A | `nameDesc` | `name` / `title` case-insensitive descending |
| Recently added | `addedNewest` | Items: `addedAt` desc; folders: `name` asc after items sort group |
| Oldest added | `addedOldest` | Items: `addedAt` asc nulls last; folders: `name` asc |
| Type | `type` | Primary: extension category (video → image → other); secondary: `title` asc |

**Folder-first rule:** subfolders always render **before** items in `FolderScreen`, regardless of sort mode. Sort applies **within** the subfolder group and **within** the item group independently.

**Tie-breaking:** after primary key, compare `name`/`title` case-insensitively ascending.

**Missing `addedAt`:** items sort **after** dated items in `addedNewest`; **before** dated items in `addedOldest`; equal group sorts by `title`.

**Status:** sort does not hide `missing` / `unavailable` items — status affects playability only (existing `isPlayable` gate).

### Filter modes (folder browse)

| Mode | Key | Scope |
|---|---|---|
| All | `all` | Subfolders and items |
| Folders only | `foldersOnly` | Hide item grid |
| Video | `video` | Items whose extension ∈ video set; subfolders still shown |
| Images | `images` | Items whose extension ∈ image set; subfolders still shown |

- **Single active filter** at a time (mutually exclusive chips or segmented control).
- Filters are **non-destructive** and **session-scoped** — not persisted across app restarts in 4.3.
- Filters apply to the **current folder only** — not recursive into subfolders.
- Extension classification uses `Catalog.supportedExtensions` intersected with static video/image sets aligned with `backend/indexer.py`.

**No audio, books, or documents filter** until the indexer emits those types.

### Sort persistence

- **Global default sort mode** persisted in `SettingsRepository` under an expanded `general.libraryBrowse.defaultSortMode` field (additive envelope v1 change).
- **Active sort** in `FolderScreen` initializes from the global default; in-session override does **not** auto-persist.
- **Set as default** action (bookmark icon) explicitly saves the current sort via `SettingsRepository.saveDefaultLibrarySortMode`.
- New subfolder `FolderScreen` routes reset to persisted default sort and `all` filter; Back preserves mounted route session state.

### Implementation (Step 6, 2026-07-13)

- `FolderBrowseControls` — sort popup + filter chips below breadcrumbs.
- `_FilterEmptyBody` — filter-specific empty state with **Show all** (distinct from true empty folder).
- Filter-empty copy per ADR-008 updated in UI to match spec: "No items match this filter".

### Sort vs filter independence

- **Persisted default sort** (`SettingsRepository`) and **session filter** (ephemeral `FolderScreen` state) are separate concerns.
- Applying or clearing a filter must not read or write sort preferences.
- Changing the global default sort must not capture or persist the active filter.

### Search interaction

- Folder sort/filter state does **not** affect Global Search.
- Search retains its own `SearchFilters` (library + extension) and score-based ordering.
- If search result grouping is added (4.3 UI polish), it does not change `SearchService.search()` ranking — presentation layer only.

### Empty filtered results

When the current folder has content but the active filter hides all items (e.g. Video filter in an image-only folder), show `EmptyState`:

- Title: "No matching items in this folder."
- Subtitle: "Try a different filter or browse subfolders."
- Action: clear filter chip

---

## Rationale

- Filesystem/default order preserves the user's physical layout when they want it.
- `addedAt` is the only temporal field reliably present for Recently Added parity.
- Session-only filters avoid preference creep before user research; sort default in settings matches network-timeout precedent.
- Folder-first respects existing two-section layout and TV-friendly scanning pattern.

---

## Consequences

### Positive

- Deterministic, testable ordering with explicit tie-break rules.
- No catalogue schema change required.
- Filter dimensions grounded in indexer output.

### Negative

- `general` settings group gains fields — requires validation in `SettingsRepository` and migration-safe defaults.
- Type sort treats folders separately from items — may feel asymmetric (documented).

### Neutral

- Per-folder sort memory deferred — can move to `LibraryMetadataRepository` later if needed.

---

## Alternatives considered

### Alternative A — Persist active filter in settings

**Rejected because:** filters are exploratory/temporary; persistence adds UI state complexity without validated user demand.

### Alternative B — Modified-date sort from filesystem stat

**Rejected because:** not in `catalog.json`; would require indexer schema change and HTTP catalogue cannot stat remote files reliably in 4.3.

### Alternative C — Mixed folder/item sort (no folder-first)

**Rejected because:** breaks established grid sections and folder-first browsing mental model.

---

## Related documents

- [M4 Phase 4.3 specification](../../roadmap/m4-phase-4.3-library-experience.md)
- [ADR-004: Settings Storage and Versioning](./ADR-004-settings-storage-and-versioning.md)
- [ADR-007: Library Metadata and Favourites](./ADR-007-library-metadata-and-favourites.md)
- [library.md](../library.md)
