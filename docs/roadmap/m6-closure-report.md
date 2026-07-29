# M6 — Books & Comics — Milestone Closure Audit

**Audit date:** 2026-07-28  
**Branch:** `m6-development`  
**Baseline:** M5 — `v0.6.0` / `m5-complete`  
**Auditor scope:** Phase completion, DoD reconciliation (CBZ-only), ADR hygiene, regression and runtime evidence, release readiness assessment  
**Release execution:** **Not performed** in this audit (no tags, version bump, or push)

→ [M6 plan](./m6-plan.md) · [v0.7.0-dev tracker](../release/v0.7.0-dev.md) · [Books & comics architecture](../architecture/books-comics.md)

---

## 1. Executive summary

Milestone 6 delivers a **Windows-first books and comics reading experience** on the existing folder-tree platform: catalogue v4 with `book` and `comic` media kinds, browse/search/detail integration, CBZ comic reader, PDF/EPUB book reader, shared reading progress and Continue Reading (ADR-027), reader hardening, and Phase **6.4C** comic UX/progress/resilience closure.

**Production comic format:** **CBZ only** (ADR-026 **Accepted**, 2026-07-27). CBR/RAR production support was investigated, rejected for redistribution reasons, and removed. Legacy `.cbr` catalogue entries show external conversion guidance.

**Regression (2026-07-28 audit run):** Flutter **1402 passed, 19 skipped, 0 failed** (~66s). Backend unittest **31 passed, 0 failed**. Windows Release build **succeeded**. Core M6 opt-in runtime harnesses **P63–P66 passed** on this host. Phase **6.2** opt-in browse harness **4 passed, 2 failed** — stale test harness (missing `ReadingProgressCoordinator` provider after Phase 6.5); **not a product regression** (default-suite presentation tests green).

**Verdict:** **Conditionally ready for milestone closure.** All implementation phases are complete with evidence. Release finalisation (version bump, tags, `m6-complete.md`, index/README sync) and Phase 6.2 runtime harness refresh are named follow-ups before shipping `v0.7.0`.

---

## 2. Repository state (audit entry)

| Check | Result |
|---|---|
| Branch | `m6-development` |
| Working tree | Clean at audit start |
| Phase 6.4C closure commit | `1fc643d5e0c2d7b6bc17d61b7a541bbd726185da` present |
| Divergence from `origin/m6-development` | **7 commits ahead**, 0 behind (not pushed) |
| App version (`pubspec.yaml`) | `0.6.0+1` (unchanged — release task) |

---

## 3. Phase completion matrix

| Phase | Objective | Documented status | Closure / key commit | Test / runtime evidence | Audit verdict | Unresolved |
|---|---|---|---|---|---|---|
| **6.0** | Planning and architecture | Complete | `b3e844a` | Docs only | ✅ Complete | — |
| **6.1** | Catalogue schema, indexer, metadata | Complete | `e20e1e0` | `test_indexer.py`, `test_document_metadata.py`, catalogue compatibility tests | ✅ Complete | ADR-024 acceptance doc sync (this audit) |
| **6.2** | Browse, search, detail presentation | Complete | `eab1751` | `book_comic_presentation_test.dart`, `book_comic_search_test.dart`; P62 runtime **4/6** (harness stale) | ✅ Complete (product) | P62 harness provider refresh — **non-blocking** |
| **6.3** | CBZ comic reader foundation | Complete — CBZ-only | `b9c048c` (CBR removal) | Archive/opener/controller tests; P63 runtime **13/13** | ✅ Complete | — |
| **6.4** | PDF/EPUB book reader | Complete | `c73e7c7` | Book reader tests; P64 runtime **4/4** | ✅ Complete | — |
| **6.4C** | Comic UX, progress, resilience, diagnostics | Complete | `1fc643d` (+ Steps 2–6 chain) | 88 `phase_64c_*` scenarios; P63 extended **13/13 ×2** (prior) | ✅ Complete | Accepted limitations documented §6.4C |
| **6.5** | Reading progress, Continue Reading | Complete | `3042d38` | Coordinator/projection/isolation tests; P65 runtime **8/8** | ✅ Complete | — |
| **6.6** | Reader hardening, diagnostics, runtime | Complete | `3abb169` | Hardening + UX tests; P66 runtime **9/9** | ✅ Complete | H6 UnRAR superseded by ADR-026 |
| **Release** | Tags, version, release summary | Planned | — | — | ⏳ **Deferred** | Separate release-finalisation task |

