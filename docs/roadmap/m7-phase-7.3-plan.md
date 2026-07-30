# M7 Phase 7.3 — Metadata Matching and Manual Selection

**Status:** In progress — Phase 7.3.2 coordinator complete (2026-07-30); UI deferred
**Prerequisite:** [Phase 7.2B closure](./m7-phase-7.2b-closure-report.md) complete
**Branch:** `m7-development`
**Related ADRs:** [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) (Proposed), [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md) (Proposed)

→ [M7 plan](./m7-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md) · [Phase 7.2 plan](./m7-phase-7.2-plan.md)

---

## Objective

Introduce **deterministic book metadata matching**, **confidence bands**, **ambiguity handling**, and **manual candidate selection** — with explicit provider interaction only and conservative auto-apply policy.

Phase 7.3 connects Phase 7.2 provider candidates to Phase 7.1 enrichment persistence through a provider-neutral scoring layer and a limited book-detail UI.

**Production activation** of enrichment UI remains gated by Phase 7.7 privacy opt-in unless a development-only flag is used for harness validation.

---

## Scope

| Area | In scope |
|---|---|
| Deterministic candidate scoring service | Title, author, year, ISBN, publisher, language signals |
| Confidence bands and thresholds | Identifier, high, ambiguous, unmatched |
| Ambiguity detection | Top-two margin, conflicts, insufficient inputs |
| Match evaluation models | Provider-neutral, explainable, non-persistent by default |
| Manual link persistence | `linkedManual`, `matchMethod.manual` |
| Relink and unlink workflows | Preserve user overrides |
| Book detail metadata section | Status, refresh, change match, unlink |
| Candidate selection dialog/screen | Explicit user choice, confirmation |
| ISBN explicit refresh auto-link | Existing 7.2 path — unchanged policy |
| Fake-provider unit/widget tests | No live network in CI |
| Windows runtime harness scenarios | Fake provider only |

## Out of scope

| Area | Deferred to |
|---|---|
| Automatic silent apply of search/high-confidence candidates | **Not in M7** — confirmation required |
| Background or catalogue-load matching | Never |
| Cover artwork download | Phase 7.4 |
| Full enriched presentation merge service | Phase 7.5 |
| Search index enrichment terms | Phase 7.5 |
| Privacy opt-in settings UI | Phase 7.7 (UI may ship behind gate) |
| Credential storage | Phase 7.7 |
| Live Open Library in CI | Phase 7.8 optional |
| Music/video/comic matching | Future milestones |
| Multi-provider merge | Future |
| Raw evaluation persistence | Diagnostics aggregates only |

---

## Existing constraints (reviewed)

### Phase 7.1 persistence

- Record key: catalogue `item.id` (md5 of path)
- States: `unmatched`, `linkedByIdentifier`, `linkedHighConfidence`, `linkedManual`, `ambiguous`, `ignored`, `stale`
- `lockedFields` authoritative; per-field `locked` derived on normalize
- Collection fields stored as sorted JSON array strings (v1 compatibility)
- No raw provider JSON
- Catalogue replace prunes orphan records; no automatic id transfer

### Phase 7.2 provider layer

- `BookMetadataRefreshService.refreshByIsbn` — auto-persists on exact ISBN bibkey (`linkedByIdentifier`, confidence 1.0)
- `BookMetadataRefreshService.searchCandidates` — returns candidates; **does not persist**
- `ProviderBookCandidate` — separate from enrichment record; provider ordering not TTSPlayer confidence
- No production DI in `main.dart`; no UI hook
- User-Agent neutral (`TTSPlayer/0.8`) — live calls disabled until approved identity

### UI conventions

- `ItemDetailScreen` — catalogue metadata only (title, author, series, year, extension chips)
- Confirmation: `AlertDialog` pattern (`settings_screen`, `clear_listening_history_dialog`)
- No enrichment section on book detail today

### Local book metadata inputs (catalogue)

