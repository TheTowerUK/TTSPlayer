# M6 — Books & Comics — Milestone Complete

**Status:** ✅ **COMPLETE** — 2026-07-29  
**Branch:** `m6-development`  
**Baseline:** M5 — `v0.6.0` / `m5-complete`  
**Release tags:** `m6-complete` · `v0.7.0`  
**Application version:** `0.7.0+1`  
**Platform focus:** Windows desktop (primary)

→ [M6 plan](../roadmap/m6-plan.md)  
→ [M6 closure audit](../roadmap/m6-closure-report.md)  
→ [Books & comics architecture](../architecture/books-comics.md)  
→ [Release index](./README.md)

---

## 1. Executive summary

Milestone 6 extends TTSPlayer with a **Windows-first books and comics reading experience** on the existing folder-tree platform: catalogue schema v4 and scanner v0.5.0, `book` and `comic` media kinds, browse/search/detail integration, **CBZ-only** comic reading, PDF and EPUB book readers, shared reading progress and Continue Reading (ADR-027), reader hardening, diagnostics, and per-page resilience.

All implementation phases (6.0–6.6 and **6.4C**) are complete. ADR-024–027 are **Accepted**. Automated regression is green (**1415** passed / **18** skipped). Backend unittest **31 passed**. Windows Release build succeeds. Opt-in runtime harnesses **P62–P66** all pass.

**Production comic format:** **CBZ only** (ADR-026 Accepted). CBR/RAR is not supported; legacy catalogue entries show external conversion guidance.

**M6 does not** ship bookmarks, annotations, dual-page spreads, manga RTL, cloud sync, in-app format conversion, or mobile-specific reader optimisation — see §4.

---

## 2. Objectives

| Objective | Outcome |
|---|---|
| Index books and comics in folder-tree catalogue | ✅ `catalogue_version: 4`, scanner `0.5.0`, `book` / `comic` kinds |
| Browse without invented categories | ✅ Folder filters, search, detail surfaces |
| CBZ comic reader | ✅ Lazy archive, bounded cache, fit modes, progress |
| PDF / EPUB book reader | ✅ Dedicated readers on Windows |
| Shared reading progress | ✅ ADR-027 repository; Continue Reading |
| Reuse M4/M5 infrastructure | ✅ Search, artwork, cache, diagnostics, providers |
| No video/music regression | ✅ Isolated keys; suite + runtime coverage |
| Windows runtime validation | ✅ P62–P66 harnesses green |

---

## 3. Delivered scope

### Major features

| Area | Delivered |
|---|---|
| **Catalogue** | Schema v4 · scanner 0.5.0 · `.pdf`, `.epub`, `.cbz` · author/series/page metadata |
| **Browse & search** | Book/comic kind labels · folder filters · search chips |
| **Comic reader** | CBZ-only · lazy ZIP · path safety · fit modes · wheel/tap/swipe · progress |
| **Book reader** | PDF (`pdfrx`) · EPUB (parser + HTML) · navigation · progress |
| **Reading progress** | Debounced writes · restore · completion · Read Again · Continue Reading |
| **Resilience** | Archive-level errors · per-page placeholders · retry · redacted diagnostics |
| **Runtime validation** | Opt-in Windows harnesses P62–P66 |

### Architecture

```text
Catalogue (schema v4)
    ↓
Browse / Search / Detail (media_kind routing)
    ↓
ComicReaderScreen (CBZ) · BookReaderScreen (PDF/EPUB)
    ↓
ReadingProgressRepository + Coordinator (ADR-027)
    ↓
ContinueReadingProjection (derived view — not a folder)
    ↓
Diagnostics (redacted reader + reading aggregates)
```

**Isolation:** reading progress uses `ttsplayer_reading_progress_v1` only; video `position_*` and music listening/session keys are untouched.

### ADRs

| ADR | Title | Status |
|---|---|---|
| 024 | Book/Comic Catalogue Schema | Accepted (CBZ-only comic production) |
| 025 | Identity and Metadata Precedence | Accepted |
| 026 | Reader Surface Architecture | Accepted (CBZ-only) |
| 027 | Reading Progress and Continue Reading | Accepted |

---

## 4. Deferred scope

