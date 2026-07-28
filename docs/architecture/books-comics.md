# Books & Comics Architecture (M6)

**Status:** Active — Phase 6.3 ✅ **Complete** (CBZ comic reader); Phase 6.4 ✅ **Complete** (book reader); Phase 6.5 ✅ **Complete** (reading progress); Phase 6.6 ✅ **Complete** (reader hardening); Phase **6.4C** ✅ **Complete** (2026-07-28)

**Milestone plan:** [m6-plan.md](../roadmap/m6-plan.md) · [Phase 6.4C](../roadmap/m6-phase-6.4-comic-reading-experience.md)
**Related ADRs:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [ADR-025](./decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md) · [ADR-027](./decisions/ADR-027-reading-progress-and-continue-reading.md)

> **Production comic format:** **CBZ only**. CBR/RAR is not supported. Legacy `.cbr` catalogue entries show external conversion guidance. UnRAR DLL, CLI, FFI and packaging integrations were removed (ADR-026 **Accepted**).

---

## Purpose

Describe how books and comics fit into TTSPlayer’s folder-first, provider-neutral platform without inventing categories, parallel catalogues, or silent absorption of deferred music work.

---

## Supported formats

| Kind | Production formats | Reader |
|---|---|---|
| **Comic** | **`.cbz`** (ZIP-based comic archive) | `ComicReaderScreen` |
| **Book** | `.pdf`, `.epub` | `BookReaderScreen` |
| Video / audio / image | Unchanged | Existing surfaces |

**CBR/RAR:** not supported directly. Users convert externally to CBZ and rescan. The indexer may still list legacy `.cbr` paths from an older catalogue; the client blocks open and shows conversion guidance.

---

## Design constraints (inherited)

| Constraint | Implication |
|---|---|
| Filesystem is truth | Folder names are the only library categories |
| Catalogue principle | No virtual “All Books” / “All Comics” roots |
| Graceful degradation | Missing cover/metadata still shows the item |
| Item status model | Status gates playability; unknown status is safe |
| Local-first | Readers work offline against local/NAS paths |
| Reuse infrastructure | Providers, resolver, search, artwork, cache, diagnostics |

---

## Catalogue and scanner

- Indexer emits `media_kind: book` or `comic` for supported extensions
- Client `CatalogueInfo.maxSupportedCatalogueVersion` is **4**
- Browse, search, and detail surfaces show kind labels without hardcoded category names
- Comic detail: **Open Comic** → CBZ reader; book detail: **Open Book** → PDF/EPUB reader

---

## Comic archive architecture (`lib/features/comics/archive/`)

| Component | Role |
|---|---|
| `ComicArchiveOpener` | Resolve local path; open `.cbz`/`.zip`; reject `.cbr`/`.rar` with conversion guidance |
| `ComicArchiveSource` | List pages, load bytes, dispose — implementation-neutral contract |
| `CbzZipArchiveSource` | Lazy ZIP central-directory read; per-entry inflate on demand |
| `CbzZipLazyReader` | Metadata-only open; no full-archive RAM decode |
| `comic_path_safety.dart` | Reject traversal and absolute paths; natural filename ordering; supported image extensions only |
| `ComicArchiveException` | Classified, user-safe error taxonomy |

**Archive-level failures** (missing file, invalid ZIP, empty archive, no supported image entries, path-safety rejection) occur before the reader opens. The detail screen / opener shows a controlled error; the reader is not created without a valid page list.

**Page list stability:** unsupported image extensions are excluded at list time. Entries with supported extensions but corrupt bytes remain in the logical page list so page indices and reading progress stay stable.

---

## Comic reader architecture (`lib/features/comics/reader/`)

| Component | Role |
|---|---|
| `ComicReaderController` | Page list, index, load state, adjacent prefetch, bounded cache, per-page failure map |
| `ComicPageCache` | Default **5 entries**, **24 MiB** decoded-byte cap; LRU eviction; failed loads never cached |
| `ComicReaderScreen` | Fullscreen scaffold, progress coordination, immersive chrome, fit mode, input routing |
| `ComicViewport` | Fit modes, wheel/tap/swipe, `InteractiveViewer` zoom/pan, decode error callback |
| `ComicFitMode` | Contain (default), fit width, fit height — not persisted |
| `ComicPageFailure` | Typed per-page failure categories for UI and diagnostics |
| `openComicReaderScreen` | Entry helper; snackbar on controlled failure |

### Navigation (Phase 6.4C)

All page changes route through a single navigation path (`_navigatePage` / controller `goToIndex`).

