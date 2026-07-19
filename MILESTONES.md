# TTSPlayer Milestones

Canonical milestone detail lives in [`docs/roadmap/`](docs/roadmap/).

| Milestone | Theme | Status |
|---|---|---|
| M2 | [First Playable Release](docs/roadmap/roadmap.md#m2--first-playable-release) | ✅ v0.2.0 |
| M3 | [Personal Media Experience](docs/roadmap/m3-personal-media-experience.md) | ✅ v0.3.0 |
| M3.5 | [Network Client Foundation](docs/roadmap/network-client-foundation.md) | ✅ `m3.5-complete` |
| M4 | [User Experience and Platform Integration](docs/roadmap/m4-plan.md) | ✅ `v0.5.0` — [release summary](docs/release/m4-release-summary.md) |
| M5 | [Music](docs/roadmap/m5-plan.md) | 🔄 In progress — Phase 5.1 next |
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

**Status:** ✅ Complete — 2026-07-18
**Branch:** `m4-development`
**Development version:** `v0.5.0-dev`
**Tag (recommended):** `m4-complete` after manual QA sign-off

### M4 progress

| Sub-phase | Focus | Status |
|---|---|---|
| **4.1** | Provider Management | ✅ Complete (2026-07-12) |
| **4.2** | Settings Framework | ✅ Complete (2026-07-12) |
| **4.3** | Library Experience | ✅ Complete (2026-07-13) |
| **4.4** | Playback Improvements | ✅ Complete (2026-07-14) |
| **4.5** | Performance and Caching | ✅ Complete (2026-07-16) |
| **4.6** | Diagnostics and Supportability | ✅ Complete (2026-07-17) |
| **4.7** | Release and Documentation | ✅ Complete (2026-07-18) |

→ [M4 release summary](docs/release/m4-release-summary.md)
→ [M4 plan](docs/roadmap/m4-plan.md)

---

## M5 — Music

**Status:** In progress — Phase 5.0 complete; **Phase 5.1 next**
**Branch:** `m4-development`
**Baseline:** `v0.5.0`

### M5 progress

| Sub-phase | Focus | Status |
|---|---|---|
| **5.0** | Planning and Architecture | ✅ Complete (2026-07-19) |
| **5.1** | Music Catalogue and Metadata | **Next** |
| **5.2** | Music Library Experience | Planned |
| **5.3** | Music Playback and Queue | Planned |
| **5.4** | Music State and Listening History | Planned |
| **5.5** | Performance, Diagnostics and Runtime Validation | Planned |
| **5.6** | Release and Documentation | Planned |

→ [M5 plan](docs/roadmap/m5-plan.md)
→ [Music architecture](docs/architecture/music.md) *(Proposed)*
→ [ADR-020–023](docs/architecture/decisions/README.md#m5--music-proposed)
