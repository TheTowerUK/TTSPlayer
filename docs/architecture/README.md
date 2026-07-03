# Architecture

System design notes for TTSPlayer — scanner, catalogue schema, client services, and platform boundaries.

## Principles

- **Filesystem is truth** — the folder tree is never invented, merged, or renamed by the app.
- **Folder-first catalogue** — `catalog.json` mirrors the real directory structure.
- **Atomic writes** — failed scans never corrupt a working catalogue.
- **Local-first** — the app functions offline against a local or NAS path.

## Key components

| Component | Location | Role |
|---|---|---|
| Indexer | `backend/indexer.py` | Crawls media roots → `catalog.json` |
| Catalogue model | `client/ttsplayer/lib/models/` | Parses folder tree, items, scan metadata |
| CatalogService | `client/ttsplayer/lib/services/catalog_service.dart` | Loads and reloads catalogue |
| ScannerService | `client/ttsplayer/lib/services/scanner_service.dart` | Runs indexer subprocess |
| PlaybackService | `client/ttsplayer/lib/services/playback_service.dart` | Windows: media_kit; other: video_player |

Detailed architecture documents will be added here as the system grows.
