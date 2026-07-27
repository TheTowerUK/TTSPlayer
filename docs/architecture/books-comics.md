# Books & Comics Architecture (M6)

**Status:** Active — Phase 6.3 ✅ **Complete** (CBZ comic reader, 2026-07-27); Phase 6.4 ✅ **Complete** (book reader, 2026-07-26); ADR-026 **Accepted** (CBZ-only production comic format)  
**Milestone plan:** [m6-plan.md](../roadmap/m6-plan.md)  
**Related ADRs:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [ADR-025](./decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md) · [ADR-027](./decisions/ADR-027-reading-progress-and-continue-reading.md)

> Phases 6.1–6.6 complete on `m6-development`. Comic production format is **CBZ only**; CBR removed from scope (external conversion + rescan).

---

## Purpose

Describe how books and comics fit into TTSPlayer’s existing folder-first, provider-neutral platform without inventing categories, parallel catalogues, or silent absorption of deferred music work.

---

## Design constraints (inherited)

| Constraint | Implication for books/comics |
|---|---|
| Filesystem is truth | Folder names are the only library categories |
| Catalogue principle | No “All Books” / “Comics” virtual roots as fake folders |
| Graceful degradation | Missing cover/metadata still shows the item |
| Item status model | Status gates playability/openability; unknown status safe |
| Local-first | Readers work offline against local/NAS/HTTPS media |
| Reuse infrastructure | Providers, resolver, search, artwork, cache, diagnostics |

---

## Content model (proposed)

### Media kinds

| Kind | Typical formats (M6 baseline) | Primary surface |
|---|---|---|
| `comic` | **`.cbz`** (ZIP-based) | Comic archive reader (Phase 6.3) |
| `book` | `.pdf`, `.epub` | Document reader (Phase 6.4) |
| existing | `video`, `audio`, `image`, `unknown` | Unchanged |

**Recommendation:** Keep `book` and `comic` distinct. Presentation, progress units, and reader stacks differ enough that a single `document` kind would force awkward branching.

**Comic format:** `.cbz` is the supported production comic archive format. **CBR/RAR is not supported** — convert externally to CBZ and rescan. See [ADR-026 Accepted](./decisions/ADR-026-reader-surface-architecture.md).

### Catalogue versions

| Version | Scanner | Content |
|---|---|---|
| 3 | 0.4.0 | Video / audio / image + music metadata |
| **4** | **0.5.0** | + book / comic kinds and extensions |

Client `CatalogueInfo.maxSupportedCatalogueVersion` is **4**. Higher versions throw `UnsupportedCatalogueVersionException`.

### What is not a comic in initial M6 scope

Loose image sequences in a folder remain `image` items (M4 behaviour). Promoting folders of images to “virtual comics” invents structure and is out of scope unless separately approved.

---

## Catalogue and scanner

### Indexer responsibilities

- Discover supported book/comic extensions under the scanned root
- Emit `media_kind` of `book` or `comic`
- Preserve folder tree as-is; prune empty branches per existing rules
- Prefer lightweight metadata (filename stem as title; optional embedded title if cheap and reliable)
- Never invent category labels from format
- Continue atomic write of `catalog.json`

### Client responsibilities

- Parse new kinds with unknown-kind safety (default presentation, not crash)
- Present books/comics in folder browse, search, and detail with kind labels/icons (Phase 6.2)
- Route open actions by kind to the correct reader **when readers exist** (6.3/6.4); until then show a non-reader stub and refuse A/V playback
- Keep `SupportedExtensions` and catalogue `supported_extensions` in sync

### Browse and presentation (Phase 6.2)

| Surface | Behaviour |
|---|---|
| Folder browse | `.pdf`/`.epub` → Book; `.cbz` → Comic; mixed folders show all kinds; filters `Books` / `Comics` |
| Cards / list rows | Kind badge + subtitle (author/series when present); distinct literature vs comics placeholders |
| Search | Kind chips in TYPE filter row; author/series in search blob (6.1); no path leakage |
| Item detail | Comics: **Open Comic** → comic reader; Books: **Open Book** → PDF/EPUB reader |
| Isolation | Books/comics never open video player, music player, or image viewer |

No virtual “All Books” / “All Comics” libraries. Search opens `ItemDetailScreen` (same comic open action).

### Versioning

- Likely `catalogue_version: 4` when book/comic kinds and extensions ship (ADR-024)
- Older clients must ignore unknown kinds safely; older catalogues remain loadable

---

## Identity and metadata (proposed)

Aligned with music ADR-021 patterns:

| Field | Source of truth |
|---|---|
| Stable item `id` | Path-derived (existing MD5-of-path pattern) |
| Display title | Filename stem unless richer metadata is explicitly trusted |
| Cover / thumbnail | Optional; placeholder on miss |
| Series / volume / author | Optional enrichment only — never invent folders |

Remote metadata APIs are out of M6 scope.

---

