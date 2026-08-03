# M7 Phase 7.4 — Artwork Enrichment and Cache

**Status:** In progress — audit complete (2026-08-03); implementation not started
**Prerequisite:** [Phase 7.3.6 closure](./m7-phase-7.3.6-closure-report.md)
**Branch:** `m7-development`
**Related ADRs:** [ADR-015](../architecture/decisions/ADR-015-artwork-and-image-decode-caching.md) (Accepted), [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) (Proposed), [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md) (Proposed)

→ [M7 plan](./m7-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md) · [Books provider evaluation](../architecture/books-metadata-provider-evaluation.md)

---

## Objective

Implement the first complete **book** artwork-enrichment path: provider-neutral artwork references, explicit download, durable disk cache, central precedence resolution, and integration with the Phase 7.3 metadata-linking workflow — without production Open Library activation, background downloads, or catalogue schema changes.

---

## Preliminary audit (7.4.1)

### Repository baseline (2026-08-03)

| Check | Value |
|---|---|
| Branch | `m7-development` |
| HEAD | `2e27f33` |
| Phase 7.3 runtime | `82aa1ae` |
| Phase 7.3 closure | `2e27f33` |
| Working tree | Clean |
| Divergence vs `origin/m6-development` | `0 19` |
| Catalogue schema | `catalogue_version` max **4** (`CatalogueInfo.maxSupportedCatalogueVersion`) |
| Enrichment persistence | `MetadataEnrichmentRepository.currentStateVersion` **1**, key `ttsplayer_metadata_enrichment_v1` |
| Flutter deps (relevant) | `http`, `path_provider`, `shared_preferences` — no image-specific packages; **`crypto` transitive only** (see [Cache key hashing](#cache-key-hashing-742-prerequisite)) |

### Existing artwork stack

| Component | Current behaviour | Phase 7.4 impact |
|---|---|---|
| **`ArtworkService`** | Synchronous filesystem probes; bounded LRU (**500**) of `ArtworkCandidate` keyed `library:`, `folder:`, `media:{itemId}` | **Extend** with provider-cache source via a separate resolver layer — do not embed HTTP or disk cache inside `ArtworkService` probes |
| **`ArtworkCandidate`** | `kind`, `source` (`catalogThumbnail`, `sidecar`, `folderArt`, `placeholder`), `filePath`, `visualKind` | **Extend** `ArtworkSource` with `providerCache` (local file path only — never URL) |
| **`ArtworkImage`** | Loads via `MediaLocationResolver`; supports `file://` and `http(s)://` with decode hints (ADR-015); `errorBuilder` → placeholder | **Reuse** for cached provider files; **do not** pass live provider URLs from resolver |
| **`LruCache`** | Generic fixed-capacity LRU; used only for path-resolution candidates | **Reuse** pattern; separate disk-cache index |
| **Flutter `ImageCache`** | 100 MB budget via `configureArtworkFlutterImageCache()` | **Reuse**; document relationship to disk cache; no duplicate bitmap store |
| **`CatalogCacheCoordinator`** | Clears `ArtworkService` candidate cache on catalogue replace | **Extend** to invalidate provider artwork *eligibility* bindings when enrichment pruned; disk files follow retention policy |
| **Embedded artwork** | Not implemented (ID3/APIC, EPUB cover) | Precedence slot reserved per ADR-029 |
| **User artwork override** | Not implemented (`lockedFields` exists on enrichment records but no `artwork` field key or picker) | Precedence slot **1** reserved; no picker UI in 7.4 unless already scoped |
| **Sidecar / folder art** | Stem match + named sidecars (`poster`, `cover`, …) + folder art files | **Preserve** — beats provider cache |
| **Catalogue thumbnail** | `item.thumbnailPath` when present and readable | **Preserve** — currently checked before sidecars in `ArtworkService` |

**Surfaces using `ArtworkService.forMediaItem` today:** `TtsMediaCard`, `ItemDetailScreen` poster, search rows, Continue Watching, favourites, music thumbnail fallback.

**Duplication risk:** Adding provider logic inside `ArtworkService._forMediaItem` would mix local probes with enrichment state. **Decision:** introduce a **`MetadataArtworkResolver`** (or equivalent) that composes `ArtworkService` local result with enrichment-linked cache eligibility.

### Existing metadata enrichment stack

| Component | Artwork-related state today |
|---|---|
| **`NormalizedBookMetadata`** | No cover URL, cover ID, or artwork reference fields |
| **`OpenLibraryResponseParser`** | Does not parse `cover_i`, `covers`, or Covers API identifiers |
| **`MetadataEnrichmentRecord`** | Text fields only via `EnrichmentBookFieldKeys`; no artwork reference blob |
| **`BookMetadataMatchTransition`** | Link/relink/unlink text fields; no artwork reference persistence |
| **`BookMetadataMatchingCoordinator`** | Search/select/relink/unlink — no artwork download |
| **`BookMetadataEnrichmentSection`** | Metadata matching UI only — no cover download controls |
| **Feature gate** | `MetadataEnrichmentFeatureConfig.metadataEnrichmentDevelopmentEnabled` |
| **Production provider** | Open Library adapter exists; **not wired in `main.dart`**; tests use fakes |

### Storage and lifecycle

| Mechanism | Status |
|---|---|
| Enrichment JSON | SharedPreferences envelope v1 |
| Artwork disk cache | **Not implemented** (ADR-015 explicitly deferred disk store) |
| `path_provider` | Declared in `pubspec.yaml`; **not used in `lib/` yet** — suitable for app-support cache root |
| Temp/atomic write helpers | No shared utility; follow enrichment repository atomic save pattern |
| Diagnostics | `ArtworkService` candidate count + Flutter `ImageCache` bytes in runtime snapshot ([ADR-018](../architecture/decisions/ADR-018-runtime-snapshot-model.md)) |
| Redaction | [ADR-019](../architecture/decisions/ADR-019-diagnostics-export-support-strategy.md) — no paths/URLs in exports |
| Runtime harness pattern | Phase 7.3.6: `PHASE_736_RUNTIME=1`, `@Tags`, `LiveTestWidgetsFlutterBinding`, scripted provider |

### Architectural decisions already governing design

| ADR | Relevance |
|---|---|
| **ADR-015** (Accepted) | Path-resolution LRU + decode sizing; **no disk cache** in M4 — Phase 7.4 adds a **separate** provider disk cache without contradicting ADR-015 scope |
| **ADR-029** (Proposed) | Artwork precedence, cache-first, no widget hotlinking — **primary design authority** for 7.4 |
| **ADR-028** (Proposed) | Provider boundary, no raw payload persistence |
| **New ADR** | **Optional ADR-030 Proposed** for provider artwork disk-cache policy (quota, eviction, security) if closure review wants it separated from ADR-015 — not required to start 7.4.2 |

**No blocker** requiring code changes before architecture sign-off. Open Library cover identifiers must be **added to the provider mapper** (edition/search parse + stable cover ID) — scoped to 7.4.2/7.4.5, not live HTTP.

---

## Four-concern boundary (required)

| Concern | Owner (proposed) | Responsibility |
|---|---|---|
| **Reference** | `MetadataArtworkReference` model + persistence on enrichment record | Provider-neutral cover identity; cache state; no bytes |
| **Selection** | `MetadataArtworkResolver` | Single precedence policy; returns displayable local path + provenance |
| **Retrieval** | `MetadataArtworkDownloadService` + `MetadataArtworkCache` | Explicit HTTP (fake in tests), validation, atomic disk write, quota |
| **Presentation** | Existing `ArtworkImage` + enrichment section UI | Load cached files only; bounded messages |

Coordinator optional: **`MetadataArtworkCoordinator`** orchestrates download/refresh with item-scoped lifecycle (reuse 7.3.4/7.3.5 generation pattern).

---

## Artwork reference model (proposed)

Persist on `MetadataEnrichmentRecord` (new optional `artworkReference` map or dedicated sub-object in envelope v1 — **backward compatible** when absent):

| Field | Purpose |
|---|---|
| `providerId` | Provider namespace |
| `providerRecordId` | Edition/work linkage — must match active enrichment link |
| `artworkId` | Stable provider image ID (e.g. Open Library cover ID) — **not** signed URL |
| `kind` | `cover` (v1 enum) |
| `contentType` | Last validated MIME |
| `width` / `height` | Optional |
| `fetchedAt` | Reference recorded |
| `validatedAt` | Last successful download validation |
| `cacheState` | `available`, `downloaded`, `stale`, `failed`, `unavailable` |
| `cacheKey` | Deterministic app-owned key |
| `localRelativePath` | Path relative to cache root (not absolute in SharedPreferences) |
| `validator` | Optional ETag / Last-Modified / provider revision string |

**Not stored:** image bytes, Base64, raw signed URLs as durable identity, full filesystem paths to media library.

Open Library mapper (provider-specific, not in widgets): derive `artworkId` from `cover_i` / edition cover fields → Covers API URL only at download time.

---

## Source precedence (authoritative)

Align with [m7-plan.md](./m7-plan.md) and ADR-029:

1. User-selected artwork override (**reserved** — not implemented)
2. Catalogue thumbnail (`thumbnail_path`) — existing first check in `ArtworkService`
3. Local sidecar (stem + named sidecars)
4. Folder artwork
5. Embedded artwork (**future**)
6. **Cached provider artwork** (linked enrichment record + valid cache file + matching `providerRecordId`)
7. Placeholder

**Policy:** Provider artwork never replaces sidecar/folder/thumbnail. Unlink → provider cache **ineligible** immediately; files may remain until eviction. Relink → old record's cache ineligible; new reference only after new link.

Single resolver output:

```dart
// Illustrative
class MetadataArtworkResolution {
  final ArtworkSource source;
  final String? displayFilePath; // app-owned cache or library path
  final String? provenanceLabel;
  final bool isCached;
  final bool isStale;
  final bool usedFallback;
}
```

---

## Retrieval policy (Phase 7.4 initial)

| Trigger | Allowed |
|---|---|
| User **Download cover** / **Refresh cover** in enrichment section | Yes |
| User confirms metadata link | Persist reference only — **no auto-download** in 7.4 initial slice |
| Detail open / card scroll | **No** provider calls |
| Background / catalogue load | **No** |

Preferred v1: link stores reference; download is explicit. (Aligns with user spec "preferred initial behaviour".)

---

## Download validation (proposed)

- HTTPS only (HTTP allowed only in test fixture server)
- Timeout: **15 s** (matches graceful-degradation network guidance)
- Max size: **8 MB** default (conservative for cover images)
- Reject empty body, non-image `Content-Type`, HTML error pages
- Decode validation via `dart:ui` `instantiateImageCodec` — **no new package**
- Write `*.part` → fsync → rename atomically
- On refresh failure: retain previous valid file + metadata

---

## Disk cache (proposed)

| Aspect | Policy |
|---|---|
| Root | `{ApplicationSupportDirectory}/metadata_artwork_cache/` via `path_provider` |
| Key | `sha256(providerId + providerRecordId + artworkId)` — hex filename; see [Cache key hashing](#cache-key-hashing-742-prerequisite) |
| Extension | From validated MIME (`.jpg`, `.png`, `.webp`) |
| Index | Separate JSON metadata file `cache_index_v1.json` in same root |
| Default max | **256 MB** total |
| Eviction trigger | After successful write + on repository init if over **100%**; target **80%** of max |
| Eviction order | LRU by `lastAccessedAt` among entries not pinned as "recently displayed" (optional pin: last 24 h access exempt from first pass) |
| Orphans | Lazy delete on read miss; proactive sweep on init |
| Corruption | Delete entry + re-download on explicit user action |
| Security | Cache root canonicalized; reject `..` in keys; never write outside root |

---

## Memory cache (proposed)

**Reuse ADR-015 stack:**

- **Disk file** → `ArtworkImage` / `Image.file` with decode hints
- **Flutter `ImageCache`** holds decoded pixels (100 MB cap)
- **ArtworkService LRU** remains path-probe cache only — **do not** store provider bytes there

When cache file changes: evict Flutter cache entry for old path if tracked (optional file-path-based eviction helper — minimal scope).

No second project-owned bitmap LRU unless profiling shows Flutter cache insufficient.

---

## Metadata-link lifecycle (artwork)

| Event | Artwork behaviour |
|---|---|
| **Link / relink confirm** | Persist `MetadataArtworkReference` when provider supplies cover ID; state `available` or `downloaded` if cache hit for same key |
| **Same-record relink** | Reuse cache if key unchanged |
| **Relink to new record** | Old reference ineligible; pending downloads for old `(itemId, providerRecordId)` ignored |
| **Unlink** | Clear reference from enrichment record; resolver stops selecting provider cache |
| **Ignore / resume** | No download; cache files retained but ineligible when unlinked |

Reuse `_lifecycleGeneration` / item-scoped patterns from `BookMetadataEnrichmentSection`.

---

## UI integration (minimum)

### Enrichment section (7.4.5)

- Show cover availability, downloaded/stale state
- Actions: **Download cover**, **Refresh cover** (when linked + reference present)
- Bounded success/failure messages
- Pending disables duplicate action

### Item detail (7.4.6)

- Poster via central resolver — **no download on open**

### Browse cards (7.4.6, conditional)

- Use cached provider file **only if already on disk**
- **No** list-triggered downloads; defer if scope pressure

---

## Diagnostics and privacy (7.4 scope)

Extend runtime snapshot / structured test counters (full export may defer to 7.7):

- `providerArtworkReferencePresent`
- `providerArtworkCacheState`
- `providerArtworkCacheEntryCount`
- `providerArtworkCacheTotalBytes`
- `providerArtworkDownloadInvocationCount` (tests/runtime)

Never export: credentials, signed URLs, raw HTTP text, absolute cache paths, image bytes.

---

## Cache key hashing (7.4.2 prerequisite)

**Audit check (approved 2026-08-03):** the proposed SHA-256 cache key must not rely on a transitive `package:crypto` import.

### Current state (verified 2026-08-03)

| Check | Result |
|---|---|
| Direct `crypto` in `pubspec.yaml` | **No** |
| `crypto` in `pubspec.lock` | **Yes — transitive** (`pdfrx`, `pdfrx_engine`, `uuid`, dev `hooks`) at **3.0.7** |
| Existing `import 'package:crypto/crypto.dart'` in `lib/` | **None** |
| Existing project SHA-256 / digest utility | **None** — catalogue item IDs use backend MD5; client has no shared hash helper |
| `archive` package comment (UnRAR Gate 0) | Documents intent only; no Dart SHA-256 usage in client today |

### Decision (7.4.2)

1. **Add `crypto` as a direct dependency** in `client/ttsplayer/pubspec.yaml` when implementing cache-key derivation — first change in the 7.4.2 slice, before any `package:crypto` import.
2. **Pin** to the lockfile-resolved line already present transitively: `crypto: ^3.0.7` (or compatible caret within 3.x).
3. **Implement** a single helper (e.g. `metadata_artwork_cache_key.dart`) that computes:

   ```dart
   // Canonical input: UTF-8 bytes of joined components with U+001E separator
   // (avoids ambiguous concatenation when IDs contain common substrings).
   sha256.convert(utf8.encode('$providerId\u001e$providerRecordId\u001e$artworkId')).toString()
   ```

4. **Do not** import `package:crypto` from application code until step 1 is merged — transitive availability is not sufficient for a durable dependency contract.

**Alternatives considered and rejected for 7.4:**

- **Transitive import only** — violates audit requirement; breaks if `pdfrx`/`uuid` stop pulling `crypto`.
- **String slug / sanitization without hash** — simpler but weaker collision safety and filename-length bounds when provider IDs contain path-like segments.
- **New non-crypto hash package** — unnecessary; `crypto` is already resolved in the lockfile.

**7.4.2 deliverables tied to this check:** pubspec direct dependency + cache-key unit tests (deterministic hex output, separator stability, empty-component rejection if applicable).

---

## Implementation sequence

| Step | Deliverable | Status |
|---|---|---|
| **7.4.1** | Audit + architecture (this document) | Complete |
| **7.4.2** | Direct `crypto` dep + cache-key helper; artwork reference model + persistence + repository tests | Planned |
| **7.4.3** | Disk cache, download validation, cleanup + tests | Planned |
| **7.4.4** | Central resolver + precedence + tests | Planned |
| **7.4.5** | Book metadata workflow integration + lifecycle tests | Planned |
| **7.4.6** | Detail + cached browse presentation | Planned |
| **7.4.7** | Windows runtime harness (`PHASE_74_RUNTIME=1`, `phase74-runtime`) + closure report | Planned |

---

## Test strategy (summary)

60+ cases specified in Phase 7.4 charter — grouped by: models/persistence, precedence, download/validation, cache behaviour, metadata lifecycle, UI, integration, runtime harness.

Existing Phase 7.3 tests must remain green after each sub-phase.

Runtime harness: scripted image bytes fixture, temp cache root, no live HTTP — extend patterns from `phase_736_metadata_matching_windows_runtime_test.dart`.

---

## Files likely to change (forecast)

**New (lib):**

- `lib/features/metadata_enrichment/artwork/` — reference model, **cache-key helper**, cache, download service, resolver, coordinator
- Provider mapper extensions (Open Library cover ID extraction)

**Modified (lib):**

- `metadata_enrichment_record.dart` / repository envelope
- `book_metadata_match_transition.dart` / mapper (reference on link)
- `book_metadata_enrichment_section.dart`
- `artwork_candidate.dart` / `artwork_kind.dart` — new source enum value
- `item_detail_screen.dart` or resolver call site
- `tts_media_card.dart` (cached-only path)
- Diagnostics models (counts only)

**New (test):**

- Unit/widget tests per sub-phase
- `phase_74_artwork_windows_runtime_test.dart` + support fixtures

**Docs:**

- This plan, closure report(s), `metadata-enrichment.md`, `m7-plan.md`, `v0.8.0-dev.md`, optional ADR-030 Proposed

---

## Scope exclusions (Phase 7.4)

Production Open Library activation, live HTTP in CI, credentials UI, bulk/background download, music/video/comic artwork, user artwork picker, settings UI for cache limits, catalogue schema changes, backend changes, new packages without review (**exception:** direct `crypto` promotion per [Cache key hashing](#cache-key-hashing-742-prerequisite)), version bump.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Open Library cover fields absent in normalized metadata | Add parser fields in 7.4.2; fake provider supplies cover ID in tests |
| Precedence duplication across widgets | Single resolver; widgets call resolver not cache directly |
| Disk cache vs ADR-015 confusion | Document as separate layer; ADR-015 unchanged |
| `ArtworkImage` network path temptation | Resolver returns only local cache paths for provider art |
| Envelope v1 migration | Optional artwork sub-object; missing → backward compatible |
| Concurrent downloads | Coalesce by cache key; item-scoped generation tokens |
| Transitive `crypto` import | Add direct `crypto` dependency in 7.4.2 before any hash helper; document in this plan |

---

## Recommended first implementation step

**Phase 7.4.2 — Artwork models and persistence:** add direct `crypto` dependency + `MetadataArtworkCacheKey` helper; define `MetadataArtworkReference`, extend enrichment record JSON (backward compatible), repository round-trip tests, and fake-provider cover ID in test fixtures — **without** download UI or HTTP.

---

## Commit strategy (proposed)

Split by sub-phase: implementation commit(s) per 7.4.2–7.4.6; documentation commit at 7.4.7 closure. Leave uncommitted until sub-phase review unless otherwise approved.
