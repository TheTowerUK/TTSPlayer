# M6 Phase 6.6 — Reader Performance, Memory & UX Hardening

**Status:** Complete (2026-07-27)  
**Branch:** `m6-development`  
**Baseline commit:** `3042d38` (Phase 6.5 complete)  
**Discipline:** Measurement-first, runtime-validated (same pattern as M5.6)

---

## Validation environment (final)

| Item | Value |
|---|---|
| Machine | Windows 11 Pro, build 26200 |
| Display | 3440 × 1440, single monitor |
| Native Windows scaling | **100%** (AppliedDPI 96) |
| Flutter | 3.44.4 stable |
| Dart | 3.12.2 |
| Release build | `build\windows\x64\runner\Release\ttsplayer.exe` |
| Opt-in runtime gate | `PHASE_66_READER_HARDENING=1` + tag `phase66-reader` |

**Tooling notes:** Process RSS is process-level only. Native Windows DPI at 125–200% was **not available** on the validation host (fixed at 100%). Layout at equivalent scales was validated via automated widget tests (`TextScaler` + `devicePixelRatio`). Multi-monitor DPI transition: **not available** (single display).

---

## Hardening matrix (final)

| # | Finding | Classification |
|---|---|---|
| H1 | CBZ lazy ZIP | **Fixed** ✅ |
| H2 | EPUB lazy loader | **Fixed** ✅ |
| H3 | Comic byte cap | **Fixed** ✅ |
| H4 | CBR process-per-page | **Measured — retained** |
| H5 | CBR temp cleanup | **Verified** ✅ |
| H6 | UnRAR redistribution | **Milestone blocker** |
| H7 | PDF pdfrx cache | **Fixed/documented** ✅ |
| H8 | PDF password UI | **Deferred** → post-M6 UX |
| H9 | PDF text a11y | **Accepted limitation** |
| H10 | EPUB scroll after typography | **Accepted limitation** (offset stored; precision not re-certified) |
| H11–H12 | EPUB scroll-only / flat TOC | **Accepted limitation** |
| H13 | Unicode fixture-set | **Partial** (EPUB unicode hrefs in ZIP: limitation) |
| H14 | High-DPI / resize | **See UX matrix below** |
| H15 | Long-session cleanup | **Passed** ✅ |
| H16 | Continue Reading caps | **Regression pass** ✅ |
| H17 | Reader diagnostics | **Complete** ✅ |
| H18–H20 | CBR parser / CBZ sort / progress isolation | **Regression pass** ✅ |

---

## UX and accessibility matrix (final)

**Legend:** ✅ Pass · 🤖 Automated · 📋 Manual · ⚠️ Limitation · ➖ N/A on host · ⏳ Deferred

### Validation environment

| Field | Recorded value |
|---|---|
| Windows | 11 Pro build 26200 |
| Resolution | 3440 × 1440 |
| Native scaling | 100% only |
| Monitors | Single |
| Build | Windows Release from Phase 6.6 tree |

### Display scaling

Native Windows DPI above 100% was **not available on validation host**. Equivalent layout scaling was exercised via P66-UX widget tests at 100–200%.

| Scale | Dashboard | Continue Reading | Book detail | Comic detail | PDF reader | EPUB reader | CBZ reader | CBR unavailable |
|---|---|---|---|---|---|---|---|---|
| 100% native | 📋 Manual smoke ✅ | 🤖+📋 ✅ | 🤖 ✅ | 🤖 ✅ | 📋 P64 ✅ | 📋 P64 ✅ | 📋 P63 ✅ | 🤖 ✅ |
| 125% | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | ➖ | ➖ | ➖ | 🤖 ✅ |
| 150% | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | ➖ | ➖ | ➖ | 🤖 ✅ |
| 175% | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | ➖ | ➖ | ➖ | 🤖 ✅ |
| 200% | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | 🤖 ✅ | ➖ | ➖ | ➖ | 🤖 ✅ |

Reader rows at 125–200%: layout policy validated on detail/Continue Reading surfaces; full reader chrome at native DPI ➖ (host limitation). Phase 6.3/6.4 runtime harnesses cover reader keyboard/nav at 1280×800.

### Window state

