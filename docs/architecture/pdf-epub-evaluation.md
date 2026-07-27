# PDF and EPUB Dependency Evaluation (M6 Phase 6.4 Gate 0)

**Date:** 2026-07-26  
**Branch:** `m6-development`  
**Scope:** Windows-first book reader dependencies only. No spike packages remain in the repo.

---

## Summary

| Format | Selected stack | Gate decision |
|---|---|---|
| PDF | `pdfrx` ^2.4.7 (PDFium via native assets) | **Pass** |
| EPUB | TTSPlayer-owned parser (`archive` + `xml`) + `flutter_html` ^3.0.0 renderer | **Conditional pass** |

---

## PDF candidates

### `pdfrx` — **Selected (Pass)**

| Criterion | Result |
|---|---|
| Licence | MIT (`pdfrx`, `pdfrx_engine`); PDFium BSD-style (see package NOTICES) |
| Windows Release build | Succeeds; native assets packaged via `pdfrx` |
| Local file open | Validated via `PdfDocument.openFile` / `PdfViewer.file` |
| Multi-page rendering | Per-page render via PDFium (not full-document bitmap decode) |
| Navigation / zoom | `PdfViewerController` page + zoom APIs |
| Keyboard | Reader shell maps arrows, Page Up/Down, Ctrl+±/0, Escape |
| Resource cleanup | `PdfDocument.dispose()` on probe; viewer disposes with widget |
| Corrupt / encrypted | Classified via `mapPdfOpenError`; encrypted PDFs fail clearly (no password UI in 6.4) |
| Testability | Unit/widget tests without visible desktop session |
| Maintenance | Active 2.x line with explicit desktop support |

**Conditional note:** pdfrx documents Windows Developer Mode for symlinked native assets during some developer builds. Release build succeeded in this environment without extra global installs.

### `pdfx` — **Rejected**

- Similar render-to-image model; less active maintenance signal than `pdfrx`.
- No material licensing or Windows advantage over `pdfrx`.

---

## EPUB candidates

### `epub_view` — **Rejected (Fail)**

- Dependency conflict: requires `image` ^3 while `media_kit` transitively requires `image` ^4.

### `epubx` — **Rejected (Fail)**

- Conflicts on both `image` and `archive` (project uses `archive` ^4.0.9 for CBZ comics).

### WebView / `sakura_epub` — **Rejected (Fail)**

- No viable Windows desktop support for TTSPlayer's Flutter Windows target.

### TTSPlayer parser + `flutter_html` — **Selected (Conditional pass)**

| Criterion | Result |
|---|---|
| EPUB 2 / 3 package parsing | OPF spine/manifest parsing validated with synthetic fixtures |
| Spine order / TOC | Spine-ordered chapters; TOC derived from spine titles |
| Internal links | `onLinkTap` routes relative hrefs to spine index |
| Images | Local `img` resolved from in-memory resource map; HTTP(S) blocked |
| CSS | `flutter_html` stylesheet subset; no arbitrary JS |
| Unicode | Fixture-set validated (Japanese/European samples) |
| Malformed / unsafe packages | Classified errors: invalid ZIP, missing container, bad spine, unsafe paths, scripts |
| Windows Release build | Pure Dart + Flutter; no extra native EPUB binary |
| Deterministic location | `EpubBookLocation`: spine index + href + scroll offset |
| Licence | `flutter_html` MIT; `archive`/ `xml` BSD-style |

**Conditional requirements (Phase 6.4 DoD / limitations):**

1. Full EPUB ZIP decoded into memory for the open session (same interim pattern as CBZ). Viewport rendering does **not** bound parser memory.
2. Continuous scroll/pagination mode is **continuous scroll only** in 6.4 (deliberate; paginated reflow deferred).
3. EPUB NCX/nav nested TOC beyond flat spine titles is best-effort only.
4. Password-protected PDF entry UI deferred; encrypted PDFs surface `pdfEncrypted` error.

---

## Rejected spike artifacts

No temporary evaluation packages or binaries were committed. Gate 0 used `pub add` locally and removed conflicting candidates before implementation landed.

---

## Phase 6.6 follow-ups

### PDF / PDFium audit (M6.6 — pdfrx 2.4.7)

| Question | Finding |
|---|---|
| Does pdfrx retain rendered pages internally? | **Yes.** `_PdfViewerState` keeps `_PageRenderCache` with `pageImages` / `pageImagesPartial` maps keyed by page number. Bitmap eviction runs when estimated bytes exceed [PdfViewerParams.maxImageBytesCachedOnMemory]. |
| Default cache / prefetch | `limitRenderingCache: true` (PDFium limited image cache flag); `maxImageBytesCachedOnMemory: 100 MiB`; `horizontalCacheExtent` / `verticalCacheExtent: 1.0` viewport for adjacent-page prefetch; progressive partial renders with configurable thresholds. |
| Configurable limits? | **Yes** via public [PdfViewerParams] only. TTSPlayer sets **48 MiB** rendered-page budget (`book_pdf_viewer_params.dart`). |
| Native PDF document lifetime | [PdfDocumentRef] with `autoDispose: true`; shared [PdfDocumentListenable] cache keyed by file path. Native handle released when ref/listenable disposes after viewer teardown. |
| Native page/render surface lifetime | Per-render [PdfImage] / `ui.Image` disposed on cache eviction or viewer `dispose()`. Partial render timers cancelled on dispose. |
| What disposes on reader close? | [PdfViewer] state `dispose()` cancels pending renders, disposes cached `ui.Image`s, detaches controller. TTSPlayer removes [PdfViewerController] listener and nulls controller; does **not** call non-existent `PdfViewerController.dispose()`. Route pop destroys [PdfViewer] widget. |
| Repeated zoom levels | Higher zoom renders replace/augment cache entries; byte-cap eviction removes distant pages — **obsolete high-res bitmaps are evicted, not guaranteed immediately freed to OS** (Dart/GPU retention limits observability). |
| Reopen same PDF | New route creates new [PdfViewer]; ref cache may reuse [PdfDocument] for same path until listenable disposes — reopen after full close observed clean in MP66-PDF-2 (20× cycle). |
| Large page count (120+) | Progressive loading optional; default loads all page metadata. Navigation validated with generated 120-page fixture. Process RSS rises during render; not a hard leak in 20× reopen test. |
| Image-heavy pages | Large content streams render through PDFium; bounded by TTSPlayer 48 MiB cache + `limitRenderingCache`. |
| Text accessibility | **Unsupported** — raster/image presentation path; no semantic text exposed to screen readers. |

**Tooling limitation:** Process RSS (`ProcessInfo.currentRss`) is the only practical Windows metric in harness tests. RSS drop after dispose is **not** proof of native heap release.

| ID | Item | Status |
|---|---|---|
| P66-EPUB-1 | Streaming/lazy EPUB resource loading to bound memory | ✅ M6.6 |
| P66-EPUB-2 | Richer NCX/NAV TOC and paginated reflow mode | Deferred |
| P66-PDF-1 | Password entry flow for encrypted PDFs | Deferred |
| P66-PDF-2 | PDF text accessibility audit if PDFium text API is exposed | **Accepted limitation** (documented) |
| P66-PDF-3 | Tune [PdfViewerParams] from audit evidence | ✅ 48 MiB cap |

**Related:** [books-comics.md](./books-comics.md) · [m6-phase-6.6-reader-hardening.md](../roadmap/m6-phase-6.6-reader-hardening.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md)
