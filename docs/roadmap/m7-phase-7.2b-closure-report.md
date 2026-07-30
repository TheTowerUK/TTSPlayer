# M7 Phase 7.2B — Open Library Adapter Foundation Closure Report

**Date:** 2026-07-30
**Branch:** `m7-development`
**Status:** Phase 7.2B Complete — Phase 7.2 In Progress

→ [Phase 7.2 plan](./m7-phase-7.2-plan.md) · [Provider evaluation](../architecture/books-metadata-provider-evaluation.md) · [M7 plan](./m7-plan.md)

---

## Summary

Phase 7.2B implements the provider-neutral books metadata contract, injectable HTTP transport, Open Library ISBN and search adapters, normalized results, bounded error mapping, enrichment record conversion, and an explicit refresh application service — all with deterministic fake HTTP tests and **no live provider calls in CI**.

Production UI and `main.dart` wiring are intentionally unchanged. Enrichment is reachable only through `BookMetadataRefreshService` invoked explicitly by future phases or tests.

---

## Implemented contract

| Component | Location |
|---|---|
| `BookMetadataProvider` | `lib/features/metadata_enrichment/providers/book_metadata_provider.dart` |
| Provider-neutral models | `lib/features/metadata_enrichment/models/` |
| `MetadataHttpTransport` | `lib/features/metadata_enrichment/transport/` |
| Open Library adapter | `lib/features/metadata_enrichment/providers/open_library/` |
| `BookMetadataRefreshService` | `lib/features/metadata_enrichment/services/book_metadata_refresh_service.dart` |
| Enrichment field mapper | `lib/features/metadata_enrichment/services/book_metadata_enrichment_mapper.dart` |
| Fake provider / transport | `fake_book_metadata_provider.dart`, `fake_metadata_http_transport.dart` |

---

## Open Library endpoints

| Operation | Endpoint | Parameters |
|---|---|---|
| ISBN lookup | `GET /api/books` | `bibkeys=ISBN:{normalized}`, `format=json`, `jscmd=data` |
| Explicit search | `GET /search.json` | `title`, `author`, `first_publish_year`, `limit`, `fields=...` |

**Transmitted:** normalized ISBN, title, author, optional year, User-Agent, client IP (inherent).
**Not transmitted:** local paths, filenames, credentials, catalogue tree.

---

## User-Agent policy

- Injected via `OpenLibraryConfig.userAgent` — not a credential
- Default: `TTSPlayer/0.8` (neutral — no project URL or personal email)
- Tests use deterministic `TTSPlayer-Test/1.0`
- Live validation remains disabled until a stable project contact address is selected

---

## ISBN normalization policy

- Strip spaces and hyphens; uppercase ISBN-10 check digit `X`
- Enforce 10- or 13-digit length and character set
- **Checksum validation enforced** — invalid checksum fails locally without HTTP
- ISBN-13 must use `978`/`979` prefix

---

## Error mapping

Open Library HTTP and transport failures map to `BookMetadataProviderFailureCategory`, then to `EnrichmentLastErrorCategory` on persistence. Empty lookup/search results are **not** errors.

| Condition | Provider category | Enrichment category |
|---|---|---|
| Invalid local request | `invalidRequest` | *(rejected before provider)* |
| HTTP 401 | `authentication` | `authenticationFailure` |
| HTTP 403 | `authorization` | `providerUnavailable` |
| HTTP 429 | `rateLimited` | `rateLimited` |
| HTTP 500+ | `providerUnavailable` | `providerUnavailable` |
| Timeout / network | `timeout` / `networkUnavailable` | `networkFailure` |
| Cancelled | `cancelled` | `cancelled` |
| Malformed JSON | `malformedResponse` | `parseFailure` |
| Unexpected content type | `unsupportedResponse` | `parseFailure` |
| Empty 200 body | success / empty | *(unmatched — not error)* |

No automatic retry loops in the adapter.

---

## Persistence conversion

- Collection fields (`authors`, `publishers`, `languages`, `subjects`, ISBN lists) stored as **JSON array strings** in `EnrichmentFieldValue.value` for Phase 7.1 v1 compatibility (bounded scalar representation — not arbitrary JSON blobs)
- List values are **sorted lexicographically** before `jsonEncode` for deterministic persistence
- Scalar fields stored as plain strings
- All provider fields use `EnrichmentFieldSource.provider` with `providerId` and `updatedAt`
- `lockedFields` on the record are respected — locked keys are not overwritten on refresh
- **Missing-field policy:** refresh merges incoming provider fields only; keys absent from the new response are **retained** from the existing record (not cleared)
- **Exact-ISBN confidence:** `1.0` when the Books API returns a record under the exact `ISBN:<value>` bibkey (`lookupKeyConfirmed`); otherwise `1.0` only when the normalized lookup ISBN appears in metadata identifier lists

---

## Empty-result policy

| Scenario | Behaviour |
|---|---|
| ISBN lookup empty, no existing record | No record created; returns `BookMetadataRefreshEmpty` |
| ISBN lookup empty, existing record | Clears provider linkage; sets `unmatched`; preserves field values and locks |
| Search empty | Returns empty candidate list; no persistence |
| Provider failure, no existing record | Failure returned; nothing persisted |
| Provider failure, existing record | Updates `lastErrorCategory` only; preserves enriched fields |

---

## Search candidate deduplication

1. Prefer edition key (`/books/OL...M`)
2. Else work key + title + first author + year
3. Tie-break: higher provider score, then lexicographic `providerRecordId`

Provider ordering is not converted to TTSPlayer match confidence.

---

## Test evidence

| Suite | Result |
|---|---|
| Focused metadata tests (33) | **33 passed** |
| Full `flutter test` | **1470 passed, 19 skipped** |
| Live Open Library tests | Not implemented (optional) |

Focused files:

- `test/book_metadata_provider_test.dart`
- `test/open_library_book_metadata_provider_test.dart`
- `test/book_metadata_refresh_service_test.dart`

Fixtures: `test/support/open_library_test_fixtures.dart`

---

## Explicit exclusions (verified)

- No automatic matching (Phase 7.3)
- No cover download (Phase 7.4)
- No credential persistence
- No production UI hook
- No provider calls during catalogue load, rescan, or repository init
- No raw provider JSON persistence
- No new dependencies
- No version bump

---

## Remaining Phase 7.2 / M7 work

| Item | Phase |
|---|---|
| Production DI wiring / dev hook (optional) | 7.2 residual or 7.3 |
| Automatic matching and ambiguous UX | 7.3 |
| Match confirmation UI | 7.3 |
| Cover artwork (Covers API) | 7.4 |
| Enriched detail presentation | 7.5 |
| Privacy opt-in disclosure UI | 7.7 |
| OS-backed credential storage (ISBNdb secondary) | 7.7 |
| Windows runtime harness with fake provider | 7.8 |

---

## ADR status

**ADR-028** and **ADR-029** remain **Proposed**. Implementation confirms client-primary enrichment and normalized persistence without raw payloads; no ADR amendment required.

---

## Related documents

- [metadata-enrichment.md](../architecture/metadata-enrichment.md)
- [books-metadata-provider-evaluation.md](../architecture/books-metadata-provider-evaluation.md)
- [Phase 7.1 closure](./m7-phase-7.1-closure-report.md)