| Field | Source | Matching use |
|---|---|---|
| `title` | Catalogue / filename | Primary text signal |
| `author` | Scanner optional | Primary text signal |
| `year` | Catalogue optional | Supporting signal |
| `filePath` / stem | Filesystem | Weak filename fallback only — **never transmitted** |
| ISBN | Not in catalogue v4 today | User-entered or sidecar future; Phase 7.3 accepts explicit ISBN input on refresh |

**Gap:** Catalogue does not emit ISBN. Phase 7.3 refresh UI must accept optional ISBN from user input or future sidecar; scoring uses ISBN only when locally supplied for comparison.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Book detail UI (Phase 7.3)                                       │
│  Refresh → review candidates → confirm → manual link / unlink    │
└────────────────────────────┬────────────────────────────────────┘
                             │ explicit only
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ BookMetadataMatchingCoordinator (new)                            │
│  compose local inputs → search/ISBN → score → decide → persist   │
└──────┬──────────────────────────────┬───────────────────────────┘
       │                              │
       ▼                              ▼
┌──────────────────┐        ┌────────────────────────────────────┐
│ BookMetadata      │        │ BookMetadataMatchEvaluator (new)    │
│ RefreshService    │        │ normalize → score → rank → decide   │
│ (7.2)             │        └────────────────────────────────────┘
└──────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ MetadataEnrichmentRepository (7.1)                               │
└─────────────────────────────────────────────────────────────────┘
```

**New components (implementation):**

| Component | Responsibility |
|---|---|
| `BookMetadataComparisonNormalizer` | Unicode, case, punctuation, articles — comparison only |
| `BookMetadataMatchEvaluator` | Signal scores, penalties, total, band, ambiguity |
| `BookMetadataMatchingCoordinator` | Orchestrates refresh + evaluate + persist transitions |
| `BookMetadataMatchPresentation` | Human-readable explanation strings (not raw scores) |

Evaluations are **transient** (in-memory for UI session). Only enrichment record + optional diagnostics counters persist.

---

## Scoring model

### Principles

- **Deterministic** — same inputs → same scores and ordering
- **Explainable** — each signal named and bounded
- **Conservative** — penalties for edition/volume/author conflicts
- **Provider-independent** — operates on `ProviderBookCandidate` + local inputs
- **No ML** — fixed weights and tiers

### Signal weights (additive, cap 1.0 before penalties)

| Signal | Weight | Condition |
|---|---:|---|
| `isbn13Exact` | 1.0 (identifier path) | Normalized ISBN-13 equal — **bypasses score bands; uses ISBN refresh path** |
| `isbn10Exact` | 1.0 (identifier path) | Normalized ISBN-10 equal |
| `isbnEquivalent` | 1.0 (identifier path) | Deterministic 978 ISBN-10 ↔ ISBN-13 conversion match |
| `titleExact` | 0.35 | Normalized full title equal |
| `titleMainExact` | 0.28 | Main title equal, subtitle differs |
| `titleStrong` | 0.22 | Token-set ratio ≥ 0.85 |
| `titlePartial` | 0.12 | Token-set ratio ≥ 0.60 |
| `titleFilename` | 0.06 | Stem similarity only — requires author ≥ partial |
| `subtitleAgree` | 0.05 | Bonus if subtitles match when main title matches |
| `authorPrimaryExact` | 0.30 | First author exact normalized match |
| `authorAnyExact` | 0.20 | Any author exact match |
| `authorSurname` | 0.12 | Surname match, given name initial-compatible |
| `yearExact` | 0.10 | Publication year equal |
| `yearClose` | 0.07 | ±1 year |
| `yearApprox` | 0.04 | ±3 years |
| `publisherMatch` | 0.05 | Any publisher token overlap |
| `languageMatch` | 0.03 | Language code equal |
| `providerHint` | 0.00 | **Not added to score** — tie-break ordering only |

**Title tier exclusivity:** Use highest matching title tier only (not cumulative).

**Author tier exclusivity:** Use highest matching author tier only.

**Year tier exclusivity:** Use highest matching year tier only.

**Filename fallback rule:** `titleFilename` applies only when no stronger title tier matched; it never stacks with `titleExact`, `titleMainExact`, `titleStrong`, or `titlePartial`.

### Score computation pipeline

Evaluation is deterministic and proceeds in fixed stages:

1. **Raw weighted total** — sum of the single winning title tier, single winning author tier, single winning year tier, optional `subtitleAgree` bonus, and publisher/language matches (if any).
2. **Penalties** — subtract fixed penalty values (ISBN conflict does not change ordering math; it sets `disqualifiedForAutoLink`).
3. **Penalized score** — `rawTotal − penaltySum`, floored at `0.0`.
4. **Final clamped score** — `min(1.0, max(0.0, penalizedScore))` — always in **`0.0–1.0`**.
5. **Confidence band** — derived from final score and identifier flags (transient recommendation only for search).
6. **Ambiguity decision** — separate rule on ranked final scores (top-two margin).

Provider hint affects **tie-break ordering only** and is never added to the score.

### Penalties (subtracted after raw total, before clamp)

| Penalty | Value | Condition |
|---|---:|---|
| `isbnConflict` | disqualify auto | Local trusted ISBN present and candidate ISBN differs — cannot auto-link |
| `authorConflict` | −0.25 | Local author present; candidate primary author clearly different |
| `volumeMismatch` | −0.15 | Volume number in title differs |
| `editionMismatch` | −0.10 | Edition markers differ (e.g. "2nd edition") |
| `omnibusMismatch` | −0.20 | Omnibus/complete works vs single volume |
| `abridgedMismatch` | −0.15 | Abridged/unabridged conflict |
| `studyGuideMismatch` | −0.20 | Study guide/workbook vs primary work |
| `yearLargeGap` | −0.15 | >10 years apart without ISBN agreement |
| `languageMismatch` | −0.10 | Both languages known and differ |

### Ranking

1. Descending total score (after penalties, excluding disqualified auto-link)
2. Identifier match flag (exact ISBN beats non-ISBN at equal score)
3. Provider hint score (weak)
4. Lexicographic `providerRecordId`

Provider API result order is **ignored**.

---

## ISBN equivalence and conflict policy

### Normalization (reuse 7.2)

- Strip spaces/hyphens; uppercase `X`; checksum validated on user input
- Invalid ISBN → local rejection before provider call

### Equivalence

- **ISBN-13 ↔ ISBN-10:** For ISBN-13 starting with `978`, convert to ISBN-10 by dropping prefix and recalculating check digit; reverse conversion adds `978` prefix
- **979 prefix:** No ISBN-10 equivalent — ISBN-13 only
- Multiple ISBNs on provider record: match if **any** equals local normalized value

### Exact identity

- Triggers `linkedByIdentifier`, `matchMethod.identifier`, confidence `1.0`
- Only on **explicit ISBN refresh** (Books API bibkey) or evaluator identifier path with local trusted ISBN

### Conflicts

- Local trusted ISBN + candidate ISBN both present and none equivalent → `isbnConflict`
- Auto-link **forbidden**; candidate may appear in manual list with warning
- Title similarity cannot override ISBN conflict

---

## Text normalization rules

Applied to **comparison copies** only; display values unchanged.

| Rule | Behaviour |
|---|---|
| Unicode | NFC normalization |
| Case | Lowercase for Latin scripts |
| Whitespace | Collapse runs; trim |
| Punctuation | Remove except apostrophe in names |
| Apostrophe | Normalize `'` `'` `` ` `` → `'` |
| Ampersand | `&` → `and` |
| Leading articles | Strip `the`, `a`, `an` (English) for title comparison |
| Subtitle separators | Split on `:`, ` - `, ` — `, ` / ` |
| Edition phrases | Detect `2nd ed`, `second edition`, `revised` — compare separately |
| Bracketed text | Strip `(…)`, `[…]` for title tier; retain for penalty detection |
| Author initials | `J. K.` ↔ `JK` ↔ `J K` compatible |
| Surname order | `Last, First` → `First Last` for comparison |
| Diacritics | Fold to ASCII where unambiguous (e.g. `é` → `e`) |
| Roman numerals | Normalize `II` ↔ `2` in volume context |
| Volume indicators | Extract `Vol. 3`, `#3`, `Book 3` for penalty check |

