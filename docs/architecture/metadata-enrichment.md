# Metadata Enrichment Architecture

**Status:** Planning (M7 Phase 7.0)
**Milestone:** M7 — Metadata Enrichment and Library Experience
**Related ADRs:** [ADR-028](./decisions/ADR-028-external-metadata-enrichment-boundary.md) (Proposed), [ADR-029](./decisions/ADR-029-metadata-precedence-provenance-and-matching.md) (Proposed)

→ [M7 plan](../roadmap/m7-plan.md) · [Phase 7.1 closure](../roadmap/m7-phase-7.1-closure-report.md) · [Books provider evaluation](./books-metadata-provider-evaluation.md)
→ [Books & comics](./books-comics.md) · [Music](./music.md)
→ [Artwork caching ADR-015](./decisions/ADR-015-artwork-and-image-decode-caching.md)
→ [Diagnostics ADR-017](./decisions/ADR-017-diagnostics-architecture.md)

---

## Purpose

Define how TTSPlayer adds **optional external metadata** without compromising local authority. This document complements accepted local-precedence ADRs ([ADR-021](./decisions/ADR-021-music-metadata-precedence-and-identity.md), [ADR-025](./decisions/ADR-025-book-comic-identity-and-metadata-precedence.md)) by describing the enrichment overlay, storage, and runtime merge — not scanner emission rules.

---

## Core rule

> Local files and the local catalogue remain the source of truth.

External metadata **enriches presentation**. It does not determine whether an item exists, which folder it belongs to, or whether it can be played or opened.

---

## System boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│                        Filesystem (truth)                        │
└────────────────────────────┬────────────────────────────────────┘
                             │ scan
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  catalog.json (v4) — indexer / HTTP provider                   │
│  id, file_path, media_kind, local title/tags, status           │
└────────────────────────────┬────────────────────────────────────┘
                             │ load
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Flutter client                                                  │
│  ┌──────────────┐  ┌────────────────────┐  ┌─────────────────┐ │
│  │ MediaItem    │  │ Enrichment store   │  │ User state      │ │
│  │ (catalogue)  │+ │ (provider overlay) │+ │ (favourites,    │ │
│  │              │  │                    │  │  progress, etc.)│ │
│  └──────────────┘  └────────────────────┘  └─────────────────┘ │
│         │                    ▲                                   │
│         │    merge at        │ explicit refresh / detail        │
│         ▼    presentation    │ (never on bare catalogue load)   │
│  ┌──────────────────────────────────────────┐                   │
│  │ MetadataPresentationService (proposed)    │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  UI: cards, detail, search blob extension, artwork resolver      │
└─────────────────────────────────────────────────────────────────┘
                             │ optional HTTPS
                             ▼
                    External metadata providers
                    (opt-in, per media kind)
