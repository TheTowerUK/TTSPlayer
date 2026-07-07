# M3.5 Phase Status — Serving Layer & Media Access

**Last updated:** 2026-07-07  
**Cycle:** `v0.4.0-dev`  
**Milestone:** M3.5 **COMPLETE** — validated on physical TNAS (HTTPS)

→ [M3.5 final acceptance](../release/m3.5-media-access-complete.md#m35-final-acceptance)  
→ [Deployment validation](../release/m3.5-media-access-complete.md#deployment-validation--2026-07-07)  
→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [TNAS reference provider checklist](./tnas-caddy-deploy-checklist.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Phase 4 plan](../roadmap/m35-phase-4-plan.md)  
→ [Pre-implementation review](../roadmap/m35-pre-implementation-review.md)

---

## M3.5 status: COMPLETE

Validated against physical TerraMaster TNAS using Caddy HTTPS deployment (`https://ttsplayer.local:8443`). Confirmed on target hardware:

- HTTPS catalogue loading
- Provider configuration and selection
- Remote media streaming
- HTTP Range request support (video seeking)
- Certificate trust (Caddy `tls internal` CA installed on client)
- Local-first and HTTP-required access modes

Implementation alone is not sufficient for closure — this milestone is **proven on the deployment target**, not only in unit tests.

---

## Current status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Path mapping spec, `caddy.config`, deployment docs, local Caddy validation | ✅ **Complete locally** |
| **Phase 2** | TNAS + Caddy reference HTTP provider validation | ✅ **Complete (HTTP :8443)** |
| **Phase 2.5** | Media access abstraction — provider-neutral `MediaLocationResolver` spec | ✅ **Accepted** — 2026-07-05 |
| **Phase 3a** | Flutter `MediaLocationResolver` + unit tests (no playback wiring) | ✅ **Complete** |
| **Phase 3b** | Wire resolver into playback and artwork | ✅ **Complete** |
| **M3.5** | Exit criteria + deployment validation | ✅ **COMPLETE** — 2026-07-07 |
| **Phase 4** | Network catalogue + provider configuration | ✅ **Complete** — [plan](../roadmap/m35-phase-4-plan.md) |
| **4.1** | HTTP catalogue provider (`CatalogService.loadFromUrl()`) | ✅ **Complete** |
| **4.2** | Media provider configuration model | ✅ **Complete** |
| **4.3** | Settings UI | ✅ **Complete** |
| **4.4** | Provider selection & fallback | ✅ **Complete** |
| **4.5** | HTTPS/TLS refinement and production validation | ✅ **Complete** — [validation notes](./phase-4.5-validation.md) |

**M3.5 complete** — tag `m3.5-media-access-complete`; deployment re-validated 2026-07-07 — [deployment validation](../release/m3.5-media-access-complete.md#deployment-validation--2026-07-07).

---

## Gates

| Gate | Requirement |
|---|---|
| Phase 2 complete | TNAS `/catalog.json` → 200; `/media/...` Range → **206** — **done 2026-07-05 (HTTP :8443)**; HTTPS Flutter validation **done 2026-07-07** |
| Phase 2.5 accepted | [Media access abstraction](../architecture/media-access-abstraction.md) reviewed and agreed — **done 2026-07-05** |
| Phase 3a start | Phase 2.5 accepted — resolver + tests only |
| Phase 3b start | Phase 3a complete — resolver + tests pass; no playback wiring in 3a |

---

## Smoke test results — 2026-07-05

Environment: Windows dev machine → TNAS `MEDIATNAS-B725` (`192.168.178.130` / `MEDIATNAS-B725.fritz.box`). Local catalogue at `Y:\Media\catalog.json` (61,619,422 bytes).

### TNAS (production target) — pre-deployment — superseded

Earlier 2026-07-05 attempt before Caddy Docker was running on `:8443`:

| Test | URL | Result |
|---|---|---|
| Catalogue (HTTP) | `http://192.168.178.130/catalog.json` | **404** — TOS nginx default UI; no TTSPlayer route |
| Media (HTTP) | `http://192.168.178.130/media/...` | **404** |
| Catalogue (HTTPS) | `https://192.168.178.130/catalog.json` | **502 Bad Gateway** — existing proxy; Caddy not serving |

→ See [TNAS reference provider validation](#tnas-reference-provider-validation--2026-07-05) below.

### Local validation (config logic) — passed

Caddy 2.9.1 run locally against `Y:\Media` using the same route structure as `backend/caddy.config` (HTTP test instance).

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
→ https://<nas-host>:8443/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4
```

---

## TNAS reference provider validation — 2026-07-05

Host: `192.168.178.130`  
Port: `8443`  
Mode: Caddy Docker container  
Protocol: HTTP for initial validation

| Test | Result |
|---|---|
| `/catalog.json` | 200 OK |
| `/media/...` Range | 206 Partial Content |
| `Content-Range` | Present |
| `Accept-Ranges` | Present |

**Conclusion:** Routing, path mapping, file serving, and video Range support work on real TNAS hardware.

TLS with `tls internal` validated 2026-07-07 from Flutter after Caddy CA trust — see [deployment validation](../release/m3.5-media-access-complete.md#deployment-validation--2026-07-07).

---

## TNAS HTTPS deployment validation — 2026-07-07

Host: `ttsplayer.local`  
Port: `8443`  
Protocol: HTTPS (Caddy `tls internal`, CA trusted on Windows client)

| Test | Result |
|---|---|
| `GET /catalog.json` (HTTPS) | ✅ 200 — Flutter catalogue load |
| Provider config + startup selection | ✅ Settings persisted; remote URL used when locals unavailable |
| Remote media playback | ✅ First frame + streaming |
| Range requests (seek) | ✅ 206 Partial Content |
| Certificate trust | ✅ After Caddy CA install |
| Local preferred mode | ✅ Local when mounted; HTTPS fallback when not |
| HTTP required mode | ✅ Remote-only path |

**Conclusion:** M3.5 media access and Phase 4 provider configuration are validated end-to-end on physical TNAS hardware, not only in automated tests.

## Unblock criteria

### Phase 2 (TNAS reference provider) — complete (HTTP)

Validated 2026-07-05 on `http://192.168.178.130:8443`:

1. `GET /catalog.json` → **200** ✅
2. `GET /media/<relative-path>` with `Range` → **206** + `Content-Range` ✅

HTTPS / `tls internal` — follow-up when Windows trust or cert issue is resolved.

### Phase 2.5 (abstraction) — complete

1. [media-access-abstraction.md](../architecture/media-access-abstraction.md) accepted — 2026-07-05
2. TNAS/Caddy documented as reference deployment only

### Phase 3a (Flutter resolver)

1. `MediaLocationResolver` + unit tests — see [Phase 3 plan](../roadmap/m35-phase-3-plan.md)
2. No `PlaybackService` wiring in this phase

### Phase 3b (integration) — complete

Resolver wired into `PlaybackService.play()` and `ArtworkImage` load path. Catalogue paths unchanged.

---

## Exit criteria before Phase 4 — satisfied (2026-07-05)

### Windows regression — **PASS**

- [x] Play video from `Y:\Media`
- [x] Seek forwards/backwards
- [x] Pause/resume
- [x] Stop/close playback
- [x] Artwork loads — pass with observation ([backlog](../roadmap/backlog-artwork-discovery-improvements.md))
- [x] Resume position unchanged
- [x] Startup behaviour unchanged

Full checklist: [Windows regression](../release/m3.5-media-access-complete.md#windows-regression-checklist)

### TNAS validation — complete (HTTP :8443)

Per [TNAS Caddy reference provider checklist](./tnas-caddy-deploy-checklist.md):

- [x] `/catalog.json` → **200** — 2026-07-05
- [x] `/media/...` Range → **206** — 2026-07-05
- [x] `Content-Range` / `Accept-Ranges` present
- [x] Client HTTPS/TLS validation and error handling — Phase 4.5 ([notes](./phase-4.5-validation.md))
- [x] HTTPS Flutter production smoke test on TNAS — 2026-07-07 ([deployment validation](../release/m3.5-media-access-complete.md#deployment-validation--2026-07-07))
- [x] Remote catalogue + media playback from Flutter on TNAS — 2026-07-07

---

## Next actions

1. **Backlog:** [Artwork discovery improvements](../roadmap/backlog-artwork-discovery-improvements.md) (Phase 4.x)
2. **Next milestone:** TBD — M3.5 and Phase 4 closed

**M3.5 closed** — critical resolver/playback fixes only; no milestone scope creep.
