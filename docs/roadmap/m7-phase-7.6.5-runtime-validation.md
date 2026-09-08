# M7 Phase 7.6.5 — Windows UX/Workflow Runtime Validation

**Status:** Complete with packaged-app interaction smoke retained for 7.6.6/release QA

**Validated:** 2026-09-07 on Windows

**Baseline:** `30121e4 feat(m7.6): add direct media activation routing`

→ [Phase 7.6 plan](./m7-phase-7.6-ux-workflow-plan.md) · [M7 plan](./m7-plan.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

## Outcome

The Phase 7.6 workflow remains sound. No production defect or semantic change was required. One pre-existing Phase 6.2 Windows harness expectation was stale: it clicked a supported book card and expected Details, although Phase 7.6.4 intentionally routes that primary action to the reader. The harness now selects the explicit Details control and proves that back navigation returns to the folder.

Local-first metadata precedence, accepted-match gating, deterministic search ranking, zero-dependency `SearchService` construction, artwork resolution, and scanner/provider contracts were not changed.

## Validation matrix

| Area | Case | Result | Evidence | Mode |
|---|---|---|---|---|
| Folder/library | Available video → video player | Pass | shared activation table + `PlayerScreen` lifecycle tests | Automated |
| Folder/library | Available audio → single-track music player | Pass | shared activation table + music player tests; surface uses shared helper | Automated |
| Folder/library | PDF / EPUB → book reader | Pass | Phase 6.4 Windows harness, 4/4 | Automated Windows |
| Folder/library | CBZ / ZIP → comic reader | Pass | shared extension policy; Phase 6.3 Windows harness, 13/13 (CBZ production path) | Automated Windows |
| Folder/library | Image / unsupported / missing → Details | Pass | table-driven activation-policy tests | Automated |
| Folder/library | Explicit Details is independent | Pass | `TtsMediaCard` nested-control test; refreshed Phase 6.2 R6 | Automated Windows |
| Search | Primary action uses shared routing | Pass | source wiring audit + activation-policy tests | Automated/static |
| Search | Details action independent; stale item safe | Pass | search presentation suite | Automated |
| Search | Enriched Details remains intact | Pass | Phase 7.5 Windows R1–R12, 12/12 | Automated Windows |
| Recently Added | Routing parity and explicit Details | Pass | source wiring audit; shared-card isolation + policy tests | Automated/static |
| Favourites | Routing parity; Details; favourite state | Pass | favourites suite + shared policy/card tests | Automated |
| Players | Video/audio route return preserves caller | Pass | player and music-player navigation/lifecycle tests | Automated |
| Readers | PDF/EPUB/CBZ open, navigate, and close cleanly | Pass | Phase 6.3 and 6.4 Windows harnesses | Automated Windows |
| Readers | ZIP supported-reader policy | Pass | table-driven policy; ZIP uses the same comic archive opener as CBZ | Automated/static |
| Interaction | Mouse click and nested Details do not double-activate | Pass | widget pointer tests and activation counters | Automated |
| Interaction | Keyboard activation where exposed | Pass | search Enter/result activation, reader keyboard navigation, player shortcuts | Automated Windows/widget |
| Interaction | Back/close predictable; no duplicate route observed | Pass | folder Details R6; reader/player lifecycle tests | Automated Windows/widget |
| Errors | Missing, unsupported, image, stale result | Pass | activation and search regression suites | Automated |
| Errors | Reader/player initialization failure | Pass | corrupt-CBZ controlled error and player error/retry/back tests | Automated Windows/widget |
| Rescan | Exact book/comic path, nested replacement, last-good failure | Pass | folder-rescan focused tests and Phase 7.6.3 regression coverage | Automated |
| Artwork | Continue Watching aspect ratio remains proportional | Pass | card/artwork fit and bounded-layout tests | Automated |

## Executed evidence

| Command/suite | Result |
|---|---|
| Focused activation/search/favourites/rescan/player/reader selection | **140 passed, 2 skipped, 0 failed** |
| `PHASE_62_RUNTIME=1` books/comics browsing | Initial R6 stale expectation failed; after harness-only correction: **6 passed, 0 failed** |
| `PHASE_63_READER=1` comic reader | **13 passed, 0 failed** |
| `PHASE_64_READER=1` book reader | **4 passed, 0 failed** |
| `PHASE_75_RUNTIME=1` enriched search/detail | **12 passed, 0 failed** |
| `flutter analyze` | **360 existing findings, 0 errors**; no new finding from the harness correction |
| Full `flutter test` | **1,853 passed, 21 skipped, 0 failed** |

The two focused skips were the Phase 6.3 and 6.4 opt-in sentinels in the ungated focused command; both harnesses were then run with their Windows gates enabled and passed.

## Defect and correction

| Defect | Correction | Scope |
|---|---|---|
| Phase 6.2 R6 expected a primary click on a supported PDF to open Details | Select `media_details_mixed-book` inside the card before asserting Details/back behaviour | Test infrastructure only; no production code |

## Files changed

- `client/ttsplayer/test/phase_62_books_comics_windows_runtime_test.dart`
- `docs/roadmap/m7-phase-7.6.5-runtime-validation.md`
- `docs/roadmap/m7-phase-7.6-ux-workflow-plan.md`
- `docs/roadmap/m7-plan.md`
- `docs/release/v0.8.0-dev.md`

## Remaining manual checks

The automated Windows harnesses render and exercise the production Flutter routes, readers, focus actions, and native PDF/comic paths. They cannot prove operating-system window-manager behaviour in the packaged executable. A short release smoke remains advisable: primary mouse activation for one real video and audio file, Alt+Left/Escape/back after playback, one real ZIP archive, and confirmation that no invisible secondary window or double launch appears. This is release QA, not evidence of an implementation gap, and does not block Phase 7.6.5 closure.

## Closure recommendation

Close Phase 7.6.5. The complete automated matrix is green after the test-only compatibility correction. Proceed to Phase 7.6.6 documentation reconciliation, retaining the packaged-app smoke above as an explicit release check.
