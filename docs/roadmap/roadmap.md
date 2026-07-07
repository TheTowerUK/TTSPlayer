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

**Status:** ✅ Complete (v0.3.0)

Windows-first polish: library manager, dashboard, Continue Watching, thumbnails, search, diagnostics, Live NAS / Demo visibility.

→ [M3 goals](./m3-personal-media-experience.md)  
→ [Release snapshot](../release/v0.3.0.md)

---

## M3.5 — Network Client Foundation

**Status:** ✅ Complete — [`m3.5-complete`](../release/m3.5-media-access-complete.md#deployment-validation--2026-07-07) (2026-07-07)

HTTPS catalogue loading, provider configuration UI, startup provider selection, and end-to-end validation on TerraMaster TNAS + Caddy. Android/iOS home-network smoke builds remain optional follow-up.

→ [M3.5 release snapshot](../release/m3.5-media-access-complete.md)  
→ [Phase 4 plan](./m35-phase-4-plan.md)  
→ [Development cycle](../release/v0.4.0-dev.md)  
→ [Mobile delivery overview](./mobile-delivery.md)

---

## M4 — Rich Media Libraries

**Status:** Planned — [detailed goals](./m4-rich-media-libraries.md)

Photo and image browsing from the user's folder structure. Builds on M3 artwork and folder navigation; documented during M3 Sprint 4 closure.

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