## Reader architecture (Phase 6.3 comic — implementation checkpoint)

### Current reader status (2026-07-25)

| Format | Status |
|---|---|
| **CBZ** | Fully implemented; runtime validated (unit + opt-in Windows harness) |
| **CBR** | Technically implemented; locally validated when approved UnRAR present; **production distribution blocked** pending approval for the exact `UnRAR.exe` |
| **Missing CBR tooling** | Production route: `ComicArchiveOpener.openPath` / `openComicReaderScreen` → controlled `cbrSupportUnavailable` snackbar before a broken reader session (same path exercised in unit/harness tests) |
| **Unicode entry names** | Validated for **current fixture set only** (ASCII + nested paths); non-ASCII / supplementary-character archive entry names remain follow-up unless covered by representative tests |

### Surfaces

| Surface | Role |
|---|---|
| Folder / detail / search→detail | Discover and open |
| Comic reader (`ComicReaderScreen`) | Paged image sequence from archive |
| Book reader (`BookReaderScreen`) | PDF via `pdfrx`; EPUB via TTSPlayer parser + `flutter_html` |
| Continue Reading | Phase 6.5 — `ReadingProgressRepository` + dashboard section |

Video `PlayerScreen` and music listening surfaces are **not** reused for reading.

### Module boundaries (`lib/features/comics/`)

| Layer | Responsibility |
|---|---|
| `ComicArchiveOpener` | Resolve local path via `MediaLocationResolver`; choose CBZ vs CBR source; probe CBR tooling before route |
| `ComicArchiveSource` | Implementation-neutral list/load/dispose contract |
| `CbzZipArchiveSource` | In-process ZIP via `package:archive` |
| `CbrCliArchiveSource` | Adapter over Gate 0 `UnrarCliCbrAdapter` (replaceable) |
| Page ordering / safety | Natural filename order; reject unsafe paths; image extensions only |
| `ComicPageCache` | Bounded LRU (default **5** pages); failed loads not cached; cleared on dispose |
| `ComicReaderController` | Session navigation + load/prefetch; no Phase 6.5 persistence |
| `ComicReaderScreen` | Fit-to-window page display, controls, keyboard, errors |
| `openComicReaderScreen` | Entry helper — snackbar on controlled failure (never broken route) |

### Keyboard / controls (Windows)

| Input | Action |
|---|---|
| ← / Page Up | Previous page |
| → / Page Down | Next page |
| Home | First page |
| End | Last page |
| Escape / AppBar back | Exit reader |
| Toolbar buttons | First / prev / next / last |

Shortcuts are ignored while an `EditableText` owns focus. Page indicator: `Page N of M` (semantics live region).

### Cache / temp policy

- **Controller page cache:** retain current page; optional adjacent prefetch (neighbors only).
- Hard cap: `ComicPageCache.maxEntries` (default 5) on **decoded page bytes held by the controller only**.
- Cleared when the reader disposes.
- CBR: owned temp extract dir per page; cleaned after read; reopen does not reuse stale temps.
- **CBZ archive memory (interim limitation):** `CbzZipArchiveSource` reads the full `.cbz` file, then `ZipDecoder.decodeBytes` decompresses **all** ZIP entries into an in-memory `Archive` retained for the open session. Navigation reuses entry bytes already held in that structure — this is **not** selective/random-access I/O. The five-page controller cache does **not** bound this underlying archive-parser memory.
- **Memory (M6.6):** `CbzZipLazyReader` reads ZIP central directory only; pages inflated on demand. `ComicPageCache` caps decoded bytes (24 MiB) and entries (5).

### Extraction / decode