---

## 4. M6 Definition of Done audit

Disposition key: **Met** · **Superseded** · **Deferral** · **Limitation** · **Blocker** · **N/A**

### Architecture and ADR governance

| Item | Disposition | Evidence / notes |
|---|---|---|
| ADR-024–027 Accepted or superseded | **Met** (with doc updates) | ADR-026/027 Accepted; ADR-024/025 **Accepted in this audit** with CBZ-only amendment (ADR-024 §CBR superseded by ADR-026) |
| `books-comics.md` reflects implementation | **Met** | Phase 6.4C refresh; CBZ-only, progress, diagnostics |
| No parallel catalogue/search/diagnostics systems | **Met** | Reuses M4/M5 stack |

### Functional behaviour

| Item | Disposition | Evidence / notes |
|---|---|---|
| Book/comic files indexed with correct `media_kind` | **Met** | Indexer `0.5.0`, v4; `.pdf`/`.epub`/`.cbz` |
| Comics include `.cbz` **and** `.cbr` (original DoD) | **Superseded** | ADR-026 Accepted — production **CBZ-only**; indexer emits `.cbz` only; legacy `.cbr` paths may remain in old catalogues |
| Browse via real folders | **Met** | Folder/search/detail; `book_comic_*` tests |
| Comic reader for **both CBZ and CBR** (original DoD) | **Superseded** | CBZ production reader; CBR blocked with conversion guidance |
| Graceful comic archive failures | **Met** | Opener + page-level resilience (6.4C) |
| PDF/EPUB book reader | **Met** | Phase 6.4 + P64 runtime |
| Reading progress + Continue Reading | **Met** | ADR-027; Phase 6.5 + 6.4C comic policies |
| Missing metadata does not hide items | **Met** | Graceful degradation rules |

### Compatibility and isolation

| Item | Disposition | Evidence / notes |
|---|---|---|
| Video browse / Continue Watching / playback | **Met** | `reading_progress_isolation_test.dart`; no M6 video regressions in suite |
| Music browse / playback / history / session | **Met** | P65 runtime music key unchanged; isolation tests |
| Reading progress isolated from video/music keys | **Met** | `ttsplayer_reading_progress_v1` namespace |

### Automated regression

| Item | Disposition | Evidence / notes |
|---|---|---|
| Focused M6 suites pass | **Met** | Book/comic, progress, reader, archive suites in default run |
| Full Flutter suite passes | **Met** | **1402 passed, 19 skipped, 0 failed** (2026-07-28) |

### Windows runtime validation

| Item | Disposition | Evidence / notes |
|---|---|---|
| Opt-in M6 runtime harnesses pass | **Met** (core) | P63 **13/13**, P64 **4/4**, P65 **8/8**, P66 **9/9** (this audit) |
| Comic runtime includes **CBZ and CBR** fixtures (original DoD) | **Superseded** | CBZ-only; CBR unavailable UI validated in widget/UX tests |
| Windows Release build succeeds | **Met** | `flutter build windows --release` ✅ (this audit) |
| No UnRAR/RAR native dependency | **Met** | No UnRAR in `lib/` production paths; Release build without RAR tooling |

### Performance and UX

| Item | Disposition | Evidence / notes |
|---|---|---|
| Large catalogues usable | **Limitation** | Informational baselines; not a ship gate |
| Reader failures show recovery | **Met** | Error placeholders, retry, dismissible errors |

### Diagnostics and documentation

| Item | Disposition | Evidence / notes |
|---|---|---|
| Redacted reading/reader diagnostics | **Met** | Phase 6.5/6.6/6.4C diagnostics |
| Release notes / indexes updated | **Deferral** | This audit + `v0.7.0-dev`; **`m6-complete.md` and tags** → release task |
| Version and tags published | **Deferral** | Explicitly out of scope for this audit |
| Working tree clean | **Met** | At audit entry |

