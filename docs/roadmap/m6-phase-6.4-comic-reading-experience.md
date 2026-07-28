# M6 Phase 6.4C — Comic Reading Experience Closure

**Status:** ✅ **Complete** (2026-07-28) — Steps 1–7 closed on `m6-development`
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

Optional: **`phase_64c_comic_progress_test.dart`** for progress-only validation; extend **`phase_63_comic_reader_windows_runtime_test.dart`** for reader UX runtime (Step 6).

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

### Step 2 — Progress gap audit and comic validation ✅

| | |
|---|---|
| **Scope** | Verify 6.5 comic paths; add missing unit tests for restore/clamp/completion |
| **Files** | `phase_64c_comic_progress_test.dart`, `reading_progress_coordinator.dart`, `reading_progress_record.dart`, `reading_progress_policy.dart`, `reading_progress_test_support.dart` |
| **Tests** | 32 scenarios in `phase_64c_comic_progress_test.dart` |
| **DoD** | All comic progress unit tests green; gaps documented below |
| **Exclusions** | No new repository type; no reader UI changes |

#### Step 2 audit — existing behaviour confirmed

| Area | Finding |
|---|---|
| Restore path | `openComicReaderScreen` → `resolveReadingRestore` → `ComicReaderScreen` restore via `ReadingProgressRestorePlan.comicLocation` |
| Debounced save | `ComicReaderScreen._persistProgress` → `ReadingProgressCoordinator.onLocationChanged` (2 s debounce) |
| Close flush | `onReaderClosed` drains debounce then flushes |
| Multi-page completion | Last page fraction ≥ 0.95 marks complete immediately |
| Continue Reading | Completed records excluded; legacy CBR → `unsupportedComicFormat` |
| Isolation | `ttsplayer_reading_progress_v1` only; video/music keys untouched |
| Reconciliation | Entry-name match, index clamp, document-changed fallback — covered in Phase 6.5 |

#### Step 2 gaps fixed (production)

| Gap | Fix |
|---|---|
| Single-page comic marked complete on open (`fractionForComic(0,1)==1.0`) | `fractionForComic` returns `singlePageComicInProgressFraction` (0.5) for one-page comics; completion on `onReaderClosed` after layout ready |
| Completion cleared when navigating back from last page | Sticky completion: `session.completed \|\| isCompletedFraction(...)` until explicit restart |
| Stale controller doc comment | Updated `comic_reader_controller.dart` |

#### Step 2 single-page completion policy (confirmed)

- **While open:** progress fraction stays at **0.5** (below 0.95 threshold); `completed` remains false.
- **On close:** after layout ready, single-page comic is marked complete and flushed.
- **Read Again:** `comic_navigation` calls `beginSession` + `onReaderRestarted` before opening reader (clears completion, page 0).

#### Step 2 tests added

- `test/phase_64c_comic_progress_test.dart` — restore/reconciliation, lifecycle, completion, isolation, legacy CBR projection.
- `phase65BeginComicSession` helper in `reading_progress_test_support.dart`.

#### Deferred to Step 4

Per-page corrupt-image resilience.

### Step 3 — Reader presentation and navigation ✅

| | |
|---|---|
| **Scope** | Fit modes, wheel, tap zones, swipe, zoom/pan contract, immersive chrome |
| **Files** | `comic_fit_mode.dart`, `comic_viewport.dart`, `comic_reader_screen.dart`, `phase_64c_comic_reader_interaction_test.dart` |
| **Tests** | 16 widget scenarios in `phase_64c_comic_reader_interaction_test.dart` |
| **DoD** | Input routing deterministic; progress unchanged by display settings |
| **Exclusions** | Corrupt-page resilience (Step 4) |

#### Step 3 input contract (implemented)

| Input | At base transform | When zoomed |
|---|---|---|
| ← / → / Page Up / Down / Home / End | One bounded page change | Same (keyboard unaffected) |
| Escape | Show chrome if hidden; else close | Same |
| Mouse wheel | Previous / next (120 px threshold) | No page change |
| Tap left 25% / right 25% | Previous / next | Disabled |
| Tap centre 50% | Toggle chrome | Disabled |
| Horizontal swipe (contain only) | Previous / next (48 px min) | Pan only; no page change |
| Pinch / drag in viewer | Zoom / pan | — |

#### Fit modes

- **Contain** (default) — `BoxFit.contain`
- **Fit width** — `BoxFit.fitWidth`
- **Fit height** — `BoxFit.fitHeight`

