# TTSPlayer Milestones

Canonical milestone detail lives in [`docs/roadmap/`](docs/roadmap/).

| Milestone | Theme | Status |
|---|---|---|
| M2 | [First Playable Release](docs/roadmap/roadmap.md#m2--first-playable-release) | ✅ v0.2.0 |
| M3 | [Personal Media Experience](docs/roadmap/m3-personal-media-experience.md) | ✅ v0.3.0 |
| M3.5 | [Network Client Foundation](docs/roadmap/network-client-foundation.md) | ✅ `m3.5-complete` |
| M4 | [User Experience and Platform Integration](docs/roadmap/m4-plan.md) | 🔄 Active — Phase 4.1 complete (`v0.5.0-dev`) |
| M7 | [Multi-device Experience](docs/roadmap/mobile-delivery.md#m7--multi-device-experience) | Planned |

→ [Roadmap principles](docs/roadmap/principles.md)  
→ [Mobile delivery (future — not M3 scope)](docs/roadmap/mobile-delivery.md)

---

## M2 — First Playable Release (v0.2.0)

**Tag:** `v0.2.0`

- First successful end-to-end playback on Windows (media_kit)
- Folder-tree browsing from live or bundled catalogue
- Full rescan with refreshed catalogue reload
- Playback preflight, timeout, resume position, and error recovery

---

## M3 — Personal Media Experience

**Status:** Complete — tag `v0.3.0` / `m3-complete`

### M3 Progress

| Sprint | Focus | Status |
|---|---|---|
| Sprint 1 | Dashboard & Library Foundation | ✓ |
| Sprint 2 | Global Search & Discovery | ✓ |
| Sprint 3 | Artwork & Visual Identity | ✓ |
| Sprint 4 | Polish & Experience Refinement | ✓ |

Sprint checkpoints: `m3-sprint-3`, `m3-complete`. Sprint 4 delivered Featured Folders, Recently Added (`added_at`), dashboard overview, and desktop/a11y polish — see [milestone review](docs/roadmap/m3-milestone-review.md).

→ [Full M3 goals](docs/roadmap/m3-personal-media-experience.md)

---

## M3.5 — Network Client Foundation

**Status:** ✅ Complete  
**Tag:** `m3.5-complete`

### Highlights

- HTTPS catalogue loading
- Provider configuration
- TNAS deployment validation
- HTTP Range playback

→ [M3.5 release snapshot](docs/release/m3.5-media-access-complete.md#deployment-validation--2026-07-07)  
→ [M3.5 goals](docs/roadmap/network-client-foundation.md)  
→ [Mobile delivery overview](docs/roadmap/mobile-delivery.md)

---

## M4 — User Experience and Platform Integration

**Status:** Active development — Phase 4.1 complete  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`

### M4 progress

| Sub-phase | Focus | Status |
|---|---|---|
| **4.1** | Provider Management | ✅ Complete (2026-07-12) |
| **4.2** | Settings Framework | 📋 Next |

### Focus

Polish settings, provider visibility, library browsing, playback controls, performance, and in-app diagnostics — building on M3 personal UX and M3.5 provider-neutral media access.

→ [M4 plan](docs/roadmap/m4-plan.md)  
→ [Phase 4.1 specification](docs/roadmap/m4-phase-4.1-provider-management.md)  
→ [v0.5.0-dev tracker](docs/release/v0.5.0-dev.md)
