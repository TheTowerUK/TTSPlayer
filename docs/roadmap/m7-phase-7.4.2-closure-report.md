# M7 Phase 7.4.2 — Artwork Models and Persistence

**Status:** Complete (2026-08-03)
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.4 plan](./m7-phase-7.4-plan.md) (7.4.1 audit)
**Implementation commit:** `f65d676` — `feat(m7.4): add artwork reference persistence`

→ [M7 plan](./m7-plan.md) · [Phase 7.4 plan](./m7-phase-7.4-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.4.2 | `faed43c` — `docs(release): record Phase 7.4 planning` |
| Phase 7.4.1 audit docs | `ee60bfe` — `docs(m7.4): define artwork enrichment and cache plan` |
| Phase 7.3 closure | `2e27f33` — `docs(m7.3): close Phase 7.3 validation and runtime harness` |
| Working tree before 7.4.2 | Clean (after 7.4.1 planning commits) |
| Enrichment envelope | `stateVersion` **1**, key `ttsplayer_metadata_enrichment_v1` |

---

## Objective

Persist **provider-neutral artwork identity** on enrichment records — reference metadata only. The application can record that a linked book has provider artwork with a stable ID. **No image bytes, downloads, disk cache, resolver, UI, or HTTP** in this slice.

---

## Direct `crypto` dependency decision

| Check | Before 7.4.2 | After 7.4.2 |
|---|---|---|
| Direct `crypto` in `pubspec.yaml` | No (transitive via `pdfrx`, `pdfrx_engine`, `uuid`) | **Yes — `crypto: ^3.0.7`** |
| Rationale | Audit required durable contract for SHA-256 cache keys | Promoted existing lockfile line; no new package family |

`package:crypto` is imported only from `metadata_artwork_cache_key.dart`. No transitive-only import.

---

## Cache-key algorithm

**Helper:** `MetadataArtworkCacheKey.compute()` in `lib/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart`

| Aspect | Policy |
|---|---|
| Input | Trimmed `providerId`, `providerRecordId`, `artworkId` |
| Separator | U+001E (record separator) between components |
| Digest | SHA-256 over UTF-8 bytes of joined string |
| Output | Lowercase 64-char hex string |
| Validation | Rejects empty identity components with `ArgumentError` |

```dart
sha256.convert(utf8.encode('$providerId\u001e$providerRecordId\u001e$artworkId')).toString()
```

Unit tests: `test/metadata_artwork_cache_key_test.dart` — determinism, separator collision safety, trim behaviour, empty rejection.

---

## Artwork reference model

**Location:** `lib/features/metadata_enrichment/artwork/`

| Type | Purpose |
|---|---|
| `MetadataArtworkReference` | Persisted reference sub-object on enrichment record |
| `MetadataArtworkKind` | `cover` (v1 enum) |
| `MetadataArtworkCacheState` | `available`, `downloaded`, `stale`, `failed`, `unavailable` |

### `MetadataArtworkReference` fields

| Field | 7.4.2 usage |
|---|---|
| `providerId` | Provider namespace |
| `providerRecordId` | Edition/work linkage — must match active enrichment link |
| `artworkId` | Stable provider image ID (string) — **not** a URL |
| `kind` | `cover` |
| `contentType` | Optional — unset at link time |
| `width` / `height` | Optional — unset at link time |
| `fetchedAt` | Reference recorded (UTC) |
| `validatedAt` | Optional — unset (no download yet) |
| `cacheState` | **`available`** on link (identity known, no local file) |
| `cacheKey` | SHA-256 hex from cache-key helper |
| `localRelativePath` | **null** (7.4.3+) |
| `validator` | Optional — unset |

**Not stored:** image bytes, Base64, signed URLs, absolute cache paths in SharedPreferences.

`normalized()` validates identity fields and verifies `cacheKey` matches recomputed digest.

---

## Envelope version decision

| Decision | Detail |
|---|---|
| `MetadataEnrichmentRepository.currentStateVersion` | **Unchanged at 1** |
| Storage key | `ttsplayer_metadata_enrichment_v1` |
| New shape | Optional `artworkReference` object on each record in `records[]` |
| Schema bump | **Not required** — additive optional field only |

---

## Backward compatibility

| Scenario | Behaviour |
|---|---|
| Records without `artworkReference` | Load normally; field absent → `null` |
| Malformed `artworkReference` | Skipped with recovery warning; record retained without artwork |
| Pre-7.4.2 JSON envelopes | Full round-trip; no migration step |
| Text `fields` map | Unchanged — artwork is **not** an `EnrichmentBookFieldKeys` entry |

---

## Provider-neutral metadata extension

**`NormalizedBookMetadata.coverArtworkId`** — optional stable provider cover identifier (string). No URL construction at parse time.

### Open Library parsing (`OpenLibraryResponseParser`)

| API path | Source field | Mapping |
|---|---|---|
| Search `_parseSearchDoc` | `cover_i` (int) | First positive int → string `coverArtworkId` |
| Books API `_parseEditionMap` | `covers` (int array) | First positive int → string `coverArtworkId` |

No Covers API URL construction. No HTTP changes.

**Test fixtures:** `FakeBookMetadataProvider.sampleMetadata()` / `sampleCandidate()` supply default cover IDs for transition and coordinator tests.

---

## Metadata-link lifecycle (artwork reference)

Implemented via `BookMetadataEnrichmentMapper` and `BookMetadataMatchTransition` — coordinator signatures unchanged.

| Event | Artwork behaviour |
|---|---|
| **Link** (ISBN or manual) | Persist `MetadataArtworkReference` when `coverArtworkId` present; `cacheState: available` |
| **Relink** | Replace reference from new metadata; clear when new metadata has no cover ID |
| **Same-record refresh** (`mergeProviderFields`) | Reuse existing reference when `cacheKey` unchanged; update `fetchedAt` |
| **Unlink** | Clear reference via `_clearProviderLinkage` |
| **Ignore** | Clear reference (same linkage clear as unlink) |
| **Resume matching** | **Unchanged** — transitions `ignored` → `unmatched` only; no artwork side effects |
| **Ambiguous** | Clear reference when `providerRecordId` cleared |

---

## Explicit non-deliverables (7.4.2)

| Area | Status |
|---|---|
| Download service / HTTP | Not implemented |
| Disk cache / `path_provider` usage | Not implemented |
| `MetadataArtworkResolver` | Not implemented |
| Enrichment section UI (Download/Refresh cover) | Not implemented |
| `ArtworkService` / `ArtworkSource.providerCache` | Not implemented |
| Item detail / browse presentation changes | Not implemented |
| Production Open Library wiring in `main.dart` | Not implemented |

**Boundary preserved:** the app knows *“this book has provider artwork with ID X”* — not how to download it. Phase 7.4.3 owns retrieval and validation.

---

## Files delivered (`f65d676`)

**New (lib):**

- `lib/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart`
- `lib/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart`
- `lib/features/metadata_enrichment/artwork/metadata_artwork_kind.dart`
- `lib/features/metadata_enrichment/artwork/metadata_artwork_reference.dart`

**Modified (lib):**

- `metadata_enrichment_record.dart` — optional `artworkReference`
- `normalized_book_metadata.dart` — `coverArtworkId`
- `open_library_response_parser.dart` — `cover_i` / `covers[0]`
- `book_metadata_enrichment_mapper.dart` — `artworkReferenceFromMetadata`, `mergeArtworkReference`
- `book_metadata_match_transition.dart` — link/relink/clear lifecycle
- `fake_book_metadata_provider.dart` — test cover IDs
- `pubspec.yaml` / `pubspec.lock` — direct `crypto`

**New (test):**

- `metadata_artwork_cache_key_test.dart`
- `metadata_artwork_reference_test.dart`

**Extended (test):**

- `metadata_enrichment_record_test.dart`
- `metadata_enrichment_repository_test.dart`
- `book_metadata_matching_transitions_test.dart`
- `open_library_book_metadata_provider_test.dart`

---

## Validation

| Gate | Result |
|---|---|
| Focused 7.4.2 suites | Pass |
| Full `flutter test` | **1699 passed, 20 skipped, 0 failed** |
| Phase 7.3 suites | Green (no regressions) |

---

## Next task

**Phase 7.4.3 — Disk cache and download validation:** `MetadataArtworkCache`, explicit download service, atomic write, quota/eviction, decode validation — still no production HTTP in CI and no enrichment-section download UI unless scoped in 7.4.5.

→ [Phase 7.4 plan](./m7-phase-7.4-plan.md)
