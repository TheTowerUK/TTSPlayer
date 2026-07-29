# Metadata Enrichment Architecture

**Status:** Planning (M7 Phase 7.0)
**Milestone:** M7 — Metadata Enrichment and Library Experience
**Related ADRs:** [ADR-028](./decisions/ADR-028-external-metadata-enrichment-boundary.md) (Proposed), [ADR-029](./decisions/ADR-029-metadata-precedence-provenance-and-matching.md) (Proposed)

→ [M7 plan](../roadmap/m7-plan.md)
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

**Key:** `ttsplayer_metadata_enrichment_v1` (SharedPreferences or successor SQLite — decision in Phase 7.1)

**Record key:** catalogue item `id`

| Field group | Examples |
|---|---|
| Linkage | `providerId`, `providerRecordId`, `matchMethod`, `confidence` |
| Lifecycle | `fetchedAt`, `expiresAt`, `lastError`, `ignored` |
| Locks | `lockedFields[]` — refresh skips these |
| Payload | Normalized `fields` map with per-field provenance |

### Catalogue replacement coordination

On `CatalogCacheCoordinator` catalogue replace (existing ADR-014 pattern):

1. Load new catalogue ids
2. Prune enrichment records whose `itemId` absent
3. Do **not** block catalogue load on enrichment I/O failure
4. Invalidate artwork decode cache; optionally prune provider artwork disk cache for removed ids

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

## Provider abstraction (Phase 7.2)

```dart
// Illustrative — not implemented
abstract class MetadataProvider {
  String get id;
  Set<MediaKind> get supportedKinds;
  Future<ProviderSearchResult> search(MatchQuery query, {CancelToken? cancel});
  Future<EnrichmentPayload?> fetchRecord(String providerRecordId, {CancelToken? cancel});
}
```

- One interface; per-provider adapters
- Fake implementations for unit/integration tests
- No live network in default `flutter test` CI

---

## Artwork integration

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
