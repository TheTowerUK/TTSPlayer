# M7 Phase 7.4.3 — Disk Cache and Validation

**Status:** Complete (2026-08-03) — uncommitted for review
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.4.2 closure](./m7-phase-7.4.2-closure-report.md)
**Implementation commit:** pending review

→ [M7 plan](./m7-plan.md) · [Phase 7.4 plan](./m7-phase-7.4-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.4.3 | `f6fc8fc` — `docs(m7.4): document artwork reference persistence` |
| Phase 7.4.2 implementation | `f65d676` — `feat(m7.4): add artwork reference persistence` |
| Phase 7.4.2 documentation | `f6fc8fc` |
| Working tree before 7.4.3 | Clean |
| Divergence vs `origin/m6-development` | `0 23` |
| Direct `crypto` dependency | `crypto: ^3.0.7` (from 7.4.2) |
| Unrelated changes | None |

---

## Objective

Implement the durable **provider artwork disk cache and validation layer** — explicit retrieval infrastructure, atomic writes, cache metadata, cleanup, and corruption recovery — **without UI, resolver precedence, or automatic downloads**.

---

## Existing code reused

| Component | Reuse |
|---|---|
| `MetadataArtworkReference` / `MetadataArtworkCacheKey` | Identity and cache-key derivation (7.4.2) |
| `MetadataArtworkCacheState` | `downloaded`, `failed`, etc. |
| `MetadataTransport*Exception` | HTTP timeout/network/cancel taxonomy |
| `LruCache` pattern (ArtworkService) | Eviction ordering reference only |
| `BookMetadataEnrichmentMapper.mergeArtworkReference` | Same-key refresh preserved (7.4.2) |
| Test temp-dir pattern | `Directory.systemTemp.createTemp` + recursive tearDown |
| `path_provider` | Production cache root only (`getApplicationSupportDirectory`) |
| `path` package (transitive) | Safe join/canonicalization under cache root |

**Not duplicated:** SharedPreferences for cache index; ArtworkService probes; widget hotlinking.

---

## Cache architecture

Four-concern split (retrieval slice only):

| Component | Responsibility |
|---|---|
| **`MetadataArtworkFilesystem`** | Cache root, relative paths, temp files, atomic rename, index atomic write |
| **`MetadataArtworkCacheRepository`** | Index load/save, lookup, upsert, eviction, orphan sweep, missing-file recovery |
| **`MetadataArtworkDownloadService`** | Explicit `download` / `refresh`, validation orchestration, generation guard |
| **`MetadataArtworkValidator`** | Byte/MIME/decode validation via `dart:ui` |

Supporting types: `MetadataArtworkCacheEntry`, `MetadataArtworkHttpClient`, `FakeMetadataArtworkHttpClient`, `OpenLibraryArtworkDownloadUrlResolver`, `MetadataArtworkDownloadGenerationGuard`.

**No UI. No resolver. No coordinator wiring. No automatic download triggers.**

---

## Cache metadata

**Index file:** `{ApplicationSupportDirectory}/metadata_artwork_cache/cache_index_v1.json`

**Envelope:**

```json
{
  "indexVersion": 1,
  "entries": [ /* MetadataArtworkCacheEntry */ ]
}
```

**`MetadataArtworkCacheEntry` fields:** `cacheKey`, `providerId`, `providerRecordId`, `artworkId`, `relativePath`, `contentType`, `width`, `height`, `byteSize`, `createdAt`, `lastValidatedAt`, `lastAccessedAt`, `validator`, `cacheState`.

Artwork **reference** remains in enrichment SharedPreferences envelope v1 — cache index is separate.

---

## Filesystem layout

```
{ApplicationSupportDirectory}/
  metadata_artwork_cache/
    cache_index_v1.json
    {cacheKey}.jpg|.png|.webp|.gif
    {cacheKey}.{ext}.part   (transient only)
```

- All persisted paths are **relative** to cache root.
- Absolute paths resolved only at runtime via `MetadataArtworkFilesystem.fileForRelativePath`.
- Never uses media folders, catalog.json, or SharedPreferences for image bytes.

---

## Cache identity

Uses Phase 7.4.2 `MetadataArtworkCacheKey.compute()` — SHA-256 hex of `providerId`, `providerRecordId`, `artworkId` (U+001E separated). Never derived from title, author, ISBN, filename, or URL.

---

## Validation strategy

Order: download → temp file → validate bytes → promote → persist index entry.

| Rule | Value |
|---|---|
| HTTPS only | Production client; HTTP allowed in test fakes |
| Timeout | 15 s |
| Max size | 8 MB |
| Reject | empty body, HTML, unsupported MIME, decode failure |
| Decode | `dart:ui` `instantiateImageCodecFromBuffer` |
| MIME | Header normalized + magic-byte sniff fallback |
| Extension | From validated MIME only — never trust provider filename |

On **refresh failure:** previous valid cache file and metadata retained.

---

## Atomic write strategy

1. Write bytes to `{relativePath}.part` (flush)
2. Validate before promotion (validation runs on bytes in memory; temp written after validation in download service)
3. `rename()` temp → final `{cacheKey}{ext}`
4. Fallback copy+delete on rename failure (Windows-safe)
5. Persist index via `cache_index_v1.json.part` → rename

Validation failure: delete temp; do not overwrite valid cache.

---

## Cleanup and quota

| Policy | Value |
|---|---|
| Default max | 256 MB |
| Eviction trigger | After successful write; on `initialize()` / `cleanup()` |
| Eviction target | 80% of max |
| Eviction order | LRU by `lastAccessedAt` |
| Orphan files | Deleted when not in index |
| Orphan metadata | Removed when file missing |
| Idempotent | Repeated `cleanup()` safe |

Never touches library sidecars, folder art, or catalogue thumbnails.

---

## Corruption handling

| Condition | Behaviour |
|---|---|
| Missing file on lookup | Remove index entry; return null |
| Invalid metadata JSON | Skip entry with recovery; retain valid entries |
| Validation failure on download | Delete temp; preserve existing cache on refresh |
| Generation mismatch | Abort commit; no cache write |

Artwork **reference** on enrichment record is unchanged by cache invalidation — re-download remains possible in later phases.

---

## Lifecycle integration

| Event | Cache behaviour (7.4.3 API) |
|---|---|
| Same artwork / same cache key | `download()` returns existing cache without HTTP |
| Same-record refresh | Reuses entry when key unchanged |
| Relink (different key) | Separate cache entries |
| Unlink | Cache **retained** until explicit `remove()` or eviction |
| Stale generation | `MetadataArtworkDownloadGenerationGuard` blocks commit |

Coordinator/enrichment persistence of `localRelativePath` after download deferred to 7.4.5.

---

## Security

- Rejects non-HTTPS URIs in production HTTP client
- Rejects `..` and absolute relative paths
- Never trusts provider filenames or Content-Type alone
- Validates decode and dimensions before promotion
- Stores validated extension from MIME map only

---

## Files changed (implementation — uncommitted)

**New (lib):**

- `artwork/metadata_artwork_cache_entry.dart`
- `artwork/metadata_artwork_filesystem.dart`
- `artwork/metadata_artwork_cache_repository.dart`
- `artwork/metadata_artwork_validator.dart`
- `artwork/metadata_artwork_mime_types.dart`
- `artwork/metadata_artwork_http_client.dart`
- `artwork/metadata_artwork_download_service.dart`
- `artwork/metadata_artwork_download_result.dart`
- `artwork/metadata_artwork_download_url_resolver.dart`
- `artwork/metadata_artwork_download_generation_guard.dart`
- `artwork/fake_metadata_artwork_http_client.dart`
- `providers/open_library/open_library_artwork_download_url_resolver.dart`

**New (test):**

- `test/metadata_artwork_validator_test.dart`
- `test/metadata_artwork_cache_repository_test.dart`
- `test/metadata_artwork_download_service_test.dart`
- `test/support/metadata_artwork_test_fixtures.dart`

---

## Tests

| Suite | Coverage |
|---|---|
| Validator | valid PNG, empty, HTML, invalid bytes, oversized, wrong MIME |
| Filesystem | atomic index, temp promote |
| Repository | round-trip, lookup, missing file, LRU quota, orphan sweep |
| Download service | download, cache hit, refresh preserve, validation fail, generation guard, relink keys, explicit remove |

**No UI tests.**

---

## Runtime validation

No new Windows runtime harness in 7.4.3 — unit/integration tests use deterministic PNG fixtures and `FakeMetadataArtworkHttpClient` (no live HTTP). Runtime harness deferred to 7.4.7.

---

## Full regression

| Gate | Result |
|---|---|
| New 7.4.3 suites | 20 passed |
| Phase 7.4.2 suites | Green |
| Phase 7.3 suites | Green |
| Full `flutter test` | **1689 passed, 20 skipped, 0 failed** |

---

## Known limitations

- Open Library URL resolver implemented but production provider not wired in `main.dart`
- Enrichment record `localRelativePath` / `downloaded` state not auto-updated after download (7.4.5)
- No `MetadataArtworkResolver` / browse or detail presentation (7.4.4–7.4.6)
- No download UI or background retrieval
- Cache index has no forward migration beyond `indexVersion: 1`

---

## Deferred to later sub-phases

| Item | Phase |
|---|---|
| Central precedence resolver | 7.4.4 |
| Coordinator + enrichment section download/refresh UI | 7.4.5 |
| Item detail / browse cached presentation | 7.4.6 |
| Windows runtime harness | 7.4.7 |

---

## Proposed commit split

1. **Implementation:** `feat(m7.4): add artwork disk cache and validation`
2. **Documentation:** `docs(m7.4): close Phase 7.4.3 disk cache and validation`

---

## Next task

**Phase 7.4.4 — Central resolver and precedence:** `MetadataArtworkResolver` composing `ArtworkService` local probes with enrichment-linked cache eligibility; `ArtworkSource.providerCache`; single precedence policy — still no download UI.

→ [Phase 7.4 plan](./m7-phase-7.4-plan.md)
