# M3.5 Path Mapping — Canonical Specification

**Status:** Approved  
**Cycle:** `v0.4.0-dev`  
**Applies to:** HTTP serving layer (Caddy) and `HttpServingProvider` inside [MediaLocationResolver](./media-access-abstraction.md)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [TNAS deployment guide](../deployment/tnas-serving-layer.md)  
→ [M3.5 goals](../roadmap/network-client-foundation.md)

---

## Media roots

These three prefixes refer to the **same logical media library**. `HttpServingProvider` (see [media access abstraction](./media-access-abstraction.md)) must recognise all of them when stripping paths.

| Environment | Root prefix |
|---|---|
| Windows (mapped drive) | `Y:\Media` |
| Windows (UNC) | `\\MEDIATNAS-B725\Media` |
| TNAS filesystem | `/volume1/Media` |

Catalogue `file_path` values are absolute paths under one of these roots, as emitted by `indexer.py` at scan time.

---

## HTTP routes

| Resource | URL | TNAS filesystem path |
|---|---|---|
| Catalogue | `https://<nas-host>/catalog.json` | `/volume1/Media/catalog.json` |
| Scan history (optional) | `https://<nas-host>/scan.history.json` | `/volume1/Media/scan.history.json` |
| Media files | `https://<nas-host>/media/<relative-path>` | `/volume1/Media/<relative-path>` |

**Important:** The HTTP media route is `https://<nas-host>/media/` — there is **no** extra `/Media/` segment after `/media/`.

---

## Mapping rule

Given a catalogue `file_path` and configured NAS host:

1. **Strip** the matching media root prefix (`Y:\Media`, UNC root, or `/volume1/Media`).
2. **Normalise** the remaining relative path to forward slashes (`/`).
3. **URL-encode** each path segment individually (preserve `/` separators).
4. **Append** the result to `https://<nas-host>/media/`.

The indexer catalogue schema is **unchanged** — resolution happens in the serving layer contract and the client resolver only.

---

## Examples

### Windows local path

```
file_path:  Y:\Media\Videos\movie.mp4
relative:   Videos/movie.mp4
stream URL: https://<nas-host>/media/Videos/movie.mp4
```

### UNC path

```
file_path:  \\MEDIATNAS-B725\Media\Videos\movie.mp4
relative:   Videos/movie.mp4
stream URL: https://<nas-host>/media/Videos/movie.mp4
```

### TNAS path (indexer run on NAS)

```
file_path:  /volume1/Media/Videos/movie.mp4
relative:   Videos/movie.mp4
stream URL: https://<nas-host>/media/Videos/movie.mp4
```

### Path with spaces

```
file_path:  Y:\Media\Home Videos\My Movie.mp4
relative:   Home Videos/My Movie.mp4
stream URL: https://<nas-host>/media/Home%20Videos/My%20Movie.mp4
```

### Nested folder

```
file_path:  Y:\Media\Videos\Action\title.mp4
stream URL: https://<nas-host>/media/Videos/Action/title.mp4
```

---

## Caddy filesystem layout

Caddy serves `/media/*` from **`/volume1/Media`** using `handle_path`, which strips the `/media` URL prefix before resolving files:

```
GET /media/Videos/movie.mp4
  → file: /volume1/Media/Videos/movie.mp4
```

```
GET /catalog.json
  → file: /volume1/Media/catalog.json
```

See `backend/caddy.config`.

---

## Supported extensions

Media URLs must use extensions indexed by the scanner (`backend/indexer.py`):

| Type | Extensions |
|---|---|
| Video | `.mp4`, `.mkv`, `.mov`, `.m4v`, `.avi` |
| Image | `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.tif`, `.tiff` |

Caddy blocks requests for other extensions under `/media/*`. Keep Caddy and indexer lists in sync when either changes.

---

## Artwork and sidecars

Sidecar images beside video files (e.g. `poster.jpg`, stem-matched `.jpg`) use the **same mapping rule** as media files when resolved for HTTP artwork loading:

```
Y:\Media\Videos\poster.jpg
  → https://<nas-host>/media/Videos/poster.jpg
```

Sidecar files excluded from catalogue item listings remain valid artwork URLs when present on disk.

---

## Client resolver (Phase 3a + 3b complete)

Implemented as `HttpServingProvider` behind [MediaLocationResolver](./media-access-abstraction.md). Wired into playback and artwork at consumption boundaries. Must:

- Accept configurable `nasHost` (e.g. `https://mediatnas.local`)
- Try all three root prefixes when stripping `file_path`
- Be case-insensitive when matching Windows drive/UNC prefixes
- Leave paths that are already `http://` or `https://` unchanged
- Use the same segment encoding rules as this document

Desktop local/UNC playback **without** HTTP resolution remains unchanged.

---

## Verification

Run the smoke tests in [TNAS serving layer deployment](../deployment/tnas-serving-layer.md) after every Caddy config change.

Minimum checks:

1. `GET /catalog.json` returns 200 JSON
2. `GET /media/Videos/<known-file>.mp4` returns 200
3. `GET /media/Videos/<known-file>.mp4` with `Range: bytes=0-1023` returns **206 Partial Content**

---

## References

| File | Purpose |
|---|---|
| `backend/caddy.config` | HTTPS static file server |
| `backend/indexer.py` | `SUPPORTED_EXTENSIONS` source of truth |
| `ttsplayer.config.json` | Dev Windows roots (`Y:\Media`, UNC) |
