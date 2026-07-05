# M3.5 Phase 3 — MediaLocationResolver Implementation Plan

**Status:** Phase 3a complete — awaiting Phase 3b wiring approval  
**Accepted:** Phase 2.5 — 2026-07-05  
**Cycle:** `v0.4.0-dev`

→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Phase status](../deployment/m35-phase-status.md)

---

## Gate

**Phase 2.5 accepted** — Flutter resolver may be implemented. Scope is **limited to `MediaLocationResolver` and unit tests** in this phase. Do not wire `PlaybackService`, `CatalogService` HTTP startup, or mobile settings yet.

**Phase 2** (TNAS + Caddy smoke tests) continues in parallel as optional HTTP reference validation.

---

## Objective

Implement the provider-neutral resolver defined in [media-access-abstraction.md](../architecture/media-access-abstraction.md):

```
Catalogue file_path  →  MediaLocationResolver  →  ResolvedMediaLocation
```

---

## In scope (Phase 3a)

| Item | Detail |
|---|---|
| Provider types | `MediaAccessProviderType`, `MediaLocationResolveStatus` |
| Result type | `ResolvedMediaLocation` with `uri`, status, error reason |
| Config | Media roots, optional HTTP base URL, access mode |
| Local provider | Drive letter, UNC, absolute Windows paths → `file://` on desktop |
| HTTP provider | Strip root, segment-encode, append to `/media/` base — [path-mapping.md](../architecture/path-mapping.md) |
| Pass-through | Existing `http://` / `https://` paths |
| Unresolved states | Missing HTTP config on non-desktop, unknown root for HTTP, empty path |
| Unit tests | Path stripping, URL encoding, provider selection matrix |

---

## Out of scope (Phase 3a)

| Item | Deferred |
|---|---|
| `PlaybackService.play()` wiring | Phase 3b |
| `ArtworkService` wiring | Phase 3b |
| `CatalogService` HTTP startup / rescan | Phase 4 |
| Mobile settings UI | Phase 4 |
| Provider registration in `main.dart` | Phase 3b |
| File existence checks inside resolver | Preflight stays in playback layer |

---

## Module layout

```
client/ttsplayer/lib/services/media_access/
  media_access_provider.dart      # enums
  resolved_media_location.dart    # result type
  media_access_config.dart        # roots, base URL, mode
  media_path_utils.dart           # strip root, encode segments
  local_file_provider.dart
  http_serving_provider.dart
  media_location_resolver.dart    # public entry point
```

---

## Provider selection

```
resolve(filePath)
  ├─ http(s) URL?           → passThrough, resolved
  ├─ Windows desktop + localPreferred mode → localFile, file:// URI
  ├─ httpMediaBaseUrl set?  → httpServing (strip root → encode → base)
  └─ else                   → unresolved + reason
```

`httpRequired` mode on non-Windows skips local file even for paths that look local.

---

## Test matrix (minimum)

| Input | Platform | Config | Expected |
|---|---|---|---|
| `https://host/media/a.mp4` | any | any | pass-through |
| `Y:\Media\Videos\a.mp4` | Windows | localPreferred | `file://` |
| `\\NAS\Media\Videos\a.mp4` | Windows | localPreferred | `file://` |
| `D:\Media\Videos\a.mp4` | Windows | localPreferred | `file://` |
| `Y:\Media\Videos\a.mp4` | non-Windows | HTTP base | `https://…/media/Videos/a.mp4` |
| UNC path | non-Windows | no HTTP | unresolved |
| Path with spaces | HTTP | encoded `%20` | |
| `/volume1/Media/Videos/a.mp4` | HTTP | correct URL | |
| No matching root | HTTP | unresolved | |

---

## Definition of done (Phase 3a)

- [x] Resolver module implemented under `services/media_access/`
- [x] Unit tests pass (`flutter test test/media_location_resolver_test.dart`)
- [x] `flutter analyze` clean
- [x] No changes to `PlaybackService` play startup path
- [x] Docs updated: phase status, abstraction doc cross-linkPhase 3b (separate PR/commit): wire resolver into playback and artwork.

---

## References

| File | Role |
|---|---|
| `docs/architecture/path-mapping.md` | HTTP strip/encode rules |
| `ttsplayer.config.json` | Default media roots |
| `playback_service.dart` | Future integration point |
