# M3.5 Phase Status — Serving Layer & Media Access

**Last updated:** 2026-07-05  
**Cycle:** `v0.4.0-dev`

→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [TNAS deploy checklist](./tnas-caddy-deploy-checklist.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Pre-implementation review](../roadmap/m35-pre-implementation-review.md)

---

## Current status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Path mapping spec, `caddy.config`, deployment docs, local Caddy validation | ✅ **Complete locally** |
| **Phase 2** | Deploy Caddy on TNAS; HTTPS smoke tests on real hardware | ⛔ **Blocked** — pending TNAS Caddy deployment |
| **Phase 2.5** | Media access abstraction — provider-neutral `MediaLocationResolver` spec | 🎯 **Document for acceptance** |
| **Phase 3** | Flutter resolver + provider implementations | ⛔ **Blocked** — until Phase **2.5 accepted** |

**Do not implement player or network startup changes until Phase 2.5 is accepted.**

Phase 2 (TNAS serving) is an **optional reference implementation** for the HTTP provider. It does not replace Phase 2.5 documentation.

---

## Gates

| Gate | Requirement |
|---|---|
| Phase 2 complete | TNAS `/catalog.json` → 200; `/media/...` → 200; Range → **206** |
| Phase 2.5 accepted | [Media access abstraction](../architecture/media-access-abstraction.md) reviewed and agreed |
| Phase 3 start | Phase 2.5 accepted (Phase 2 strongly recommended for HTTP integration testing) |

---

## Smoke test results — 2026-07-05

Environment: Windows dev machine → TNAS `MEDIATNAS-B725` (`192.168.178.130` / `MEDIATNAS-B725.fritz.box`). Local catalogue at `Y:\Media\catalog.json` (61,619,422 bytes).

### TNAS (production target) — failed — serving not deployed

| Test | URL | Result |
|---|---|---|
| Catalogue (HTTP) | `http://192.168.178.130/catalog.json` | **404** — TOS nginx default UI; no TTSPlayer route |
| Media (HTTP) | `http://192.168.178.130/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4` | **404** |
| Catalogue (HTTPS) | `https://192.168.178.130/catalog.json` | **502 Bad Gateway** — existing proxy; Caddy not serving |
| Ports 80 / 443 | — | Open |

**Conclusion:** Caddy not deployed on TNAS. Phase 2 operational work remains.

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
→ https://<nas-host>/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4
```

---

## Unblock criteria

### Phase 2 (TNAS serving)

On the NAS hostname:

1. `GET https://<nas-host>:8443/catalog.json` → **200**
2. `GET https://<nas-host>:8443/media/<relative-path>` → **200**
3. `Range: bytes=0-1023` → **206** + `Content-Range`

### Phase 2.5 (abstraction)

1. [media-access-abstraction.md](../architecture/media-access-abstraction.md) accepted
2. TNAS/Caddy documented as reference deployment only

### Phase 3 (Flutter)

Begin `MediaLocationResolver` only after Phase 2.5 acceptance.

---

## Next actions

1. **Phase 2:** [TNAS Caddy deploy checklist](./tnas-caddy-deploy-checklist.md)
2. **Phase 2.5:** Review and accept [media access abstraction](../architecture/media-access-abstraction.md)
3. **Phase 3:** Implement resolver (blocked)
