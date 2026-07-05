# M3.5 Pre-Implementation Review

**Date:** July 2026  
**Cycle:** `v0.4.0-dev`  
**Status:** Phase 1 complete (serving layer docs + Caddy config) — Flutter not started  
**Platform:** NAS serving layer + Flutter HTTP access mode

→ [Path mapping (approved)](../architecture/path-mapping.md)  
→ [TNAS deployment & smoke tests](../deployment/tnas-serving-layer.md)  
→ [M3.5 goals](./network-client-foundation.md)  
→ [Development cycle](../release/v0.4.0-dev.md)

---

## Purpose

Before writing M3.5 code, assess what already exists in the backend, Caddy template, and Flutter catalogue/playback paths. This review identifies reusable foundations, gaps, risks, and a recommended implementation order.

**Rule:** Review first. Implement second. Windows local/UNC behaviour must remain unchanged.

---

## Executive summary

| Layer | Maturity | Verdict |
|---|---|---|
| **Indexer (`indexer.py`)** | Production-ready for local/UNC | No M3.5 changes required for v1; paths stay filesystem-native |
| **NAS serving (`caddy.config`)** | Aligned to approved mapping | Deploy + smoke tests on TNAS (Phase 2) |
| **Catalogue loading (client)** | Partial HTTP hooks | Manual URL load works in-session; startup/rescan/playback resolver missing |
| **Playback (client)** | Partial | Accepts `http(s)://` if already in `file_path`; no path-to-URL mapping |
| **Mobile / settings** | Not started | No NAS URL config, no platform-specific startup |

The critical M3.5 bridge is **not** the indexer — it is the **path resolver + HTTP catalogue lifecycle + NAS serving layer**, with desktop regression protection throughout.

---

## 1. Backend review

### 1.1 What exists

| Asset | Path | Role |
|---|---|---|
| Indexer | `backend/indexer.py` | Filesystem crawler → `catalog.json` + `scan.history.json` |
| Tests | `backend/test_indexer.py` | 16 unit tests (extensions, sidecars, `added_at`, library merge) |
| Docker | `backend/Dockerfile` | Python 3.12 + ffmpeg container for indexer only |
| Caddy template | `backend/caddy.config` | Static HTTPS file server sketch |
| Shared config | `ttsplayer.config.json` | `cataloguePath`, `historyPath`, `mediaRoots[]` |

**Scanner version:** `0.3.3` · **Catalogue schema:** v2 (`catalogue_version: 2`)

### 1.2 Indexer behaviour (relevant to M3.5)

- Emits **absolute filesystem paths** in `file_path` — `Y:\Media\...`, UNC, or `/volume1/...` depending on scan environment.
- **No HTTP awareness** — no base URL, stream URL, or serving hints in catalogue output. Correct per filesystem-is-truth principle.
- **Atomic writes** via temp file + rename (`write_atomic`) — failed scans never corrupt prior catalogue.
- **Progress protocol** — `PROGRESS: {...}` JSON on stdout for Flutter `ScannerService` (Windows subprocess only).
- **Library rescan** — merges one branch; preserves `added_at` across rescans.

### 1.3 Indexer constraints (do not break)

1. Stdlib-only Python — no pip packages unless explicitly requested.
2. Filesystem is truth — scanner must not invent URLs or rename folders.
3. Mobile must **not** run the indexer — catalogue pulled from NAS over HTTPS.
4. `ttsplayer.config.json` has stale `"catalogueVersion": 1` — indexer emits `2`; cosmetic doc/config sync only.

### 1.4 Backend gaps for M3.5