---

## Confidence bands and thresholds

| Band | Threshold | Persisted `EnrichmentMatchState` (Phase 7.3) | Auto-persist |
|---|---|---|---|
| **Identifier confirmed** | ISBN equivalent match | `linkedByIdentifier` | Yes — **explicit ISBN refresh only** |
| **High confidence** | Final score ≥ **0.85** and no disqualifying conflict | *(none — transient evaluation band)* | **No** |
| **Acceptable candidate** | Final score ≥ **0.60** | *(none — candidate list)* | No |
| **Below minimum** | Final score < **0.60** | Hidden from default list (diagnostics only) | No |
| **Ambiguous set** | Top two ≥ 0.60 and margin < **0.08** | `ambiguous` (search outcome only; no provider fields) | No |
| **Unmatched** | No candidate ≥ 0.60 | `unmatched` | No |
| **Ignored** | User explicit | `ignored` | No |
| **Stale** | Path/id change policy (7.1) | `stale` | No |

`linkedHighConfidence` is **reserved for a future approved automatic-match workflow** and is **not written** by Phase 7.3 persistence code. Transient models may still return `BookCandidateMatchDecision.highConfidenceCandidate` as a UI/diagnostics recommendation.

### Ambiguity margin

When the two highest scores are both ≥ 0.60 and `(score1 - score2) < 0.08`, the set is **ambiguous** — present both (and others ≥ 0.60) for manual selection; do not pre-select.

