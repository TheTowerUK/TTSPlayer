# M6 Phase 6.4C — Comic Reading Experience Closure

**Status:** Planning (2026-07-27) — **not started**  
**Branch:** `m6-development`  
**Predecessor:** Phase 6.3 ✅ Complete (CBZ archive reader foundation)  
**Related:** [m6-plan.md](./m6-plan.md) · [books-comics.md](../architecture/books-comics.md) · [ADR-026 Accepted](../architecture/decisions/ADR-026-reader-surface-architecture.md) · [ADR-027 Accepted](../architecture/decisions/ADR-027-reading-progress-and-continue-reading.md)

> **Identifier note:** **6.4C** is a comic-specific follow-on closure track. It does **not** replace or renumber the completed repository **Phase 6.4** (book reader). Use **6.4C** in headings, release entries, test tags, and commit descriptions for this track.

---

## Repository phase alignment (read first)

`m6-plan.md` uses a **cross-format** phase sequence. **6.4C** is distinct from repo Phase 6.4:

| `m6-plan.md` phase | Focus | Status in repo |
|---|---|---|
| **6.3** | CBZ comic archive reader foundation | ✅ Complete |
| **6.4** | Book document reader (PDF/EPUB) | ✅ Complete |
| **6.5** | Reading progress & Continue Reading (all reader formats) | ✅ Complete |
| **6.6** | Reader performance, memory & UX hardening | ✅ Complete |

**This document** scopes **Phase 6.4C** — comic-specific reading experience closure — turning the Phase 6.3 CBZ foundation into a production-quality comic reader with persistent, isolated progress.

During the M6 implementation arc, parts of this scope were **partially delivered early** under Phases 6.5 and 6.6 (shared reading-progress repository, comic page cache bounds, lazy CBZ I/O, keyboard navigation, basic zoom). **Phase 6.4C** is the **formal closure pass** for comic UX and progress: verify what landed, close documented gaps, and satisfy the Definition of Done below without reintroducing CBR/UnRAR.

Do **not** renumber completed book-reader work. Repo Phase 6.4 (PDF/EPUB) remains unchanged.

---

## 1. Current baseline (Phase 6.3 foundation)

Phase 6.3 provides a **CBZ-only** archive-to-reader pipeline. The following exists today under `client/ttsplayer/lib/features/comics/`:

### Archive layer

| Component | Location | Behaviour |
|---|---|---|
| `ComicArchiveOpener` | `archive/comic_archive_opener.dart` | Resolves local path; opens `.cbz`/`.zip`; rejects `.cbr`/`.rar` with conversion guidance |
| `CbzZipArchiveSource` | `archive/cbz_zip_archive_source.dart` | Lazy ZIP central-directory read; per-entry inflate on demand (M6.6) |
| `CbzZipLazyReader` | `archive/cbz_zip_lazy_reader.dart` | Metadata-only open; no full-archive RAM decode |
| `comic_path_safety.dart` | `archive/comic_path_safety.dart` | Rejects traversal, absolute paths; natural filename ordering; image extension filter |
| `ComicArchiveException` | `archive/comic_archive_errors.dart` | Classified, user-safe error taxonomy |

### Reader session

| Component | Location | Behaviour |
|---|---|---|
| `ComicReaderController` | `reader/comic_reader_controller.dart` | Page list/load; prev/next/first/last; adjacent prefetch; bounded cache integration |
| `ComicPageCache` | `reader/comic_page_cache.dart` | Default **5 entries**, **24 MiB** decoded-byte cap; LRU eviction; cleared on dispose |
| `ComicReaderScreen` | `reader/comic_reader_screen.dart` | Fullscreen scaffold; page image via `InteractiveViewer` (0.5–4× zoom); controls bar |
| `openComicReaderScreen` | `reader/comic_navigation.dart` | Entry from item detail; snackbar on failure; blocks unsupported formats before open |

### Navigation (Phase 6.3)

| Input | Action |
|---|---|
| ← / Page Up | Previous page |
| → / Page Down | Next page |
| Home / End | First / last page |
| Escape / AppBar back | Close reader |
| Toolbar | First / prev / next / last + `Page N of M` indicator |