| Input | Behaviour |
|---|---|
| ← / → / Page Up / Down / Home / End | Bounded page change |
| Escape | Show chrome if hidden; else close |
| Mouse wheel (base transform) | Previous / next page |
| Side tap zones (25% / 50% / 25%) | Previous / next / toggle chrome |
| Horizontal swipe (contain, base transform) | Previous / next |
| Pinch / drag in viewer | Zoom / pan only — no page change |

Fit mode and page changes reset transform. Zoom, fit mode and chrome visibility are **not** persisted.

### Cache and preload

- Current page retained until navigation or dispose
- Adjacent ±1 preload when enabled
- Preload failures recorded per page without disturbing the active page
- Failed pages do not consume cache slots

### Per-page error handling (Phase 6.4C Step 4)

| Failure | Behaviour |
|---|---|
| Single corrupt / undecodable page | Page-level placeholder; prev/next/retry; reader stays open |
| Preload failure | Silent record; placeholder when navigated to |
| Archive removed after open | Uncached loads fail per-page; cached pages remain readable |
| Archive open failure | Global error before reader creation (unchanged) |

Retry is user-initiated only; clears failure and reloads one page; does not write progress.

---

## Book reader architecture (`lib/features/books/`)

Phase 6.4 **complete**. PDF via `pdfrx`; EPUB via TTSPlayer parser + `flutter_html`. See [pdf-epub-evaluation.md](./pdf-epub-evaluation.md).

---

## Reading progress (Phase 6.5 + ADR-027)

| Layer | Role |
|---|---|
| `ReadingProgressRepository` | Schema version **1**; key `ttsplayer_reading_progress_v1` |
| `ComicReadingLocationPayload` | `pageIndex`, `pageCountAtSave`, optional `entryName` |
| `ReadingProgressCoordinator` | Debounced writes; flush on close; completion handling |
| `ContinueReadingProjection` | Derived dashboard view — not a filesystem folder |

**Comic policies:**

- Restore clamps/reconciles by entry name when page count shifts
- Multi-page completion at **≥ 0.95** fraction on last page
- Single-page comics: in-progress while open; complete on close after viewing
- **Read Again** clears completion and opens from page 1

**Isolation:** comic/book progress never writes video `position_*` or music persistence keys.

---

## Error boundaries (summary)

| Layer | Examples | User experience |
|---|---|---|
| Pre-open archive | Missing CBZ, corrupt ZIP, empty archive | Detail/snackbar; reader not opened |
| Active reader page | Extract/decode failure | Placeholder on that page; navigation continues |
| Preload | Adjacent page fails | Current page unaffected |
| Post-open source loss | File removed mid-session | Uncached loads fail; cache serves prior pages |

User-visible messages are generic; diagnostics use redacted identities and stable category labels only.

---

## Diagnostics (Phase 6.4C Step 5)

Comic reader state is exposed through the existing **Comic reader** diagnostics subsection (pull snapshot from `ReaderSessionTelemetry` at export time).

When a CBZ reader is active, diagnostics may include:

- Active session flag
- Archive type (`cbz`)
- Redacted catalogue item identity
- One-based page number and total page count
- Fit mode, chrome visibility, base/zoomed view state
- Successful cache entry count and approximate bytes (not process memory)
- Configured cache limits
- Count of tracked page failures; current failure category; retry availability
- Progress session active / completed flags

Not exported: raw page bytes, archive entry names, filesystem paths, exception text, stack traces.

Historical **Reader session** aggregates (last format, cache totals across formats, cleanup result) remain in the separate Reader session section.

---

## Exclusions (explicit)

- CBR/RAR production support (removed)
- Dual-page spreads, manga RTL
- Bookmarks, annotations, highlights
- Cloud / multi-device sync
- In-app CBZ conversion
- Library metadata editing (filesystem-is-truth)

---

## Test strategy

| Layer | Coverage |
|---|---|
| Archive | `comic_archive_cbz_test.dart`, `comic_archive_opener_test.dart` |
| Reader | `comic_reader_controller_test.dart`, `phase_64c_comic_reader_interaction_test.dart`, `phase_64c_comic_page_error_test.dart` |
| Progress | `phase_64c_comic_progress_test.dart`, `reading_progress_isolation_test.dart` |
| Diagnostics | `phase_64c_comic_reader_diagnostics_test.dart`, `diagnostics_reader_session_test.dart` |
| Opt-in Windows | `phase_63_comic_reader_windows_runtime_test.dart` (`PHASE_63_READER=1`) |

---

## Historical note

M6 planning originally evaluated CBR alongside CBZ. Gate 0 investigation and ADR-026 record the **accepted CBZ-only** production decision. Historical evaluation documents remain for audit; they do not describe active production architecture.