```

---

## What stays in `catalog.json`

Unchanged from catalogue v4 / indexer contract:

- Path-derived `id`
- `file_path`, `media_kind`, `status`, `size_bytes`, `added_at`
- Locally extracted fields at scan time (music tags, book author, comic series, ffprobe duration)
- `thumbnail_path` remains null from scanner until a future local thumbnail feature

**Forbidden in M7:** writing provider IDs, descriptions, or poster URLs into `catalog.json`.

---

## Enrichment store (proposed)

**Key:** `ttsplayer_metadata_enrichment_v1` (SharedPreferences JSON envelope — **implemented Phase 7.1**)

**Record key:** catalogue item `id`

**Field locks:** `lockedFields` on the enrichment record is authoritative; per-field `locked` flags are derived on normalization and must not disagree after `normalized()`.

| Field group | Examples |
|---|---|
| Linkage | `providerId`, `providerRecordId`, `matchMethod`, `confidence` |
| Lifecycle | `fetchedAt`, `expiresAt`, `lastError`, `ignored` |
| Locks | `lockedFields[]` — refresh skips these |
| Payload | Normalized `fields` map with per-field provenance |

### Catalogue replacement coordination

On `CatalogCacheCoordinator` catalogue replace (existing ADR-014 pattern):

1. Load new catalogue ids
2. Prune enrichment records whose `itemId` absent via `MetadataEnrichmentRepository.validateAgainstCatalog`
3. Do **not** block catalogue load on enrichment I/O failure
4. Invalidate artwork decode cache (provider artwork disk cache deferred to Phase 7.4)

**Rename/move:** Item id is md5(path). Old enrichment records are pruned when the old id disappears; automatic transfer to a new id is Phase 7.3 stale handling.

---

## Presentation merge

At UI boundary, `MetadataPresentationService` (name TBD in 7.1) produces a **view model** merging:

1. User overrides (locks)
2. Sidecar / embedded (when exposed to client)
3. Catalogue `MediaItem`
4. Enrichment overlay fields not locked
5. Fallbacks (filename, placeholders)

Search index extension (Phase 7.5): append provider keywords to `searchBlob` at index build time — never replace local terms.

---

## Provider abstraction (Phase 7.2B — implemented)

**Selected books provider:** [Open Library](https://openlibrary.org/developers/api) — see [books-metadata-provider-evaluation.md](./books-metadata-provider-evaluation.md).

Production contract (client):

- `BookMetadataProvider` — `lookupByIsbn`, `search`
- `MetadataHttpTransport` — injectable GET transport with timeout and cancellation
- `BookMetadataRefreshService` — explicit ISBN refresh → `MetadataEnrichmentRepository.upsert`
- Open Library adapter isolated under `providers/open_library/`

**Not wired in `main.dart` yet** — enrichment is service-level only until Phase 7.3+ UI. No live network in default CI; fake HTTP transport in tests.

→ [Phase 7.2B closure](../roadmap/m7-phase-7.2b-closure-report.md)

## Matching and manual selection (Phase 7.3 — complete)

Phase 7.3 adds deterministic candidate scoring, confidence bands, ambiguity detection, and manual link persistence.

**Phase 7.3.1 (complete):** provider-neutral normalizer, ISBN equivalence utility, weighted evaluator, stable ranker, and transient explainable evaluation models under `lib/features/metadata_enrichment/matching/`. No persistence, networking, UI, or production wiring.

**Phase 7.3.2 (complete):** `BookMetadataMatchingCoordinator` is the application-facing workflow API. It delegates ISBN lookup to the lower-level `BookMetadataRefreshService` while owning search-and-evaluate, manual selection, relink, unlink, ignore, resume matching, and bounded ambiguous/no-match persistence via `BookMetadataMatchTransition`. Non-empty evaluated search results always return `BookCandidateSearchEvaluationSuccess`; `BookCandidateSearchNoProviderCandidates` is reserved for an empty provider candidate list.

**Phase 7.3.3 (complete):** `BookMetadataEnrichmentSection` on book `ItemDetailScreen` — development-gated via `MetadataEnrichmentFeatureConfig`, match-state presentation, provider attribution, explicit ISBN/search/coordinator transitions, and transient search summary. No production provider or coordinator wiring in `main.dart`.

**Phase 7.3.4 (complete):** `BookMetadataCandidateDialog` and presentation mappers — reviewable candidates from coordinator-owned `BookCandidateSelectionContext`, provider-neutral cards, ordinary and critical-conflict confirmation, `selectCandidate()` / `relinkCandidate()` persistence to `linkedManual`, invalid-context recovery, and repository-failure handling without additional provider calls.

**Phase 7.3.5 (complete):** Lifecycle polish for unlink, ignore, resume, and rematch — renamed user-facing actions, explicit confirmation copy, bounded transition success messages, unified item-scoped lifecycle generation, transient workflow clearing, and focused lifecycle widget tests. No coordinator or schema changes.

**Phase 7.3.6 (complete):** Windows opt-in runtime harness (`PHASE_736_RUNTIME=1`, tag `phase736-runtime`) exercising production enrichment section, coordinator, repository, and candidate dialog with `Phase736ScriptedBookMetadataProvider` (deterministic, no HTTP). Scenarios M1–M30 cover search, selection, conflicts, relink, unlink/ignore/resume, failures, item lifecycle, and persistence reload. Default CI/`flutter test` skips runtime scenarios when the gate is absent.

```powershell
cd client\ttsplayer
$env:PHASE_736_RUNTIME='1'
flutter test test/phase_736_metadata_matching_windows_runtime_test.dart --tags phase736-runtime
```

→ [Phase 7.3.6 closure](../roadmap/m7-phase-7.3.6-closure-report.md)

**Conservative auto-apply policy (Phase 7.3):**

- **Explicit ISBN refresh** → auto-persist `linkedByIdentifier`, `matchMethod.identifier`, confidence `1.0` (Phase 7.2)
- **Search candidates** → evaluate transient confidence band (including high confidence ≥ 0.85); **never silently persist**
- **User selects/confirms any search candidate** → persist `linkedManual`, `matchMethod.manual` — even when score is high-confidence
- **`linkedHighConfidence`** → reserved for a future approved automatic-match workflow; **not written** by Phase 7.3
- **Ambiguous sets** → `ambiguous` state; no provider fields applied until manual selection

→ [Phase 7.3 plan](../roadmap/m7-phase-7.3-plan.md) · [Phase 7.3.6 closure](../roadmap/m7-phase-7.3.6-closure-report.md) · [Phase 7.4 plan](../roadmap/m7-phase-7.4-plan.md) · [Phase 7.4.2 closure](../roadmap/m7-phase-7.4.2-closure-report.md) · [Phase 7.4.3 closure](../roadmap/m7-phase-7.4.3-closure-report.md) · [Phase 7.4.4 closure](../roadmap/m7-phase-7.4.4-closure-report.md) · [Phase 7.4.5 closure](../roadmap/m7-phase-7.4.5-closure-report.md)

---

## Artwork integration

### Phase 7.4.2 — Artwork reference persistence (complete)

Provider-neutral artwork **identity** is persisted on enrichment records without downloading images.

**Delivered (`f65d676`):**

- `MetadataArtworkReference` on `MetadataEnrichmentRecord` (optional `artworkReference` in envelope v1)
- `NormalizedBookMetadata.coverArtworkId` — stable provider cover ID, never a URL
- `MetadataArtworkCacheKey` — SHA-256 hex via direct `crypto: ^3.0.7` dependency
- Open Library parser: search `cover_i`, Books API `covers[0]`
- Link/relink/same-record refresh/unlink/ignore lifecycle via `BookMetadataEnrichmentMapper` and `BookMetadataMatchTransition`

**Initial link state:** `cacheState: available`, `localRelativePath: null` — identity only.

**Not in 7.4.2:** download service, disk cache, resolver, UI, HTTP, production Open Library wiring.

→ [Phase 7.4.2 closure](../roadmap/m7-phase-7.4.2-closure-report.md)

### Phase 7.4.3 — Disk cache and validation (complete)

Explicit retrieval infrastructure without UI:

- `MetadataArtworkFilesystem` — app-support cache root, relative paths, atomic temp→rename
- `MetadataArtworkCacheRepository` — `cache_index_v1.json`, lookup, LRU eviction (256 MB → 80%), orphan sweep
- `MetadataArtworkDownloadService` — explicit `download()` / `refresh()` / `lookup()` / `remove()` / `cleanup()`
- `MetadataArtworkValidator` — HTTPS, 15 s timeout, 8 MB cap, MIME + `dart:ui` decode validation
- `MetadataArtworkDownloadGenerationGuard` — stale download commit prevention
- Open Library Covers URL resolver (download time only; not persisted)

**Not in 7.4.3:** resolver, UI, coordinator wiring, automatic downloads, production HTTP in CI.

→ [Phase 7.4.3 closure](../roadmap/m7-phase-7.4.3-closure-report.md)

### Phase 7.4.4 — Central resolver and precedence (complete)

**`MetadataArtworkResolver`** (Option A — composes `ArtworkService`):

- Local precedence unchanged: thumbnail → sidecar → folder → placeholder probe via `ArtworkService`
- Provider cache inserted before placeholder when linked book + valid cache entry
- `ArtworkSource.providerCache` for validated cache files
- `MetadataArtworkCacheRepository.peekLookup()` — no index write on resolution rebuild
- Stale entries remain displayable with `isStale: true`
- No HTTP, download, or provider URL construction

→ [Phase 7.4.4 closure](../roadmap/m7-phase-7.4.4-closure-report.md)

### Phase 7.4.5 — Book metadata artwork workflow (complete)

**`BookMetadataArtworkCoordinator`** orchestrates explicit download/refresh:

- Composes `MetadataArtworkDownloadService`, `MetadataEnrichmentRepository`, generation guard
- Merges **artwork fields only** after successful cache write
- Already-cached download: zero HTTP, skip enrichment rewrite when unchanged
- Refresh failure: prior cache retained (`BookMetadataArtworkPriorCacheRetained`)
- Item-scoped generation invalidation on relink/unlink/item change
- Duplicate operation coalescing per cache key

**`BookMetadataEnrichmentSection`** exposes Download/Refresh controls and bounded status labels via `MetadataArtworkPresentation`. No item-detail or browse-card wiring (7.4.6).

→ [Phase 7.4.5 closure](../roadmap/m7-phase-7.4.5-closure-report.md)

### Planned artwork presentation (7.4.6)

Extends [ArtworkService](./decisions/ADR-015-artwork-and-image-decode-caching.md) with an additional candidate source **after** sidecars, **before** placeholder:

| Priority | Source |
|---|---|
| 1 | User lock → local file path |
| 2 | Sidecar (existing) |
| 3 | Embedded (future) |
| 4 | Provider cache file on disk |
| 5 | Placeholder |

Provider URLs are never passed directly to widgets — download worker writes to quota-bounded cache first.

---

## Security and privacy

- Master opt-in default **off**
- **Credential storage:** requires an OS-backed secure-storage mechanism. Windows options (Credential Manager, DPAPI-backed storage) must be evaluated during implementation — not decided in Phase 7.0. Application-managed reversible encryption is not an acceptable fallback without a separately approved key-protection design. **Until secure storage is available, provider credentials must not be persisted.** Credentials are redacted in diagnostics ([ADR-017](./decisions/ADR-017-diagnostics-architecture.md), [ADR-019](./decisions/ADR-019-diagnostics-export-support-strategy.md))
- **Provider query inputs (Open Library):** explicit ISBN, normalized title, author, and optional year only — never full paths, filenames, or file stems
- **Local-only comparison:** filename stem may be used locally as a weak title fallback signal during candidate evaluation; derived text is never transmitted to the provider
- Matching queries use normalized titles and basenames — not full paths
- Export bundle includes enrichment **counts and states** only

---

## Backend relationship (deferred)

Optional future: indexer writes `enrichment.json` companion keyed by item id during `--library-path` rescan. Clients merge identically to client-fetched enrichment. **Not M7 required path** — see [ADR-028](./decisions/ADR-028-external-metadata-enrichment-boundary.md).

---

## Related documents

- [M7 plan](../roadmap/m7-plan.md)
- [ADR-028](./decisions/ADR-028-external-metadata-enrichment-boundary.md)
- [ADR-029](./decisions/ADR-029-metadata-precedence-provenance-and-matching.md)