### Tests (Phase 6.3)

| Test | Gate |
|---|---|
| `comic_archive_cbz_test.dart` | Unit — ordering, path safety, corrupt CBZ |
| `comic_archive_opener_test.dart` | Unit — CBZ open; CBR rejection message |
| `comic_reader_controller_test.dart` | Unit — navigation bounds, cache |
| `comic_page_cache_test.dart` | Unit — eviction policy |
| `phase_63_comic_reader_windows_runtime_test.dart` | Opt-in Windows — `PHASE_63_READER=1`, tag `phase63-reader` |

### Explicitly **not** Phase 6.3 baseline

The following are **out of scope for 6.3** and belong to **Phase 6.4C** or were partially pre-delivered in 6.5/6.6:

- Fit-width / fit-height presentation modes (beyond default `BoxFit.contain`)
- Mouse-wheel page turns; tap zones; swipe gestures
- Immersive chromeless reading mode
- Formal completion policy sign-off for comics
- Dedicated comic progress validation matrix (see §5 — shared repo exists; comic closure tests required)
- Pointer/zoom vs navigation conflict resolution policy

### Already in repo from later phases (audit — verify, do not reimplement)

| Capability | Delivered via | Notes |
|---|---|---|
| Reading progress persistence | Phase 6.5 — `ReadingProgressRepository`, `ReadingProgressCoordinator` | `ComicReadingLocationPayload`; key `ttsplayer_reading_progress_v1` |
| Continue Reading | Phase 6.5 — `ContinueReadingProjection`, dashboard section | Comic CBZ items; unsupported `.cbr` → `unsupportedComicFormat` |
| Resume on open | `ComicReaderScreen` + `resolveReadingRestore` | Restores page index; `startFromBeginning` / Read Again on detail |
| Lazy CBZ memory | Phase 6.6 — `CbzZipLazyReader` | Central directory only while open |
| Cache bounds | Phase 6.6 — `ComicPageCache` defaults | Telemetry via `ReaderSessionTelemetry` |
| Reader diagnostics aggregates | Phase 6.6 — `ReaderSessionDiagnostics` | Comic cache entry/byte counts; redacted export |

Phase 6.4C implementation must **begin with a gap audit** against this table before writing new persistence code.

---

## 2. Phase objective

Deliver a **Windows-first, production-quality CBZ comic reading experience** with **persistent, isolated reading progress**, while preserving future mobile compatibility.

Success means a user can open a CBZ from the catalogue, read with predictable navigation and presentation controls, leave and return to the last-read page, complete a comic with clear Continue Reading behaviour, and never affect video or music state — **without CBR, PDF, EPUB, or cloud sync scope**.

---

## 3. In scope

| Area | Requirement |
|---|---|
| **Navigation** | Deterministic prev/next/first/last; bounded indices; no wrap |
| **Keyboard** | Extend 6.3 contract; document focus ownership |
| **Pointer** | Mouse wheel page turns (when not zoom-panning); optional left/right tap zones on desktop |
| **Touch** | Swipe horizontal page turns where `ScrollConfiguration`/gesture arena allows; no double-fire with keyboard |
| **Presentation** | Fit-width, fit-height, contain (default); page indicator retained |
| **Zoom / pan** | Retain `InteractiveViewer`; explicit policy so zoom gestures do not change pages |
| **Immersive mode** | Optional chrome hide/show (AppBar + controls bar); Escape restores chrome then exits |
| **Progress** | Auto-save on page change (debounced); restore on open; prune on catalogue replace |
| **Completion** | Deterministic rule (§6); detail **Read Again** / **Start from Beginning** |
| **Cache** | Retain 6.6 bounds; configurable constants if justified; adjacent preload only |
| **Errors** | Single bad page must not block entire comic when other pages are valid |
| **Diagnostics** | Comic reader aggregates only; redaction rules unchanged |
| **Tests** | Unit, widget, isolation, optional Windows runtime harness extension |

---

## 4. Out of scope

