# M7 Phase 7.2 — Books Provider Vertical Slice

**Status:** Complete — implementation scope closed (2026-07-30); Windows runtime deferred to Phase 7.8
**Prerequisite:** [Books metadata provider evaluation](../architecture/books-metadata-provider-evaluation.md) (Phase 7.2A complete)
**Branch:** `m7-development`
**Provider decision:** **Open Library — Selected**

→ [M7 plan](./m7-plan.md) · [Provider evaluation](../architecture/books-metadata-provider-evaluation.md) · [Phase 7.2B closure](./m7-phase-7.2b-closure-report.md) · [Phase 7.1 closure](./m7-phase-7.1-closure-report.md)

---

## Objective

Implement a **controlled books metadata vertical slice** using **Open Library** behind a provider-neutral abstraction, with fake HTTP tests in CI and **no credential persistence**.

Phase 7.2 is split:

| Sub-phase | Focus | Status |
|---|---|---|
| **7.2A** | Provider evaluation and selection | Complete (2026-07-30) |
| **7.2B** | Provider abstraction + Open Library adapter + refresh service + fake HTTP tests | Complete (2026-07-30) |

Explicit refresh wiring (`BookMetadataRefreshService`) was delivered in 7.2B; no separate 7.2C implementation phase.

---

## Provider selection summary

**Selected:** [Open Library](https://openlibrary.org/developers/api)

**Rejected primary:** Google Books (persistence/terms conflict), LoC JSON API (coverage), WorldCat (institutional)

**Future secondary:** ISBNdb (paid API key, explicit opt-in later)

---

## Implemented (Phase 7.2B)

- `BookMetadataProvider` abstraction (books only)
- Open Library adapter (Books API ISBN lookup; Search API for explicit queries)
- `MetadataHttpTransport` + `HttpMetadataHttpTransport` + `FakeMetadataHttpTransport`
- `NormalizedBookMetadata` → `MetadataEnrichmentRecord` mapper
- `BookMetadataRefreshService` (explicit ISBN refresh + search candidates)
- Fake provider and fixture-backed tests
- User-Agent identification (no secret)
- Rate-limit aware error categories

## Out of scope

- Cover download / Covers API (Phase 7.4)
- Automatic high-confidence matching (Phase 7.3)
- Match confirmation UI (Phase 7.3)
- Enriched detail presentation (Phase 7.5)
- Credential storage (Phase 7.7)
- Production UI wiring / `main.dart` provider registration (deferred)
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

- [x] Fake HTTP test suite passes (33 focused)
- [x] No live provider HTTP in default `flutter test`
- [x] No credentials in repo, prefs, or diagnostics
- [x] Enrichment records persist via Phase 7.1 repository
- [x] Ordinary catalogue load triggers zero provider calls
- [ ] Windows runtime harness with fake provider (deferred to Phase 7.8)
- [ ] ADR-028/029 remain Proposed unless governance accepts at milestone closure

---

## Dependencies

- Phase 7.1 enrichment repository complete
- Phase 7.2A provider evaluation complete
- Phase 7.3 matching (follows adapter)
