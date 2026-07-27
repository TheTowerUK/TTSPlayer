# ADR-026: Reader Surface Architecture

**Status:** **Proposed** — preferred production CBR backend identified (UnRAR64.dll FFI, Gate 1 **Technical Pass**); Phase 6.3 **In Progress**; Phase 6.4 ✅ **Complete**  
**Release condition (blocking Accept):** Bundled redistribution of official `UnRAR64.dll` **awaiting publisher/legal confirmation** — see [unrar-dll-provenance.md](../unrar-dll-provenance.md). Public Release packages must **not** include the DLL until confirmed.  
**Date:** 2026-07-24 (proposed) / 2026-07-27 (Gate 1 technical checkpoint)  
**Milestone:** M6 — Phase 6.3 **In Progress** (engineering complete; governance open); Phase 6.4 **complete**  
**Related:** [books-comics.md](../books-comics.md) · [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [unrar-dll-provenance.md](../unrar-dll-provenance.md) · [ADR-023](./ADR-023-music-player-surface-architecture.md)

---

## Preferred candidate (not yet Accepted)

**Candidate A — Official RARLab `UnRAR64.dll` via FFI** earned Gate 1 **Technical Pass** (2026-07-27).

Unresolved before **Accept**:

1. Explicit publisher or qualified legal confirmation for bundling the unmodified DLL + `license.txt` in TTSPlayer Windows installers/ZIP/Store packages.
2. Release-layout packaging proof with bundled DLL (no environment override).
3. Formal security-update ownership sign-off for production channels.

Until resolved: ADR remains **Proposed**; Phase 6.3 remains **In Progress**; M6 closure **blocked**.

## Context

Video uses `video_player` / MediaKit on `PlayerScreen`. Music uses a dedicated listening surface and queue (ADR-022/023). Books and comics need paged/document navigation, not continuous A/V playback.

Reusing the video player for PDFs or forcing comics through the music shell would create brittle abstractions and regress A/V behaviour.

Gate 0: `package:unrar` **Fail**; official UnRAR CLI **Conditional pass** (dev/fallback only). Gate 1 (2026-07-27): official **UnRAR64.dll** FFI adapter — **Technical Pass**; bundled redistribution **awaiting confirmation**.

---

## Decision (proposed — comic reader provisionally validated)

1. Introduce **dedicated reader surfaces**:
   - Comic reader (archive → paged images) for **both `.cbz` and `.cbr`** — **implemented in Phase 6.3 checkpoint**
   - Book reader (PDF / EPUB document model) — **implemented in Phase 6.4 checkpoint**
2. Readers may share **chrome patterns** (app bar, theme, focus targets, error banners) but **not** `VideoPlayerController`, music queue, or listening session controllers.
3. Open actions route by `media_kind` from folder/detail/search→detail.
4. All media access uses existing **MediaLocationResolver** / provider stack.
5. Comic archives use an implementation-neutral `ComicArchiveSource`:
   - CBZ: in-process ZIP (`package:archive` / lazy reader — Phase 6.6)
   - CBR: `CbrBackendResolver` selects **UnRAR64.dll FFI** (preferred) → **UnRAR CLI fallback** → controlled unavailable (no PATH)
6. Comic reader validation checkpoint (not final Accept): Windows validation of **both** CBZ and CBR open + page navigation under documented Conditional-pass constraints.
7. Failure modes: missing file; corrupt archive; unsupported archive variant; **encrypted** archive; **multi-volume** archive; missing CBR tooling → dismissible error with recovery (back / dismiss), **never crash**, and **never affect** the rest of the catalogue or other media kinds.
8. **Shipping:** Optional CMake install of `UnRAR64.dll` + `license.txt` when present under `third_party/unrar_dll/`. **Legal review required** before committing/shipping the binary. Dev harness: `PHASE_63_UNRAR_DLL`, `PHASE_63_UNRAR_EXE`.

---

## Provisional validation record (Phase 6.3 checkpoint — 2026-07-25)

| Format | Status |
|---|---|
| **CBZ** | Fully implemented; runtime validated (unit + opt-in Windows harness) |
| **CBR** | Gate 1 **Technical Pass** — `UnrarDllCbrAdapter`; CLI dev/fallback only; **bundled ship blocked** |
| **Missing CBR tooling** | Production controlled unavailable (not test-only) |
| **Unicode entry names** | Gate 1 fixture pass when generated locally; broader matrix in harness |
| **ADR Accept / Phase 6.3 close** | **Not yet** — publisher/legal redistribution confirmation required |

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
- [x] Production UnRAR **technical** path selected and validated (Gate 1 DLL)
- [ ] Publisher/legal redistribution confirmation — **blocking for Accept and Phase 6.3 close**
- [ ] Phase 6.3 Definition of Done complete (see [m6-plan.md](../../roadmap/m6-plan.md))