### Persistence policy (Phase 7.3)

| Path | Persisted state | Method | Confidence |
|---|---|---|---|
| Explicit ISBN lookup success | `linkedByIdentifier` | `identifier` | `1.0` |
| User selects/confirms any search candidate (including high-band) | `linkedManual` | `manual` | evaluator final score |
| Search with ambiguous set, no selection yet | `ambiguous` | — | — |
| No acceptable candidates | `unmatched` | — | — |

Search-derived candidates are **never silently persisted**, even when classified transiently as high confidence.

Expected search flow:

```text
no record
→ transient high-confidence or ambiguous evaluation
→ user confirms/selects
→ linkedManual
```

There is **no** Phase 7.3 transition `no record → linkedHighConfidence`.

---

## Worked examples

Scores use weights/penalties above. "Persist" = enrichment record written.

### 1. Exact ISBN match

| | |
|---|---|
| **Inputs** | Local ISBN `9780140449136`; explicit ISBN refresh |
| **Signals** | ISBN bibkey hit |
| **Score** | Identifier path (not banded) |
| **Band** | Identifier confirmed |
| **State** | `linkedByIdentifier` |
| **Persist** | Yes — automatic on refresh |

### 2. Exact title and author, matching year

| | |
|---|---|
| **Inputs** | Title "The Republic", author "Plato", year 2007; candidate matches |
| **Signals** | titleExact 0.35 + authorPrimaryExact 0.30 + yearExact 0.10 = **0.75** |
| **Band** | Acceptable (below 0.85) |
| **State** | Candidate list → user confirm → `linkedManual` |
| **Persist** | After confirmation only |

### 3. Exact title and author, different edition year

| | |
|---|---|
| **Inputs** | Local year 2007; candidate year 1998; no ISBN |
| **Signals** | 0.35 + 0.30 + yearApprox 0.04 = **0.69** |
| **Band** | Acceptable |
| **State** | Manual selection recommended |
| **Persist** | After confirmation |

### 4. Similar title, different author