| Exclusion | Notes |
|---|---|
| CBR / RAR / UnRAR (DLL, CLI, FFI, packaging) | Removed — ADR-026 Accepted CBZ-only |
| PDF / EPUB reading | Repo Phase 6.4 book reader — complete |
| Bookmarks, annotations, highlights | Post-M6 |
| Library metadata editing | Filesystem-is-truth |
| Dual-page spreads, manga RTL | Post-M6 |
| Cloud / multi-device sync | M7 |
| Favourites redesign | Unrelated |
| Video / music changes | Regression forbidden |
| In-app CBZ conversion | User converts externally |

---

## 5. Persistence architecture

### Design decision: shared versioned repository (ADR-027)

Comic progress **must not** use a separate preference file or duplicate prune logic. Follow **ADR-027 Accepted**:

| Layer | Type | Role |
|---|---|---|
| `ReadingProgressRecord` | Per-item envelope | Stable `mediaId`, `mediaKind: comic`, `readerFormat: cbz` |
| `ComicReadingLocationPayload` | Location | `pageIndex`, `pageCountAtSave`, optional `entryName`, `archiveFormat` |
| `ReadingProgressRepository` | Persistence | Schema version **1**; key `ttsplayer_reading_progress_v1` |
| `ReadingProgressCoordinator` | Session | Debounced writes; flush on close; completion handling |
| `ContinueReadingProjection` | Derived view | Not a filesystem folder |

### Isolation guarantees (must remain true)

| Store | Key namespace | Comic progress |
|---|---|---|
| Video resume | `position_*` (PlaybackService) | **No writes** |
| Music listening | ADR-022 repository | **No writes** |
| Music session | ADR-022 session repo | **No writes** |
| Reading progress | `ttsplayer_reading_progress_v1` | **Only** comic/book records |

Validate with existing `reading_progress_isolation_test.dart` patterns; extend for comic-specific regression cases.

### Persisted fields (comic records)

| Field | Source | Purpose |
|---|---|---|
| `mediaId` | Catalogue item id | Stable key (path rename loses progress — same as video) |
| `mediaKind` | `comic` | Routing |
| `readerFormat` | `cbz` | Reconciliation |
| `location.pageIndex` | Zero-based | Resume target |
| `location.pageCountAtSave` | At save time | Bounds check on restore |
| `location.entryName` | Optional | Entry-name reconciliation when page count shifts |
| `progressFraction` | Derived | Continue Reading sort + completion threshold |
| `completed` / `completedAt` | Policy §6 | Continue Reading exclusion |
| `lastReadAt` / `firstReadAt` | Timestamps | Ordering |
| `title`, `sourceBasename` | Snapshot | Display without catalogue (redacted in diagnostics export) |

### Restore behaviour matrix

| Condition | Behaviour |
|---|---|
| Reopen comic | Restore `pageIndex` if `0 ≤ index < pageCount`; else clamp to last valid page |
| Page count decreased | Prefer `entryName` match if present; else clamp index |
| Page count increased | Keep index if still valid |
| File missing | Item detail shows missing status; Continue Reading shows unavailability |
| Catalogue id gone | Pruned on catalogue replace / validation |
| Stored index out of bounds | Clamp to `pageCount - 1`; do not crash |
| User **Start from Beginning** | Coordinator restart; index 0; clears completion |
| User **Read Again** on completed | Opens from beginning; new session |
| Nearly complete (≥95%) | Mark completed per policy §6 |
| Legacy `.cbr` item | No open; no new progress writes; conversion guidance only |

No new catalogue schema fields. No writes to `catalog.json`.

---

## 6. Completion policy

Use existing **`ReadingProgressPolicy.completionThreshold = 0.95`** with comic-specific interpretation:

### Mark complete when

1. User reaches the **last page** (`pageIndex == pageCount - 1`) **and** remains there through a debounced save, **or**
2. `progressFraction ≥ 0.95` (covers last-page fraction for any page count ≥ 2).

For **single-page comics**, require explicit last-page navigation (index 0) **and** a minimum dwell — do **not** mark complete on open alone. Implementation: completion only when `pageCount > 1` uses fraction threshold **or** `(pageCount == 1 && user navigated away and back)` is unnecessary — **prefer**: single-page comics mark complete only when user closes reader after viewing (force save on close) rather than on first paint.