Fit mode and page changes reset `InteractiveViewer` transform. Zoom/pan/fit/chrome are **not** persisted.

#### Known limitations (Step 3)

- Swipe page turns enabled only in **Contain** at base transform (conflict-safe subset with `InteractiveViewer`).
- Wheel routing uses `Listener.onPointerSignal` in production; widget tests use `debugWheelDelta`.
- Fit-width/height overflow pans via `InteractiveViewer`; no separate scroll view.

#### Deferred to Step 5

Diagnostics expansion; `books-comics.md` CBZ-only refresh.

### Step 4 — Per-page error resilience ✅

| | |
|---|---|
| **Scope** | Distinguish archive-level vs page-level failures; placeholder, retry, preload and progress on failed pages |
| **Files** | `comic_page_failure.dart`, `comic_reader_controller.dart`, `comic_reader_screen.dart`, `comic_viewport.dart`, `phase_64c_comic_page_error_test.dart`, `comic_reader_controller_test.dart` |
| **Tests** | 28 scenarios in `phase_64c_comic_page_error_test.dart`; archive-level cases reuse `comic_archive_cbz_test.dart` / `comic_archive_opener_test.dart` |
| **DoD** | One corrupt page does not block navigation, retry, or progress; archive open failures unchanged |
| **Exclusions** | Diagnostics expansion (Step 5); live archive rebuild |

#### Step 4 error boundaries (implemented)

| Layer | Failure | Behaviour |
|---|---|---|
| **Archive (pre-open)** | Missing file, invalid ZIP, empty archive, no image entries, path traversal, CBR | Existing opener/detail path; reader does not open without a page list |
| **Archive (post-open)** | Source removed/changed on uncached load | Page-level `sourceMissing` / `archiveReadFailure`; cached pages still readable |
| **Page load** | Entry extract failure, unsupported bytes | `_pageFailures` map; controller stays `ready`; `_ErrorPane` only when `pages.isEmpty` |
| **Page decode** | `Image.memory` decode failure | `reportCurrentPageDecodeFailed()` → `decodeFailure` category; single callback via `errorBuilder` |
| **Preload** | Adjacent page fails | Recorded silently; current page undisturbed; no cache entry for failed load |

#### Page-load state contract

- `ComicPageLoadStatus`: `notRequested`, `loading`, `loaded`, `failed`
- `ComicPageFailure`: entry name, `ComicPageFailureCategory`, safe `userMessage`, `canRetry`
- Failures are **not** stored in `ComicPageCache`; failed entries do not consume LRU slots

#### Current-page failure UI

- `_PageFailurePane`: user message, `Page N of M`, optional **Retry** button
- Toolbar navigation, back, and Escape (immersive) remain available
- Page count and indices unchanged when pages fail (stable progress identity)

#### Retry policy

- User-initiated only via toolbar placeholder or `retryCurrentPage()`
- Clears failure + cache entry for that page; reloads one page only
- Ignored while the same page is already loading; repeated failures return to stable placeholder
- Does not write reading progress or change page index

#### Progress on failed pages

- Navigation onto a failed page persists logical `pageIndex` through existing coordinator path
- Retry does not create duplicate progress writes
- Close on failed page flushes progress normally
- Completion policy unchanged (Step 2); decode failure alone does not mark complete

#### Known limitations (Step 4)

- No live archive rebuild when source changes mid-session
- Widget-level decode placeholder text is transient until controller state updates

### Step 5 — Diagnostics and docs sync ✅

| | |
|---|---|
| **Scope** | Redacted comic-reader diagnostics; `books-comics.md` CBZ-only refresh; roadmap terminology |
| **Files** | Telemetry, diagnostics service/export/UI, comic reader wiring, `phase_64c_comic_reader_diagnostics_test.dart`, `books-comics.md`, `m6-plan.md` |
| **Tests** | 12 scenarios in `phase_64c_comic_reader_diagnostics_test.dart`; diagnostics/redaction/screen tests updated |
| **DoD** | Comic reader diagnostics subsection; architecture doc matches production CBZ-only reader |
| **Exclusions** | Windows runtime (Step 6); phase closure (Step 7) |

#### Step 5 diagnostics contract

Active CBZ reader sessions expose: active flag, archive type, redacted item identity, page N/M, fit mode, chrome visibility, base/zoomed view state, successful cache metrics and limits, failed-page count, current failure category, retry availability, last safe error category, progress session flags. Pull-only via `ReaderSessionTelemetry`; cleared on reader dispose.

