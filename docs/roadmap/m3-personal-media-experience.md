# M3 — Personal Media Experience

**Theme:** Personal Media Experience  
**Status:** Current milestone — development cycle `v0.4.0-dev` (M3.5 Network Client Foundation follows)  
**Platform focus:** Windows-first polish  
**Architecture impact:** None — experience-layer improvements on the existing local/UNC folder-tree catalogue.

→ [Full roadmap](./roadmap.md)  
→ [Sprint 4 plan](./m3-sprint-4-plan.md)  
→ [M4 preview (next milestone)](./m4-rich-media-libraries.md)  
→ [Mobile delivery (future — not M3 scope)](./mobile-delivery.md)

---

## M3 Progress

| Sprint | Focus | Status |
|---|---|---|
| Sprint 1 | Dashboard & Library Foundation | ✓ Complete |
| Sprint 2 | Global Search & Discovery | ✓ Complete |
| Sprint 3 | Artwork & Visual Identity | ✓ Complete (`m3-sprint-3`) |
| Sprint 4 | Polish & Experience Refinement | ✓ Complete |

**Checkpoint (Sprint 3):** Design tokens, `ArtworkService`, card upgrades, sidecar-aware artwork, dashboard live refresh, and vertical scroll. Sprint 4 closes the milestone with `added_at`, Featured Folders, overview panel, and polish.

→ [Sprint 4 implementation plan](./m3-sprint-4-plan.md)

---

## Goals

Windows-first improvements to how the user manages and enjoys their library:

| Area | Goal |
|---|---|
| Library Manager | Clearer top-level library presentation from the live catalogue |
| Dashboard | Home layout: libraries, scan summary, status at a glance |
| Continue Watching | Surface in-progress items from playback history |
| Artwork / thumbnails | Posters in grids and detail views; placeholder on failure |
| Recently Added | Newest catalogue items via per-item `added_at` from indexer (Sprint 4) |
| Featured Folders | Prominent catalogue folders on dashboard — not user-curated collections (Sprint 4) |
| Catalogue search | Find items by title across the loaded catalogue |
| Diagnostics | Playback and catalogue health visible when something fails |
| NAS / demo status | Clear **Live NAS** vs **Demo** labelling and path visibility |
| Folder browsing | Improved navigation, hierarchy, and empty states |

**Deferred beyond M3:** User-curated Collections, Favourites, and Watch Later — app-state organisation for a future milestone once the platform supports richer library management.

---

## Future: Settings (not in M3)

Settings UI is deferred until after the personal media baseline is solid.

**Windows (M3 era — config file only):**

| Setting | Example |
|---|---|
| Media root (drive letter) | `Y:\Media` |
| Media root (UNC / SMB) | `\\MEDIATNAS-B725\Media` |
| Catalogue file location | `Y:\Media\catalog.json` |

Until Settings exists, paths are read from `ttsplayer.config.json` with built-in fallbacks (`Y:\Media\catalog.json`, then UNC). The bundled asset catalogue remains demo-only.

**Mobile (M3.5 — not M3):** NAS base URL, catalogue URL, HTTPS configuration. See [mobile-delivery.md](./mobile-delivery.md).

---

## Explicitly out of scope for M3

These belong to later milestones and must not pull M3 off course:

| Item | Milestone |
|---|---|
| Android / iOS builds | M3.5 |
| HTTPS catalogue / media streaming | M3.5 |
| Path-to-URL resolver | M3.5 |
| NAS Caddy/Nginx deployment | M3.5 (infra; can start in parallel with late M3) |
| Remote control / multi-device sync | M7 |
| Dedicated image/music/book experiences | M4–M6 |
| Filesystem restructuring or virtual libraries | Never (see project rules) |
| External metadata APIs (TMDB, etc.) | Out of scope until requested |
| User-curated Collections / Favourites | Future milestone (post-M3) |

---

## Success criteria

M3 is done when a Windows user can:

1. See **Live NAS** vs **Demo** status clearly on the dashboard
2. Resume watching from a **Continue Watching** row on Home
3. Browse top-level **libraries** that mirror their NAS folder structure
4. Browse folders with **thumbnails** and clearer hierarchy
5. **Search** the catalogue by title without leaving the app
6. Discover **Featured Folders** and **Recently Added** items from catalogue data alone
7. Understand playback or catalogue failures via **diagnostics**, not blank screens

---

## After M3

When Sprint 4 completes, M3 is feature-complete for Windows personal media. The next deliberate step is **[M4 — Rich Media Libraries](./m4-rich-media-libraries.md)** (image browsing and viewing), documented in advance so the transition is planned rather than reactive.
