# Architecture

System design notes for TTSPlayer — scanner, catalogue schema, client services, and platform boundaries.

## Principles

- **Filesystem is truth** — the folder tree is never invented, merged, or renamed by the app.
- **Folder-first catalogue** — `catalog.json` mirrors the real directory structure.
- **Atomic writes** — failed scans never corrupt a working catalogue.
- **Local-first** — the app functions offline against a local or NAS path.
- **Storage-backend neutral** — playback uses [MediaLocationResolver](./media-access-abstraction.md), not raw catalogue paths.

## M3.5 foundation (complete)

| Document | Status |
|---|---|
| [Path mapping](./path-mapping.md) | Accepted — HTTP serving layer rules |
| [Media access abstraction](./media-access-abstraction.md) | Accepted — provider-neutral playable URI model |

## M4 planning (complete)

Planning and implementation documents for [M4 — User Experience and Platform Integration](../roadmap/m4-plan.md). All M4 architecture domains are **Implemented / Accepted**.

| Document | Phase | Status |
|---|---|---|
| [Provider management](./provider-management.md) | 4.1 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.1-provider-management.md) |
| [Settings](./settings.md) | 4.2 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.2-settings-framework.md) |
| [Library experience](./library.md) | 4.3 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.3-library-experience.md) |
| [Playback](./playback.md) | 4.4 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.4-playback-improvements.md) · ADR-010–013 |
| [Caching](./caching.md) | 4.5 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.5-performance-caching.md) · ADR-014–016 |
| [Diagnostics](./diagnostics.md) | 4.6 | **Implemented / Accepted** — [spec](../roadmap/m4-phase-4.6-diagnostics-supportability.md) · ADR-017–019 |

## M5 planning (active)

Planning document for [M5 — Music](../roadmap/m5-plan.md). **Not implemented.**

| Document | Phase | Status |
|---|---|---|
| [Music](./music.md) | 5.0 ✅ / 5.1 next | **Planned / Proposed** — [M5 plan](../roadmap/m5-plan.md) · ADR-020–023 **Proposed** |

## Architecture Decision Records

Significant cross-layer decisions are recorded as ADRs:

→ [ADR framework](./decisions/README.md) · [Template](./decisions/ADR-template.md) · [ADR index](./decisions/README.md#index)

## Key components

| Component | Location | Role |
|---|---|---|
| Indexer | `backend/indexer.py` | Crawls media roots → `catalog.json` |
| Catalogue model | `client/ttsplayer/lib/models/` | Parses folder tree, items, scan metadata |
| CatalogService | `client/ttsplayer/lib/services/catalog_service.dart` | Loads catalogue; HTTP and local providers; fallback |
| MediaProviderConfigService | `client/ttsplayer/lib/services/media_access/` | Persisted provider configuration (M3.5; dual-write transition in 4.2) |
| SettingsRepository | `client/ttsplayer/lib/services/settings/` | Versioned settings envelope (M4.2) |
| LibraryMetadataRepository | `client/ttsplayer/lib/services/library/` | Versioned user library metadata (M4.3 Step 1) |
| MediaLocationResolver | `client/ttsplayer/lib/services/media_access/` | Resolves catalogue paths → playable URI |
| Caddy config | `backend/caddy.config` | HTTPS static file server (M3.5 reference) |
| ScannerService | `client/ttsplayer/lib/services/scanner_service.dart` | Runs indexer subprocess |
| PlaybackService | `client/ttsplayer/lib/services/playback_service.dart` | Windows: media_kit; other: video_player; uses resolver |
| ArtworkService | `client/ttsplayer/lib/services/artwork/` | Sidecar and placeholder artwork; bounded cache (4.5) |
| SearchService | `client/ttsplayer/lib/features/search/` | In-memory search index (4.5 lifecycle) |
| DiagnosticsService | `client/ttsplayer/lib/services/diagnostics/` | Read-only runtime snapshot aggregation (Step 2) |