#### Deferred to Step 6

Windows runtime harness extension; final phase closure documentation.

### Step 6 — Windows runtime and regression ✅

| | |
|---|---|
| **Scope** | Extend Phase 6.3 opt-in harness for Phase 6.4C closure scenarios |
| **Files** | `phase_63_comic_reader_windows_runtime_test.dart`, `phase_64c_comic_progress_test.dart` (session wiring regression), `comic_reader_screen.dart` (progress-session race fix) |
| **Tests** | 13 opt-in runtime cases + default CI suite |
| **DoD** | Matrix documented; runtime evidence recorded; no CBR/UnRAR |
| **Exclusions** | Phase 7 closure sign-off |

#### Runtime environment (2026-07-28)

| Item | Value |
|---|---|
| OS | Windows 10.0.26200 |
| Flutter | 3.44.4 (stable) |
| Dart | 3.12.2 |
| Build | `flutter build windows --release` → `build\windows\x64\runner\Release\ttsplayer.exe` ✅ |
| Runtime command | `$env:PHASE_63_READER='1'; flutter test test/phase_63_comic_reader_windows_runtime_test.dart --tags phase63-reader` |
| Runtime result | **Run 1:** 13 passed, 0 failed · **Run 2:** 13 passed, 0 failed |
| Default suite | **1423 passed, 16 skipped** (includes opt-in skip when `PHASE_63_READER` unset) |
| CBR / UnRAR | Not required |

#### Runtime hardening notes (resolved before final runs)

During harness extension, interim failures exposed and resolved:

- progress coordinator provider wiring (`ChangeNotifierProvider` for coordinator);
- a fast-open progress-session race when archive listing completed before coordinator binding (production fix + regression test);
- deterministic async waits for production-path CBZ open and page-indicator readiness.

These were fixed before the final successful Run 1 and Run 2 executions above. Interim development failures are not recorded as final validation results.

#### Fixtures (runtime-generated under `%TEMP%`)

| Fixture | Purpose |
|---|---|
| **Multi-page CBZ** (8 pages, byte-distinct `tinyPng`) | Ordering, navigation, restore, completion, diagnostics |
| **Single-page CBZ** | Step 2 completion-on-close policy |
| **Partially corrupt CBZ** (`page_001` valid, `page_002` invalid bytes, `page_003` valid) | Page-level failure placeholder |
| **Invalid archive CBZ** (64 × `0x7F` bytes) | Controlled pre-open archive error (Phase 6.3 baseline retained) |

#### Scenario matrix (C1–C34)

| ID | Scenario | Classification |
|---|---|---|
| C1 | Production path opens valid CBZ | Automated runtime |
| C2 | Page 1 / total indicator | Automated runtime |
| C3 | Contain default fit mode | Automated runtime |
| C4 | Chrome visible on open | Automated runtime |
| C5 | Active telemetry: CBZ, redacted identity | Automated runtime |
| C6 | Right Arrow forward | Automated runtime |
| C7 | Left Arrow back | Automated runtime |
| C8 | Home first page | Automated runtime |
| C9 | End last page | Automated runtime |
| C10 | Bounded at edges | Automated runtime |
| C11 | Mouse wheel at base transform | Widget automated (`phase_64c_comic_reader_interaction_test.dart`, `debugWheelDelta`) |
| C12 | Fit Width via toolbar | Automated runtime |
| C13 | Fit Height via toolbar | Widget automated (`phase_64c_comic_reader_interaction_test.dart`; popup exceeds 800px test surface) |
| C14 | Immersive toggle hides/restores chrome | Automated runtime |
| C15 | Escape restores hidden chrome | Automated runtime |
| C16 | Navigate + close flush | Automated runtime |
| C17 | Reopen restores saved page | Automated runtime |
| C18 | Close before debounce persists latest page | Automated runtime |
| C19 | Final page completion | Automated runtime |
| C20 | Completed comic excluded from Continue Reading | Automated runtime |
| C21 | Read Again opens page 1 | Automated runtime |
| C22 | Single-page not complete on open | Automated runtime |
| C23 | Single-page completes on close | Automated runtime |
| C24 | Single-page Read Again | Widget automated (`phase_64c_comic_progress_test.dart`) |
| C25 | Open partially corrupt CBZ | Automated runtime |
| C26 | Navigate to corrupt logical page | Automated runtime |
| C27 | Page failure placeholder | Automated runtime |
| C28 | Page indicator remains correct | Automated runtime |
| C29 | Navigate to valid page after corrupt page | Widget automated (`phase_64c_comic_page_error_test.dart`) |
| C30 | Retry safe on failed page | Automated runtime (retry control present) |
| C31 | Close on failed page flushes logical progress | Automated runtime |
| C32 | Active diagnostics fields | Automated runtime |
| C33 | Export redaction (no temp paths) | Automated runtime |
| C34 | Telemetry cleared after reader dispose | Automated runtime |
| — | Invalid archive graceful error | Automated runtime (Phase 6.3 baseline) |
| — | Debug-controller keyboard path | Support-hook validated (Phase 6.3 baseline retained) |

