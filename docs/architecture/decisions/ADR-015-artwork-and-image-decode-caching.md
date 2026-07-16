# ADR-015: Artwork and Image Decode Caching

**Status:** Accepted — implemented (M4 Phase 4.5 closure 2026-07-16)
**Milestone:** M4 Phase 4.5  
**Authors:** M4 documentation pass

---

## Context

`ArtworkService` resolves thumbnail → sidecar → folder art → placeholder using **synchronous** filesystem probes cached in an **unbounded** `Map`. `ArtworkImage` decodes full-resolution files via `Image.file` / `Image.network` with no `cacheWidth` / `cacheHeight`.

At library scale this causes:

- Growing memory from candidate cache entries
- UI thread work when many cards scroll into view
- Decode memory spikes when sidecars are large poster images

Phase 4.3 unified artwork across dashboard, folder, search, and detail. Phase 4.5 improves efficiency without changing resolution precedence or catalogue mutation rules.

---

## Decision

1. **Candidate cache (ArtworkService)** — bounded **LRU** keyed by existing entity keys (`library:`, `folder:`, `media:`). Default cap: **500** entries (configurable constant for tests).

2. **Invalidation** — `clearCache()` on catalogue revision per [ADR-014](./ADR-014-catalogue-revision-cache-invalidation.md). LRU reset on clear.

3. **Filesystem probes** — may remain synchronous for 4.5 if bounded by lazy grid build; implementation may batch or memoize negative results within the LRU entry. Must not scan entire directories off-screen at dashboard startup.

4. **Image decode (ArtworkImage)** — pass `cacheWidth` and `cacheHeight` derived from layout constraints (rounded to device pixel ratio). Network and file paths both use constraints.

5. **Flutter ImageCache budget** — set `PaintingBinding.instance.imageCache.maximumSizeBytes` at app start for desktop (default target: **100 MB**). Document in architecture; tune constant in implementation.

6. **No disk thumbnail store** in 4.5. No new dependencies.

7. **Placeholder and error paths** unchanged — `errorBuilder` → `MediaPlaceholder`; missing files never hide items.

8. **Flutter `ImageCache` is not cleared on catalogue replacement** — only the app-owned `ArtworkService` candidate cache is cleared. Pixel cache eviction remains framework-managed within the 100 MB budget.

---

## Rationale

- Separates **path resolution cache** (ArtworkService) from **pixel cache** (Flutter ImageCache).
- Decode sizing gives largest win for poster sidecars without NAS thumbnail generation.
- LRU cap bounds worst-case session memory while remaining simple.

---

## Consequences

### Positive

- Predictable memory ceiling for artwork path.
- Smoother scroll in large folders.

### Negative

- LRU eviction may re-probe filesystem for scrolled-away rows — acceptable vs unbounded growth.

### Neutral

- Phase 4.6 cache health can expose candidate count and ImageCache byte usage.
- **Implementation (Step 3):** `LruCache` capacity 500; `ArtworkDecodeSize` / surface presets; coordinator invalidation unchanged.

---

## Implementation

| Aspect | Detail |
|---|---|
| **Cache owner** | `ArtworkService` |
| **Capacity** | 500 entries (production default) |
| **LRU policy** | Evict LRU on insert at capacity; access promotes |
| **Key identity** | Entity-scoped prefixes — not filename |
| **Decode sizing** | Logical surface size × DPR → `cacheWidth` / `cacheHeight` |
| **Flutter budget** | 100 MB via `configureArtworkFlutterImageCache()`; not cleared on catalogue replace |
| **Invalidation** | `clearCache()` via `CatalogCacheCoordinator` (ADR-014) — candidate cache only |
| **Limitations** | No disk cache; placeholder entries cached; no negative decode cache; exact RAM savings not measured |

Tests: `lru_cache_test.dart`, `artwork_service_lru_test.dart`, `artwork_decode_size_test.dart`, `artwork_image_test.dart`. Step 6 integration/benchmarks; Step 7 runtime R11–R12 (`phase_45_windows_runtime_test.dart`).

---

## Alternatives considered

### Alternative A — Disk-backed thumbnail cache

**Rejected because:** Invalidation, NAS path mapping, and deployment complexity exceed 4.5 scope.

### Alternative B — Async `exists` with `Isolate`

**Rejected for 4.5 unless profiling proves sync probes block frames — defer unless baseline audit shows need.

### Alternative D — Global Flutter `ImageCache.clear()` on catalogue replacement

**Rejected because:** Forces full decode re-fetch across all surfaces; unrelated to catalogue revision; harms scroll performance after rescan.

### Alternative E — Claim exact RAM savings from decode hints

**Rejected because:** Decode sizing bounds architectural risk; per-session RAM varies by content and DPR — report informational benchmarks only.

### Alternative F — Skip candidate cache entirely; only ImageCache sizing

**Rejected because:** Repeated sidecar path probes per scroll still waste UI time.

---

## Related documents

- [ADR-014: Catalogue Revision Cache Invalidation](./ADR-014-catalogue-revision-cache-invalidation.md)
- [caching.md](../caching.md)
- [library.md](../library.md)
- [M4 Phase 4.5 specification](../../roadmap/m4-phase-4.5-performance-caching.md)
