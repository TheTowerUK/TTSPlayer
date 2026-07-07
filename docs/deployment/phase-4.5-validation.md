# Phase 4.5 — HTTPS/TLS Validation Notes

**Status:** Complete — 2026-07-07  
**Scope:** Production validation rules for remote catalogue and media URLs; readable TLS/network errors; TNAS/Caddy smoke-test guidance.

**Hardware validation:** Confirmed on TerraMaster TNAS via `https://ttsplayer.local:8443` — 2026-07-07.

→ [Phase 4 plan](../roadmap/m35-phase-4-plan.md)  
→ [TNAS Caddy checklist](./tnas-caddy-deploy-checklist.md)  
→ [Phase status](./m35-phase-status.md)

---

## Remote URL security rules (client)

Implemented in `client/ttsplayer/lib/services/media_access/remote_url_security.dart`.

| URL scheme | Access mode | Save validation | Runtime fetch |
|---|---|---|---|
| `https://` | Any | Accepted | Accepted |
| `http://` | `localPreferred` | Accepted with **warning** banner | Accepted (LAN/dev) |
| `http://` | `httpRequired` | **Rejected** — must use `https://` | N/A (cannot save) |
| Invalid scheme | Any | Rejected | N/A |

**Defaults unchanged:** built-in config uses local catalogue paths only; no remote URLs until the user saves them in Settings.

**Persisted config:** invalid stored config (e.g. plain HTTP with HTTP required mode) falls back to defaults on load — same behaviour as other validation failures.

---

## Error messages (catalogue fetch)

`RemoteFetchErrors.catalogueLoadMessage()` maps failures to readable banners:

| Failure | User message |
|---|---|
| Timeout | Timed out loading catalogue. Check the URL and network. |
| Socket / network | Network error loading catalogue: … |
| TLS handshake | Secure connection failed — certificate may be untrusted; trust Caddy CA or use a valid certificate |
| Certificate | Certificate error loading catalogue from … |
| HTTP non-200 | HTTP status line from server |

Failed fetches **never replace** the last-good catalogue (graceful degradation unchanged).

---

## TNAS / Caddy production smoke test (Flutter-oriented)

Run after Caddy is serving on `:8443` with `tls internal` (or a trusted public cert).

### 1. Certificate validity

From the dev PC:

```powershell
Invoke-WebRequest -Uri "https://<nas-host>:8443/catalog.json" `
  -SkipCertificateCheck -UseBasicParsing | Select-Object StatusCode
```

Without `-SkipCertificateCheck`, Windows must trust the Caddy internal CA (export from Caddy storage and install to **Trusted Root**), or use a hostname + cert the OS already trusts.

**Pass:** `200` with trusted cert, or `200` with `-SkipCertificateCheck` confirming routing only.

### 2. Catalogue URL (Settings → Remote catalogue URL)

Example:

```
https://MEDIATNAS-B725.fritz.box:8443/catalog.json
```

**Pass:** App loads catalogue on startup/rescan; no dismissible error banner.

### 3. Media base URL (Settings → Remote media base URL)

Example:

```
https://MEDIATNAS-B725.fritz.box:8443/media/
```

Trailing slash required. Must match [path mapping](../architecture/path-mapping.md) — no extra `/Media/` segment.

### 4. Range request playback

Pick a video from the catalogue and play from the detail screen with **HTTP required** mode (or **local preferred** when local path is unavailable).

**Pass:** First frame renders; seek forward/back works (implies **206 Partial Content** from Caddy).

### 5. Settings validation spot-check

| Input | Mode | Expected |
|---|---|---|
| `https://…/catalog.json` | Any | Save succeeds, no warnings |
| `http://…/catalog.json` | Local preferred | Save succeeds, security warning banner |
| `http://…/catalog.json` | HTTP required | Save blocked — use HTTPS |

Restart the app after saving — resolver and catalogue providers are applied at startup.

---

## Acceptance (Phase 4.5)

- [x] HTTPS remote URLs accepted in validation and fetch
- [x] Plain HTTP warned (local preferred) or rejected (HTTP required)
- [x] TLS/certificate/network failures do not crash; readable banners
- [x] Timeout path covered by existing + centralized error mapping
- [x] Unit/widget tests for rules and fetch failures
- [x] Production smoke-test notes in deployment docs
- [x] End-to-end HTTPS validation on physical TNAS — 2026-07-07
- [x] Local/default behaviour preserved

---

## References

| File | Role |
|---|---|
| `remote_url_security.dart` | HTTPS preference and save-time rules |
| `remote_fetch_errors.dart` | Readable catalogue fetch errors |
| `media_provider_settings_screen.dart` | Warning banner for plain HTTP |
| `catalog_service.dart` | TLS-aware error handling in `_load` |