#### Production paths exercised

Real `ComicArchiveOpener`, lazy CBZ source, `ComicReaderController`, `ComicReaderScreen`, `ComicViewport`, `ReadingProgressRepository`, `ReadingProgressCoordinator`, `ReaderSessionTelemetry`, diagnostics export formatter, toolbar and keyboard routing.

#### Runtime defect found and fixed

**Progress session race:** when CBZ `open()` completed before `ReadingProgressCoordinator` was bound, `_ensureProgressSessionStarted()` could mark the session begun without calling `beginSession`, leaving progress writes disabled. Fixed by deferring `_progressSessionBegun` until `_coordinator` is non-null. Regression: `phase_64c_comic_progress_test.dart` — “fast CBZ open still begins coordinator session”.

#### Known limitations

- Native pointer-wheel dispatch under `flutter test` not asserted (C11).
- Fit Height menu item clipped at default 800px surface height (C13).
- Post-corrupt navigation to next valid page validated in widget tests with fake source (C29).
- Visual zoom/pan smoothness: not required.

#### Deferred to Step 7

~~Formal phase closure sign-off and Definition of Done checklist completion.~~ → **Complete** (see §15).

### Step 7 — Closure audit and documentation ✅

| | |
|---|---|
| **Scope** | Definition-of-done audit; test/evidence inventory; limitations disposition; release and M6 plan sync |
| **Files** | This document, `v0.7.0-dev.md`, `m6-plan.md` |
| **DoD** | All §14 items verified with cited evidence; phase status → **Complete** |
| **Exclusions** | M6 milestone audit (separate) |

---

## 14. Definition of done

Phase 6.4C (comic reading experience closure) is **complete** (2026-07-28):

- [x] CBZ comics open through the production reader path
- [x] Last-read page saves and restores reliably (ADR-027 repository)
- [x] Progress uses shared schema-versioned store; **no** video/music key writes
- [x] Navigation is deterministic and bounded (keyboard, wheel, tap, swipe per §8)
- [x] Fit modes and zoom/pan follow §9 without accidental page changes
- [x] Completion policy §6 implemented and tested
- [x] Large comics remain responsive under cache bounds
- [x] Malformed archives and single bad pages fail gracefully
- [x] Diagnostics remain redacted
- [x] Unit + widget tests pass; Windows opt-in harness extended and documented
- [x] Architecture docs updated; **no CBR/UnRAR reintroduction**
- [x] This document status → **Complete**

Full evidence: §15.

---

## 15. Phase closure (2026-07-28)

### 15.1 Objective outcome

Phase **6.4C** closes the comic-specific reading experience on the existing Phase 6.3 CBZ foundation: production-path progress persistence, reader interaction contract, per-page error resilience, redacted diagnostics, and Windows runtime validation — **CBZ-only**, with no CBR/UnRAR production dependency.

### 15.2 Implementation summary

| Area | Outcome |
|---|---|
| Progress | ADR-027 repository; debounced writes; close flush; restore/reconciliation; single-page completion-on-close; multi-page threshold completion |
| Interaction | Contain default; fit width/height; keyboard/wheel/tap/swipe contract; immersive chrome; zoom/pan without accidental page turns |
| Resilience | Archive-level block; page-level placeholders; retry; preload isolation |
| Diagnostics | Pull-based snapshot + session-scoped telemetry; redacted export |
| Runtime | Extended Phase 6.3 opt-in harness; progress-session race fix |

### 15.3 Commit matrix

