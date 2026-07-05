# M3.5 — Network Client Foundation

**Theme:** Media Access Foundation → Network Catalogue & Provider Configuration  
**Status:** M3.5 **closed** (tag `m3.5-media-access-complete` @ `fa0f66a`) · **Phase 4 active**  
**Architecture impact:** Provider-neutral resolver at playback/artwork boundaries; Phase 4 adds catalogue loading and provider configuration.

→ [M3.5 final acceptance](../release/m3.5-media-access-complete.md#m35-final-acceptance)  
→ [Phase 4 plan](./m35-phase-4-plan.md)  
→ [Pre-implementation review](./m35-pre-implementation-review.md)  
→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [TNAS reference provider checklist](../deployment/tnas-caddy-deploy-checklist.md)  
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
| **2** | TNAS reference HTTP provider validation | ✅ Complete (HTTP :8443) |
| **2.5** | [Media access abstraction](../architecture/media-access-abstraction.md) — **accepted** |
| **3a** | Flutter `MediaLocationResolver` + unit tests | ✅ complete |
| **3b** | Wire resolver into playback and artwork | ✅ complete |
| **4** | [Network catalogue + provider configuration](./m35-phase-4-plan.md) | 🎯 **Active** |

**M3.5 closed** — critical fixes only; all new capability is Phase 4 or backlog.

**Gate before Phase 4:** ✅ satisfied 2026-07-05 — [phase status](../deployment/m35-phase-status.md#exit-criteria-before-phase-4-satisfied-2026-07-05).

---

## Phase 4 — Network Catalogue & Provider Configuration

→ Full plan: [m35-phase-4-plan.md](./m35-phase-4-plan.md)

| Sub-phase | Focus |
|---|---|
| **4.1** | HTTP catalogue provider (`CatalogService.loadFromUrl()`) |
| **4.2** | Media provider configuration model |
| **4.3** | Settings UI |
| **4.4** | Provider selection & fallback |
| **4.5** | HTTPS/TLS refinement and production validation |

**M3.5:** Can TTSPlayer access media through a provider-neutral abstraction? → **Yes.**  
**Phase 4:** How do users configure and use multiple providers seamlessly?

Use the same cadence as M3.5: document first, small testable sub-phases, separate commits, close before moving on.

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
