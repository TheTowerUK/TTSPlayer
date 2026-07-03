# M3.5 — Network Client Foundation

**Theme:** Network Client  
**Status:** Planned (bridge milestone — not current scope)  
**Architecture impact:** Adds HTTP access mode to the existing Flutter client; does **not** change catalogue schema or filesystem-first indexing.

→ [Mobile delivery overview](./mobile-delivery.md)  
→ [Full roadmap](./roadmap.md)

---

## Purpose

Enable the **same Flutter app** to browse and play media on iOS and Android by switching from local/UNC paths to HTTPS catalogue and media streams.

This milestone exists **between** M3 (Windows-first polish) and M7 (true multi-device). It is not a separate app and not a rewrite.

---

## Goals

| Area | Goal |
|---|---|
| NAS catalogue | `catalog.json` hosted and reachable over HTTPS |
| Serving layer | Caddy or Nginx deployed on TNAS; range requests for video |
| Path resolver | Translate scanner `file_path` values to stream URLs |
| Mobile settings | Configure NAS base URL and catalogue endpoint |
| Platform targets | Android / iOS smoke builds on home network |
| Scanner | Disable local subprocess scanner on mobile; reload from NAS |
| Cache | Retain last-good catalogue when network fetch fails |
| Diagnostics | Surface network vs demo vs live NAS status on mobile |

---

## Success criteria

M3.5 is done when:

1. A phone on home Wi‑Fi loads `catalog.json` from the NAS over HTTPS
2. Tapping Play streams a video with working seek (range requests)
3. Rescan is not offered on mobile; catalogue refresh pulls the latest NAS file
4. A failed fetch preserves the previous catalogue and shows a recoverable error
5. Windows desktop behaviour is unchanged (local/UNC + local scanner still work)

---

## Explicitly out of scope

- Remote control, cast, device discovery → M7
- App Store / Play Store release polish (can follow once smoke builds pass)
- Running `indexer.py` on the device
- SMB drive mounting on iOS
- New media types (images, music, books) → M4–M6
