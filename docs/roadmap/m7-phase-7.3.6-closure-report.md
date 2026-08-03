# M7 Phase 7.3.6 — Widget-Test Consolidation and Windows Runtime Harness

**Status:** Complete (2026-08-03) — uncommitted for review
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3.5 closure](./m7-phase-7.3.5-closure-report.md)

→ [M7 plan](./m7-plan.md) · [Phase 7.3 plan](./m7-phase-7.3-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.3.6 | `7b22f5e` — `docs(m7.3): document lifecycle workflow polish` |
| Phase 7.3.5 implementation | `e945f8d` — `feat(m7.3): polish metadata unlink ignore and rematch flows` |
| Phase 7.3.5 documentation | `7b22f5e` |
| Working tree before 7.3.6 | Clean |
| Divergence vs `origin/m6-development` | `0 17` |
| Unrelated changes | None |

---

## Prior harness conventions reused

| Convention | Source |
|---|---|
| `PHASE_*_RUNTIME=1` env gate + single skip when absent | Phase 4.6, 6.2, 6.3 |
| `@Tags(['phase736-runtime'])` + `dart_test.yaml` entry | Phase 6.2/6.3 |
| `LiveTestWidgetsFlutterBinding.ensureInitialized()` | Phase 5.5, 6.2 |
| Windows-only skip with clear reason | All prior runtime harnesses |
| Production provider/coordinator/repository wiring | Phase 5.5 playback harness |
| Deterministic fake at provider boundary only | Phase 7.3 widget tests |
| `Phase736MetadataRuntimeBaseline` informational summary | Phase 5.5 baseline pattern |
| Optional `PHASE_736_LOCAL_CATALOG` (does not affect deterministic baseline) | Phase 6.2 local catalog pattern |
| SharedPreferences mock + repository reload | Metadata enrichment unit tests |
| Item-scoped lifecycle host widget | Phase 7.3.4/7.3.5 widget tests |
| `CountingTransitionCoordinator` / delayed coordinators | `book_metadata_enrichment_section_test_support.dart` |

---

## Harness architecture

```
phase_736_metadata_matching_windows_runtime_test.dart  (M1–M30, O1)
  └── phase_736_metadata_runtime_harness.dart          (Phase736RuntimeContext, hosts)
        ├── phase_736_scripted_book_metadata_provider.dart
        ├── phase_736_metadata_fixtures.dart
        ├── phase_736_metadata_runtime_baseline.dart
        └── book_metadata_enrichment_section_test_support.dart (tap helpers)
```

Production components under test:

- `BookMetadataEnrichmentSection`
- `ItemDetailScreen` (book detail integration)
- `BookMetadataCandidateDialog` / `BookMetadataCandidateCard`
- `BookMetadataMatchingCoordinator` (production implementation)
- `MetadataEnrichmentRepository`
- `BookMetadataRefreshService`
- Presentation mappers (`MetadataMatchStatePresentation`, candidate/warning presentation)

Fake boundary: `Phase736ScriptedBookMetadataProvider` implements `BookMetadataProvider` — maps search titles to deterministic fixture responses; counts invocations; never performs HTTP.

---

## Environment gate and tag

| Item | Value |
|---|---|
| Gate | `PHASE_736_RUNTIME=1` |
| Tag | `phase736-runtime` |
| Non-Windows | Single skip — Windows-only |
| Gate absent | Single skip explaining enablement |
| Optional local catalog | `PHASE_736_LOCAL_CATALOG` → scenario O1 (manual) |

```powershell
cd client\ttsplayer
$env:PHASE_736_RUNTIME='1'
flutter test test/phase_736_metadata_matching_windows_runtime_test.dart --tags phase736-runtime
Remove-Item Env:PHASE_736_RUNTIME
```

---

## Fixture catalogue (`PHASE736-RUNTIME`)

| ID | Item | Initial state | Provider scenario |
|---|---|---|---|
| A | `m736-book-a` Strong Match | No record | Strong + secondary ranked candidates |
| B | `m736-book-b` Conflict | No record | Author conflict candidate (ISBN in fixture metadata; ISBN conflict via search requires trusted local ISBN — covered in widget tests) |
| C | `m736-book-c` Manual Link | `linkedManual` | Pre-seeded |
| D | `m736-book-d` Ignored | `ignored` | Pre-seeded |
| E | `m736-book-e` Rematch | `linkedManual` + locked author | Rematch alt + same-record candidates |
| F | `m736-book-f` Empty | No record | Empty search result |
| G | `m736-book-g` Failure | No record | Provider network failure |
| — | `m736-video` Sample Video | N/A | Non-book isolation |

---

## Scenario matrix

| ID | Classification | Result |
|---|---|---|
| M1 | Automated | Pass — harness init, fixture load, zero provider calls |
| M2 | Automated | Pass — item detail section visible, no provider on open |
| M3 | Automated | Pass — one search, reviewable candidates, no persistence |
| M4 | Automated | Pass — ranked order, no preselection, qualitative match text, provider-neutral fields |
| M5 | Automated | Pass — one select write, `linkedManual`, local title unchanged |
| M6 | Automated | Pass — cancel confirm, no persistence, dialog reusable |
| M7 | Automated | Pass — critical author warning, no enum leakage |
| M8 | Automated | Pass — critical override, one write, `linkedManual` |
| M9 | Automated | Pass — coordinator backstop → critical confirm → override retry |
| M10 | Automated | Pass — rematch search, link retained during review |
| M11 | Automated | Pass — cancel rematch, link unchanged |
| M12 | Automated | Pass — relink path, locked author preserved, provider fields updated |
| M13 | Automated | Pass — same-record message, no redundant search |
| M14 | Automated | Pass — unlink cancel, no write |
| M15 | Automated | Pass — one unlink, `unmatched`, bounded success message |
| M16 | Automated | Pass — one ignore (requires `unmatched` record), search suppressed |
| M17 | Automated | Pass — one resume, no auto provider call |
| M18 | Automated | Pass — empty result, retry available |
| M19 | Automated | Pass — bounded failure, no transport text, retry per attempt |
| M20 | Automated | Pass — repository failure, retry without re-search |
| M21 | Automated | Pass — duplicate confirm → one write |
| M22 | Automated | Pass — item change closes dialog, no cross-item persistence |
| M23 | Automated | Pass — delayed select ignored by replacement item |
| M24 | Automated | Pass — delayed unlink ignored by replacement item |
| M25 | Automated | Pass — dispose with open dialog, no exception |
| M26 | Automated | Pass — cross-item states isolated |
| M27 | Automated | Pass — video item: no enrichment section, no provider |
| M28 | Automated | Pass — reload preserves match/lock state, no transient UI state |
| M29 | Deferred | Metadata diagnostics export not in M7.3 scope |
| M30 | Automated (informational) | Pass — baseline summary printed |
| O1 | Optional/manual | Skipped unless `PHASE_736_LOCAL_CATALOG` set |

**Runtime totals (gate on):** 30 passed, 1 skipped (O1), 0 failed.

---

## Widget-test consolidation

No test files were merged or deleted. Audit conclusion: existing split preserves diagnostic clarity.

| Layer | Files | Role |
|---|---|---|
| Unit — evaluator/ranker/decisions | `book_candidate_evaluator_test.dart`, `book_metadata_matching_transitions_test.dart` | Deterministic scoring and transition policy |
| Unit — coordinator/repository/refresh | `book_metadata_matching_coordinator_test.dart`, `metadata_enrichment_repository_test.dart`, `book_metadata_refresh_service_test.dart` | Persistence and orchestration |
| Unit — isolation | `book_metadata_matching_isolation_test.dart` | Cross-item record isolation |
| Widget — section/ISBN/search | `book_metadata_enrichment_section_test.dart` | Gate, states, ISBN, search summaries, transitions |
| Widget — candidate selection | `book_metadata_candidate_selection_test.dart` | Dialog, conflicts, relink, lifecycle, ISBN conflict with override |
| Widget — lifecycle polish | `book_metadata_lifecycle_polish_test.dart` | Unlink/ignore/resume/rematch labels and item lifecycle |
| Widget — item detail | `item_detail_screen_test.dart` (metadata group) | Production detail route integration |
| Runtime — end-to-end wiring | `phase_736_metadata_matching_windows_runtime_test.dart` | Production stack + scripted provider (M1–M30) |
| Shared support | `book_metadata_enrichment_section_test_support.dart`, `metadata_enrichment_test_support.dart`, `phase_736_*` | Harnesses, fakes, fixtures |

Duplicate assertions removed: **none** — widget tests retain focused policy names; runtime harness covers production wiring evidence without duplicating evaluator unit cases.

---

## Defects found and fixed

No production defects discovered. Harness development adjusted test assertions only (publisher label format, `unmatched` record required for ignore action, M9 confirm-before-backstop flow matching widget tests).

---

## Test execution totals

| Suite | Passed | Skipped | Failed |
|---|---:|---:|---:|
| Phase 7.3 focused (candidate + lifecycle + section + coordinator + transitions + isolation + refresh + item detail) | 131 | 0 | 0 |
| Windows runtime (`PHASE_736_RUNTIME=1`) | 30 | 1 | 0 |
| Full `flutter test` (no runtime gate) | 1684 | 20 | 0 |

The full regression includes the runtime file’s single gate-absent skip (+19 existing skips). Runtime scenarios do not execute without the gate.

---

## Phase 7.3 completion matrix

| Sub-phase | DoD item | Evidence |
|---|---|---|
| 7.3.1 | Evaluator/ranker deterministic | `book_candidate_evaluator_test.dart`; runtime M4 ordering |
| 7.3.2 | Coordinator + transitions | Coordinator/transitions tests; runtime M5–M17 |
| 7.3.3 | Item-detail section (dev gate) | Section + item detail tests; runtime M2 |
| 7.3.4 | Candidate selection + conflicts | Candidate selection tests; runtime M3–M9, M21 |
| 7.3.5 | Unlink/ignore/rematch polish | Lifecycle polish tests; runtime M10–M17 |
| 7.3.6 | Runtime harness + consolidation | This report; M1–M30 pass |
| Cross-cutting | No implicit provider calls | M2, M16, M17, M27; isolation tests |
| Cross-cutting | Item-scoped async lifecycle | M22–M25; widget lifecycle tests |
| Cross-cutting | Fake provider in CI/default test | Default regression green without gate |
| Cross-cutting | ADR-029 Proposed | Unchanged |

**Phase 7.3 status:** Complete.

---

## ADR-029 status

**Proposed** — unchanged. Runtime harness validates implementation against the proposed precedence model; governance acceptance remains a separate review.

---

## Known limitations

- Book B runtime conflict uses **author conflict** through production search (catalogue items lack trusted ISBN for search-path ISBN conflict). ISBN conflict critical UI is fully covered in `book_metadata_candidate_selection_test.dart`.
- Ignore action requires an `unmatched` enrichment record (not `forNoRecord()` presentation) — matches coordinator `ignore()` contract.
- M29 diagnostics deferred until Phase 7.7.
- Production Open Library remains inactive (Phase 7.8 optional).

---

## Proposed commit split

1. `test(m7.3): add metadata matching Windows runtime harness` — harness, fixtures, provider, baseline, `dart_test.yaml` tag
2. `docs(m7.3): close Phase 7.3 validation and runtime harness` — this report, plan, architecture, release updates

---

## Recommended next task

**Phase 7.4 — Artwork enrichment and cache** per [m7-plan.md](./m7-plan.md): download worker, disk quota, precedence integration with enrichment records.

---

## Files changed (7.3.6)

**New**

- `client/ttsplayer/test/phase_736_metadata_matching_windows_runtime_test.dart`
- `client/ttsplayer/test/support/phase_736_metadata_fixtures.dart`
- `client/ttsplayer/test/support/phase_736_scripted_book_metadata_provider.dart`
- `client/ttsplayer/test/support/phase_736_metadata_runtime_harness.dart`
- `client/ttsplayer/test/support/phase_736_metadata_runtime_baseline.dart`
- `docs/roadmap/m7-phase-7.3.6-closure-report.md`

**Modified**

- `client/ttsplayer/dart_test.yaml`
- `docs/roadmap/m7-phase-7.3-plan.md`
- `docs/architecture/metadata-enrichment.md`
- `docs/release/v0.8.0-dev.md`