| Step | SHA | Message (summary) |
|---|---|---|
| Planning | `0a8b0a4bd68881143e06f5914f6390d24077e712` | `docs(m6): plan Phase 6.4C comic reading closure` |
| Step 2 | `a12a1e25e2a52f2f2abf3209de84149c3e4bb230` | `feat(m6.4c): validate comic progress and fix completion gaps` |
| Step 3 | `f9f9f728f9de3842c0ee62ea2406913e826e9052` | `feat(m6.4c): add comic reader fit modes and input routing` |
| Step 4 | `4d3ac927113cddc3ff27f3734d849e8b4d02f91e` | `feat(m6.4c): add per-page comic error resilience` |
| Step 5 | `90554cdaaa01eb04ff827e3bd8836ffc6f00d2f3` | `feat(m6.4c): add comic reader diagnostics and refresh architecture docs` |
| Step 6 | `bc015c32dc5529983b85a8595d1edb81b368a30d` | `test(m6.4c): extend Windows comic reader runtime validation` |
| Step 7 | *(this closure commit)* | `docs(m6.4c): close comic reading experience phase` |

### 15.4 Test and runtime evidence inventory

| Evidence | Count / result | Primary files |
|---|---|---|
| Step 2 progress tests | 32 scenarios | `phase_64c_comic_progress_test.dart` |
| Step 3 interaction tests | 16 scenarios | `phase_64c_comic_reader_interaction_test.dart` |
| Step 4 page-error tests | 28 scenarios | `phase_64c_comic_page_error_test.dart` |
| Step 5 diagnostics tests | 12 scenarios | `phase_64c_comic_reader_diagnostics_test.dart` |
| Step 6 Windows runtime | 13 passed ×2 | `phase_63_comic_reader_windows_runtime_test.dart` |
| Archive / opener / controller / cache (reused) | existing suite | `comic_archive_*`, `comic_reader_controller_test.dart` |
| **Phase 6.4C focused total** | **88 widget/unit scenarios** | four `phase_64c_*` files |
| **Default Flutter suite (2026-07-28)** | **1423 passed, 16 skipped** | `flutter test` |
| **Windows Release build** | ✅ | `flutter build windows --release` |
| **Runtime Run 1** | 13 passed, 0 failed | `PHASE_63_READER=1`, tag `phase63-reader` |
| **Runtime Run 2** | 13 passed, 0 failed | consecutive repeatability |

### 15.5 Definition-of-done matrix

| Requirement | Status | Implementation | Automated tests | Runtime | Limitation / disposition |
|---|---|---|---|---|---|
| CBZ production reader path | ✅ | `comic_navigation.dart`, `ComicReaderScreen` | progress, interaction, page-error | C1 | — |
| CBR blocked from reader | ✅ | `isSupportedComicArchiveExtension`, detail UI | progress legacy CBR projection | — | Conversion guidance only |
| No UnRAR dependency | ✅ | CBR code removed; ADR-026 Accepted | opener rejects `.cbr` | — | Out of scope |
| Save / restore last page | ✅ | `ReadingProgressCoordinator`, restore plan | `phase_64c_comic_progress_test.dart` | C16–C17 | — |
| Entry-name reconciliation | ✅ | `resolveReadingRestore`, `comicLocation` | progress restore tests | C17 | — |
| Close flush before debounce | ✅ | `onReaderClosed`, `drainPendingWrites` | progress + close tests | C18 | — |
| Multi-page completion threshold | ✅ | `ReadingProgressPolicy.completionThreshold` | progress completion tests | C19–C21 | — |
| Single-page complete on close | ✅ | `_maybeCompleteSinglePageComicOnClose` | progress single-page tests | C22–C23 | — |
| Completed excluded from Continue Reading | ✅ | `ContinueReadingProjection` | progress projection tests | C20 | — |
| Read Again page one | ✅ | `onReaderRestarted`, `startFromBeginning` | progress Read Again tests | C21 | C24 widget-automated |
| Completion sticky until restart | ✅ | coordinator session policy | progress tests | — | — |
| Comic isolation from video/music | ✅ | `ttsplayer_reading_progress_v1` key only | isolation tests | — | — |
| Contain default fit | ✅ | `ComicFitMode.contain` | interaction tests | C3 | — |
| Fit Width / Fit Height | ✅ | toolbar menu | interaction tests | C12 | C13 fit height: widget-automated (800px surface) |
| Bounded keyboard navigation | ✅ | `ComicReaderScreen` key routing | interaction + runtime | C6–C10 | — |
| Wheel at base transform | ✅ | `ComicViewport` wheel handler | interaction (`debugWheelDelta`) | — | C11 widget-automated |
| Tap zones / chrome toggle | ✅ | viewport + toolbar | interaction tests | C14 | — |
| Swipe (contain, base transform) | ✅ | viewport drag | interaction tests | — | No swipe in fit width/height overflow |
| Zoom/pan no accidental page turn | ✅ | transform gate in viewport | interaction tests | — | Accepted limitation |
| Page/fit change resets transform | ✅ | `_resetViewportForPageChange` | interaction tests | — | — |
| Immersive chrome hide/restore | ✅ | `_toggleChrome`, Escape | interaction tests | C14–C15 | — |
| Central `_navigatePage` path | ✅ | all input routes | interaction tests | — | — |
| Lazy CBZ access | ✅ | `CbzZipArchiveSource` | archive tests | production path | — |
| Bounded cache | ✅ | `ComicPageCache` limits | controller/cache tests | diagnostics C32 | — |
| Adjacent preload | ✅ | `prefetchAdjacent` | controller tests | C1 multi-page | — |
| Failed pages excluded from cache metrics | ✅ | cache + telemetry | page-error, diagnostics | C32 | — |
| No eager full-archive decode | ✅ | lazy per-page load | archive tests | — | — |
| Archive-level failure blocks open | ✅ | `ComicArchiveOpener` | opener tests | invalid archive | — |
| Page failure keeps reader open | ✅ | `_PageFailurePane` | page-error tests | C25–C28 | — |
| Stable page count | ✅ | controller index bounds | page-error tests | C28 | — |
| Retry user-initiated | ✅ | `retryCurrentPage` | page-error tests | C30 | — |
| Preload failure isolated | ✅ | controller prefetch logic | page-error preload tests | — | — |
| Safe failure categories | ✅ | `ComicPageFailureCategory` | diagnostics tests | C32 | — |
| Close on failed page flushes progress | ✅ | coordinator on close | page-error tests | C31 | — |
| Active comic diagnostics | ✅ | `ReaderSessionTelemetry` | diagnostics tests | C32–C34 | — |
| Redaction / session ownership | ✅ | session IDs, redaction helpers | diagnostics + redaction tests | C33–C34 | — |
| `books-comics.md` CBZ-only | ✅ | architecture refresh Step 5 | — | — | — |
| Full suite green | ✅ | — | 1423 passed, 16 skipped | — | — |
| Runtime harness ×2 | ✅ | — | — | Run 1 & Run 2: 13/13 | — |

