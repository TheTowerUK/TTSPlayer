# ADR-018: Runtime Snapshot Model

**Status:** Proposed  
**Date:** 2026-07-16  
**Milestone:** M4 Phase 4.6  
**Authors:** M4 documentation pass

---

## Context

Phase 4.6 must expose heterogeneous runtime state — provider health, catalogue counts, cache bounds, search index lifecycle, playback capabilities — in a single read-only UI and export bundle.

Without a formal snapshot model, widgets would assemble ad hoc maps, export formats would drift from on-screen content, and redaction rules would scatter across the presentation layer.

ADR-017 assigns aggregation to `DiagnosticsService`. This ADR defines the **immutable DTO contract** that service produces.

---

## Decision

### 1. Root type: `RuntimeDiagnosticsSnapshot`

Immutable value object with:

| Field | Type | Notes |
|---|---|---|
| `capturedAt` | `DateTime` | UTC ISO-8601 in export |
| `application` | `ApplicationDiagnostics` | Required |
| `provider` | `ProviderDiagnostics` | Required; degraded when catalogue null |
| `catalogue` | `CatalogueDiagnostics?` | Null when no catalogue loaded |
| `cache` | `CacheDiagnostics` | Required |
| `search` | `SearchDiagnostics` | Required |
| `playback` | `PlaybackDiagnostics` | Required |
| `library` | `LibraryDiagnostics?` | Null when metadata repo unavailable |

Factory: `DiagnosticsService.buildSnapshot()` — no persistence, no streaming updates. UI may rebuild on navigation or manual refresh.

### 2. Section DTOs and field contracts

#### `ApplicationDiagnostics`

| Field | Source | Redaction |
|---|---|---|
| `appVersion` | `package_info.version` | None |
| `buildNumber` | `package_info.buildNumber` | None |
| `platform` | `Platform.operatingSystem` | None |
| `startupElapsed` | Bootstrap timestamp delta | Duration string |

#### `ProviderDiagnostics`

| Field | Source | Redaction |
|---|---|---|
| `accessMode` | `MediaAccessConfig.mode` | Label enum |
| `activeProviderKind` | local / https | No paths |
| `activeProviderHost` | HTTPS host only | No path, query, credentials |
| `providers` | `CatalogueProviderSnapshot.providers` | Per row: kind, health, one-line `lastError` |
| `lastRefreshAt` | `CatalogService.lastRefreshedAt` | ISO timestamp |
| `lastSuccessfulLoadAt` | `CatalogService.lastCatalogueLoadAt` | ISO timestamp |
| `isUsingFallback` | `CatalogService.isUsingFallback` | Bool |
| `isDegradedLoad` | `CatalogService.isDegradedLoad` | Bool |

#### `CatalogueDiagnostics`

| Field | Source | Redaction |
|---|---|---|
| `catalogueIdentity` | `Catalog.catalogueIdentity` | Truncate to 12 chars + ellipsis |
| `sourceKind` | demo / live / degraded classification | Label |
| `folderCount` | Derived from `Catalog` | Count |
| `itemCount` | `Catalog.totalItems` | Count |
| `isLoading` | `CatalogService.isLoading` | Bool |
| `lastError` | `CatalogService.errorMessage` | User-readable text |

**Never include:** `root_path`, `file_path`, full HTTPS URLs, UNC paths.

#### `CacheDiagnostics`

| Field | Source |
|---|---|
| `artworkCandidateCount` | `ArtworkService.cacheEntryCount` |
| `artworkCandidateCapacity` | `ArtworkService.defaultCacheCapacity` (500) |
| `artworkEvictionCount` | `ArtworkService.cacheEvictionCount` |
| `imageCacheBudgetBytes` | `PaintingBinding.instance.imageCache.maximumSizeBytes` |
| `imageCacheCurrentBytes` | `PaintingBinding.instance.imageCache.currentSizeBytes` |

#### `SearchDiagnostics`

| Field | Source |
|---|---|
| `hasIndex` | `SearchService.hasIndex` |
| `catalogueIdentity` | `SearchService.catalogueIdentity` (truncated) |
| `indexedItemCount` | `SearchService.indexedItemCount` |
| `indexBuildCount` | `SearchService.indexBuildCount` |
| `isBuildInFlight` | `SearchService.isBuildInFlight` |

#### `PlaybackDiagnostics`

| Field | Source | Redaction |
|---|---|---|
| `engine` | `useMediaKitPlayback` | `media_kit` / `video_player` |
| `speedSettingsSupported` | `playbackSpeedSettingsSupported` | Bool |
| `hasActiveSession` | `PlaybackService.currentItem != null` | Bool |
| `sessionItemId` | `currentItem.id` | Id only |
| `sessionItemTitle` | `currentItem.title` | Display title |
| `errorKind` | `PlaybackErrorKind?` | Taxonomy label |
| `errorMessage` | User-readable | No stack traces |
| `isPlaying` | `PlaybackService.isPlaying` | Bool |
| `isInitializing` | `PlaybackService.isInitializing` | Bool |

#### `LibraryDiagnostics`

| Field | Source |
|---|---|
| `favouriteItemCount` | `LibraryMetadataRepository` |
| `favouriteFolderCount` | same |
| `metadataVersion` | settings envelope version if exposed |

### 3. Serialization

- **In-app:** Dart objects only; no JSON persistence in 4.6 v1.
- **Export:** Plain-text sections with stable `=== Section ===` headings (ADR-019).
- **Tests:** Golden or prefix assertions on `formatExport()` output.

### 4. Redaction helpers

Centralize in `DiagnosticsService` or `diagnostics_redaction.dart`:

- Truncate catalogue/search identities
- Strip path-like substrings from error messages if they slip through
- Omit `file_path` fields entirely at mapping time — never read from `MediaItem`

---

## Rationale

- Immutable DTOs make widget tests and export tests deterministic.
- Explicit per-field redaction table prevents accidental path leakage during implementation.
- Nullable `catalogue` and `library` sections model graceful degradation when load failed.
- Reusing Phase 4.5 getter names (`indexBuildCount`, `cacheEntryCount`) keeps test and UI vocabulary aligned.

---

## Consequences

### Positive

- One schema serves UI, clipboard, and file export.
- New diagnostic fields add one DTO field + one mapper — predictable extension point.

### Negative

- Snapshot is point-in-time; rapidly changing playback state may appear stale until refresh.
- Wide DTO surface requires maintenance when services evolve.

### Neutral

- No versioning field on snapshot in 4.6 v1; export includes app version for support correlation.

---

## Alternatives considered

| Alternative | Rejected because |
|---|---|
| `Map<String, dynamic>` snapshot | No compile-time field contracts; weak redaction |
| JSON as primary in-app model | Unnecessary parsing; plain text export is primary |
| Include full `Catalog` tree | Path leakage risk; oversized export |
| Real-time `Stream` of diagnostics | Over-engineering for support use case |

---

## Related documents

- [ADR-017](./ADR-017-diagnostics-architecture.md)
- [ADR-019](./ADR-019-diagnostics-export-support-strategy.md)
- [M4 Phase 4.6 specification](../../roadmap/m4-phase-4.6-diagnostics-supportability.md)
- [item-status-model.md](../../../.cursor/rules/item-status-model.mdc) — status values not duplicated in diagnostics v1