| | |
|---|---|
| **Inputs** | Title strong match; local "Plato", candidate "Aristotle" |
| **Signals** | 0.22 + authorConflict −0.25 = **0.00** (floor) |
| **Band** | Below minimum |
| **State** | Not shown / unmatched |
| **Persist** | No |

### 5. Same series, different volume

| | |
|---|---|
| **Inputs** | "Harry Potter and the Chamber of Secrets" vs "…Philosopher's Stone" |
| **Signals** | titlePartial 0.12 + authorAny 0.20 − volumeMismatch 0.15 = **0.17** |
| **Band** | Below minimum |
| **State** | Unmatched |
| **Persist** | No |

### 6. Top two editions nearly identical scores

| | |
|---|---|
| **Inputs** | Two candidates 0.78 and 0.76 |
| **Margin** | 0.02 < 0.08 |
| **Band** | Ambiguous |
| **State** | `ambiguous` after search (no auto pick) |
| **Persist** | No until manual choice |

### 7. Missing local author and ISBN

| | |
|---|---|
| **Inputs** | Title only "Republic"; candidate titleExact, author "Plato" |
| **Signals** | 0.35 only = **0.35** |
| **Band** | Below minimum |
| **State** | Unmatched or prompt user to refine search |
| **Persist** | No |

### 8. Conflicting ISBN, similar title

| | |
|---|---|
| **Inputs** | Local ISBN A; candidate ISBN B; titleExact |
| **Signals** | isbnConflict — auto disqualified |
| **Band** | Acceptable if score ≥ 0.60 for display with **warning** |
| **State** | Manual only with conflict badge |
| **Persist** | Manual confirm allowed; never auto |

### 9. Manual selection of lower-scored candidate

| | |
|---|---|
| **Inputs** | User picks rank #3 (0.65) over rank #1 (0.78) |
| **State** | `linkedManual`, confidence = evaluated score of chosen candidate (0.65) |
| **Persist** | Yes — user authoritative |

### 10. User chooses "None of these"

| | |
|---|---|
| **Inputs** | Candidates shown; user declines |
| **State** | `unmatched` (or `ignored` if "Don't suggest again") |
| **Persist** | Update match state only; no provider fields applied |

---

## Match evaluation models (proposed)

```dart
// Illustrative — Phase 7.3 implementation
class BookCandidateMatchSignal {
  final String id;           // e.g. 'titleExact'
  final double contribution; // weighted contribution
  final String? detail;      // optional explain fragment
}

class BookCandidateMatchEvaluation {
  final ProviderBookCandidate candidate;
  final double totalScore;
  final List<BookCandidateMatchSignal> signals;
  final List<String> warnings;       // e.g. 'isbnConflict'
  final bool identifierMatch;
  final bool disqualifiedForAutoLink;
  final int rank;
  final double deltaFromTop;
  final EnrichmentMatchState recommendedState;
  final String summaryExplanation;   // UI string
}

class BookCandidateMatchSet {
  final List<BookCandidateMatchEvaluation> ranked;
  final bool isAmbiguous;
  final String? ambiguityReason;
  final BookCandidateMatchDecision decision;
}

enum BookCandidateMatchDecision {
  identifierLinked,
  highConfidenceCandidate,
  ambiguous,
  unmatched,
}
```

**Not persisted:** full `BookCandidateMatchSet`. Optional: store last `confidence` and `matchState` on record only.

---

## State transition matrix

