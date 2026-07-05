# M3.5 Phase Status — Serving Layer

**Last updated:** 2026-07-05  
**Cycle:** `v0.4.0-dev`

→ [TNAS deploy checklist](./tnas-caddy-deploy-checklist.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Pre-implementation review](../roadmap/m35-pre-implementation-review.md)

---

## Current status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Path mapping spec, `caddy.config`, deployment docs, local Caddy validation | ✅ **Complete locally** |
| **Phase 2** | Deploy Caddy on TNAS; run HTTPS smoke tests on real hardware | ⛔ **Blocked** — pending TNAS Caddy deployment |
| **Phase 3+** | Flutter path resolver, HTTP catalogue lifecycle, mobile | ⛔ **Blocked** — until TNAS `/media` Range returns **206** |

**Flutter resolver work remains blocked** until Phase 2 passes on the NAS.

---

## Smoke test results — 2026-07-05

Environment: Windows dev machine → TNAS `MEDIATNAS-B725` (`192.168.178.130` / `MEDIATNAS-B725.fritz.box`). Local catalogue at `Y:\Media\catalog.json` (61,619,422 bytes).

### TNAS (production target) — failed — serving not deployed

| Test | URL | Result |
|---|---|---|
| Catalogue (HTTP) | `http://192.168.178.130/catalog.json` | **404** — TNAS nginx default UI; no TTSPlayer route |
| Media (HTTP) | `http://192.168.178.130/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4` | **404** |
| Catalogue (HTTPS) | `https://192.168.178.130/catalog.json` | **502 Bad Gateway** — existing proxy; Caddy not serving |
| Ports 80 / 443 | — | Open (nginx on 80; HTTPS proxy broken or misconfigured) |

**Conclusion:** Path mapping and `backend/caddy.config` are documented but **not deployed on TNAS**. Phase 2 required before any Flutter HTTP/resolver work.

### Local validation (config logic) — passed

Caddy 2.9.1 run locally against `Y:\Media` using the same route structure as `backend/caddy.config` (HTTP test instance). Sample media path validated against real catalogue entry.

| Test | Expected | Result |
|---|---|---|
| `GET /catalog.json` | 200 | ✅ 200 |
| `HEAD /media/.../VID_20180714_200000.mp4` | 200, `Accept-Ranges: bytes` | ✅ 200 |
| `Range: bytes=0-1023` (HEAD) | 206, `Content-Range` | ✅ 206 `bytes 0-1023/266943224` |
| `Range: bytes=0-1023` (GET) | 1024 bytes | ✅ 206, 1024 bytes |
| `GET /media/Videos/test.exe` | 403 | ✅ 403 |
| `GET /scan.history.json` | 200 if present | ✅ 200 |

Path mapping confirmed (no extra `/Media/` segment):

```
Y:\Media\Images\Photos\Family\Photos for Angela\VID_20180714_200000.mp4
→ https://<nas-host>/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4
```

---

## Unblock criteria

Phase 2 is done when all of the following pass **on the TNAS hostname** (not localhost):

1. `GET https://<nas-host>/catalog.json` → **200**
2. `GET https://<nas-host>/media/<relative-path>` → **200** for a known catalogue item
3. `GET` with `Range: bytes=0-1023` → **206** with valid `Content-Range`

Only then: begin Flutter `PathResolverService` (Phase 3).

---

## Next action

Follow [TNAS Caddy deploy checklist](./tnas-caddy-deploy-checklist.md).