### After completion

| Surface | Behaviour |
|---|---|
| Continue Reading | Item **excluded** |
| Item detail | Shows **Completed**; primary action **Read Again** |
| Read Again | Opens page 1; clears completion via coordinator restart |
| Start from Beginning (mid-read) | Index 0; clears completion if set |

Progress for completed items may remain at final page in storage but is hidden from Continue Reading until restarted.

---

## 7. Reader state architecture

Existing split is **sufficient**; avoid new service layers.

| Responsibility | Owner |
|---|---|
| Page list, index, load state | `ComicReaderController` |
| Navigation bounds | Controller (`canGoPrevious` / `canGoNext`) |
| Progress save coordination | `ComicReaderScreen` → `ReadingProgressCoordinator` |
| Zoom / pan transform | `InteractiveViewer` (local widget state — **do not persist zoom**) |
| Fit mode | New enum on screen state (`ComicFitMode`: contain, fitWidth, fitHeight) |
| Cache / preload | Controller + `ComicPageCache` |
| Lifecycle / dispose | Controller disposes source + clears cache; screen closes coordinator session |
| Errors | Controller sets `ComicArchiveException`; screen shows `_ErrorPane` |

Optional: extract `_ComicViewport` widget for fit/zoom/gesture routing — only if screen file grows unwieldy.

Update stale comment on `ComicReaderController` (“no Phase 6.5 persistence”) during implementation.

---

## 8. Navigation contract

### Keyboard (page change)

| Key | Action |
|---|---|
| Left Arrow, Page Up | Previous page |
| Right Arrow, Page Down | Next page |
| Home | First page |
| End | Last page |
| Escape | If chrome hidden → show chrome; else close reader |
| F11 / optional | Toggle immersive (if implemented) |

Ignored when `EditableText` owns focus (existing rule).

### Mouse wheel

| Context | Behaviour |
|---|---|
| Viewport focused, scale == 1.0 | Wheel up → previous page; wheel down → next page |
| Viewport zoomed (scale ≠ 1.0) | Wheel pans vertically within viewer; **no page change** |
| Ctrl + wheel | Optional zoom in/out (if added); never changes page |

Use `Listener`/`ScrollConfiguration` with explicit consumption to avoid duplicate handling with `InteractiveViewer`.

### Pointer / touch

| Input | Action |
|---|---|
| Click left 25% of viewport | Previous page (desktop) |
| Click right 25% of viewport | Next page (desktop) |
| Horizontal swipe beyond threshold | Next/previous page (touch/trackpad) |
| Double-tap | **Out of scope** (avoid conflicting with zoom) |
| Pinch | Zoom within `InteractiveViewer` only |

Gesture arena: swipe handler must not fire when scale > 1.0 unless swipe starts at edge (document in implementation).

---

## 9. Rendering and performance

Baseline: **Phase 6.6** lazy CBZ + bounded cache — do not replace without measurement evidence.

| Policy | Value / rule |
|---|---|
| Default fit | `BoxFit.contain` (current) |
| Fit width | `BoxFit.fitWidth` — letterbox vertically |
| Fit height | `BoxFit.fitHeight` — letterbox horizontally |
| Zoom range | 0.5× – 4× (current `InteractiveViewer` limits) |
| Pan limits | `InteractiveViewer` default boundary margin |
| Decoded image lifetime | Held in `ComicPageCache` while reader open; evicted by LRU |
| Current page | Always retained until navigation or dispose |
| Adjacent preload | ±1 page only (`prefetchAdjacent = true`) |
| Cache max entries | **5** (default — change only with benchmark) |
| Cache max bytes | **24 MiB** decoded (default) |
| Large pages | Reject at archive layer if over configured uncompressed limit; user message on extract failure |
| Archive disposal | `ComicArchiveSource.dispose()` on controller dispose |
| Memory pressure | No OS-level handler in M6; rely on cache bounds + lazy I/O |

Constants live in `ComicPageCache` constructor defaults; expose as named constants if tests need shared values.

---

## 10. Error handling

