# M7 Phase 7.3.2 — Matching Coordinator and Persistence Transitions

**Status:** Complete (2026-07-30)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3.1 closure](./m7-phase-7.3.1-closure-report.md)

→ [M7 plan](./m7-plan.md) · [Phase 7.3 plan](./m7-phase-7.3-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Delivered

Service-level orchestration under `client/ttsplayer/lib/features/metadata_enrichment/services/`:

| Component | Responsibility |
|---|---|
| `BookMetadataMatchingCoordinator` | Application-facing explicit operations |
| `BookMetadataMatchTransition` | Deterministic enrichment record transitions |
| `BookCandidateSelectionContext` | Transient validation token for manual selection |
| `BookCandidateReviewPolicy` | Reviewable-candidate and critical-conflict rules |
| `book_metadata_matching_result.dart` | Sealed bounded result types |

**Not delivered:** production UI, book-detail section, dialogs, settings/privacy UI, production provider activation, main wiring, background matching, Windows runtime harness.

---

## Application-facing ISBN boundary

- **`BookMetadataMatchingCoordinator`** is the application-facing workflow API for Phase 7.3+ UI.
- **`BookMetadataRefreshService`** is a lower-level ISBN implementation service used by the coordinator through dependency injection.
- Future UI and main application wiring must call the coordinator, not the refresh service directly.
- ISBN validation, conflict detection, no-result policy, lock preservation, and persistence construction are shared through `BookMetadataMatchTransition` and refresh-service delegation — not duplicated independently in the coordinator.

---

## Search result semantics

| Result | Meaning |
|---|---|
| `BookCandidateSearchNoProviderCandidates` | Provider returned an empty candidate list |
| `BookCandidateSearchEvaluationSuccess` | One or more candidates were evaluated — **always** used for non-empty provider results |

Non-empty evaluated results are **never** represented as `NoProviderCandidates`.

`BookCandidateSearchEvaluationSuccess` exposes:

- `matchSet` — complete transient evaluation
- `selectionContext` — coordinator-owned validation token
- `hasAcceptableCandidates` — evaluator acceptable band (≥ 0.60 or identifier match)
- `hasReviewableCandidates` — candidates eligible for manual selection
- `requiresConflictReview` — ambiguous/conflict-review set

Weak unrelated candidates below threshold remain in `matchSet.rankedEvaluations` but are **not** reviewable.

---

## Reviewable-candidate policy

All evaluated candidates remain in the transient match set internally.

Manual selection is allowed only for **reviewable** candidates:

1. **Acceptable band** — score ≥ 0.60 or identifier match (evaluator `acceptableEvaluations`)
2. **Critical conflict review** — below threshold but with ISBN conflict, contradictory author, or `disqualifiedForAutoLink`, **and** partial-or-better title agreement

Ordinary weak provider hits below 0.60 without critical conflict are not selectable.

Critical override confirmation (`BookCandidateSelectionConfirmation.overrideCriticalConflicts`) is required only for:

- ISBN conflict
- Contradictory author
- `disqualifiedForAutoLink`

Non-critical warnings (edition, volume, language, omnibus, abridged) do not require the override flag.

---

## Selection-context integrity

`BookCandidateSelectionContext` binds:

- local item id
- provider id
- search fingerprint (includes item id and normalized local inputs)
- coordinator-owned evaluations keyed by provider record id
- reviewable record id list
- generated-at timestamp (informational only — no expiry enforcement)

Contexts are reusable value objects; the coordinator does not consume or invalidate them after use.

Invalid context returns `BookCandidateSelectionInvalidContext` (not “stale”) when item id, provider id, or record id do not match.

Confidence and candidate metadata always come from the context evaluation — never from caller input.

---

## Explicit persistence preconditions

### `recordAmbiguousOutcome()`

Requires a valid selection context and a match set classified as ambiguous/conflict review (`matchSet.isAmbiguous`).

### `recordNoMatchOutcome()`

Requires bounded `BookNoMatchPersistenceReason`:

- `userSelectedNone`
- `noReviewableCandidates`

Linked records are preserved unless the user explicitly unlinks first.

### Ignored state

Lookup, search, selection, relink, ambiguous recording, and no-match recording reject ignored items until `resumeMatching()`. `ignore()` and `resumeMatching()` do not invoke the provider.

---

## Field ownership (relink / unlink / ignore)

- **Relink:** remove old unlocked provider-owned fields absent from the new candidate; preserve user overrides and locked fields; replace provider provenance.
- **Unlink / ignore:** remove unlocked provider-owned fields; retain user overrides; do not convert provider values to user values.

---

## Test evidence

| Suite | Result |
|---|---|
| Coordinator + transitions + isolation + refresh | 41 passed |
| Affected provider/evaluator/ranker tests | 36 passed |
| Full `flutter test` | **1577 passed, 19 skipped, 0 failed** |

---

## Remaining work

| Step | Deliverable |
|---|---|
| 7.3.3 | Book detail metadata section (debug gate) |
| 7.3.4 | Candidate selection + confirmation dialogs |
| 7.3.5+ | Unlink/ignore UI, widget tests, Windows harness, closure |

**ADR-029:** remains **Proposed**.
