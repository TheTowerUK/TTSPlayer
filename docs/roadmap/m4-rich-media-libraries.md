> **Superseded scope note (2026-07-10):** This document described **content-domain expansion** (image libraries) as M4. Active M4 is now **[User Experience and Platform Integration](./m4-plan.md)** on branch `m4-development` (`v0.5.0-dev`). Retain this file as reference for a future content-expansion milestone; do not treat it as the active M4 plan.

# M4 — Rich Media Libraries (superseded draft)

**Theme:** Rich Media Libraries  
**Status:** Planned — begins after M3.5 (`v0.4.0-dev` cycle)  
**Platform focus:** Windows-first; builds on the M3 personal media experience  
**Architecture impact:** Extends content-type handling and browsing UX on the existing folder-tree catalogue — no virtual libraries, no metadata providers.

→ [Full roadmap](./roadmap.md)  
→ [M3 Personal Media Experience](./m3-personal-media-experience.md)  
→ [Roadmap principles](./principles.md)

---

## Why M4 follows M3

M3 delivers a **cohesive personal media shell**: dashboard, libraries, folder browsing, search, artwork, Continue Watching, and catalogue-driven discovery. When M3 Sprint 4 closes, the application should feel **intentional and complete for video-first use** on Windows.

M4 is the first **content-domain expansion** milestone: treating non-video media types as first-class browsing and playback experiences, still rooted in the user's folder structure.

This document exists so the transition from M3 → M4 is **deliberate**, not reactive.

---

## Relationship to work already shipped

Several M4 foundations exist before M4 officially starts:

| Area | Current state (post-M3) | M4 builds on |
|---|---|---|
| Image indexing | Scanner indexes `.jpg`, `.png`, `.webp`, etc.; sidecars excluded beside video | Dedicated **image library** browsing and viewing |
| Artwork pipeline | `ArtworkService`, sidecar rules, placeholders | Image **primary content**, not just decoration |
| Card language | `LibraryCard`, `TtsMediaCard`, design tokens | Image-optimised grid (1:1 / fit layouts) |
| Folder tree | `FolderScreen`, `Catalog.allItems` | Same navigation — no new hierarchy model |
| Search | Title/filename search across catalogue | Extend filters/routing for image items |

M4 must **not** reinterpret M3 dashboard sections (Featured Folders, Recently Added) as image-specific features unless the catalogue data supports it naturally.

---

## Goals

| Area | Goal |
|---|---|
| Image browsing | Grid and folder views optimised for still images |
| Image viewing | Full-screen viewer with next/previous within folder context |
| Library identity | Image folders use square or fit artwork; labels from folder names only |
| Mixed folders | Folders with both video and images render all indexed items — no invented splits |
| Search | Find images by title/filename; open in viewer or parent folder |
| Performance | Large folders remain usable (lazy grids, reasonable memory on desktop) |
| Scanner | Stable image metadata where cheap (dimensions optional; no EXIF geocoding required for v1) |

---

## Non-goals (M4 v1)

| Item | Deferred to |
|---|---|
| RAW / HEIC / proprietary formats | Later M4 iteration or explicit user request |
| Photo editing, albums, faces, GPS maps | Out of scope — not a photo manager |
| AI tagging, auto albums, duplicate detection | Never without explicit user request |
| TMDB / MusicBrainz / external metadata | Out of scope until requested |
| User-curated Collections / Favourites | Post-M3 organisation feature — separate from Featured Folders |
| Mobile image libraries | M3.5 (network client) then parity where practical |
| Music playback | M5 |
| Books / comics | M6 |

---

## Architecture expectations

Continue using existing services:

| Service | M4 role |
|---|---|
| `CatalogService` | Load catalogue; no schema invention in client |
| `ArtworkService` | Image items may use file path as primary artwork |
| `PlaybackService` | **Extend or sibling** for image viewing — not forced through video player |
| `ScannerService` | Full + scoped scan unchanged; optional richer image fields |
| Folder navigation | `FolderScreen` → item detail → viewer |

**Principles:**

- Filesystem is truth — folder names are labels.
- Graceful degradation — missing dimensions or metadata never hides the image.
- No virtual libraries aggregating across folders.
- Catalogue schema changes only when justified; prefer optional fields.

---

## Proposed M4 phases (draft)

Phases are indicative — refine when M4 becomes active.

### Phase A — Image item routing

- Detect image extensions on `MediaItem` (already derivable from path).
- Route **Play/Open** on image items to an image viewer, not `VideoPlayerController`.
- Item detail screen adapts actions for still vs video content.

### Phase B — Image viewer

- Full-screen viewer: zoom/pan (desktop), keyboard prev/next, escape to close.
- Browse within parent folder order (filesystem/index order — no custom sort in v1).

### Phase C — Image-optimised grids

- Folder grids use aspect ratio appropriate to images (design system: 1:1 for music/images).
- Placeholder and loading patterns from M3 artwork stack.

### Phase D — Search and dashboard touchpoints

- Search results distinguish video vs image (cosmetic icon only — not category labels).
- Optional: Recently Added already surfaces new images once `added_at` exists (M3 Sprint 4).

### Phase E — Scanner enhancements (optional)

- Optional `width` / `height` on image items if cheap to stat/read header.
- No hard dependency — viewer works without dimensions.

---

## Success criteria (draft)

M4 v1 is done when a Windows user can:

1. Browse an **Images** library (or any folder of indexed images) with appropriate grids and artwork.
2. Open an image full-screen and move prev/next within the same folder.
3. Search for an image by name and open it without leaving the app.
4. Still browse video libraries exactly as in M3 — no regressions.
5. Run full and scoped scans that index images consistently with video sidecar rules.

---

## Dependencies and ordering

| Dependency | Notes |
|---|---|
| **M3 complete** | Sprint 4 polish, `added_at`, Featured Folders, design consistency |
| **M3.5 not required** | M4 is local/UNC desktop-first, same as M3 |
| **Indexer sidecar rules** | Already shipped — image libraries must not treat sidecars as primary media beside video |

Recommended milestone order after M3:

```
M3 (complete) → M4 (image libraries) → M3.5 (network client) → M5/M6 → M7
```

M3.5 may run in parallel with late M4 if resources allow, but **M4 does not require HTTP streaming** on desktop.

---

## Open questions (resolve at M4 kickoff)

1. **Single viewer vs lightbox** — minimal pan/zoom scope for v1?
2. **Mixed video+image folders** — same grid with type-appropriate cards, or unified card with icon hint only?
3. **Catalogue fields** — are optional `width`/`height` worth scanner complexity in v1?
4. **Featured Folders** — should high-image-count folders rank higher when M4 lands?

---

## Related documents

| Document | Purpose |
|---|---|
| [M3 Personal Media Experience](./m3-personal-media-experience.md) | Current milestone |
| [Design system](../design/design-system.md) | Card ratios, artwork rules |
| [Catalogue principle](../../.cursor/rules/catalogue-principle.mdc) | Folder names from data |
| [MVP scope](../../.cursor/rules/mvp-scope.mdc) | Baseline behaviours |

When M4 development starts, update [roadmap.md](./roadmap.md) status and split this draft into sprint-sized work items.
