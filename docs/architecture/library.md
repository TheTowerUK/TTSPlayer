# Library Experience (M4 planning)

**Status:** Planning — M4 Phase 4.3  
**Related roadmap phase:** [M4 Phase 4.3 — Library Experience](../roadmap/m4-plan.md#phase-43--library-experience)

→ [Design system](../design/design-system.md)  
→ [M3 library experience](../roadmap/m3-library-experience.md)

---

## Purpose

Polish browsing, discovery, and navigation on the **existing folder-tree catalogue** — without inventing virtual libraries or hardcoded media categories.

---

## Current baseline (M3 complete)

| Capability | State |
|---|---|
| Dashboard | `DashboardScreen` — libraries, Continue Watching, Recently Added, Featured Folders, storage status |
| `DashboardService` | Catalogue-driven section data |
| Folder browse | `FolderScreen` — grid of subfolders and items |
| Library Manager | `LibraryManagerScreen` — library roots, scoped rescan |
| Global search | `SearchScreen` — title/filename across catalogue |
| Artwork | `ArtworkService`, `ArtworkImage`, sidecar rules, placeholders |
| Cards | `LibraryCard`, `TtsMediaCard`, `TtsFolderCard` |
| Item detail | `ItemDetailScreen` — metadata, Play gate via `MediaItemStatus.isPlayable` |
| Continue Watching | `ContinueWatchingSection` — playback history driven |
| Recently Added | `RecentlyAddedSection` — indexer `added_at` field |
| Featured Folders | Catalogue-driven ranking |
| Item status model | `available`, `unavailable`, `missing`, etc. |

**Not in baseline:** in-folder sort/filter controls, favourites, breadcrumbs, unified empty-state patterns across all browse surfaces.

---

## M4 goals

- **Sorting and filtering** within folder context (name, date added, etc.)
- **Search refinement** — scope, type hints, clearer result actions
- **Favourites** — user-curated list stored in app state (labelled as app state, not a folder)
- **Continue Watching / Recently Added** UX polish
- **Breadcrumbs** for deep folder navigation
- **Empty and error states** with recovery actions everywhere in browse flow
- **Consistent artwork** presentation across dashboard, folder, and search

---

## Proposed responsibilities

| Component | M4.3 role |
|---|---|
| `FolderScreen` | Sort/filter controls; breadcrumbs |
| `SearchScreen` | Refined filters and result presentation |
| Favourites store | New app-state service (not filesystem) |
| Dashboard sections | Polish layout; no new virtual sections |
| `CatalogService` | Unchanged schema; client-side sort/filter only |

---

## Data / state considerations

- Sort/filter preferences may link to [settings.md](./settings.md) defaults
- Favourites: list of `MediaItem.id` + optional folder bookmarks — versioned prefs or small JSON blob
- Filesystem order remains indexer default when user selects "default order"

---

## Failure handling

- Empty folder: valid state with guidance (rescan, navigate up)
- Missing artwork: placeholder — never hide item
- Search with no results: suggest broader query or check catalogue source

---

## Testing considerations

- Widget tests for sort order and breadcrumb trail
- Favourites add/remove/list round-trip
- Regression: folder names from data only — no hardcoded section headers

---

## Open decisions

1. **Favourites model** — items only vs folder bookmarks vs both?
2. **Sort scope** — per-folder memory vs global default?
3. **Filter dimensions** — status, extension, playable-only?

---

## Out of scope

- Virtual "All Movies" libraries
- TMDB metadata enrichment
- Image viewer / rich media libraries ([superseded draft](../roadmap/m4-rich-media-libraries.md))

---

## Related documents

- [settings.md](./settings.md)
- [Catalogue principle](../../.cursor/rules/catalogue-principle.mdc)