| Gap | Severity | Notes |
|---|---|---|
| Caddy not deployed | **Blocker** | Template exists; no TNAS install/run docs or verified config |
| Path mapping undefined | ~~**Blocker**~~ **Resolved** | Spec: [path-mapping.md](../architecture/path-mapping.md) |
| Extension mismatch | ~~**High**~~ **Resolved** | Caddy allowlist synced with `indexer.py` |
| Range request verification | **High** | Procedure in [tnas-serving-layer.md](../deployment/tnas-serving-layer.md); run on deploy |
| `scan.history.json` not served | ~~**Low**~~ **Resolved** | Route added to `caddy.config` |
| No deploy/verify scripts | ~~**Medium**~~ **Resolved** | Smoke test doc with curl + PowerShell |
| Docker ≠ serving | **Info** | Indexer container separate from HTTPS serving stack |

---

## 2. Caddy configuration review

### 2.1 Approved configuration (`backend/caddy.config`)

```
/catalog.json       →  /volume1/Media/catalog.json
/scan.history.json  →  /volume1/Media/scan.history.json
/media/*            →  /volume1/Media/<relative>   (handle_path strips /media prefix)
```

→ Full spec: [path-mapping.md](../architecture/path-mapping.md)  
→ Deploy & verify: [tnas-serving-layer.md](../deployment/tnas-serving-layer.md)

### 2.2 Previously identified issues (Phase 1 resolution)

| Issue | Resolution |
|---|---|
| Dev vs prod paths | Canonical roots documented: `Y:\Media`, UNC, `/volume1/Media` |
| Extra `/Media/` in URL | **Rejected** — `/media/Videos/...` maps directly under `/volume1/Media/Videos/...` |
| Missing extensions | All `SUPPORTED_EXTENSIONS` allowed in Caddy |
| Range requests | Smoke test procedure documented (expect `206 Partial Content`) |
| Catalogue path case | TNAS root uses `/volume1/Media` (capital M) |

### 2.3 Phase 1 verdict

Caddy config and documentation are **ready for TNAS deployment**. Phase 2 is operational verification on real hardware — not further config design.

---

## 3. Catalogue loading review (Flutter client)

### 3.1 Current load flow

```
loadOnStartup()
  └─ _tryLivePaths()  [local File.exists() only]
       ├─ ttsplayer.config.json → cataloguePath
       ├─ shared_preferences catalog_path
       └─ liveCataloguePaths[] fallbacks (Y:\, UNC)
  └─ [fail] → bundled assets/catalog.json (demo)

Manual "Load Catalog" dialog
  └─ startsWith('http') → loadFromUrl()  [15s timeout, status 200]
  └─ else → loadFromFile()

rescan() / Refresh
  └─ _tryLivePaths() again  [local only]
```

### 3.2 What already works

| Capability | Location | Notes |
|---|---|---|
| HTTP GET catalogue | `CatalogService.loadFromUrl()` | 15s timeout; non-200 throws |
| Last-good on failed reload | `CatalogService._load()` | Replaces catalogue only on success |
| Persist path + source | `shared_preferences` | `catalog_path`, `catalog_source` written |
| Scan history over HTTP | `ScanHistoryService.loadAdjacentTo()` | Derives history URL from catalogue URL |
| Remote preflight skip | `checkFilePresence()` | Skips local `File.exists()` for http(s) |
| Playback passthrough | `mediaUriForPlayback()` | Returns http(s) URLs unchanged |
| Error banners | `DashboardBanners` | Dismissible; retry actions |
| Scanner platform gate | `ScannerService._run()` | Blocked on web and non-Windows |

### 3.3 Critical gaps

