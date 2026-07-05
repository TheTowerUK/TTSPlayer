# TNAS Caddy Deploy Checklist

**Milestone:** M3.5 Network Client Foundation  
**Phase:** 2 — operational deployment on TerraMaster NAS  
**Prerequisite:** Phase 1 complete — [path mapping](../architecture/path-mapping.md), [caddy.config](../../backend/caddy.config), [local validation note](./m35-phase-status.md)

→ [Serving layer guide](./tnas-serving-layer.md) (smoke test commands)  
→ [Phase status](./m35-phase-status.md)

**Do not start Flutter path resolver work until step 9 passes on the NAS.**

---

## Before you begin

| Item | Detail |
|---|---|
| NAS hostname | Example: `MEDIATNAS-B725.fritz.box` or `192.168.178.130` |
| Windows mount | `Y:\Media` → same tree as TNAS `/volume1/Media` |
| Config file | `backend/caddy.config` in the repo |
| Conflict | TNAS ships **nginx on port 80**; HTTPS on **443** may already be in use |

---

## Checklist

### 1. Confirm `/volume1/Media` exists

On the TNAS shell (SSH, TOS terminal, or Docker host):

```bash
ls -la /volume1/Media
```

**Pass:** directory exists and lists your library folders (e.g. `Videos`, `Images`, `Music`).

**Fail:** wrong path or case — Windows `Y:\Media` must map to `/volume1/Media` (capital **M**), not `/volume1/media`.

---

### 2. Confirm `catalog.json` at `/volume1/Media/catalog.json`

```bash
ls -la /volume1/Media/catalog.json
head -c 200 /volume1/Media/catalog.json
```

**Pass:** file exists; output starts with `{` and contains `"catalogue"` or `"folders"`.

If missing, run the indexer on Windows (writes to `Y:\Media\catalog.json`) or on the NAS:

```bash
python3 /path/to/indexer.py --config /path/to/ttsplayer.config.json
```

---

### 3. Stop or avoid conflict with existing nginx on 80 / 443

**Observed on 2026-07-05:** TNAS responds on port 80 with nginx (TOS UI); HTTPS on 443 returned **502 Bad Gateway** — no TTSPlayer routes.

Choose **one** strategy:

| Strategy | When to use |
|---|---|
| **A. Alternate ports** | Keep TNOS nginx on 443; run Caddy on e.g. `:8443` for TTSPlayer only (simplest for first deploy) |
| **B. Reverse-proxy integration** | Configure TNOS nginx to proxy `/catalog.json` and `/media/*` to Caddy on an internal port |
| **C. Replace front door** | Stop TNOS web UI on 443 and let Caddy bind 443 (disrupts TNOS HTTPS admin — not recommended unless you understand impact) |

**Recommended for first deploy:** Strategy **A** — Caddy on `:8443` with `tls internal`, then smoke-test at `https://<nas-host>:8443/...`. Move to 443 after validation.

Document your chosen ports in TNOS firewall if needed.

---

### 4. Choose deployment mode

#### Option A — Caddy binary / system service