| Scenario | PDF | EPUB | CBZ | Result |
|---|---|---|---|---|
| Narrow 900×420 detail | — | — | — | 🤖 ✅ |
| Normal 1280×800 reader | 📋 P64 | 📋 P64 | 📋 P63 | ✅ |
| Maximised / minimise-restore | 📋 Release smoke | 📋 | 📋 | ✅ (no crash) |
| Resize while reader open | ⏳ | ⏳ | ⏳ | Not re-run natively; no defect filed |
| Multi-monitor DPI transition | ➖ | ➖ | ➖ | Single monitor host |

### Keyboard-only

| Scenario | Coverage | Result |
|---|---|---|
| Continue Reading → reader | P65 runtime | ✅ |
| Detail Open / Start from Beginning / Read Again | P64 + semantics | ✅ |
| PDF page nav / zoom / close | P64 runtime | ✅ |
| EPUB chapter / TOC / text size | P64 partial | ✅ |
| CBZ prev/next / boundaries | P63 runtime | ✅ |
| Focus restore after close | ⏳ | Deferred — requires assistive-tech certification (P64 back-to-detail verified) |

### Accessibility / semantics

| Control | Result | Notes |
|---|---|---|
| Continue Reading section | ✅ | `Semantics(header)` + card composite labels |
| Progress bar | ✅ | `Semantics` value `%` on indicator |
| Open Book / Read Again | ✅ | Material button labels |
| CBR unavailable card | ✅ | `button: false` + reason text; dashboard now wires `cbrToolingAvailable` |
| PDF zoom / EPUB text size | 📋 | Tooltip labels; PDF document text **⚠️ unsupported** |
| Reader loading | ✅ | EPUB/comic labeled spinners |
| Error close | ✅ | Book reader live region |
| PDF semantic document text | ⚠️ | **Accepted limitation** — raster PDFium path |

### Presentation scenarios

| Scenario | Result |
|---|---|
| Long book/comic title | ✅ Fixed app bar ellipsis; detail `maxLines: 3` |
| Long file path on detail | ✅ Fixed `maxLines: 3` ellipsis |
| Large portrait/landscape comic page | 📋 P63/P66 lazy fixtures |
| Long EPUB chapter | 📋 P64 |
| Rapid PDF nav / zoom | 📋 P64 + P66 reopen tests |
| Continue Reading 20 / repo 100 records | P65 projection ✅ |
| Completed + Read Again | P65 ✅ |
| Missing CBR tooling | ✅ Projection + dashboard wiring |
| Reader load failure | 📋 Controlled error panes |

### Defects fixed in UX pass

1. **Dashboard CBR flag** — `ContinueReadingProjection(cbrToolingAvailable: …)` now uses `UnrarCliResolver`.
2. **App bar long titles** — `TtsAppBar` ellipsis.
3. **Detail file path overflow** — ellipsis/wrap cap.
4. **EPUB loading semantics** — labeled spinner.
5. **Continue Reading progress semantics** — explicit percent value.
6. **Phase 6.3 harness** — `ReadingProgressCoordinator` provider for comic reader widget test.

---

## Memory model, baselines, CBR policy

See prior sections in git history and [`pdf-epub-evaluation.md`](../architecture/pdf-epub-evaluation.md).

| Format | Session cache |
|---|---|
| CBZ | ≤5 entries, ≤24 MiB |
| EPUB | ≤32 entries, ≤16 MiB |
| PDF | pdfrx 48 MiB rendered-page cap |
| CBR | One-process-per-page extract (retained) |

---

## Phase 6.6 Definition of Done

| Criterion | Status |
|---|---|
| Performance/memory baselines | ✅ |
| CBZ/EPUB memory | ✅ |
| PDF bounded/documented | ✅ |
| Comic cache bounded | ✅ |
| CBR measured | ✅ |
| Long-session cleanup | ✅ |
| Unicode (scoped) | ✅ |
| UX/a11y matrix | ✅ |
| Full suite + Release | ✅ |
| Phase 6.3 blocker documented | ✅ |
| Phase 7 not started | ✅ |

---

## Related documents

- [books-comics.md](../architecture/books-comics.md)
- [pdf-epub-evaluation.md](../architecture/pdf-epub-evaluation.md)
- [cbr-rar-evaluation.md](../architecture/cbr-rar-evaluation.md)
- [m6-plan.md](./m6-plan.md)
