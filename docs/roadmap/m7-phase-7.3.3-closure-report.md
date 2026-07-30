# M7 Phase 7.3.3 — Book Detail Metadata Enrichment Section

**Status:** Complete (2026-07-30)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.3.2 closure](./m7-phase-7.3.2-closure-report.md)

→ [M7 plan](./m7-plan.md) · [Phase 7.3 plan](./m7-phase-7.3-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Delivered

Development-gated book-only metadata enrichment UI under `client/ttsplayer/lib/features/metadata_enrichment/`:

| Component | Responsibility |
|---|---|
| `MetadataEnrichmentFeatureConfig` | Injected development gate (`metadataEnrichmentDevelopmentEnabled`, default off) |
| `MetadataMatchStatePresentation` | Bounded labels, explanations, icons, permitted actions for all seven match states + no record |
| `MetadataProviderPresentation` | User-facing provider attribution (`open_library`, `fake_books`, unknown fallback) |
| `MetadataEnrichmentUiMessages` | Coordinator result → bounded user-facing messages |
| `BookMetadataEnrichmentSection` | Stateful detail section: load record, explicit coordinator actions, transient search summary |
| `ItemDetailScreen` integration | Section placed after catalogue metadata panel, before play/open actions |

**Not delivered:** candidate selection dialog, warning-confirmation dialog, production Open Library activation, settings/privacy UI, background matching, Windows runtime harness, catalogue schema changes, dependency/version changes.

---

## Development gate

- `MetadataEnrichmentFeatureConfig.defaults` → `metadataEnrichmentDevelopmentEnabled: false`
- `MetadataEnrichmentFeatureConfig.developmentEnabled` → explicit test/harness preset
- Registered in `main.dart` via `Provider<MetadataEnrichmentFeatureConfig>.value` (defaults)
- `Provider<BookMetadataMatchingCoordinator?>.value(value: null)` — no production coordinator wiring
- Section hidden when gate off; non-book items never render the section
- Enabling the gate alone does **not** invoke providers

---

## Coordinator action boundary

All provider-touching operations go through injected `BookMetadataMatchingCoordinator`:

- `lookupByIsbn` — explicit ISBN dialog submit only
- `searchAndEvaluate` — explicit Search metadata / Change metadata taps only
- `unlink`, `ignore`, `resumeMatching`, `recordNoMatchOutcome` — explicit confirmed actions only

The section does **not** call `selectCandidate()`, `BookMetadataRefreshService` directly, Open Library, or HTTP transport.

---

## Display states

| Condition | Label | Actions (when coordinator present) |
|---|---|---|
| No record | Not linked | Look up by ISBN, Search metadata |
| Unmatched | No metadata match selected | Look up, Search, Ignore |
| Linked by ISBN | Linked by ISBN | Change metadata, Unlink |
| Linked high confidence | Automatically linked | Change metadata, Unlink |
| Linked manual | Manually linked | Change metadata, Unlink |
| Ambiguous | Metadata review required | Review candidates (placeholder), Look up, Search, Ignore |
| Ignored | Metadata suggestions ignored | Resume matching |
| Stale | Metadata link may be stale | Look up, Search, Unlink |

Provider attribution and fetched date shown for linked states when available.

---

## Transient candidate handling

Search results are **not persisted** in this phase. The section keeps a transient search summary in local state:

- Empty provider list → “No metadata candidates found.”
- Reviewable candidates → review placeholder button + deferred dialog
- Conflict review → “Metadata review is required.”
- No reviewable weak candidates → “Mark as no match” via explicit `recordNoMatchOutcome`
- Change metadata on linked item → existing link retained; search summary only

---

## Widget-test evidence

| File | Coverage |
|---|---|
| `test/book_metadata_enrichment_section_test.dart` | Gate, all match states, ISBN/search/unlink/ignore/resume flows, concurrency, narrow width |
| `test/item_detail_screen_test.dart` | Gate integration on `ItemDetailScreen` |
| `test/book_metadata_matching_isolation_test.dart` | Widget avoids Open Library/HTTP; gate defaults off; no `selectCandidate` in section source |

Fake provider / in-memory repository harness: `test/support/book_metadata_enrichment_section_test_support.dart`.

Focused widget tests: **41 passed** (2026-07-30).

Full `flutter test`: **1608 passed, 19 skipped** (baseline was 1565 before Phase 7.3.3 tests).

---

## ADR-029

Remains **Proposed** — governance review deferred.

---

## Known limitations

- Candidate review is a placeholder dialog only — Phase 7.3.4 owns selection and confirmation UI.
- Production coordinator and Open Library remain unwired in `main.dart`.
- Unlink/ignore/resume shipped in 7.3.3 UI; plan sequence 7.3.5 relink flows remain partially deferred to 7.3.4+.

---

## Recommended next step — Phase 7.3.4

Implement the **candidate selection and warning-confirmation dialog**: selectable search candidates from transient `BookCandidateSelectionContext`, critical-conflict override confirmation, `selectCandidate()` persistence to `linkedManual`, and replacement of the “Review candidates” placeholder.
