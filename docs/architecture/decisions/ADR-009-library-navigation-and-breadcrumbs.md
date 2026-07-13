# ADR-009: Library Navigation and Breadcrumbs

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.3  
**Authors:** M4 documentation pass

---

## Context

TTSPlayer uses **imperative `Navigator` pushes** (`MaterialPageRoute`) — no named routes, no GoRouter, no persisted navigation stack. `FolderScreen` resolves folders by `folderPath` against the live `CatalogService.catalog` on every build.

Today:

- App bar shows the current folder `name` only — no ancestor trail.
- Back pops one route; Home (`popUntil isFirst`) returns to dashboard.
- Search and dashboard sections push `FolderScreen` or `ItemDetailScreen` directly.
- No scroll-position restoration when returning from item detail.

Phase 4.3 must improve deep-folder navigation without breaking catalogue-driven resolution or inventing hierarchy labels.

---

## Decision

### Breadcrumb source: **catalogue hierarchy**

Breadcrumb segments are derived from the **current catalogue tree**, not raw filesystem path string splitting alone.

1. Add `Catalog.ancestorChainForFolder(String folderPath)` returning `List<MediaFolder>` root → parent → current, using `findFolderByPath` and tree parent links (or path walk validated against catalogue nodes).

2. Each segment displays `MediaFolder.name` — the real directory name from `catalog.json`.

3. Tapping a segment navigates to that folder by pushing or popping to an existing `FolderScreen` with the target `folderPath`.

4. **HTTP and local catalogues** use the same logic because both expose identical `MediaFolder.path` / `name` / `id` from the indexer.

Navigation state (which segment is "current") comes from the **active `FolderScreen.folderPath`**, not a parallel route table.

### Back-stack behaviour

| Action | Behaviour |
|---|---|
| App bar Back | `Navigator.pop` — one level |
| Home button | `popUntil((route) => route.isFirst)` — dashboard |
| Breadcrumb ancestor tap | Pop to existing folder route if on stack; else `pushReplacement` or pop + push to avoid duplicate depths |
| Dashboard → folder | Fresh push |
| Search → folder | Push `FolderScreen`; breadcrumb reflects catalogue ancestry from result context |
| Item detail → back | Return to prior folder/search/dashboard |

**No persisted route stack** across app restarts in 4.3.

### Scroll restoration

- **Deferred by default** — no persisted scroll offsets in 4.3.
- **Optional session-only restoration:** when popping from `ItemDetailScreen` back to the same `FolderScreen` instance, restore scroll offset if the route was not disposed. Implementation may use `PageStorageKey` per `folderPath` — **optional** 4.3 deliverable, not required for closure if risky on Windows.

### Long paths and deep trees

- Breadcrumb row scrolls horizontally when segments overflow.
- Segment labels ellipsis middle-truncate on narrow widths; full name in tooltip.
- App bar title remains current folder `name` (existing pattern).

### Keyboard (Windows)

- `Escape` — pop if possible (extend from dashboard-only today to folder/search where safe).
- Breadcrumb segments are focusable; `Enter` activates navigation.
- Tab order: breadcrumbs → sort/filter controls → grid content.

---

## Rationale

- Catalogue-driven ancestry keeps local and remote catalogues consistent and respects folder names from data (catalogue principle).
- Reusing `folderPath` as the navigation key aligns with existing `FolderScreen` stale-path recovery after rescan.
- Avoiding persisted route stacks limits scope; dashboard `RouteAware` refresh pattern remains sufficient for catalogue updates.

---

## Consequences

### Positive

- Users gain orientation in deep trees without a navigation rewrite.
- Rescan safety preserved — missing folder still shows `_FolderMissingBody`.

### Negative

- Breadcrumb tap + back-stack deduplication requires careful navigator logic and widget tests.
- Path-based ancestry fails if catalogue tree is inconsistent — mitigated by only using resolved `MediaFolder` nodes.

### Neutral

- Named routes / deep linking remain out of scope for 4.3.

---

## Alternatives considered

### Alternative A — Filesystem path splitting only

**Rejected because:** separators and root detection differ across platforms; HTTP paths may not match client filesystem conventions; segment labels might not match catalogue `name`.

### Alternative B — Parallel navigation state machine (new `LibraryNavigationService`)

**Rejected because:** duplicates `Navigator` stack; high refactor cost for 4.3.

### Alternative C — Persist full route stack in preferences

**Rejected because:** invalid after catalogue rescan/replace; conflicts with live `findFolderByPath` resolution.

---

## Related documents

- [M4 Phase 4.3 specification](../../roadmap/m4-phase-4.3-library-experience.md)
- [ADR-007: Library Metadata and Favourites](./ADR-007-library-metadata-and-favourites.md)
- [ADR-008: Library Sorting and Filtering](./ADR-008-library-sorting-and-filtering.md)
- [library.md](../library.md)
