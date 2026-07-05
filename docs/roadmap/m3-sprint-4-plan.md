# M3 Sprint 4 — Polish & Experience Refinement

**Status:** Approved — implementation follows Sprint 3 checkpoint  
**Theme:** Close Milestone 3 — cohesive, polished, intentional  
**Platform:** Windows desktop only

→ [M3 goals](./m3-personal-media-experience.md)  
→ [Design system](../design/design-system.md)  
→ [M4 preview (next milestone)](./m4-rich-media-libraries.md)

---

## Sprint objective

Complete M3 by refining the overall experience — **not** introducing major new platform capabilities. The app should feel complete, consistent, and polished when handed to a new user.

---

## Approved deliverables

### 1. Featured Folders (not Collections)

A lightweight **Featured Folders** dashboard section — catalogue-driven only.

**In scope:**

- Reuse `TtsFolderCard` / `LibraryCard`, `ArtworkService`, `FolderScreen` navigation.
- Surface **prominent** folders from the existing catalogue tree.
- Ranking derived from catalogue signals only (e.g. `item_count`, structural prominence) — **not** user curation.
- Empty state when no candidates qualify.

**Out of scope for Sprint 4:**

- Dedicated Collections model or persistence.
- User-curated Favourites / Watch Later (future milestone).
- TMDB, franchise detection, AI grouping, or invented categories.
- “Every folder below depth 1” as a blanket rule.

**Ranking guidance (implement at kickoff):**

- Exclude top-level library roots (already in **Libraries**).
- Prefer folders with meaningful `item_count` and/or active sub-structure.
- Cap display count (e.g. 6–8) on dashboard; optional “See all” if list is long.
- Folder **name** and **path** always from catalogue data.

### 2. Recently Added

- Add optional `added_at` (ISO-8601) to indexer output — first-seen in catalogue on successful scan.
- Preserve `added_at` on full and scoped rescans when item id/path unchanged.
- Client: `MediaItem.addedAt`, `DashboardService` sort, populate `RecentlyAddedSection`.
- Replace Sprint 1 placeholder empty states with honest post-rescan copy.

### 3. Dashboard overview panel

Compact at-a-glance block from existing services:

- Last scan summary (`Catalog.scan`)
- Total items / library count
- Largest library by `item_count`
- Spacing aligned to design system

### 4. Empty states pass

Local-first, actionable copy on dashboard, Library Manager, search, Featured Folders, Recently Added, Continue Watching.

### 5. Desktop polish

Scrollbars where needed, keyboard shortcuts (search, back), focus theme, tooltips, card hover parity (including Continue Watching).

### 6. Accessibility

Semantics on interactive cards, focus indicators, tap-target audit, contrast check against canonical palette.

### 7. Design consistency pass

Eliminate inline `TextStyle` stragglers; align all M3 screens to `AppColors`, `AppTypography`, `AppSpacing`, `AppCardStyles`, `ArtworkImage`.

---

## Explicitly out of scope

Android, iOS, HTTP catalogue, HTTPS streaming, path resolver, Caddy/Nginx, remote control, profiles, TMDB, MusicBrainz, AI tagging, user Collections/Favourites persistence.

---

## Implementation order

1. **Checkpoint Sprint 3** — commit + tag `m3-sprint-3`
2. Indexer `added_at` + client parse + tests
3. Recently Added section (real data)
4. Dashboard overview panel
5. Featured Folders section + ranking helper
6. Empty states pass
7. Design consistency pass
8. Desktop polish + accessibility
9. `flutter analyze` + full test suite (Dart + Python)
10. Update MILESTONES.md — M3 complete

---

## Definition of done

- Featured Folders visible on dashboard when catalogue provides candidates.
- Recently Added powered by `added_at` after rescan.
- Dashboard feels complete (overview, spacing, scroll).
- Empty states polished across M3 screens.
- Desktop and accessibility improvements applied.
- Design system adopted consistently.
- `flutter analyze` clean; all tests pass.
- No roadmap principles violated.
