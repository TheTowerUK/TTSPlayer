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
| Content expansion | M5–M6 | Music, books (images deferred) |
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

## M4 — User Experience and Platform Integration

**Status:** ✅ Complete — [release summary](../release/m4-release-summary.md) (2026-07-18)

Polish the personal media application: provider management, settings framework, library UX, playback improvements, caching, diagnostics, and release documentation. Builds on M3.5 provider-neutral architecture without replacing filesystem-driven libraries.

→ [M4 plan](./m4-plan.md)
→ [M4 release summary](../release/m4-release-summary.md)
→ [v0.5.0-dev tracker](../release/v0.5.0-dev.md)
→ [Architecture index](../architecture/README.md)

---

## M5 — Music

**Status:** ✅ Complete — tag `m5-complete` / `v0.6.0` (2026-07-24)

Extend TTSPlayer with music catalogue metadata, artist/album/track browsing, queue-based audio playback, listening history, session persistence, and large-library performance hardening — building on M4 platform services without a parallel architecture.

→ [M5 plan](./m5-plan.md)
→ [M5 release summary](../release/m5-complete.md)
→ [Music architecture](../architecture/music.md)
→ [ADR-020–023](../architecture/decisions/README.md#m5--music)

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