| Item | Notes |
|---|---|
| CBR/RAR native reading | Superseded — external CBZ conversion + rescan |
| Bookmarks / annotations / highlights | Out of M6 scope |
| Dual-page spreads · manga RTL | Out of M6 scope |
| Cloud / multi-device sync | M7 / later |
| PDF password unlock UI | Post-M6 UX |
| EPUB full-ZIP memory model | Accepted limitation |
| Mobile reader optimisation | M7 / later |
| M5 music deferrals | Separate backlog |
| Post-milestone UX refinements | [post-milestone-ux-workflow-review.md](../roadmap/post-milestone-ux-workflow-review.md) |

---

## 5. Phase summary

| Phase | Focus | Status | Key commit |
|---|---|---|---|
| **6.0** | Planning and architecture | ✅ Complete | `b3e844a` |
| **6.1** | Catalogue schema and indexer | ✅ Complete | `e20e1e0` |
| **6.2** | Browse, search, detail | ✅ Complete | `eab1751` |
| **6.3** | CBZ comic reader foundation | ✅ Complete | `b9c048c` |
| **6.4** | PDF/EPUB book reader | ✅ Complete | `c73e7c7` |
| **6.4C** | Comic UX, progress, resilience | ✅ Complete | `1fc643d` |
| **6.5** | Reading progress, Continue Reading | ✅ Complete | `3042d38` |
| **6.6** | Reader hardening, diagnostics | ✅ Complete | `3abb169` |
| **Release** | Documentation and tags | ✅ Complete | *(release commit)* |

Repository Phase **6.4** is the book reader. Phase **6.4C** is the distinct comic reading-experience closure track.

---

## 6. Validation summary

| Validation | Result | Date |
|---|---|---|
| Full `flutter test` | **1415 passed** · **18 skipped** · **0 failed** | 2026-07-29 (release) |
| Backend unittest | **31 passed** · **0 failed** | 2026-07-28 |
| P62 browse runtime | **6/6** | 2026-07-29 (`b6ce503`) |
| P63 comic runtime | **13/13** | 2026-07-29 |
| P64 book runtime | **4/4** | 2026-07-28 |
| P65 progress runtime | **8/8** | 2026-07-28 |
| P66 hardening runtime | **9/9** | 2026-07-28 |
| Windows Release build | ✅ `ttsplayer.exe` | 2026-07-28 |

Harnesses are **opt-in** (env-gated; excluded from default suite when gates unset).

---

## 7. Accepted limitations

| Limitation | Disposition |
|---|---|
| CBZ-only comics | ADR-026 Accepted; convert CBR externally |
| Legacy `.cbr` in old catalogues | Conversion guidance until rescan |
| EPUB full-archive memory | Large EPUB RAM; lazy loader mitigates partially |
| PDF password-protected files | No unlock UI |
| PDF text accessibility | Partial |
| Comic swipe only in Contain at base transform | Documented in 6.4C |
| Diagnostic cache metrics | Not process RSS |
| Native Windows DPI >100% on validation host | Widget-equivalent coverage |

---

## 8. Runtime validation summary

| Harness | Gate | Tag | Outcome |
|---|---|---|---|
| Books/comics browse | `PHASE_62_RUNTIME=1` | `phase62-runtime` | R1–R6 pass |
| Comic reader | `PHASE_63_READER=1` | `phase63-reader` | 13 pass |
| Book reader | `PHASE_64_READER=1` | `phase64-reader` | 4 pass |
| Reading progress | `PHASE_65_READING_PROGRESS=1` | `phase65-reader` | 8 pass |
| Reader hardening | `PHASE_66_READER_HARDENING=1` | `phase66-reader` | 9 pass |

---

## 9. Final verdict

**Milestone 6 is formally complete.**

All implementation phases are delivered. Final automated and Windows runtime validation is green. No production blockers remain. The release is represented by **`v0.7.0`** on branch `m6-development`.

Tags `m6-complete` and `v0.7.0` are created locally; remote push is a separate authorised step.

**Next milestone:** [M7 — Metadata Enrichment](../roadmap/m7-plan.md) (planning). Former roadmap M7 multi-device scope is [M8](../roadmap/mobile-delivery.md#m8--multi-device-experience).

---

## Compatibility / upgrade notes

- Requires scanner **0.5.0+** and **catalogue schema v4** for books/comics. Stale v3 catalogues must be rescanned.
- Comic production format is **`.cbz` only**. Convert `.cbr` libraries externally and rescan.
- Existing video, music, Continue Watching, and listening/session keys are unchanged.
- Reading progress uses a new preference namespace; it does not modify video or music persistence.