| Gap | Impact | Evidence |
|---|---|---|
| **HTTP not restored on startup** | Session-only remote catalogues | `_tryLivePaths()` uses `File(path)` — saved HTTPS URL fails `exists()` |
| **`catalog_source` never read** | Remote source not distinguished at startup | `_prefKeySource` written, never loaded in `_tryLivePaths` / `loadOnStartup` |
| **No path-to-URL resolver** | Playback fails for HTTP catalogues with local `file_path` | `MediaItem.filePath` used directly in `PlaybackService.play()` |
| **`rescan()` is local-only** | Mobile refresh cannot re-fetch NAS catalogue | `_tryLivePaths()` has no HTTP branch |
| **`CatalogueSourceKind` has no network variant** | HTTP URLs classified as `liveNas` | `classifyCataloguePath()` only knows drive/UNC/demo |
| **`validateCatalogue()` local-only** | Library Manager validation fails for remote | Uses `File.exists()` |
| **Hardcoded dev paths** | Not portable to mobile/other machines | `scannerConfigPath`, `ScannerService._script` point at `D:\AppDev\TTSPlayer\...` |
| **Rescan UI on all platforms** | Mobile may offer scan that cannot run | Gate in service but UI still visible |

### 3.4 Behavioural bugs in HTTP mode today

1. User loads `https://nas/catalog.json` manually → works until restart → startup ignores saved URL → demo fallback.
2. Catalogue items carry `Y:\Media\...` paths → playback checks local file → fails on mobile/unmounted drives.
3. User taps Rescan after HTTP load → tries local NAS paths → error banner; catalogue preserved but not refreshed from HTTP.

These are expected for M3 scope but are **M3.5 blockers**.

---

## 4. Playback review

### 4.1 Current stack

| Platform | Engine | URI handling |
|---|---|---|
| Windows | media_kit | `mediaUriForPlayback()` → `file://` or http(s) passthrough |
| Other | video_player | `VideoPlayerController.networkUrl` / `.file` |

### 4.2 M3.5 requirements vs reality

| Requirement | Status |
|---|---|
| Stream video over HTTPS | ⚠️ Possible if `file_path` is already a URL |
| Seek / range requests | ⚠️ Depends on NAS headers — unverified end-to-end |
| Map scanner path → stream URL | ❌ No resolver service |
| UNC / drive letter unchanged on desktop | ✅ Local paths still work |

**Verdict:** Playback plumbing exists; **path resolution** is the missing layer.

---

## 5. Canonical path mapping (approved)

Full specification: **[path-mapping.md](../architecture/path-mapping.md)**

### Media roots

| Environment | Root |
|---|---|
| Windows local | `Y:\Media` |
| Windows UNC | `\\MEDIATNAS-B725\Media` |
| TNAS | `/volume1/Media` |

### HTTP media route

`https://<nas-host>/media/` — **no** extra `/Media/` segment after `/media/`.

### Mapping rule

1. Strip configured media root prefix from catalogue `file_path`
2. Normalise separators to `/`
3. URL-encode each path segment
4. Append to `https://<nas-host>/media/`

### Examples

| `file_path` | Stream URL |
|---|---|
| `Y:\Media\Videos\movie.mp4` | `https://<nas-host>/media/Videos/movie.mp4` |
| `\\MEDIATNAS-B725\Media\Videos\movie.mp4` | `https://<nas-host>/media/Videos/movie.mp4` |
| `/volume1/Media/Videos/movie.mp4` | `https://<nas-host>/media/Videos/movie.mp4` |

### Resolver placement

Client-only (Phase 3) — no catalogue schema change. Artwork/sidecar paths use the same rule.

---

## 6. Test coverage gaps

### Existing (M3)

- `catalog_service_warnings_test.dart` — local file load, scan warnings
- `catalog_lookup_test.dart` — path classification (local only)
- `playback_preflight_test.dart` — remote URL skips presence check
- `scanner_service_test.dart` — navigation after scan
- `backend/test_indexer.py` — indexer behaviour

### Missing (M3.5 — add before or with implementation)

| Area | Tests needed |
|---|---|
| `loadFromUrl` | success, timeout, non-200, malformed JSON |
| Startup restore | persisted HTTPS URL loaded on restart |
| Last-good catalogue | failed HTTP refresh preserves prior tree |
| Path resolver | local, UNC, Linux paths → HTTPS URL |
| Playback | resolved HTTPS URL passed to player |
| `ScanHistoryService` | adjacent HTTP history fetch |
| `CatalogueSourceKind` | network/https classification |
| Platform gate | rescan/scan UI hidden on non-Windows |
| Caddy smoke | script or doc'd manual steps for range + catalogue |

