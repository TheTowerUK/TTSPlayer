# M7 Phase 7.3.4 — Candidate Selection and Warning Confirmation

**Status:** Complete (2026-07-30)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3.3 closure](./m7-phase-7.3.3-closure-report.md)

→ [M7 plan](./m7-plan.md) · [Phase 7.3 plan](./m7-phase-7.3-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Delivered

Provider-neutral candidate review and explicit selection workflow under `client/ttsplayer/lib/features/metadata_enrichment/`:

| Component | Responsibility |
|---|---|
| `BookMetadataCandidatePresentation` | Maps coordinator-owned evaluations to provider-neutral display fields and qualitative match summaries |
| `BookMetadataWarningPresentation` | Maps evaluator warnings to bounded critical/non-critical user text |
| `BookMetadataCandidateCard` | Selectable radio card with title, author, optional metadata, warnings |
| `BookMetadataCandidateDialog` | Reviewable-candidate list, ordinary/critical confirmation, `selectCandidate` / `relinkCandidate` via coordinator |
| `BookMetadataEnrichmentSection` (updated) | Opens dialog from transient search context; handles success/failure/invalid-context results; clears transient state on success |
| `MetadataEnrichmentUiMessages` (updated) | Selection/relink result and success message mapping |

**Not delivered:** production Open Library activation, metadata provider settings, privacy/consent UI, automatic matching, background refresh, `linkedHighConfidence` persistence, provider artwork, cover selection, bulk matching, Windows runtime harness, HTTP/backend changes, dependency/version changes.

---

## Reviewable-candidate boundary

The dialog renders **only** `BookCandidateSelectionContext.reviewableRecordIds`, resolved through `evaluationForRecordId()` in ranked `matchSet` order. The UI does not recompute confidence, derive reviewability from score thresholds, or mutate selection-context data.

When search returns evaluations but no reviewable candidates, the section retains “No suitable metadata candidates found” and the bounded no-match action — the candidate dialog does not open.

---

## Selection flows

### Unlinked manual selection

1. Explicit search → transient `BookCandidateSelectionContext`
2. **Review candidates** → dialog (no persistence on open or card select)
3. **Use this metadata** → ordinary confirmation
4. `selectCandidate()` → `linkedManual`, `matchMethod.manual`, coordinator-owned confidence
5. Repository refresh via `ChangeNotifier`; transient search cleared

### Linked-item relink

**Change metadata** performs transient search; existing link retained until final confirmation. Confirmed selection calls `relinkCandidate()` with stale unlocked provider fields removed, user overrides and locked fields preserved. Same-record relink reports “This metadata is already linked.” without error.

### Critical-conflict override

ISBN conflict, contradictory author, and `disqualifiedForAutoLink` require dedicated override confirmation with listed warnings and `BookCandidateSelectionConfirmation.overrideCriticalConflicts`. Non-critical warnings (edition, volume, language, etc.) display on cards but use ordinary confirmation only.

Coordinator backstop `BookCandidateSelectionConflictConfirmationRequired` re-opens critical confirmation if the UI submits without override.

---

## Failure and invalid-context handling

| Result | User message | Persistence |
|---|---|---|
| Invalid context | These metadata candidates are no longer valid. Search again. | None; transient search cleared |
| Repository failure | Metadata could not be saved. | Prior state retained; retry without new search |
| Rejected / invalid transition | Bounded `MetadataEnrichmentUiMessages.selectionResultMessage` | None |

Cancellation at any confirmation step closes without persistence. Provider invocation count unchanged during dialog open, card selection, confirmation, persistence, cancellation, and failure handling.

---

## Widget-test evidence

| File | Coverage |
|---|---|
| `test/book_metadata_candidate_selection_test.dart` | Rendering, ordering, selection, relink, critical/non-critical warnings, invalid context, repository failure, concurrency, responsive, item-scoped dialog lifecycle |
| `test/book_metadata_enrichment_section_test.dart` | Review opens real dialog; ambiguous state without transient search does not show review button |
| `test/item_detail_screen_test.dart` | Gate-enabled book detail can search and open candidate review |
| `test/book_metadata_matching_isolation_test.dart` | Candidate dialog avoids provider/repository/refresh imports; calls coordinator selection APIs only |

Fake provider / in-memory repository harness: `test/support/book_metadata_enrichment_section_test_support.dart`.

Focused candidate + section + item-detail tests: **63 passed** (2026-07-31, including item-scoped dialog lifecycle).

Full `flutter test`: **1638 passed, 19 skipped, 0 failed** (2026-07-31).

---

## Commit approval

Phase 7.3.4 is **approved** for the planned two commits:

1. **Implementation** — `feat(m7.3): add book metadata candidate selection`
2. **Documentation** — `docs(m7.3): document candidate selection workflow`

---

## ADR-029

Remains **Proposed** — governance review deferred.

---

## Item-scoped dialog lifecycle

The enrichment section owns candidate review through `BookMetadataCandidateDialogSession` with a monotonic `_candidateReviewGeneration`. When `item.id` changes or the section disposes, the section dismisses only the named candidate-dialog route (and any stacked confirmation routes above it) via a captured `NavigatorState`, invalidates the dialog scope, and ignores stale session results.

---

## Known limitations

- Production coordinator and Open Library remain unwired in `main.dart`.
- Phase 7.3.5+ still owns any remaining unlink/ignore/rematch polish and Windows runtime harness per plan sequence.
- No production metadata provider settings or privacy/consent UI.

---

## Recommended next step — Phase 7.3.5

Continue **unlink / ignore / rematch flow polish** per the Phase 7.3 plan sequence, or proceed to **7.3.6 widget tests + Windows runtime harness** depending on plan priority review.