- **CBZ:** full-archive decode via `package:archive` (interim); page bytes served from decoded entry content
- **CBR:** Official **UnRAR CLI** under Gate 0 **Conditional pass** — selective per-page extract; no PATH fallback; structured args; timeout; hash gate when configured; `PHASE_63_UNRAR_EXE` for local validation only. Redistribution of `UnRAR.exe` remains **unresolved/blocking** for production packaging.
- **PDF/EPUB:** Phase 6.4 **complete** — see [Book reader](#reader-architecture-phase-64-book) and [pdf-epub-evaluation.md](./pdf-epub-evaluation.md)
- **Remote HTTP comics:** Rejected with a clear message until a later download/cache design (local-first)

### Error taxonomy

Controlled kinds include: missing archive, unsupported type, corrupt, empty, no readable images, unsafe path, CBR unavailable / hash mismatch, encrypted, multi-volume, page extract failure, timeout. User messages are safe; diagnostics are redacted (basename/codes only).

---

## Reader architecture (Phase 6.4 book — complete)

### Current book reader status (2026-07-26)

| Format | Status |
|---|---|
| **PDF** | Implemented via `pdfrx` (PDFium); per-page render; pre-route probe |
| **EPUB** | TTSPlayer-owned parser (`archive` + `xml`) + `flutter_html` renderer |
| **Reading progress** | Location models exposed; **no Phase 6.5 persistence** |
| **Unicode** | Fixture-set validated only |

Gate 0 evaluation: [pdf-epub-evaluation.md](./pdf-epub-evaluation.md).

### Module boundaries (`lib/features/books/`)

| Layer | Responsibility |
|---|---|
| `BookOpener` | Resolve local path; detect PDF vs EPUB; refuse remote-only URIs |
| `BookReaderException` / `BookReaderErrorKind` | Stable error taxonomy (PDF + EPUB) |
| `book_path_safety` | EPUB ZIP entry safety; basename redaction helpers |
| `EpubParser` | OPF/container parse; spine HTML + resources in session memory |
| `EpubBookController` | Chapter navigation, text scale, non-persistent `EpubBookLocation` |
| `BookReaderScreen` | Shared shell: title, back, location bar, format-specific controls |
| `openBookReaderScreen` | Pre-route probe; snackbar on controlled failure |
| `PdfBookLocation` / `EpubBookLocation` | Serializable shapes for Phase 6.5 (not written yet) |

### PDF behaviour

- Multi-page view via `PdfViewer.file` + `PdfViewerController`
- Page prev/next (toolbar + keyboard); zoom via controller APIs; fit reset
- Encrypted PDFs: classified `pdfEncrypted` (password UI deferred to Phase 6.6)
- **Memory:** PDFium renders pages on demand; no full-document bitmap decode in app code

### EPUB behaviour and security model

- **Continuous scroll** reading mode (paginated reflow deferred)
- Spine-order chapters; flat TOC from spine titles; internal relative links only
- **Blocked:** HTTP(S)/mailto links; remote images; `<script>` / `javascript:`; unsafe ZIP paths
- **No JS execution**; HTML rendered through `flutter_html` with constrained styles
- **Memory (M6.6):** lazy ZIP via `EpubLazyResourceLoader` — chapters and resources loaded on demand; bounded cache (16 MiB). Spine security probes still run at open.

### Book reader keyboard / controls (Windows)

| Input | PDF | EPUB |
|---|---|---|
| Escape / AppBar back | Exit | Exit |
| ← / Page Up | Previous page | Previous chapter |
| → / Page Down | Next page | Next chapter |
| Home / End | First / last page | First / last chapter |
| Ctrl + + / − / 0 | Zoom in / out / reset fit | Text size in / out / reset |

Shortcuts ignored while `EditableText` owns focus.

### Opt-in runtime harness

`PHASE_64_READER=1` — `test/phase_64_book_reader_windows_runtime_test.dart` (`--tags phase64-reader`).

---

## Reading state (proposed)

| Concern | Owner |
|---|---|
| What files exist | Catalogue / filesystem |
| Last page / position | Application reading-progress store |
| Continue Reading order | Derived from reading-progress timestamps |
| Favourites (future) | Not required for M6 DoD |

**Isolation:** Reading-progress preference keys must not collide with:

- Video `position_*`
- Music listening history / session persistence
- Favourites

Catalogue replacement must prune stale reading-progress entries using the same coordinator pattern as M5.

---

## Search and diagnostics

- Search indexes book/comic titles like other items; kind label for presentation
- Diagnostics expose aggregate counts (items indexed, opens, progress entries) with redaction parity to music
- No new diagnostics pipeline

---

## Cross-platform notes

- **Primary gate:** Windows (desktop)
- Android/iOS: architecture should not preclude later parity; not required for M6 DoD
- Native reader plugins must be documented in release notes when required

---

## Test and validation strategy

| Layer | Expectation |
|---|---|
| Unit | Indexer kinds/extensions; identity; progress repository |
| Widget | Browse labels; reader chrome; Continue Reading |
| Integration | Catalogue replace prune; key isolation |
| Opt-in Windows runtime | Open comic/book; page turn; resume after restart |
| Regression | Full Flutter suite + video/music focused suites |

---

## Relationship to deferred M5 music work

Music playlists, shuffle/repeat, lyrics, favourites redesign, and related items remain on the **music backlog**. They are not prerequisites for books/comics and must not be smuggled into M6 phases.

---

## Implementation map (by phase)

| Phase | Architecture focus |
|---|---|
| 6.1 | Schema, kinds, indexer, client models |
| 6.2 | Browse / detail / search presentation — ✅ Complete (kind badges, folder filters, search kind chips, detail stub, placeholders; no readers) |
| 6.3 | Comic reader (CBZ/CBR) — **In Progress** (implementation checkpoint; UnRAR redistribution blocking closure) |
| 6.4 | Book reader |
| 6.5 | Reading progress + Continue Reading | **Complete** |
| 6.6 | Performance, diagnostics, runtime matrix |
| Release | Governance and tags |

---

## Open decisions

See [m6-plan.md — Open questions](../roadmap/m6-plan.md#open-questions-resolve-before-or-during-early-phases).