| From | Event | To | Notes |
|---|---|---|---|
| *(none)* | ISBN refresh success | `linkedByIdentifier` | Auto; method `identifier`; confidence `1.0` |
| *(none)* | Search → ambiguous | `ambiguous` | Transient; no provider fields applied |
| *(none)* | Search → high-confidence evaluation | *(no record)* or `ambiguous` | **No auto-persist**; show candidates |
| *(none)* | Search → no candidates | `unmatched` | No record or unmatched record |
| `unmatched` / `ambiguous` | User selects candidate | `linkedManual` | Always manual method in 7.3 |
| `linkedByIdentifier` | User relink | `linkedManual` | Overrides identifier link |
| `linkedManual` | User relink | `linkedManual` | Update provider ids |
| any linked | Unlink | `unmatched` | Clear provider ids; **keep** user override fields |
| any | Ignore | `ignored` | No auto suggestions until cleared |
| `ignored` | User clears ignore | `unmatched` | Settings/detail action |
| linked | Path/id orphan | `stale` | Future detection — prompt rematch |
| linked | Refresh empty | `unmatched` | Clear linkage (7.2 policy) |
| linked | Refresh success | same state | Update unlocked provider fields |
| linked | Refresh failure | same state | Set `lastErrorCategory` only |

**Not used in Phase 7.3:** persisting `linkedHighConfidence` (reserved for future auto-match workflow).

**Unlink vs ignore:**

- **Unlink** → `unmatched`; removes provider linkage; preserves locked/user fields
- **Ignore** → `ignored`; suppresses future automatic suggestions (not implemented until opt-in exists)

---

## Manual-link persistence

On user confirmation:

| Field | Value |
|---|---|
| `matchState` | **`linkedManual` always** for user-selected search candidates (including high-band scores) |
| `matchMethod` | `manual` |
| `providerId` | From candidate |
| `providerRecordId` | From candidate |
| `confidence` | Evaluator total score of **chosen** candidate (not user certainty) |
| `fetchedAt` | UTC now |
| `fields` | Mapped provider fields; skip `lockedFields` |
| `lastErrorCategory` | Cleared on success |

**Not adding:** `linkedAt`, `linkedByUser` — `fetchedAt` + `matchMethod.manual` sufficient for v1.

---

## User override rules

| Action | Locked fields | User overrides | Provider fields |
|---|---|---|---|
| Select candidate | Preserved | Preserved | Update unlocked |
| Edit field | Becomes locked (optional UX) | Updated | — |
| Lock field | Added to `lockedFields` | — | Refresh skips |
| Unlink | Preserved | Preserved | Provider linkage cleared |
| Clear override | Removes lock | Reverts to merge precedence | — |

---

## Manual selection workflow

```
Book detail → "Refresh metadata"
  → [optional ISBN entry]
  → Loading
  → Branch:
      A) ISBN path → exact hit → confirm apply → linkedByIdentifier
      B) ISBN path → empty → offer title/author search
      C) Search path → evaluate candidates
          → 0 candidates → empty state
          → 1+ candidates → selection UI (ambiguous badge if margin fail)
          → User picks → confirmation (if replacing existing link)
          → Persist linkedManual
          → Detail refresh
  → Failure → bounded error + retry
  → Cancel → no persistence
  → "None of these" → unmatched / ignored
```

**Rematch:** Same flow from "Change match" on linked items.

**Unlink:** Confirmation dialog → `unmatched` + clear provider ids.

---

## UI scope

### Book detail — metadata enrichment section (books only)

- Match state badge (Unlinked / Linked / Ambiguous / Ignored)
- Provider attribution link (Open Library courtesy)
- Actions: Refresh metadata, Change match, Unlink, Ignore suggestions (optional)
- No provider call on screen open

### Candidate selection (dialog or full-screen on TV)

- List: title, subtitle, authors, publisher, year, ISBN, language
- Explanation chip: "ISBN exact", "Title and author match", "Publication year differs"
- Conflict warning banner for ISBN conflict
- Actions: Select, Cancel, None of these, Refine search

### Confirmation dialog (replace existing link)

- Current vs new candidate summary
- Locked fields listed as "Will not change"
- Confirm / Cancel

Numeric scores: diagnostics/dev mode only.

---

## Privacy and production activation

