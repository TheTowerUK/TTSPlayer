# M3 Milestone Review — Personal Media Experience

**Date:** 2026-07-05  
**Tag:** `m3-complete`  
**Platform:** Windows desktop

→ [M3 goals](./m3-personal-media-experience.md)  
→ [Sprint 4 plan](./m3-sprint-4-plan.md)

---

## Milestone summary

M3 delivers a cohesive personal media experience on Windows: a polished dashboard, folder-first browsing, global search, artwork-aware cards, and playback resume — all against a local or NAS catalogue with no external metadata services.

---

## Sprint outcomes

| Sprint | Delivered | Acceptance |
|---|---|---|
| **1 — Dashboard & Library Foundation** | Dashboard shell, Libraries section, Continue Watching placeholder, scan history, storage status | ✓ |
| **2 — Global Search & Discovery** | Full-tree search, result navigation, Library Manager | ✓ |
| **3 — Artwork & Visual Identity** | Design tokens, `ArtworkService`, premium cards, live CW refresh, scroll fixes | ✓ (`m3-sprint-3`) |
| **4 — Polish & Experience Refinement** | `added_at` / Recently Added, overview panel, Featured Folders, desktop shortcuts, a11y semantics | ✓ |

---

## Sprint 4 deliverables (this release)

### Indexer (`0.3.3`)

- Optional `added_at` (ISO-8601) on every indexed item
- First-seen timestamp preserved across full and library rescans when item id unchanged
- Atomic catalogue writes unchanged

### Client

- `MediaItem.addedAt` parsed from catalogue
- **Recently Added** — horizontal carousel, newest first (up to 12 items)
- **Dashboard overview** — totals, library count, largest library, last scan duration
- **Featured Folders** — catalogue-ranked subfolders (excludes library roots, cap 8)
- **Desktop polish** — Ctrl+F search, Escape back, visible scrollbars on carousels, focus/hover theme
- **Accessibility** — semantics on Recently Added and Featured Folders cards

---

## Quality gate

| Check | Result |
|---|---|
| `flutter analyze` | Clean (info-only lints) |
| `flutter test` | 55/55 passing |
| `python -m unittest backend/test_indexer.py` | 16/16 passing |

---

## Principles compliance

| Principle | Status |
|---|---|
| Filesystem is truth — folder names from data only | ✓ |
| No hardcoded media categories | ✓ |
| No TMDB / external metadata | ✓ |
| Graceful degradation on missing metadata and artwork | ✓ |
| Item status model respected | ✓ |
| Local-first / offline-capable with bundled catalogue | ✓ |

---

## Known limitations (deferred to M4+)

- No user-curated Favourites, Watch Later, or Collections persistence
- No music, books, or image-library-specific viewers beyond folder browse
- No Android/iOS builds
- No HTTPS catalogue or remote streaming path
- Bundled mock catalogue does not include `added_at` until a rescan

---

## Recommended next steps (M4)

See [M4 — Rich Media Libraries](./m4-rich-media-libraries.md):

1. Image library viewing experience
2. Music playback foundation
3. Enhanced folder browsing for mixed libraries

---

## Sign-off

M3 acceptance criteria are met. The Windows client is suitable for daily personal use against a local NAS catalogue.
