# TTSPlayer Roadmap

Living milestone plan. Each milestone builds on the previous without changing the core architecture — the filesystem remains the source of truth, and the catalogue reflects the folder tree as-is.

→ **[Roadmap principles](./principles.md)** — how the project evolves (for humans and AI tools)  
→ [Mobile delivery](./mobile-delivery.md) — one app, two access modes

---

## Progression at a glance

| Phase | Milestone | Focus |
|---|---|---|
| Foundation | M1–M2 | Solid playable platform |
| Personal UX | M3 | Polished personal media experience |
| Network access | M3.5 | Network-aware media access |
| Content expansion | M4–M6 | Images, music, books |
| Multi-device | M7 | Multi-device media ecosystem |

---

## M2 — First Playable Release

**Status:** ✅ Complete (v0.2.0)

End-to-end playback on Windows, folder-tree browsing, rescan, resume, and error recovery.

→ [Release notes](../release/release-history.md#v020--first-playable-release)

---

## M3 — Personal Media Experience

**Status:** 🎯 Current

Windows-first polish: library manager, dashboard, Continue Watching, thumbnails, search, diagnostics, Live NAS / Demo visibility. No mobile or network-client work.

→ [M3 goals](./m3-personal-media-experience.md)

---

## M3.5 — Network Client Foundation

**Status:** Planned (bridge — not current scope)

Same Flutter app, HTTP access mode: NAS-hosted `catalog.json`, Caddy/Nginx HTTPS, media streaming with range support, path-to-URL resolver, mobile settings, Android/iOS smoke builds. **Depends on NAS serving layer first.**

→ [M3.5 goals](./network-client-foundation.md)  
→ [Mobile delivery overview](./mobile-delivery.md)

---

## M4 — Image Library

**Status:** Planned

Photo and image browsing from the user's folder structure.

---

## M5 — Music Library

**Status:** Planned

Audio playback and library browsing.

---

## M6 — Books & Comics

**Status:** Planned

Reading experience for books and comic archives.

---

## M7 — Multi-device Experience

**Status:** Planned

Only after M3.5 — mobile can browse and play over HTTPS:

- Remote control
- Device discovery
- Shared resume state and watch history sync
- Profiles
- Cast / TV companion behaviour

→ [Mobile delivery — M7 scope](./mobile-delivery.md#m7--multi-device-experience)