| Rule | Policy |
|---|---|
| Explicit action only | Every provider call user-initiated |
| Transmitted | Normalized **ISBN**, **title**, **author**, optional **year** only |
| **Not transmitted** | Full paths, filenames, file stems, catalogue tree |
| Local-only comparison | Filename stem may be used **locally** as a weak title fallback signal; derived text is never sent to the provider |
| Credentials | None (Phase 7.7+) |
| Live User-Agent | Disabled until approved identity |
| First-use disclosure | **Phase 7.7** — 7.3 UI behind `kDebugMode` or feature flag until opt-in exists |

---

## Diagnostics (bounded)

**May record (counts/enum):**

- Provider id, lookup type (isbn/search), candidate count, match state, score band, ambiguity reason category, identifier conflict flag, error category, manual selection event, unlink, ignore

**Must not record:**

- Title, author, ISBN, search terms, paths, filenames, response bodies

Session-level aggregates sufficient; no per-item hashed identity required in Phase 7.3.

---

## Test strategy

### Unit — normalization

Punctuation, whitespace, Unicode, apostrophes, subtitles, initials, multi-author, diacritics, volume markers

### Unit — scoring

Each signal independently; penalties; ISBN conflict; missing fields; deterministic output

### Unit — ranking

Stable sort; tie-breaks; provider order independence; ambiguity margin

### Unit — decisions

Band assignment; identifier bypass; ambiguous set detection

### Unit — persistence

Manual link; relink; unlink; locked preservation; merge policy for missing provider fields

### Widget

Book detail section states; candidate dialog; confirmation; cancel; none-of-these; no auto-call on open

### Isolation

No provider on: init, catalogue load, rescan, detail open, repository init

### Windows runtime (Phase 7.3 harness)

Fake provider scenarios: refresh, ambiguous list, select, persist, restart, locked field, unlink, error — **no live network**

---

## Windows runtime validation

Extend M6/M7 harness with fake `BookMetadataProvider`:

1. Open book detail — zero provider calls
2. Tap refresh — fake candidates returned
3. Select candidate — record persisted
4. Relaunch — record loaded
5. Locked field survives refresh
6. Unlink clears linkage
7. Provider error surfaces retry

Mandatory gate for Phase 7.3 closure; live Open Library optional in 7.8.

---

## Definition of done

- [ ] `BookMetadataMatchEvaluator` with full unit coverage
- [ ] `BookMetadataMatchingCoordinator` wired to refresh service + repository
- [ ] Manual link / unlink / rematch persistence
- [ ] Book detail enrichment section (behind privacy gate or debug flag)
- [ ] Candidate selection + confirmation UI
- [ ] No provider calls except explicit user action
- [ ] Fake-provider widget/runtime tests pass
- [ ] Full `flutter test` green
- [ ] Documentation closure report
- [ ] ADR-029 remains Proposed until governance review

---

## Implementation sequence (recommended)

| Step | Deliverable | Status |
|---|---|---|
| 7.3.1 | Normalizer + evaluator + unit tests (no UI) | Complete (2026-07-30) |
| 7.3.2 | Matching coordinator + persistence transitions + tests | Complete (2026-07-30) |
| 7.3.3 | Book detail metadata section (debug gate) | Planned |
| 7.3.4 | Candidate selection + confirmation dialogs | Planned |
| 7.3.5 | Unlink / ignore / rematch flows | Planned |
| 7.3.6 | Widget tests + Windows runtime harness | Planned |
| 7.3.7 | Closure documentation | Planned |

---

## Commit strategy

Split implementation commits by sub-phase; documentation commit at closure.

Planning commit (this document):

```powershell
git commit `
  -m "docs(m7.3): plan metadata matching and manual selection" `
  -m "Define deterministic book candidate scoring, confidence bands, ambiguity handling, match-state transitions, manual linking, privacy boundaries, UI scope, and validation strategy."
```

---

## Related documents

- [Phase 7.2B closure](./m7-phase-7.2b-closure-report.md)
- [Books provider evaluation](../architecture/books-metadata-provider-evaluation.md)
- [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md)