---

## 7. Recommended implementation order

Aligned with [v0.4.0-dev.md](../release/v0.4.0-dev.md):

| Phase | Work | Status |
|---|---|---|
| **1** | URL mapping doc + `caddy.config` + deployment/smoke docs | ✅ Complete |
| **2** | Deploy Caddy on TNAS; run smoke tests (incl. Range 206) | ✅ HTTP :8443 validated — TLS follow-up |
| **2.5** | [Media access abstraction](../architecture/media-access-abstraction.md) | ✅ Accepted — 2026-07-05 |
| **3a** | `MediaLocationResolver` + providers in Flutter | ✅ Complete |
| **3b** | Wire into `PlaybackService` + artwork | Blocked until 3a complete |
| **4** | `CatalogService` HTTP startup + rescan refresh | Phase 3 |
| **5** | `CatalogueSourceKind.network` + Storage Status / chip updates | Phase 4 |
| **6** | Wire resolver into `PlaybackService` + artwork | Phase 3 |
| **7** | Mobile settings (media roots, base URL, provider) | Phase 4 |
| **8** | Hide scanner UI on non-Windows; smoke Android/iOS builds | Phase 4–7 |
| **9** | Tests + desktop regression suite | Throughout |

**Gate:** Phase 2.5 accepted. Phase 3a limits scope to resolver + tests; no player/network startup wiring until Phase 3b.

---

## 8. Explicit non-goals (this review)

- Changing catalogue schema (unless unavoidable — prefer client resolver)
- Running indexer on mobile
- TMDB, auth systems, or virtual libraries
- M4 image viewer / M5 music
- App Store release polish

---

## 9. Sign-off — review & Phase 1

### Pre-implementation review

- [x] Backend indexer role and constraints documented
- [x] Caddy template assessed with alignment gaps listed
- [x] Client catalogue load flow mapped
- [x] Playback/resolver gap identified
- [x] Cross-layer path mapping approved
- [x] Test gaps listed
- [x] Implementation order proposed

### Phase 1 — serving layer docs & config

- [x] Canonical path mapping approved and documented
- [x] `caddy.config` aligned (`/volume1/Media`, `handle_path /media/*`)
- [x] Extension allowlist synced with indexer
- [x] TNAS deployment guide written
- [x] HTTP Range smoke test procedure documented
- [x] **Phase 2:** TNAS reference provider validated on HTTP `:8443` — 2026-07-05 (TLS deferred)
- [x] **Phase 2.5:** Accept [media access abstraction](../architecture/media-access-abstraction.md) — 2026-07-05

**Next step:** Phase 3a — [Phase 3 plan](./m35-phase-3-plan.md). Phase 2 (TNAS Caddy) optional in parallel — [phase status](../deployment/m35-phase-status.md).

---

## References

| File | Purpose |
|---|---|
| `backend/indexer.py` | Scanner |
| `backend/caddy.config` | HTTPS template |
| `backend/Dockerfile` | Indexer container |
| `ttsplayer.config.json` | Shared dev config |
| `client/ttsplayer/lib/services/catalog_service.dart` | Catalogue loading |
| `client/ttsplayer/lib/services/scan_history_service.dart` | History loading |
| `client/ttsplayer/lib/services/playback_service.dart` | Playback |
| `client/ttsplayer/lib/services/playback_platform.dart` | URI normalisation |
| `client/ttsplayer/lib/services/scanner_service.dart` | Windows scanner subprocess |
| `docs/architecture/media-access-abstraction.md` | Provider-neutral resolver (Phase 2.5) |
| `docs/roadmap/network-client-foundation.md` | M3.5 success criteria |
