# M7 Phase 7.4.4 — Central Resolver and Artwork Precedence

**Status:** Complete (2026-08-03) — uncommitted for review
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.4.3 closure](./m7-phase-7.4.3-closure-report.md)
**Implementation commit:** pending review

→ [M7 plan](./m7-plan.md) · [Phase 7.4 plan](./m7-phase-7.4-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.4.4 | `f1e2b12` — `docs(m7.4): close Phase 7.4.3 disk cache and validation` |
| Phase 7.4.3 implementation | `7cb9950` |
| Phase 7.4.3 documentation | `f1e2b12` |
| Working tree before 7.4.4 | Clean |
| Divergence vs `origin/m6-development` | `0 25` |
| `.git/objects` write issue | Not observed during this phase |

---

## Objective

One authoritative artwork resolver combining trusted local sources with eligible cached provider artwork — policy only, no UI, no downloads, no provider URLs.

---

## Composition model (Option A — selected)

**`MetadataArtworkResolver` composes `ArtworkService`.**

| Rationale | Detail |
|---|---|
| Separation of concerns | `ArtworkService` stays local filesystem probes + LRU only |
| Metadata boundary | Enrichment eligibility and cache peek live in resolver |
| No HTTP | Download service never invoked by resolver |
| ADR-015 preserved | Path-probe LRU unchanged |

Option B (making `ArtworkService` the resolver) rejected — would pull enrichment/cache dependencies into a formerly local-only service.

---

## Final precedence order

Matches existing `ArtworkService` local order + provider cache before placeholder:

| Priority | Source | Status |
|---|---|---|
| 1 | User-selected override | Reserved — no picker |
| 2 | Catalogue thumbnail (`thumbnail_path`) | Implemented |
| 3 | Local sidecar (stem + named sidecars) | Implemented |
| 4 | Folder artwork | Implemented |
| 5 | Embedded artwork | Reserved future slot |
| 6 | Cached provider artwork (linked + valid cache) | **7.4.4** |
| 7 | Placeholder | Implemented |

**Invariant:** Every trusted local source beats provider cache.

---

## Source model changes

Extended `ArtworkSource` with `providerCache` (provider-neutral).

New types:

- `MetadataArtworkResolution` — immutable resolution result
- `MetadataArtworkIneligibilityReason` — bounded fallback reasons
- `MetadataArtworkResolver` — central policy

---

## Provider-cache eligibility

All must hold:

1. `MediaKind.book`
2. Enrichment record for `item.id`
3. Provider-linked state (`BookMetadataMatchTransition.isProviderLinked`)
4. Not `ignored`
5. Artwork reference present and aligned with record provider IDs
6. Cache entry exists for reference `cacheKey`
7. Entry identity matches reference and record
8. Displayable cache state (`downloaded` or `stale`)
9. File exists within owned cache root (via `peekLookup`)

---

## Stale artwork policy

| State | Resolver behaviour |
|---|---|
| `downloaded` | Eligible; `isStale: false` |
| `stale` | Eligible; `isStale: true` — still displayable offline |
| `available` | Ineligible (no validated file) |
| `failed` / `unavailable` | Ineligible |

Stale is not treated as missing or corrupt. No refresh initiated.

---

## Cache access policy

Added `MetadataArtworkCacheRepository.peekLookup()` — read-only, **no** `lastAccessedAt` update, **no** index persist on ordinary resolution.

Existing `lookup()` still touches access time for explicit access (e.g. post-download). Resolver uses `peekLookup` only.

---

## Lifecycle behaviour

| Event | Resolver |
|---|---|
| Link + cache | Provider cache eligible |
| Link + reference only | Falls back to placeholder |
| Relink | Old identity ineligible; new matching cache eligible |
| Same-record | Same cache key remains eligible |
| Unlink / ignore | Provider cache ineligible; file may remain on disk |
| Resume | No automatic eligibility without link |

---

## Files changed (uncommitted)

**New (lib):**

- `artwork/metadata_artwork_resolution.dart`
- `artwork/metadata_artwork_resolver.dart`

**Modified (lib):**

- `services/artwork/artwork_kind.dart` — `ArtworkSource.providerCache`
- `artwork/metadata_artwork_cache_repository.dart` — `peekLookup()`

**New (test):**

- `test/metadata_artwork_resolver_test.dart` (26 cases)

**Presentation surfaces:** unchanged — still call `ArtworkService` directly (7.4.6 wiring deferred).

---

## Tests

| Suite | Result |
|---|---|
| New resolver tests | 26 passed |
| ArtworkService | Green |
| Phase 7.4.2 / 7.4.3 | Green |
| Full `flutter test` | **1715 passed, 20 skipped, 0 failed** |

HTTP invocation count: **0** (resolver has no HTTP client).
Download-service invocation count: **0**.

Concurrent isolation: `concurrent resolutions do not cross-link cache entries` — three `Future.wait` iterations with swapped `peekLookup` delays; asserts per-item cache key/path, zero `lookup()` calls, zero HTTP/download invocations.

---

## Known limitations

- Widgets not wired to resolver yet (7.4.6)
- User override and embedded slots reserved only
- `peekLookup` still removes missing-file metadata (persist once) — not on every resolution rebuild
- Production Open Library not wired in `main.dart`

---

## ADR status

- **ADR-029:** Proposed (unchanged)
- **ADR-015:** Accepted (unchanged)
- No new ADR required

---

## Next task

**Phase 7.4.5 — Book metadata workflow integration:** wire download/refresh actions, persist reference updates after download, lifecycle tests with coordinator — still no browse-card wiring.

→ [Phase 7.4 plan](./m7-phase-7.4-plan.md)
