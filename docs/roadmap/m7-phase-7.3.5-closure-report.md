# M7 Phase 7.3.5 — Unlink, Ignore and Rematch Flow Polish

**Status:** Complete (2026-08-03)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3.4 closure](./m7-phase-7.3.4-closure-report.md)

→ [M7 plan](./m7-plan.md) · [Phase 7.3 plan](./m7-phase-7.3-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| Phase 7.3.4 commits | Present (`bd552f3` implementation, `8b85446` documentation) |
| Working tree before 7.3.5 | Clean after 7.3.4 commits |
| Divergence vs `origin/m6-development` | `0 15` (after 7.3.4 commits) |
| Unrelated changes | None |

---

## Existing logic reused

- `BookMetadataMatchingCoordinator.unlink()`, `ignore()`, `resumeMatching()`, `searchAndEvaluate()`, `relinkCandidate()`
- `BookMetadataMatchTransition.applyUnlink()` — clears provider linkage; retains user overrides and locked fields
- `MetadataMatchStatePresentation` — action gating per match state
- `BookMetadataCandidateDialogSession` — item-scoped candidate review from Phase 7.3.4
- Phase 7.3.3/7.3.4 enrichment section, confirmation, and fake-provider test harness

No new coordinator transitions or repository schema changes.

---

## Files changed

**Modified**

- `lib/features/metadata_enrichment/presentation/metadata_enrichment_ui_messages.dart`
- `lib/features/metadata_enrichment/widgets/book_metadata_enrichment_section.dart`
- `test/support/book_metadata_enrichment_section_test_support.dart`
- `test/book_metadata_enrichment_section_test.dart`

**New**

- `test/book_metadata_lifecycle_polish_test.dart`

**Documentation**

- `docs/roadmap/m7-phase-7.3.5-closure-report.md` (this file)
- `docs/roadmap/m7-phase-7.3-plan.md`
- `docs/architecture/metadata-enrichment.md`
- `docs/release/v0.8.0-dev.md`

---

## Final state/action matrix

| State | Primary actions |
|---|---|
| No record | Look up by ISBN, Search metadata |
| Unmatched | Look up by ISBN, Search metadata, Ignore metadata matching |
| Linked (ISBN / manual / high confidence) | Find different metadata, Remove metadata link |
| Ambiguous | Search, Look up by ISBN, Ignore metadata matching |
| Ignored | Resume metadata matching |
| Stale | Look up by ISBN, Search metadata, Remove metadata link |

Action visibility remains driven by `MetadataMatchStatePresentation.permits()`.

---

## Unlink flow

- **Remove metadata link** with explicit confirmation (`Remove link`).
- Copy explains local file unchanged, user overrides/locks kept, provider-linked unlocked values may be unavailable.
- One coordinator `unlink()` write; bounded success: **Metadata link removed.**
- Clears transient search and dismisses active candidate dialog on success.
- Repository failure retains linked state; retry does not invoke provider search.

---

## Ignore flow

- **Ignore metadata matching** with confirmation (`Ignore matching`).
- One coordinator `ignore()` write; success: **Metadata matching ignored for this book.**
- Clears transient search/candidate state; suppresses search via presentation model.
- Cancel makes no persistence change.

---

## Resume flow

- **Resume metadata matching** without confirmation (restores searchable state).
- One coordinator `resumeMatching()` write; success: **Metadata matching resumed.**
- Does not invoke provider automatically.
- Clears stale transient state on success.

---

## Rematch flow

- **Find different metadata** (renamed from Change metadata) starts transient search only.
- Existing link retained until successful `relinkCandidate()` after candidate confirmation.
- Search/candidate cancellation retains link; search failure shows bounded provider message.
- New search dismisses any open candidate-review session.

---

## Same-record rematch

Unchanged from Phase 7.3.4: successful no-op with **This metadata is already linked.**

---

## Override and lock preservation

Verified via unlink success test: user override title retained; coordinator transition policy unchanged.

---

## Provider-field cleanup

Unlink uses existing `applyUnlink()` — provider linkage cleared; provider-owned unlocked fields removed; user/locked fields retained.

---

## Failure and retry behaviour

Repository failures map to **Metadata could not be saved.** Prior persisted state retained. No automatic provider re-search on transition retry.

---

## Item-change and disposal protection

Unified `_lifecycleGeneration` guards unlink, ignore, resume, search, ISBN lookup, and candidate review. Item change or dispose calls `_invalidateLifecycle()` — dismisses named candidate-dialog route via captured `NavigatorState`, clears transient state, ignores delayed results from prior item.

---

## Duplicate-submit handling

Existing `_pending` guard disables actions during in-flight operations. Counting coordinator tests prove single unlink/ignore/resume writes.

---

## Test evidence

| Suite | Result |
|---|---|
| `test/book_metadata_lifecycle_polish_test.dart` | 18 passed |
| Candidate + enrichment section tests | Pass (regression) |
| Coordinator/transition/evaluator/isolation | Pass (regression) |
| Full `flutter test` | **1654 passed, 19 skipped, 0 failed** |

Invocation counters used for unlink, ignore, resume; provider search counts verified for rematch cancel and ignore flows.

---

## ADR-029

Remains **Proposed**.

---

## Known limitations

- Production Open Library and coordinator wiring in `main.dart` unchanged.
- Windows runtime harness deferred to Phase 7.3.6.
- No settings/privacy UI, automatic matching, or artwork.

---

## Scope exclusions confirmed

No production provider activation, credentials UI, privacy UI, automatic/background matching, artwork, backend/HTTP changes, dependencies, catalogue schema changes, version bump, commit, or push.

---

## Recommended commit split

1. `feat(m7.3): polish metadata unlink ignore and rematch flows`
2. `docs(m7.3): document lifecycle workflow polish`

---

## Recommended next task

**Phase 7.3.6 — Widget tests + Windows runtime harness** per the Phase 7.3 plan sequence.