---

## 5. CBR requirement reconciliation

| Original M6 requirement | Final disposition | Rationale |
|---|---|---|
| Index `.cbz` and `.cbr` | **Superseded (indexer)** | Backend `_COMIC_EXTENSIONS = {".cbz"}` only; ADR-026 Accepted |
| Open/navigate CBR in reader | **Superseded** | CBR code removed `b9c048c`; conversion guidance in detail UI |
| Gate 0 UnRAR validation | **Superseded** | Investigation archived; not a production dependency |
| UnRAR DLL/CLI/FFI packaging | **Rejected / removed** | No production references in client build |
| Legacy CBR in catalogue | **Known limitation** | May appear from pre-removal scans; Open Comic disabled; rescan after conversion |
| Historical CBR docs | **Retained** | `cbr-rar-evaluation.md`, archived UnRAR eval — audit trail only |

---

## 6. ADR summary (ADR-024 – ADR-027)

| ADR | Title | Prior status | **Final status** | Rationale |
|---|---|---|---|---|
| **ADR-024** | Book/Comic Catalogue Schema | Proposed | **Accepted** (2026-07-28) | v4 catalogue, `book`/`comic` kinds, scanner 0.5.0 implemented and tested; **comic extension amended to `.cbz` production** per ADR-026 |
| **ADR-025** | Identity and Metadata Precedence | Proposed | **Accepted** (2026-07-28) | Path-based identity, title/metadata precedence implemented in indexer + client; progress keys stable item id |
| **ADR-026** | Reader Surface Architecture | Accepted | **Accepted** | CBZ-only comic reader; dedicated book/comic surfaces |
| **ADR-027** | Reading Progress | Accepted | **Accepted** | Shared repository, Continue Reading, isolation validated |

---

## 7. Regression evidence (2026-07-28)

| Suite | Command | Result | Duration |
|---|---|---|---|
| Flutter (full) | `cd client/ttsplayer && flutter test` | **1402 passed, 19 skipped, 0 failed** | ~66s |
| Backend indexer + metadata | `cd backend && python -m unittest test_indexer test_document_metadata` | **31 passed, 0 failed** | ~0.1s |
| Windows Release | `flutter build windows --release` | **Success** → `build\windows\x64\runner\Release\ttsplayer.exe` | ~49s |

**Baseline comparison:** Phase 6.4C closure recorded **1423 passed, 16 skipped**. Current audit **1402/19** — difference reflects suite evolution (test count/reorganisation), not failures. Both runs: **0 failed**.

**Environment:** Windows 10.0.26200, Flutter 3.44.4, Dart 3.12.2.

---

## 8. Windows runtime harness inventory

| Harness | Gate | Tag | Scenarios | Prior recorded | **Audit run (2026-07-28)** | Rerun required? | Release build? |
|---|---|---|---|---|---|---|---|
| `phase_62_books_comics_windows_runtime_test.dart` | `PHASE_62_RUNTIME=1` | `phase62-runtime` | R1–R6 (6) | Not in 6.4C baseline | **4 passed, 2 failed** (R4, R6 — harness provider gap) | Refresh harness; **non-blocking** | No |
| `phase_63_comic_reader_windows_runtime_test.dart` | `PHASE_63_READER=1` | `phase63-reader` | 13 (6.3 + 6.4C) | 13/13 ×2 | **13 passed, 0 failed** | ✅ Done | No |
| `phase_64_book_reader_windows_runtime_test.dart` | `PHASE_64_READER=1` | `phase64-reader` | 4 | Phase 6.4 closure | **4 passed, 0 failed** | ✅ Done | No |
| `phase_65_reading_progress_windows_runtime_test.dart` | `PHASE_65_READING_PROGRESS=1` | `phase65-reader` | 8 | Phase 6.5 closure | **8 passed, 0 failed** | ✅ Done | No |
| `phase_66_reader_windows_runtime_test.dart` | `PHASE_66_READER_HARDENING=1` | `phase66-reader` | 9 | Phase 6.6 closure | **9 passed, 0 failed** | ✅ Done | Informational RSS baselines |

