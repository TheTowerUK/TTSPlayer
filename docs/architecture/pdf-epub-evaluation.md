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

| ID | Item |
|---|---|
| P66-EPUB-1 | Streaming/lazy EPUB resource loading to bound memory |
| P66-EPUB-2 | Richer NCX/NAV TOC and paginated reflow mode |
| P66-PDF-1 | Password entry flow for encrypted PDFs |
| P66-PDF-2 | PDF text accessibility audit if PDFium text API is exposed |

**Related:** [books-comics.md](./books-comics.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md)