### 15.6 Known limitations and disposition

| Limitation | Disposition |
|---|---|
| C11 wheel not runtime-automated under `flutter test` | **Accepted** — widget-automated via `debugWheelDelta` in Step 3 |
| C13 fit-height menu clipped at 800px test surface | **Accepted** — fit height validated in widget tests |
| C24 single-page Read Again | **Widget automated** — `phase_64c_comic_progress_test.dart` |
| C29 navigate past corrupt page in real CBZ | **Widget automated** — fake source in page-error tests |
| Swipe page turns only in Contain at base transform | **Accepted limitation** — documented §8/§9 |
| No swipe in Fit Width/Height overflow | **Approved deferral** — conflict-safe subset |
| No live archive rebuild after source replacement | **Accepted limitation** — Step 4 |
| Brief widget decode fallback before controller placeholder | **Accepted limitation** — Step 4 |
| Cross-format reader-session aggregates separate from comic subsection | **Accepted** — diagnostics architecture |
| No bookmarks, annotations, dual-page, RTL, cloud sync | **Out of scope** — M6 |
| No CBR production support | **Out of scope** — ADR-026 Accepted; external conversion |
| Visual zoom/pan smoothness | **Not required** — runtime observational |

### 15.7 Format and dependency confirmation

- **Production comic format:** CBZ only (`.cbz`).
- **CBR/RAR:** not supported; users convert externally to CBZ and rescan.
- **UnRAR:** no runtime, packaging, or Release-build dependency remains.

**Phase 6.4C is formally closed.** M6 milestone completion remains subject to separate M6 closure audit.

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
| Single-page comic completion rule | **Implemented** §6 — Step 2 |
| Mouse wheel at zoom == 1 only | **Implemented** §8 — Step 3 |
| Immersive chrome hide | **Implemented** — Step 3 |
| Separate `phase_64` harness file | **Not needed** — extended Phase 6.3 harness |
| Phase numbering vs `m6-plan.md` | **Resolved** — 6.4C distinct from repo Phase 6.4 |

---

## References

- `client/ttsplayer/lib/features/comics/`
- `client/ttsplayer/lib/features/reading/`
- `client/ttsplayer/test/phase_63_comic_reader_windows_runtime_test.dart`
- `docs/roadmap/m6-phase-6.6-reader-hardening.md` (cache/lazy CBZ evidence)