| Failure | User-visible | Reader behaviour |
|---|---|---|
| Empty CBZ | “No readable pages” | Block open; snackbar on detail |
| Corrupt ZIP | “Archive appears damaged” | Block open |
| Non-ZIP renamed to `.cbz` | “Not a readable CBZ” | Block open |
| Unsupported image format in entry | Skip at list time if not image ext; else page error | Skip or per-page error |
| Corrupt single page | “This page could not be displayed” | Retry current page; prev/next still work |
| Decode failure | Same as corrupt page | Do not cache failure |
| Missing file | Detail missing/unavailable | No open |
| Archive changed while open | Next load may fail | Show error; allow close |

Diagnostics: `diagnosticDetail` uses basename + code only (existing contract).

---

## 11. Diagnostics

Extend **existing** reader session diagnostics — no new export sections unless aggregates missing.

| Signal | Safe to expose | Notes |
|---|---|---|
| `readerFormat` | `cbz` | From telemetry |
| Page index / page count | Aggregate in session only | Not per-title in export |
| Cache entries / bytes | Yes | Already in `ReaderSessionDiagnostics` |
| Last reader error kind | Classification string | No paths |
| Archive type | `cbz` | Not file path |
| Preload state | Optional counter | Implementation detail |

Do **not** add precise RSS / native memory. Preserve redaction in `diagnostics_export_formatter.dart`.

---

## 12. Testing strategy

### Unit

- `ComicReadingLocationPayload` JSON round-trip
- `ReadingProgressRecord.fractionForComic` edge cases (1 page, last page, empty)
- Completion normalisation at 0.95 threshold
- Restore plan clamping (`resolveReadingRestore` / `comicLocation`)
- Fit mode layout helpers (if extracted)

### Widget

- Keyboard navigation (existing `phase_63` patterns)
- Tap zones change page index
- Wheel at scale 1 vs zoomed — page vs pan
- Page indicator updates
- Error pane retry
- Progress coordinator called on page change (mock)

### Integration / isolation

- Comic progress write does not touch `position_*` or music keys
- Catalogue replace prunes stale comic ids
- Corrupted `ttsplayer_reading_progress_v1` JSON → recovery path

### Archive / reader

- Valid CBZ opens (existing)
- Nested paths natural order (existing)
- Corrupt CBZ (existing)
- Mislabeled RAR as `.cbz` rejected (existing)
- Single corrupt page in multi-page CBZ — navigation continues

### Windows runtime harness

Extend **`phase_63_comic_reader_windows_runtime_test.dart`** (not a new gate unless matrix grows large):

```powershell
$env:PHASE_63_READER='1'
flutter test test/phase_63_comic_reader_windows_runtime_test.dart --tags phase63-reader
```

Add scenarios: persist → simulated relaunch restore; completion → Continue Reading exclusion; wheel navigation smoke.

Optional: **`phase_64_comic_progress_windows_runtime_test.dart`** only if 6.3 harness becomes overcrowded — prefer extending 6.3 tag.

---

## 13. Implementation steps

### Step 1 — Planning and architecture ✅ (this document)

| | |
|---|---|
| **Scope** | Baseline audit, policies, test plan |
| **Files** | `docs/roadmap/m6-phase-6.4-comic-reading-experience.md`, release tracker entry |
| **Tests** | Doc link check |
| **DoD** | Stakeholder review; phase numbering note acknowledged |
| **Exclusions** | No production code |

### Step 2 — Progress gap audit and comic validation

| | |
|---|---|
| **Scope** | Verify 6.5 comic paths; add missing unit tests for restore/clamp/completion |
| **Files** | `reading_progress_*_test.dart`, `continue_reading_projection_test.dart` |
| **Tests** | Page restore, count change, completion, isolation |
| **DoD** | All comic progress unit tests green; gaps documented |
| **Exclusions** | No new repository type |

### Step 3 — Reader presentation and navigation

| | |
|---|---|
| **Scope** | Fit modes, wheel, tap zones, immersive toggle, gesture/zoom policy |
| **Files** | `comic_reader_screen.dart`, possible `comic_viewport.dart` |
| **Tests** | Widget tests for new inputs |
| **DoD** | Navigation contract §8 satisfied; no accidental double page turns |
| **Exclusions** | RTL, dual-page |

