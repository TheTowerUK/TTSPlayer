# TNAS Serving Layer — Caddy Deployment & Smoke Tests

**Milestone:** M3.5 Network Client Foundation  
**Phase:** 1 — serving layer (no Flutter changes)  
**Platform:** TerraMaster NAS (TNAS) + Caddy

→ [Path mapping specification](../architecture/path-mapping.md)  
→ [TNAS deploy checklist](./tnas-caddy-deploy-checklist.md)  
→ [Phase status & smoke results](./m35-phase-status.md)  
→ [Caddy config](../../backend/caddy.config)  
→ [M3.5 goals](../roadmap/network-client-foundation.md)

---

## Overview

TTSPlayer serves media over HTTPS using **Caddy as a static file server**. No application server, no transcoding, no Node runtime.

| URL | Serves |
|---|---|
| `https://<nas-host>/catalog.json` | `/volume1/Media/catalog.json` |
| `https://<nas-host>/scan.history.json` | `/volume1/Media/scan.history.json` |
| `https://<nas-host>/media/<path>` | `/volume1/Media/<path>` |

Path mapping rules are defined in [path-mapping.md](../architecture/path-mapping.md).

---

## Prerequisites

- TNAS with media library at **`/volume1/Media`** (capital `M` — must match Windows `Y:\Media` content)
- `catalog.json` written by `indexer.py` to `/volume1/Media/catalog.json`
- Caddy 2.x installed on the NAS (package, binary, or container — method depends on TNAS model/OS)
- Hostname reachable on the home network (e.g. `mediatnas.local` or NAS IP)
- TLS certificate strategy chosen (see [TLS options](#tls-options))

### Filesystem check

On the NAS shell:

```bash
ls -la /volume1/Media/catalog.json
ls -la /volume1/Media/Videos/   # or your library subfolder
```

On Windows (should mirror the same tree):

```
Y:\Media\catalog.json
Y:\Media\Videos\
```

---

## Deployment steps

### 1. Copy configuration

Copy `backend/caddy.config` to the NAS, e.g.:

```
/volume1/Media/caddy/caddy.config
```

Replace placeholders:

| Placeholder | Example |
|---|---|
| `<YOUR_DOMAIN>` | `mediatnas.local` or `media.example.com` |
| `admin@<YOUR_DOMAIN>` | Your email for ACME registration (public TLS only) |

### 2. Review routes

Confirm `backend/caddy.config` matches the approved layout:

- **`/catalog.json`** — root `/volume1/Media`
- **`/media/*`** — `handle_path` strips `/media`, root `/volume1/Media`
- **Extension allowlist** — matches `SUPPORTED_EXTENSIONS` in `indexer.py`

Do not change the `/media/` URL prefix or add a `/Media/` segment — see path mapping spec.

### 3. Start Caddy

From the config directory on the NAS:

```bash
caddy validate --config /volume1/Media/caddy/caddy.config
caddy run --config /volume1/Media/caddy/caddy.config
```

For production, configure Caddy as a system service or TNAS OS startup task so it survives reboot.

### 4. Open firewall ports

- **8443/tcp** — recommended for first deploy (avoids conflict with TOS on 443)
- **443/tcp** — use when Caddy owns the HTTPS front door
- **80/tcp** — HTTP → HTTPS redirect if using public ACME

Home-network-only deployments may use `:8443` with `tls internal` (see below).

---

## TLS options

### Option A — Public domain (Let's Encrypt)

Use a real DNS name pointing at the NAS. Caddy obtains certificates automatically when `<YOUR_DOMAIN>` is a public hostname.

Best for: remote access outside the LAN (future milestones).

### Option B — Home network / `.local` hostname (recommended for M3.5 smoke tests)

Use Caddy **`tls internal`** or install a private CA certificate on test phones.

Example site block for first deploy on port 8443:

```
:8443 {
    tls internal
    # ... handlers ...
}
```

Or hostname-based:

```
mediatnas.local {
    tls internal
    # ... handlers ...
}
```

Install the Caddy root CA on Android/iOS test devices so HTTPS validates. Document the CA export path for your Caddy install.

### Option C — NAS IP with self-signed cert

Works for curl smoke tests; mobile devices require trusting the certificate manually.

---

## Smoke tests

Replace `<nas-host>` with your hostname or IP (e.g. `mediatnas.local`).

### 1. Catalogue fetch

**Bash / NAS shell:**

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "https://<nas-host>/catalog.json"
```

**Expected:** `200`

**Validate JSON:**

```bash
curl -sS "https://<nas-host>/catalog.json" | head -c 500
```

**Expected:** JSON starting with `{`, containing `"catalogue"` and `"folders"`.

**PowerShell (Windows dev machine):**

```powershell
Invoke-WebRequest -Uri "https://<nas-host>/catalog.json" -UseBasicParsing | Select-Object StatusCode
```

---

### 2. Media file — full response

Pick a known file from the catalogue, e.g. `Videos/movie.mp4`.

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://<nas-host>/media/Videos/movie.mp4"
```

**Expected:** `200`

**Headers check:**

```bash
curl -sS -I "https://<nas-host>/media/Videos/movie.mp4"
```

**Expected headers include:**

- `HTTP/2 200` or `HTTP/1.1 200`
- `Accept-Ranges: bytes` (Caddy `file_server` default)

---

### 3. HTTP Range request (required for video seek)

This is the **critical M3.5 verification** — players need partial content for seek/buffer.

```bash
curl -sS -I \
  -H "Range: bytes=0-1023" \
  "https://<nas-host>/media/Videos/movie.mp4"
```

**Expected:**

```
HTTP/2 206
Content-Range: bytes 0-1023/<total-file-size>
Content-Length: 1024
Accept-Ranges: bytes
```

**Fetch partial body:**

```bash
curl -sS \
  -H "Range: bytes=0-1023" \
  "https://<nas-host>/media/Videos/movie.mp4" \
  | wc -c
```

**Expected:** `1024`

**Mid-file range (simulates seek):**

```bash
curl -sS -I \
  -H "Range: bytes=1048576-2097151" \
  "https://<nas-host>/media/Videos/movie.mp4"
```

**Expected:** `206` with matching `Content-Range`.

**PowerShell:**

```powershell
$uri = "https://<nas-host>/media/Videos/movie.mp4"
Invoke-WebRequest -Uri $uri -Headers @{ Range = "bytes=0-1023" } -UseBasicParsing |
  Select-Object StatusCode, Headers
```

**Expected:** `StatusCode` = `206`.

---

### 4. Extension allowlist — negative test

Request an extension not in the scanner set (e.g. `.exe`):

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://<nas-host>/media/Videos/test.exe"
```

**Expected:** `403`

Request an allowed image extension:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://<nas-host>/media/Images/photo.jpg"
```

**Expected:** `200` (when file exists)

---

### 5. Path mapping alignment

Compare catalogue `file_path` to URL:

| Catalogue `file_path` | curl URL |
|---|---|
| `Y:\Media\Videos\movie.mp4` | `https://<nas-host>/media/Videos/movie.mp4` |
| `\\MEDIATNAS-B725\Media\Videos\movie.mp4` | `https://<nas-host>/media/Videos/movie.mp4` |

Extract a path from the catalogue:

```bash
python3 -c "
import json, urllib.request
data = json.load(urllib.request.urlopen('https://<nas-host>/catalog.json'))
for folder in data.get('folders', []):
    for item in folder.get('items', []):
        fp = item.get('file_path', '')
        if fp.endswith('.mp4'):
            print(fp)
            break
    else:
        continue
    break
"
```

Build the expected URL manually and run smoke test #2 and #3 against it.

---

### 6. Scan history (optional)

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://<nas-host>/scan.history.json"
```

**Expected:** `200` when the file exists; `404` is acceptable if history has not been written yet.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `404` on media URL | Wrong root — confirm `handle_path /media/*` uses root `/volume1/Media`; check for extra `/Media/` in URL |
| `403` on valid video | Extension not in allowlist — sync with `indexer.py` |
| `200` instead of `206` on Range | Upstream proxy stripping Range headers; confirm direct to Caddy |
| Certificate errors on phone | Trust Caddy internal CA or use `-k` only for curl debugging |
| Catalogue empty/wrong | Re-run indexer against `/volume1/Media` or sync from Windows scan output |

---

## Phase 1 completion checklist

Before starting Flutter client work (Phase 3):

- [ ] Caddy config deployed with `/volume1/Media` root
- [ ] `/catalog.json` returns 200
- [ ] At least one `/media/...` video returns 200
- [ ] Range request returns **206 Partial Content**
- [ ] Extension allowlist matches indexer
- [ ] Path mapping verified against real catalogue `file_path` values
- [ ] TLS strategy documented for test devices

---

## Next phase

**Phase 2:** Deploy on production TNAS and record hostname + TLS choice.  
**Phase 3:** Flutter `PathResolverService` implementing [path-mapping.md](../architecture/path-mapping.md).

Do **not** start Flutter HTTP/resolver implementation until this checklist passes on the target NAS.

---

## References

| File | Purpose |
|---|---|
| `backend/caddy.config` | Caddy site configuration |
| `backend/indexer.py` | Scanner and extension source of truth |
| `docs/architecture/path-mapping.md` | Canonical URL mapping |
| `ttsplayer.config.json` | Windows dev media roots |
