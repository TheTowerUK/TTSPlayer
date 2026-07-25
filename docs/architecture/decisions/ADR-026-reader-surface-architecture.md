# ADR-026: Reader Surface Architecture

**Status:** Proposed — Gate 0 Candidate B **FAIL**; Candidate E (UnRAR CLI) **Conditional pass** (technical only, 2026-07-25); redistribution of UnRAR.exe **unresolved/blocking** for shipping; reader not implemented; Phase 6.3 incomplete  
**Date:** 2026-07-24  
**Milestone:** M6 — Phase 6.0 / 6.3–6.4  
**Related:** [books-comics.md](../books-comics.md) · [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [ADR-023](./ADR-023-music-player-surface-architecture.md) · [ADR-007](./ADR-007-playback-architecture.md)

---

## Context

Video uses `video_player` / MediaKit on `PlayerScreen`. Music uses a dedicated listening surface and queue (ADR-022/023). Books and comics need paged/document navigation, not continuous A/V playback.

Reusing the video player for PDFs or forcing comics through the music shell would create brittle abstractions and regress A/V behaviour.

---

## Decision (proposed)

1. Introduce **dedicated reader surfaces**:
   - Comic reader (archive → paged images) for **both `.cbz` and `.cbr`**
   - Book reader (PDF / EPUB document model)
2. Readers may share **chrome patterns** (app bar, theme, focus targets, error banners) but **not** `VideoPlayerController`, music queue, or listening session controllers.
3. Open actions route by `media_kind` from folder/detail/search.
4. All media access uses existing **MediaLocationResolver** / provider stack.
5. Reader package choices (PDF/EPUB/ZIP/RAR) must be Windows-capable and documented; CBR must use a stack that **passes Phase 6.3 Gate 0**. Published `package:unrar` failed; official **UnRAR CLI** earned a **Conditional pass** (see [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [unrar-cli-provenance.md](../unrar-cli-provenance.md)). Conditions must be met before this ADR can be Accepted.
6. Comic reader **Definition of Done** requires successful Windows runtime validation of **both** CBZ and CBR fixtures (open + page navigation).
7. Failure modes: missing file; corrupt archive; unsupported archive variant; **encrypted** archive; **multi-volume** archive → dismissible error with recovery (back / rescan), **never crash**, and **never affect** the rest of the catalogue or other media kinds.

---

## Consequences

### Positive

- Clear separation of concerns; protects video/music regressions
- Allows format-specific UX (page scrubber vs spine TOC)
- Primary comic formats (CBZ + CBR) both first-class

### Negative / risks

- Two reader codepaths to maintain (mitigate with shared shell widgets)
- Native/RAR plugin weight on Windows Release builds (implementation risk; not scope deferral)

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Reuse `PlayerScreen` | Wrong interaction model; controller mismatch |
| Single mega-reader for all formats | Premature abstraction; different progress units |
| External OS default apps only | Breaks in-app Continue Reading and offline UX goals |
| Ship CBZ reader first and leave CBR “optional” | Rejected — both formats are required M6 baseline |

---

## Acceptance criteria (for later Accept)

- [ ] Comic and book readers open from browse/detail without touching A/V controllers
- [ ] Comic reader opens and navigates **CBZ and CBR** fixtures on Windows (runtime harness)
- [ ] Unsupported / encrypted / corrupt / multi-volume archives fail gracefully without crashing or affecting catalogue remainder
- [ ] Local and HTTPS opens work for representative fixtures
- [ ] Widget + runtime smoke coverage for open/navigate/fail
- [ ] Release build documents required native/RAR deps
