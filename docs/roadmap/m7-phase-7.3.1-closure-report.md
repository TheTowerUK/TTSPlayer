# M7 Phase 7.3.1 — Book Metadata Normalizer and Candidate Evaluator

**Status:** Complete (2026-07-30, uncommitted for review)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3 plan](./m7-phase-7.3-plan.md)

→ [M7 plan](./m7-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Delivered

Provider-neutral deterministic matching foundation under `client/ttsplayer/lib/features/metadata_enrichment/matching/`:

| Component | Responsibility |
|---|---|
| `LocalBookMatchInput` | Bounded local comparison inputs (no paths/provider state) |
| `BookMatchNormalizer` | Comparison-only title/author/publisher/language normalization |
| `IsbnEquivalence` | ISBN validation, conversion, equivalence, conflict detection |
| `BookCandidateMatchSignal` / `BookCandidateMatchWarning` | Explainable transient signal and warning identifiers |
| `BookCandidateMatchEvaluation` / `BookCandidateMatchSet` | Transient evaluation models |
| `BookCandidateMatchDecision` / `BookCandidateMatchBand` | Set-level recommendation and per-candidate bands |
| `BookCandidateEvaluator` | Weighted scoring, penalties, clamping, ambiguity decisions |
| `BookCandidateRanker` | Stable ranking independent of provider API order |

---

## Normalization

- Lowercase, trim, whitespace collapse, punctuation normalization
- Ampersand → `and`; typographic apostrophes → straight; apostrophes removed in comparable token form (`Author's` ≡ `Authors`)
- Leading articles retained in full form; additional article-stripped comparison form derived
- Subtitle split on `:`, spaced `—`, `–`, `-`; **full** comparison title includes main + subtitle
- Bounded format-marker stripping (Paperback, Kindle Edition, etc.)
- Edition and contextual volume markers (including Roman numerals in volume context)
- Author initials, surname-first reordering, duplicate removal; **primary author = first display-order author**
- Deterministic Latin diacritic folding (not full Unicode NFC — no additional dependency)

---

## Scoring policy (matches Phase 7.3 plan)

### Weights

| Signal | Weight |
|---|---:|
| Title exact (full) | 0.35 |
| Title main exact | 0.28 |
| Title strong (Jaccard ≥ 0.85) | 0.22 |
| Title partial (Jaccard ≥ 0.60) | 0.12 |
| Filename stem fallback | 0.06 |
| Subtitle agreement bonus | 0.05 |
| Author primary exact | 0.30 |
| Author any exact | 0.20 |
| Author surname | 0.12 |
| Year exact | 0.10 |
| Year ±1 | 0.07 |
| Year ±3 | 0.04 |
| Publisher agreement | 0.05 |
| Language agreement | 0.03 |

One winning tier each for title, author, and year. Provider hint is tie-break only.

### Penalties

| Penalty | Value |
|---|---:|
| Author conflict | −0.25 |
| Volume mismatch | −0.15 |
| Edition mismatch | −0.10 |
| Omnibus / study guide mismatch | −0.20 |
| Abridged mismatch | −0.15 |
| Large year gap (>10, no ISBN agreement) | −0.15 |
| Language mismatch | −0.10 |

ISBN conflict sets `disqualifiedForAutoLink` without adding a score penalty.

### Pipeline

`rawTotal → penalties → floor at 0.0 → clamp to 0.0–1.0 → band → ambiguity`

### Bands

- Identifier confirmed (ISBN equivalence)
- High confidence ≥ 0.85
- Acceptable ≥ 0.60
- Below minimum < 0.60

### Ambiguity

- Top two ≥ 0.60 and margin **< 0.08** → `multiple_close_matches`
- Single-candidate **ISBN conflict** with partial-or-better title agreement → `identifier_conflict` (manual review required; not described as multiple close matches)
- Single-candidate **author conflict** with partial-or-better title agreement → `contradictory_author` (manual review required)

### Transient decision semantics

`BookCandidateMatchDecision.unmatched` means **no identifier-linked, high-confidence, or ambiguous recommendation** — it does **not** mean there are no candidates suitable for manual review.

| Condition | `acceptableEvaluations` | `decision` |
|---|---|---|
| No candidate ≥ 0.60 | empty | `unmatched` |
| One or more acceptable candidates, score < 0.85, no ambiguity | non-empty | `unmatched` (manual review via list) |
| Top ≥ 0.85, not ambiguous | non-empty | `highConfidenceCandidate` |
| Ambiguous set or conflict-driven manual review | non-empty | `ambiguous` |
| ISBN equivalence | non-empty | `identifierLinked` |

Phase 7.3.2 must **not** persist `EnrichmentMatchState.unmatched` solely because the transient decision is `unmatched`. Persistent unmatched requires an explicit action (empty search, failed ISBN lookup, user “None of these”, or approved unlink transition).

### ISBN trust boundary

`IsbnComparisonResult.conflict` occurs only when **both** sides retain at least one valid identifier after checksum validation and **no** equivalent pair exists. Missing or invalid identifiers yield `insufficient`, never `conflict`.

The matching engine accepts ISBN collections as comparison inputs but does **not** decide trust. `LocalBookMatchInput.isbn10Values` / `isbn13Values` must be populated by the Phase 7.3.2 caller with trusted identifiers only.

### Filename fallback safeguards

- Filename stem contributes only when no stronger title tier matched
- Requires author tier ≥ surname (0.12)
- Filename/path values never appear in signals, warnings, or explanation identifiers (`filename_fallback` id only)
- Local input is never logged or persisted by the matching engine

### Normalization collision safeguards

- Article-stripped forms are alternates; full normalized title is retained (`The A` ≠ `A`)
- Roman numerals convert only with volume context (`Volume I` → 1; standalone `I` does not)
- Weak surnames filtered deterministically (length < 3 or bounded stop list)
- Bounded Latin diacritic folding only — display values unchanged; not full Unicode NFC

`linkedHighConfidence` is **not written** — reserved for future auto-match workflow.

---

## Test evidence

Focused tests (2026-07-30):

```text
test/book_match_normalizer_test.dart
test/isbn_equivalence_test.dart
test/book_candidate_evaluator_test.dart
test/book_candidate_ranker_test.dart
test/book_candidate_matching_isolation_test.dart
```

50+ tests in focused matching suite (see validation run).

---

## Explicitly not delivered

- Persistence / repository transitions
- Manual linking coordinator
- Provider networking / HTTP changes
- Production UI / DI / feature flags
- Diagnostics integration
- Windows runtime harness
- Production activation
- Background matching
- Catalogue schema changes
- Dependency or version changes

---

## Remaining Phase 7.3 work

| Step | Scope |
|---|---|
| **7.3.2** | Matching coordinator + persistence transitions + tests |
| 7.3.3 | Book detail metadata section |
| 7.3.4 | Candidate selection + confirmation UI |
| 7.3.5 | Unlink / ignore / rematch flows |
| 7.3.6 | Widget tests + Windows runtime harness |
| 7.3.7 | Phase 7.3 closure documentation |

ADR-029 remains **Proposed**.