- Install Caddy 2.x for TNAS architecture (check `uname -m`)
- Copy `backend/caddy.config` to the NAS (e.g. `/volume1/Media/caddy/caddy.config`)
- Replace `<YOUR_DOMAIN>` with hostname or `:8443` site address
- For LAN-only: add `tls internal` inside the site block (see [serving layer guide](./tnas-serving-layer.md#tls-options))

#### Option B — Docker with read-only mount

```bash
docker run -d --name ttsplayer-caddy \
  -p 8443:8443 \
  -v /volume1/Media:/volume1/Media:ro \
  -v /path/to/caddy.config:/etc/caddy/Caddyfile:ro \
  caddy:2-alpine \
  caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
```

Adjust published port and config path. Mount **`/volume1/Media` read-only**.

Pick one mode and record it in your NAS runbook.

---

### 5. Deploy `backend/caddy.config`

1. Copy from repo: `backend/caddy.config`
2. Set site address — examples:

   ```
   # LAN test (port 8443)
   :8443 {
       tls internal
       ...
   }

   # Or hostname
   MEDIATNAS-B725.fritz.box {
       tls internal
       ...
   }
   ```

3. Confirm handlers match [path mapping](../architecture/path-mapping.md):
   - `/catalog.json` → root `/volume1/Media`
   - `handle_path /media/*` → root `/volume1/Media` (**no** extra `/Media/` in URL)
   - Extension allowlist matches `indexer.py` `SUPPORTED_EXTENSIONS`

4. Do **not** change the `/media/` URL prefix.

---

### 6. Validate config

On the NAS (or with config copied locally against TNAS paths):

```bash
caddy validate --config /path/to/caddy.config --adapter caddyfile
```

**Pass:** `Valid configuration`

---

### 7. Start Caddy

```bash
caddy run --config /path/to/caddy.config --adapter caddyfile
```

For production, configure a startup task / systemd / TNOS app so Caddy survives reboot.

**Pass:** process running; chosen port listening (`ss -tlnp | grep 8443` or `443`).

---

### 8. Run smoke tests from your PC

Replace `<nas-host>` and port if using 8443.

#### 8a. Catalogue → 200

```powershell
Invoke-WebRequest -Uri "https://<nas-host>:8443/catalog.json" `
  -SkipCertificateCheck -UseBasicParsing | Select-Object StatusCode
```

```bash
curl -sS -k -o /dev/null -w "%{http_code}\n" "https://<nas-host>:8443/catalog.json"
```

**Pass:** `200`

#### 8b. Media file → 200

Pick a path from the catalogue. Example (2026-07-05 catalogue):

```
https://<nas-host>:8443/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4
```

```powershell
$uri = "https://<nas-host>:8443/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4"
Invoke-WebRequest -Uri $uri -Method Head -SkipCertificateCheck -UseBasicParsing |
  Select-Object StatusCode, @{n='Accept-Ranges';e={$_.Headers['Accept-Ranges']}}
```

**Pass:** `200`, `Accept-Ranges: bytes`

#### 8c. Range → 206 + Content-Range

```powershell
Invoke-WebRequest -Uri $uri -Method Head `
  -Headers @{ Range = "bytes=0-1023" } `
  -SkipCertificateCheck -UseBasicParsing |
  Select-Object StatusCode, @{n='Content-Range';e={$_.Headers['Content-Range']}}
```

**Pass:** `206`, header like `bytes 0-1023/<total>`

```bash
curl -sS -k -I -H "Range: bytes=0-1023" \
  "https://<nas-host>:8443/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4"
```

#### 8d. Extension block → 403

```bash
curl -sS -k -o /dev/null -w "%{http_code}\n" \
  "https://<nas-host>:8443/media/Videos/test.exe"
```

**Pass:** `403`

Full command reference: [tnas-serving-layer.md](./tnas-serving-layer.md)

---

### 9. Unblock Flutter resolver

When **8a–8c pass on the NAS** (not localhost):

1. Update [m35-phase-status.md](./m35-phase-status.md) with dated TNAS smoke results
2. Tag optional checkpoint: `m35-serving-layer`
3. Begin Phase 3: Flutter `PathResolverService` per [path-mapping.md](../architecture/path-mapping.md)

**Until step 9:** no `CatalogService` HTTP startup changes, no playback resolver, no mobile settings UI.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| 404 on `/catalog.json` | Caddy not running, wrong root, or nginx still fronting without proxy rules |
| 404 on `/media/...` | Missing `handle_path`; URL includes erroneous `/Media/` segment |
| 502 on HTTPS | Existing TNOS proxy target down — use alternate port (8443) first |
| 200 instead of 206 on Range | Request not reaching Caddy `file_server`; check proxy buffering |
| 403 on valid video | Extension not in allowlist — sync with `indexer.py` |
| Certificate errors on phone | Export/trust Caddy `tls internal` CA |

---

## Sign-off

| Step | Date | Pass |
|---|---|---|
| 1. `/volume1/Media` | | ☐ |
| 2. `catalog.json` | | ☐ |
| 3. Port conflict resolved | | ☐ |
| 4. Deploy mode chosen | | ☐ |
| 5. Config deployed | | ☐ |
| 6. `caddy validate` | | ☐ |
| 7. Caddy running | | ☐ |
| 8. Smoke tests (200 / 206) | | ☐ |
| 9. Flutter unblocked | | ☐ |

---

## References

| File | Purpose |
|---|---|
| `backend/caddy.config` | Production Caddy site config |
| `docs/architecture/path-mapping.md` | Filesystem → URL rules |
| `docs/deployment/m35-phase-status.md` | Phase 1 local results; unblock criteria |
| `ttsplayer.config.json` | Windows dev roots (`Y:\Media`, UNC) |