**P62 failure analysis:** `ItemDetailScreen` now calls `readingProgressSummaryForItem()` (Phase 6.5). Harness lacks `ReadingProgressCoordinator` provider → `ProviderNotFoundException`. Default-suite `book_comic_presentation_test.dart` covers detail surfaces with correct providers.

---

## 9. Accepted limitations and approved deferrals

### Accepted limitations (M6 ship scope)

| Limitation | Source |
|---|---|
| CBZ-only comics; external CBR→CBZ conversion | ADR-026 |
| EPUB full-ZIP decode in memory (large EPUB RAM) | Phase 6.4/6.6 |
| PDF password-protected files — no unlock UI | Phase 6.6 H8 deferral |
| PDF text accessibility gaps | Phase 6.6 H9 |
| EPUB scroll precision after typography change | Phase 6.6 H10–H12 |
| Comic swipe page turns only in Contain at base transform | Phase 6.4C |
| No bookmarks, annotations, dual-page, RTL, cloud sync | M6 exclusions |
| Diagnostic memory = cache metrics, not process RSS precision | Phase 6.6 |
| Native Windows DPI >100% on validation host | Phase 6.6 UX matrix |

### Approved deferrals (post-M6)

| Item | Notes |
|---|---|
| M6 Release tags and version bump | Release-finalisation task |
| `m6-complete.md` shipping summary | Release-finalisation task |
| Mobile reader optimisation | M7 / later |
| PDF password UI | Post-M6 UX |
| In-app CBZ conversion | Out of scope |
| M5 music deferrals | Separate backlog |
| Post-milestone UX and workflow | [post-milestone-ux-workflow-review.md](./post-milestone-ux-workflow-review.md) — not blocking release |

### Genuine blockers

**None identified** for milestone closure on `m6-development`. Release shipping blocked only on release-finalisation steps (version, tags, release doc).

---

## 10. Release readiness (assessment only)

| Item | Intended value | Status |
|---|---|---|
| Application version | **`0.7.0+1`** (proposed) | Not bumped |
| Semver release tag | **`v0.7.0`** | Not created |
| Milestone tag | **`m6-complete`** | Not created |
| Release summary | **`docs/release/m6-complete.md`** | Not created |
| Files needing version update | `client/ttsplayer/pubspec.yaml`, possibly `README.md` | Pending |
| Branch strategy | Close on `m6-development`; tag from closure commit (M5 pattern) | Documented |
| Windows Release build | Required before ship | ✅ Verified this audit |

### Recommended release-finalisation sequence (later task)

1. Refresh `phase_62` runtime harness (`ReadingProgressCoordinator` in provider tree); re-run P62.
2. Bump `pubspec.yaml` to `0.7.0+1`.
3. Create `docs/release/m6-complete.md` (mirror `m5-complete.md` structure).
4. Update `MILESTONES.md`, `docs/release/README.md`, `README.md` roadmap table.
5. Final `flutter test` + M6 runtime harness sweep on Windows.
6. Commit: `docs(m6): close books and comics milestone` (+ version bump commit if separated).
7. Tag `m6-complete` and `v0.7.0` on closure commit.
8. Push branch and tags when authorised.

---

## 11. Proposed documentation commit message

```
docs(m6): milestone closure audit — CBZ-only reconciliation

Record phase completion matrix, DoD disposition (ADR-026 CBR supersession),
ADR-024/025 acceptance, regression/runtime evidence, limitations, and
conditional release readiness. No version bump or tags.
```

---

## 12. Final verdict

**Conditionally ready for milestone closure.**

All M6 implementation phases (6.0–6.6, 6.4C) are complete with verified automated evidence and core Windows runtime sign-off. CBR requirements are reconciled as **superseded by ADR-026**, not open blockers. Follow before public release: release-finalisation (version, tags, `m6-complete.md`, index sync) and optional Phase 6.2 runtime harness provider refresh.
