# M7 Phase 7.2 — Books Provider Vertical Slice

**Status:** Planned — provider selected (Open Library); implementation not started
**Prerequisite:** [Books metadata provider evaluation](../architecture/books-metadata-provider-evaluation.md) (Phase 7.2A complete)
**Branch:** `m7-development`
**Provider decision:** **Open Library — Selected**

→ [M7 plan](./m7-plan.md) · [Provider evaluation](../architecture/books-metadata-provider-evaluation.md) · [Phase 7.1 closure](./m7-phase-7.1-closure-report.md)

---

## Objective

Implement a **controlled books metadata vertical slice** using **Open Library** behind a provider-neutral abstraction, with fake HTTP tests in CI and **no credential persistence**.

Phase 7.2 is split:

| Sub-phase | Focus | Status |
|---|---|---|
| **7.2A** | Provider evaluation and selection | Complete (2026-07-30) |
| **7.2B** | Provider abstraction + Open Library adapter + fake HTTP tests | Planned |
| **7.2C** | Wire explicit refresh to enrichment repository (no auto-match UI) | Planned |

---

## Provider selection summary

**Selected:** [Open Library](https://openlibrary.org/developers/api)

**Rejected primary:** Google Books (persistence/terms conflict), LoC JSON API (coverage), WorldCat (institutional)

**Future secondary:** ISBNdb (paid API key, explicit opt-in later)

---

## In scope (Phase 7.2B–7.2C)

- `BookMetadataProvider` abstraction (books only)
- Open Library adapter (Books API ISBN lookup; Search API for explicit queries)
- Fake HTTP provider for unit/integration tests
- Map responses → `NormalizedBookMetadata` → `MetadataEnrichmentRecord` upsert
- User-Agent identification (no secret)
- Explicit user-initiated refresh entry point (minimal — settings/debug or dev hook acceptable before full UI)
- Rate-limit aware error categories

## Out of scope

- Cover download / Covers API (Phase 7.4)
- Automatic high-confidence matching (Phase 7.3)
- Match confirmation UI (Phase 7.3)
- Enriched detail presentation (Phase 7.5)
- Credential storage (Phase 7.7)
- ISBNdb or Google Books adapters
- Background refresh queue
- Live provider calls in default CI

---

## Controlled slice boundary

See [evaluation doc § Phase 7.2 controlled vertical slice](../architecture/books-metadata-provider-evaluation.md#phase-72-controlled-vertical-slice-proposed).

**Inputs:** ISBN-13/10, title, author, year (disambiguation)
**Outputs:** title, subtitle, authors, description, publisher, date/year, language, subjects, ISBNs, provider record ID, provenance, fetchedAt
**Deferred:** series, covers, ratings, raw JSON

---

## Validation gates (Phase 7.2 closure)

- Fake HTTP test suite passes
- No live provider HTTP in default `flutter test`
- No credentials in repo, prefs, or diagnostics
- Enrichment records persist via Phase 7.1 repository
- Ordinary catalogue load triggers zero provider calls
- ADR-028/029 remain Proposed unless governance accepts at phase closure

---

## Dependencies

- Phase 7.1 enrichment repository complete
- Phase 7.2A provider evaluation complete
- Phase 7.3 matching (follows adapter)
