# TTSPlayer

A lightweight, local-first home media platform.  
Scan local and NAS-based folders, browse by folder structure, and play video with stable, reliable playback.

---

## Architecture Overview

```
TTSPlayer/
├── .cursor/rules/               # AI guardrails — always enforced
├── backend/
│   ├── indexer.py               # Folder-tree crawler → catalog.json
│   ├── Dockerfile               # Containerised indexer for TNAS
│   └── caddy.config             # Reverse proxy for remote access
├── assets/
│   ├── mock_data/catalog.json   # Offline-safe mock catalog
│   └── branding/                # App icons and colour tokens
└── client/ttsplayer/            # Flutter project
    ├── pubspec.yaml
    ├── assets/catalog.json      # Bundled mock (copied from mock_data)
    └── lib/
        ├── main.dart
        ├── models/              # Catalog, MediaFolder, MediaItem
        ├── services/            # CatalogService, PlaybackService
        ├── screens/             # HomeScreen, FolderScreen, PlayerScreen
        └── widgets/             # MediaCard
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Client | Flutter / Dart |
| Video playback | `video_player` (official Flutter package) |
| State management | `provider` + `ChangeNotifier` |
| Playback position | `shared_preferences` |
| Remote catalog fetch | `http` |
| Backend scanner | Python 3.12 (standard library only) |
| Reverse proxy | Caddy |
| Dev environment | Windows + Cursor IDE |

---

## Getting Started

### 1. Run the Flutter app

```powershell
cd client/ttsplayer
flutter pub get
flutter run -d windows     # or -d android, -d chrome
```

The app launches with the bundled mock catalog so it works immediately without a TNAS.

### 2. Point at a real catalog

Inside the app, tap the **folder icon** in the top bar and enter either:

- A **local path**: `D:\Media\catalog.json`
- A **remote URL**: `https://your-nas.example.com/catalog.json`

### 3. Generate a catalog from your media library

```bash
# On the TNAS or a local machine with Python 3.12+
python backend/indexer.py \
  --root /volume1/media \
  --output /volume1/media/catalog.json
```

Or with Docker:

```bash
docker build -t ttsplayer-backend ./backend
docker run --rm -v /volume1/media:/media ttsplayer-backend \
  --root /media --output /media/catalog.json
```

### 4. Serve remotely (optional)

Edit `backend/caddy.config` — replace `<YOUR_DOMAIN>` — then:

```bash
caddy run --config backend/caddy.config
```

---

## Catalog JSON Schema

The indexer mirrors the real filesystem. Folder names are the categories.

```json
{
  "generated_at": "ISO-8601",
  "scanner_version": "1.0",
  "root_path": "/volume1/media",
  "total_items": 42,
  "folders": [
    {
      "id": "md5-of-path",
      "name": "Movies",
      "path": "/volume1/media/Movies",
      "item_count": 10,
      "items": [
        {
          "id": "md5-of-file-path",
          "title": "The Grand Adventure",
          "year": 2023,
          "duration_seconds": 6840,
          "file_path": "/volume1/media/Movies/the_grand_adventure.mp4",
          "thumbnail_path": null,
          "size_bytes": 4831838208
        }
      ],
      "subfolders": []
    }
  ]
}
```

---

## MVP Scope (v1)

- [x] Video files: `.mp4 .mkv .mov .m4v .avi`
- [x] Folder-based browsing — folder name is the category
- [x] Subfolder navigation
- [x] Rescan on demand (re-fetches catalog.json)
- [x] Playback position memory (per item, via `shared_preferences`)
- [ ] Basic folder access restrictions *(in progress)*
- [ ] Thumbnail generation

## Roadmap (v2+)

- Music support
- Books and comics
- Image galleries
- Podcasts and audiobooks
- SQLite catalog backend (replaces flat JSON for large libraries)
- Thumbnail generation pipeline in `indexer.py`

---

## Design Principles

- **Folder-first** — the user's own folder structure is the source of truth.
- **Zero bloat** — no Plex/Jellyfin-style background daemons, no transcoding, no metadata scrapers unless asked.
- **Local-first** — works entirely offline against a local path or NAS mount.
- **Cross-platform** — Flutter targets Android, Windows, and future Apple platforms from one codebase.
