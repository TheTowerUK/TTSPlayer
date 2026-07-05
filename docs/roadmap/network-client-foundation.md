# M3.5 — Network Client Foundation

**Theme:** Network Client  
**Status:** Current milestone — `v0.4.0-dev` development cycle  
**Architecture impact:** Adds HTTP access mode to the existing Flutter client; does **not** change catalogue schema or filesystem-first indexing.

→ [Pre-implementation review](./m35-pre-implementation-review.md)  
→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [TNAS deploy checklist](../deployment/tnas-caddy-deploy-checklist.md)  
→ [Phase status](../deployment/m35-phase-status.md)  
→ [Mobile delivery overview](./mobile-delivery.md)

---

## Purpose

Enable the **same Flutter app** to browse and play media on iOS and Android without coupling to TNAS, Caddy, SMB, or any single storage backend. Network access uses a **provider-neutral** resolver; TNAS + Caddy is the first reference HTTP deployment.

This milestone exists **between** M3 (Windows-first polish) and M7 (true multi-device). It is not a separate app and not a rewrite.

---

## Implementation phases

| Phase | Scope |
|---|---|
| **1** | Serving-layer docs, `caddy.config`, local validation — ✅ complete |
| **2** | TNAS deployment smoke tests — optional reference HTTP deployment |
| **2.5** | [Media access abstraction](../architecture/media-access-abstraction.md) — **required before Flutter resolver** |
| **3** | Flutter `MediaLocationResolver` — blocked until Phase 2.5 **accepted** |

**Gate:** No player or network startup code changes until [media access abstraction](../architecture/media-access-abstraction.md) is accepted.

---

## Goals

| Area | Goal |
|---|---|
| NAS catalogue | `catalog.json` hosted and reachable over HTTPS |
| Serving layer | Caddy on TNAS — [deployment guide](../deployment/tnas-serving-layer.md); reference HTTP provider only |
| Media access | Provider-neutral [MediaLocationResolver](../architecture/media-access-abstraction.md) |
| HTTP mapping | [path-mapping.md](../architecture/path-mapping.md) rules inside `HttpServingProvider` |
| Mobile settings | Configure media roots, base URL, and active access provider |
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
