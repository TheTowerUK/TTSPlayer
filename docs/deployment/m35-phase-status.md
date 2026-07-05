# M3.5 Phase Status — Serving Layer & Media Access

**Last updated:** 2026-07-05  
**Cycle:** `v0.4.0-dev`

→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [TNAS reference provider checklist](./tnas-caddy-deploy-checklist.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Pre-implementation review](../roadmap/m35-pre-implementation-review.md)

---

## Current status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Path mapping spec, `caddy.config`, deployment docs, local Caddy validation | ✅ **Complete locally** |
| **Phase 2** | TNAS + Caddy reference HTTP provider validation | ✅ **Complete (HTTP :8443)** — TLS deferred |
| **Phase 2.5** | Media access abstraction — provider-neutral `MediaLocationResolver` spec | ✅ **Accepted** — 2026-07-05 |
| **Phase 3a** | Flutter `MediaLocationResolver` + unit tests (no playback wiring) | ✅ **Complete** |
| **Phase 3b** | Wire resolver into playback and artwork | ✅ **Complete** |

**Phase 3b complete** — resolver wired at playback and artwork consumption boundaries only. No catalogue loading, scanning, or settings changes.

**M3.5 architecture checkpoint:** tag `m3.5-media-access-complete` — [release snapshot](../release/m3.5-media-access-complete.md)

**TNAS+Caddy reference provider validated on HTTP :8443.** TLS deferred due Windows/Caddy internal cert issue.

Phase 2 (TNAS serving) validated routing, path mapping, file serving, and video Range support on real hardware. It does not block Phase 4 planning.

---

## Gates

| Gate | Requirement |
|---|---|
| Phase 2 complete | TNAS `/catalog.json` → 200; `/media/...` Range → **206** — **done 2026-07-05 (HTTP :8443)**; TLS follow-up |
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

TLS with `tls internal` deferred due Windows TLS handshake failure.

---

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

## Exit criteria before Phase 4

Complete both validations before opening **Phase 4 — Network Catalogue & Provider Configuration**.

### Windows regression (required)

- [ ] Play video from `Y:\Media`
- [ ] Seek forwards/backwards
- [ ] Pause/resume
- [ ] Stop/close playback
- [x] Artwork loads — **pass with observation** (most OK; some sidecar matches fail — [backlog](../roadmap/backlog-artwork-discovery-improvements.md), not M3.5)
- [ ] Resume position unchanged

Behaviour must match pre-M3.5 — the abstraction should be transparent on desktop. Known artwork sidecar matching gaps are tracked separately and do not fail M3.5.

### TNAS validation — complete (HTTP :8443)

Per [TNAS Caddy reference provider checklist](./tnas-caddy-deploy-checklist.md):

- [x] `/catalog.json` → **200** — 2026-07-05
- [x] `/media/...` Range → **206** — 2026-07-05
- [x] `Content-Range` / `Accept-Ranges` present
- [ ] HTTPS / `tls internal` (deferred — Windows TLS handshake failure)
- [ ] HTTP playback smoke test from Flutter (Phase 4+)

---

## Next actions

1. **Exit criteria:** Windows regression (required) — [checklist](../release/m3.5-media-access-complete.md#windows-regression-checklist)
2. **Phase 2 follow-up:** TLS on `:8443` when Windows/Caddy cert issue resolved
3. **Phase 4:** Network catalogue + provider configuration — see [release snapshot](../release/m3.5-media-access-complete.md#phase-4-preview)
