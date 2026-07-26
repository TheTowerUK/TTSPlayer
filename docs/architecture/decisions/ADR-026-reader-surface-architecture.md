# ADR-026: Reader Surface Architecture

**Status:** Proposed — comic + book reader architecture **provisionally validated** (comic 2026-07-25, book 2026-07-26); Phase 6.3 **In Progress**; Phase 6.4 ✅ **Complete**  
**Shipping constraint:** Production redistribution of `UnRAR.exe` remains **unresolved/blocking**; builds must not claim redistribution is approved.  
**Date:** 2026-07-24 (proposed) / 2026-07-25 (comic reader checkpoint)  
**Milestone:** M6 — Phase 6.3 (comics, in progress); Phase 6.4 (books) **complete**  
**Related:** [books-comics.md](../books-comics.md) · [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [ADR-023](./ADR-023-music-player-surface-architecture.md)

---

## Context

Video uses `video_player` / MediaKit on `PlayerScreen`. Music uses a dedicated listening surface and queue (ADR-022/023). Books and comics need paged/document navigation, not continuous A/V playback.

Reusing the video player for PDFs or forcing comics through the music shell would create brittle abstractions and regress A/V behaviour.

Gate 0: `package:unrar` **Fail**; official UnRAR CLI **Conditional pass** (technical only).

---

## Decision (proposed — comic reader provisionally validated)

1. Introduce **dedicated reader surfaces**:
   - Comic reader (archive → paged images) for **both `.cbz` and `.cbr`** — **implemented in Phase 6.3 checkpoint**
   - Book reader (PDF / EPUB document model) — **implemented in Phase 6.4 checkpoint**
2. Readers may share **chrome patterns** (app bar, theme, focus targets, error banners) but **not** `VideoPlayerController`, music queue, or listening session controllers.
3. Open actions route by `media_kind` from folder/detail/search→detail.
4. All media access uses existing **MediaLocationResolver** / provider stack.
5. Comic archives use an implementation-neutral `ComicArchiveSource`:
   - CBZ: in-process ZIP (`package:archive`) — see memory caveat in [books-comics.md](../books-comics.md)
   - CBR: replaceable CLI adapter (`CbrCliArchiveSource` → `UnrarCliCbrAdapter`) under Conditional-pass rules (no PATH fallback, hash gate, timeouts, owned temps)
6. Comic reader validation checkpoint (not final Accept): Windows validation of **both** CBZ and CBR open + page navigation under documented Conditional-pass constraints.
7. Failure modes: missing file; corrupt archive; unsupported archive variant; **encrypted** archive; **multi-volume** archive; missing CBR tooling → dismissible error with recovery (back / dismiss), **never crash**, and **never affect** the rest of the catalogue or other media kinds.
8. **Shipping:** Do not redistribute `UnRAR.exe` in production/release channels until formal approval of the exact binary. Local/dev may use `PHASE_63_UNRAR_EXE` or an optional CMake copy when present.

---

## Provisional validation record (Phase 6.3 checkpoint — 2026-07-25)

| Format | Status |
|---|---|
| **CBZ** | Fully implemented; runtime validated (unit + opt-in Windows harness) |
| **CBR** | Technically implemented; locally validated when approved UnRAR present; **production distribution blocked** pending approval for the exact `UnRAR.exe` |
| **Missing CBR tooling** | Production `ComicArchiveOpener` + `openComicReaderScreen` surface controlled unavailable state (not test-only) |
| **Unicode entry names** | Validated for current fixture set only; broader archive-entry Unicode is follow-up |
| **ADR Accept / Phase 6.3 close** | **Not yet** — redistribution approval and remaining DoD items block closure |

### Provisional validation record (Phase 6.4 checkpoint — 2026-07-26)

| Format | Status |
|---|---|
| **PDF** | Implemented via `pdfrx`; probe + viewer; Windows Release build green |
| **EPUB** | TTSPlayer parser + `flutter_html`; security model enforced; full-ZIP memory interim limitation |
| **Reading progress** | Location models only — Phase 6.5 not started |
| **Phase 6.4 close** | ✅ **Complete** (2026-07-26) — harness validates production Open Book → PdfViewer route |

---

## Consequences

### Positive

- Clear separation of concerns; protects video/music regressions
- Shared reader model above CBZ/CBR adapters (no duplicated page UX)
- Primary comic formats (CBZ + CBR) both first-class under Conditional-pass tooling

### Negative / risks

- CBR process-per-page overhead and CLI text parsing fragility
- UnRAR redistribution still blocks production packaging of CBR support
- CBZ: `package:archive` retains decoded archive in memory for the open session (interim limitation; Phase 6.6 measurement/replacement)

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Reuse `PlayerScreen` | Wrong interaction model; controller mismatch |
| Single mega-reader for all formats | Premature abstraction; different progress units |
| External OS default apps only | Breaks in-app Continue Reading and offline UX goals |
| Ship CBZ reader first and leave CBR “optional” | Rejected — both formats are required M6 baseline |
| `package:unrar` in-process | Gate 0 Fail (MSVC native hooks) |

---

## Acceptance criteria (for later Accept)

- [x] Comic reader opens from browse/detail without touching A/V controllers (checkpoint)
- [x] Comic reader opens and navigates **CBZ and CBR** fixtures on Windows (runtime harness; CBR via approved/local UnRAR under Conditional pass)
- [x] Unsupported / encrypted / corrupt / multi-volume archives fail gracefully without crashing or affecting catalogue remainder
- [ ] Local and HTTPS opens for comics — **local validated**; remote HTTP comics rejected with clear message (download/cache later)
- [x] Widget + runtime smoke coverage for open/navigate/fail
- [x] Release build documents optional UnRAR native dep (omit when absent)
- [x] Book reader (Phase 6.4 checkpoint — PDF + EPUB; no persistence)
- [ ] Production UnRAR redistribution approval — **blocking for shipping and final Accept**
- [ ] Phase 6.3 Definition of Done complete (see [m6-plan.md](../../roadmap/m6-plan.md))
