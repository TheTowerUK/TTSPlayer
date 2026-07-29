# Mobile Delivery — Future Roadmap Note

**Status:** Planned (not active scope)  
**Depends on:** NAS HTTPS serving layer — **not** on additional UI work in M3  
**Architecture:** Same Flutter codebase, different access mode — **not** a separate app or rewrite

---

## Why this document exists

M3 is Windows-first polish on the existing local/UNC model. Mobile support is a real and agreed direction, but it must not pull M3 into premature platform work.

Mobile delivery **starts with infrastructure on the NAS**, then a bridge milestone (M3.5), then metadata enrichment (M7), then multi-device features (M8). UI patterns built in M3 (folder tree, dashboard, Continue Watching) carry forward; the access layer changes.

→ [Roadmap principles](./principles.md)  
→ [M3 — Personal Media Experience](./m3-personal-media-experience.md)  
→ [M3.5 — Network Client Foundation](./network-client-foundation.md)  
→ [M7 metadata enrichment](./m7-plan.md) · [M8 in roadmap](./roadmap.md#m8--multi-device-experience)

---

## Core architectural rule

**One Flutter app. Two access modes.**

| | Windows (desktop) | Mobile (iOS / Android) |
|---|---|---|
| **Catalogue** | Local file or UNC path | HTTPS URL from NAS |
| **Playback** | Local / UNC file paths | HTTPS media streams |
| **Scanner** | Local Python subprocess (optional) | **None** — refresh catalogue from NAS |
| **Rescan trigger** | In-app rescan | NAS-side scan; app reloads `catalog.json` |

The catalogue JSON schema and folder tree remain unchanged. The filesystem is still the source of truth; the indexer still runs on the NAS or a desktop machine. Mobile clients **consume** the catalogue — they do not scan the filesystem.

---

## Prerequisite: NAS serving layer

Mobile support is blocked until the home network can serve:

1. **`catalog.json`** over HTTPS (and optionally `scan.history.json` later)
2. **Media files** over HTTPS with **byte-range** support for seeking
3. **Thumbnails** over HTTPS when available

This is the role of **Caddy or Nginx** on the TNAS (see `backend/caddy.config`). No Node/Express backend is required — static file serving plus HTTPS is sufficient for v1 mobile playback.

Scanning stays on the NAS (scheduled, manual, or triggered from Windows). Mobile devices pull an updated catalogue; they never run `indexer.py`.

---

## M3.5 — Network Client Foundation (bridge milestone)

Bridge work before true multi-device behaviour (M8). Acceptance is **smoke builds that browse and play over the network**, not App Store polish.

| Area | Deliverable |
|---|---|
| NAS hosting | `catalog.json` served reliably over HTTPS |
| Proxy | Caddy/Nginx config deployed and documented |
| Streaming | HTTP range requests verified for supported video formats |
| Path resolver | Map catalogue `file_path` (e.g. `Y:\Media\Videos\foo.mp4`) → stream URL |
| Mobile settings | NAS base URL, catalogue URL (Settings UI or interim config) |
| Platform targets | Android / iOS Flutter targets enabled; smoke builds on home Wi‑Fi |
| Scanner | Local scanner **disabled** on mobile with clear UX |
| Resilience | Cached last-good catalogue; bounded HTTP timeouts |
| Playback | `video_player` + network URLs (already the non-Windows path) |

**Explicitly not in M3.5:** remote control, device discovery, cast, profiles, shared sync — those belong to M8.

---

## M8 — Multi-device Experience

Only after mobile can browse and play over HTTPS:

| Area | Goal |
|---|---|
| Remote control | Control playback on another device |
| Device discovery | Find players on the home network |
| Shared resume | Resume position synced across devices |
| Watch history sync | Aggregated history beyond local `shared_preferences` |
| Profiles | Per-user preferences and history |
| Cast / TV companion | Phone as remote for TV playback |

---

## What already exists in the codebase

These reduce M3.5 risk — they are starting points, not finished mobile delivery:

- `CatalogService.loadFromUrl()` — remote catalogue fetch
- `VideoPlayerController.networkUrl()` — HTTP playback
- `video_player` as the non-Windows playback backend
- Graceful degradation — preserve last-good catalogue on fetch failure
- TV-friendly layout rules — useful for Android TV / future tvOS

What is **not** mobile-ready today:

- Default startup assumes `Y:\Media\catalog.json` or UNC
- `ScannerService` spawns Python (Windows desktop only)
- No path-to-URL resolver for catalogue `file_path` values
- No `android/` / `ios/` platform folders in the Flutter project yet

---

## Sequencing guardrail

```
M3 (Windows polish, local/UNC)
    ↓
NAS HTTPS serving layer (infra — can start in parallel with late M3)
    ↓
M3.5 (network client — same app, HTTP access mode)
    ↓
M4–M6 (media type expansion — independent axis)
    ↓
M7 (optional metadata enrichment — independent axis)
    ↓
M8 (multi-device experience)
```

**Do not** start M3.5 platform work until the NAS can serve catalogue + media over HTTPS on the home network. UI work alone does not unblock mobile.

---

## Settings split (future)

| Platform | Settings focus |
|---|---|
| Windows | Drive letter path, UNC path, catalogue file location |
| Mobile | NAS base URL, catalogue URL, HTTPS trust / auth if needed |

Full Settings UI is deferred from M3. Windows paths remain in `ttsplayer.config.json` until Settings ships.