### Step 4 — Per-page error resilience

| | |
|---|---|
| **Scope** | Corrupt page does not block navigation; cache does not store failures |
| **Files** | `comic_reader_controller.dart`, fixtures in `comic_test_fixtures.dart` |
| **Tests** | Multi-page CBZ with one bad entry |
| **DoD** | User can skip past bad page |
| **Exclusions** | Archive repair |

### Step 5 — Diagnostics and docs sync

| | |
|---|---|
| **Scope** | Align `books-comics.md` comic section with CBZ-only + 6.4 capabilities; reader telemetry if gaps |
| **Files** | `docs/architecture/books-comics.md`, diagnostics if needed |
| **Tests** | Diagnostics export regression |
| **DoD** | No stale CBR/UnRAR references in active architecture docs |
| **Exclusions** | ADR-026 rewrite |

### Step 6 — Windows runtime and regression

| | |
|---|---|
| **Scope** | Extend phase 63 harness; full suite + analyze + Release build |
| **Files** | `phase_63_comic_reader_windows_runtime_test.dart` |
| **Tests** | Opt-in runtime + default CI suite |
| **DoD** | Matrix pass; video/music suites unchanged |
| **Exclusions** | Phase 7 work |

### Step 7 — Closure documentation

| | |
|---|---|
| **Scope** | Mark Phase 6.4C (this document) complete in release tracker; update `m6-plan.md` comic experience row |
| **Files** | `v0.7.0-dev.md`, `m6-plan.md` |
| **DoD** | Measured results recorded; known limitations listed |
| **Exclusions** | M6 milestone audit (separate) |

---

## 14. Definition of done

Phase 6.4C (comic reading experience closure) is **complete** when:

- [ ] CBZ comics open through the production reader path
- [ ] Last-read page saves and restores reliably (ADR-027 repository)
- [ ] Progress uses shared schema-versioned store; **no** video/music key writes
- [ ] Navigation is deterministic and bounded (keyboard, wheel, tap, swipe per §8)
- [ ] Fit modes and zoom/pan follow §9 without accidental page changes
- [ ] Completion policy §6 implemented and tested
- [ ] Large comics remain responsive under cache bounds
- [ ] Malformed archives and single bad pages fail gracefully
- [ ] Diagnostics remain redacted
- [ ] Unit + widget tests pass; Windows opt-in harness extended and documented
- [ ] Architecture docs updated; **no CBR/UnRAR reintroduction**
- [ ] This document status → **Complete**

---

## ADR review (Phase 6.4C planning)

| ADR | Action |
|---|---|
| **ADR-024** (catalogue schema) | **No change required** for 6.4 — update checklist: remove “Phase 6.3 Gate 0 CBR” item when next editing ADR-024 for CBZ-only hygiene |
| **ADR-025** (identity/metadata) | **No change required** |
| **ADR-026** (reader surfaces) | **Accepted** — CBZ-only; no amendment |
| **ADR-027** (reading progress) | **Accepted** — comic progress uses existing repository; **no new ADR** |
| **New ADR** | **Not recommended** — navigation/fit/zoom contract belongs in this phase doc and `books-comics.md`; persistence already decided in ADR-027 |

---

## Assumptions and unresolved decisions

| Item | Status |
|---|---|
| Single-page comic completion rule | Proposed §6 — confirm during Step 2 |
| Mouse wheel at zoom == 1 only | Proposed §8 — confirm UX |
| Immersive chrome hide | In scope but optional for Step 3 MVP |
| Separate `phase_64` harness file | Defer unless 6.3 harness exceeds ~400 lines |
| Phase numbering vs `m6-plan.md` | Documented §alignment — no renumbering of book reader phase |

---

## References

- `client/ttsplayer/lib/features/comics/`
- `client/ttsplayer/lib/features/reading/`
- `client/ttsplayer/test/phase_63_comic_reader_windows_runtime_test.dart`
- `docs/roadmap/m6-phase-6.6-reader-hardening.md` (cache/lazy CBZ evidence)
