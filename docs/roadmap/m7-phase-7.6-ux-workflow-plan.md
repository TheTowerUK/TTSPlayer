# M7 Phase 7.6 — UX and Workflow Refinements

**Status:** In progress — 7.6.4 shared direct-activation routing complete
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.5 closure](./m7-phase-7.5-closure-report.md)
**Source tracker:** [Post-Milestone UX and Workflow Review](./post-milestone-ux-workflow-review.md)

→ [M7 plan](./m7-plan.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

---

## Objective

Close the three approved post-M6 UX/workflow items without reopening metadata-enrichment contracts:

1. Prove and preserve distortion-free Continue Watching artwork.
2. Complete book/comic folder-rescan parity on the existing scoped indexer path.
3. Remove the redundant detail-screen hop for single-action media while retaining an explicit path to details.

---

## Repository audit (7.6.1)

### Continue Watching artwork

`ContinueWatchingSection` already renders through `ResolvedMediaArtworkImage`, whose default is `BoxFit.cover`. `ArtworkImage` forwards that fit to `Image.file` / `Image.network`; therefore image aspect ratio is preserved and excess bounds are cropped rather than stretched.

The remaining gap is regression coverage. Existing `card_layout_test.dart` verifies only that the card does not overflow; it does not assert the fit contract or bounded artwork region.

### Literature folder rescan

The core path already exists:

- `FolderScreen` exposes **Rescan this folder** for catalogue folders.
- `ScannerService.runLibraryScan` passes the exact stored folder path using `--library-path` and retains navigation after success.
- `backend/indexer.py` can replace a matching folder node anywhere in the catalogue tree and recalculates ancestor/item totals.

The implementation comments still describe the operation as top-level-only, while the merge logic supports nested folders. Current widget tests prove menu visibility, and backend tests prove a library merge, but there is no explicit book/comic nested-folder end-to-end contract. Phase 7.6 will harden and document the existing capability rather than add another scanner mode.

### Item opening and playback

Entry surfaces currently route inconsistently:

| Surface | Current primary action |
|---|---|
| Continue Watching | Direct video resume |
| Continue Reading | Direct book/comic reader |
| Folder media card | `ItemDetailScreen` |
| Search result | Audio detail or generic `ItemDetailScreen`; separate audio play action |
| Recently Added item | `ItemDetailScreen` |
| Favourite item | `ItemDetailScreen` |

Direct player/reader helpers already exist, but there is no shared policy for choosing direct activation versus details.

---

## Locked interaction policy

- A primary activation on a playable single media item performs its natural action:
  - video → player;
  - audio → music player with a single-track queue;
  - supported book/comic → reader with normal progress restoration.
- Unavailable or unsupported items open details so the user receives the existing status/recovery explanation.
- Folder and grouped music entities continue to browse or open their group detail screens.
- Item details remain reachable through an explicit secondary **Details** action on affected surfaces. Phase 7.5 enriched metadata and management controls must not become inaccessible.
- Continue Watching and Continue Reading keep their existing direct-resume behaviour.
- Routing decisions are centralized; widgets do not duplicate media-kind/status policy.

---

## Implementation steps

| Step | Scope | Expected change |
|---|---|---|
| **7.6.1** | Audit and plan | This document; tracker/release status only |
| **7.6.2** ✅ | Continue Watching artwork contract | Confirmed existing `ResolvedMediaArtworkImage` path uses proportional `BoxFit.cover`; added provider-path, bounded decode/layout, portrait-source fit, and overflow regression coverage — **33 focused tests passed**; no production change required |
| **7.6.3** ✅ | Literature folder-rescan parity | Canonical exact-path arguments; aligned subtree terminology; book/comic UI forwarding; nested replacement, ancestor/total recalculation, sibling and `added_at` preservation; navigation/last-good catalogue regression coverage |
| **7.6.4** ✅ | Shared direct-activation routing | Central policy/helper wired to folder, search, Recently Added, dashboard Favourites, and full Favourites; playable video/audio/supported books/comics activate directly; unavailable/unsupported/image items fall back to details; explicit Details actions retained — **139 affected tests passed; full suite 1853 passed, 21 skipped, 0 failed** |
| **7.6.5** | Windows runtime and regression | Exercise video/audio/book/comic direct activation, Details fallback, Continue Watching aspect ratio, and scoped literature rescan with synthetic fixtures |
| **7.6.6** | Closure | Reconcile tracker, M7 plan, release notes, architecture implications, and deferred items |

Each implementation step remains independently reviewable and commit-sized.

---

## Validation matrix

### Artwork

- Continue Watching local and resolved provider artwork use `BoxFit.cover`.
- Image intrinsic aspect ratio is preserved; the artwork band stays inside the fixed card.
- Placeholder, progress indicator, decode hints, scrollbar, and Resume action remain unchanged.

### Folder rescan

- Book and comic folders expose one rescan action.
- The exact catalogue `folder.path` reaches `--library-path`; no path is inferred from labels.
- Nested replacement does not duplicate a top-level branch.
- Ancestor and catalogue totals recalculate; unrelated branches and `added_at` values remain stable.
- Successful scoped rescan keeps folder navigation and reloads the catalogue.
- Failure retains the last-good catalogue and exposes diagnostics.

### Direct activation

- Playable video opens `PlayerScreen` directly.
- Playable audio seeds the existing single-track queue and opens the music player.
- Supported book/comic opens its reader with existing progress restoration.
- Unsupported/missing media opens details.
- Every changed surface retains an explicit Details path.
- Search identity/ranking, metadata projection, provider-call count, artwork resolution, favourites, and browsing remain unchanged.

---

## Scope boundaries

No catalogue schema or provider-contract changes. No ranking changes. No new media opener, reader feature, queue model, automatic scan, background enrichment, or dependency. Phase 7.6 reuses the existing player, music, reading, scanner, catalogue, and artwork services.

The following remain deferred: bulk/multi-folder scan selection, scan scheduling, new item-detail content, reader bookmarks/annotations, and M8 multi-device behaviour.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Direct activation hides enriched details | Add an explicit Details action before changing primary taps |
| Routing logic diverges by surface | One shared policy/helper with table-driven tests |
| Audio activation loses album context | Use single-track queue only in currently ungrouped item surfaces; preserve album/artist routes |
| Nested rescan appends duplicates | Assert recursive replacement and unchanged top-level branch count |
| Rescan invalidates current folder route | Preserve `runLibraryScan` navigation behaviour and test live catalogue replacement |
| Artwork fix bypasses 7.4 resolver | Keep `ResolvedMediaArtworkImage`; test the fit passed through that path |

---

## Proposed commit sequence

1. `docs(m7.6): plan UX and workflow refinements`
2. `test(m7.6): lock Continue Watching artwork presentation`
3. `feat(m7.6): harden literature folder rescans`
4. `feat(m7.6): add direct media activation routing`
5. `test(m7.6): add Windows UX workflow runtime harness`
6. `docs(m7.6): close UX and workflow refinements`
