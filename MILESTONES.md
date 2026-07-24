# TTSPlayer Milestones

Canonical milestone detail lives in [`docs/roadmap/`](docs/roadmap/).

| Milestone | Theme | Status |
|---|---|---|
| M2 | [First Playable Release](docs/roadmap/roadmap.md#m2--first-playable-release) | ✅ v0.2.0 |
| M3 | [Personal Media Experience](docs/roadmap/m3-personal-media-experience.md) | ✅ v0.3.0 |
| M3.5 | [Network Client Foundation](docs/roadmap/network-client-foundation.md) | ✅ `m3.5-complete` |
| M4 | [User Experience and Platform Integration](docs/roadmap/m4-plan.md) | ✅ `v0.5.0` — [release summary](docs/release/m4-release-summary.md) |
| M5 | [Music](docs/roadmap/m5-plan.md) | ✅ Complete — `v0.6.0` / `m5-complete` (2026-07-24) — [release](docs/release/m5-complete.md) |
| M6 | [Books & Comics](docs/roadmap/m6-plan.md) | 🔄 In progress — Phase 6.0 Planning — [plan](docs/roadmap/m6-plan.md) · [v0.7.0-dev](docs/release/v0.7.0-dev.md) |
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

**Status:** ✅ Complete — 2026-07-24  
**Tag:** `m5-complete` / `v0.6.0`  
**Phase:** Music — catalogue extension, music browsing, audio playback, listening state, search, artwork, performance, diagnostics, release  
**Previous:** M4 complete (2026-07-18)  
**Branch:** `m5-development`  
**Baseline:** `v0.5.0`

### M5 progress

| Sub-phase | Focus | Status |
|---|---|---|
| **5.0** | Planning and Architecture | ✅ Complete (2026-07-19) |
| **5.1** | Music Catalogue and Metadata | ✅ Complete (2026-07-19) |
| **5.2** | Music Library Experience | ✅ Complete (2026-07-19) |
| **5.3** | Music Playback and Queue | ✅ Complete (2026-07-21) |
| **5.4** | Music State and Listening History | ✅ Complete (2026-07-22) |
| **5.5** | Playback Session Persistence | ✅ Complete (2026-07-23) — [spec](docs/roadmap/m5-phase-5.5-playback-session-persistence.md) · [closure](docs/roadmap/m5-phase-5.5-closure-report.md) |
| **5.6** | Music Library Performance, Scale and UX Hardening | ✅ Complete (2026-07-24) — [spec](docs/roadmap/m5-phase-5.6-music-performance-and-ux-hardening.md) · [closure](docs/roadmap/m5-phase-5.6-closure-report.md) |
| **Release** | Release and Documentation | ✅ Complete (2026-07-24) — [m5-complete.md](docs/release/m5-complete.md) |

→ [M5 plan](docs/roadmap/m5-plan.md)  
→ [M5 release summary](docs/release/m5-complete.md)  
→ [Music architecture](docs/architecture/music.md)  
→ [ADR-020–023](docs/architecture/decisions/README.md#m5--music)  

---

## M6 — Books & Comics

**Status:** 🔄 In progress — Phase 6.0 Planning and Architecture (2026-07-24)  
**Branch:** `m6-development`  
**Development tracker:** [v0.7.0-dev](docs/release/v0.7.0-dev.md)  
**Baseline:** M5 — `v0.6.0` / `m5-complete`  
**App version:** remains `0.6.0+1` until an implementation phase bumps it  

### M6 progress

| Sub-phase | Focus | Status |
|---|---|---|
| **6.0** | Planning and Architecture | ✅ Complete |
| **6.1** | Catalogue schema, media kinds, indexer formats (+ RAR/CBR provisional preferred) | ✅ Complete |
| **6.2** | Books & comics library browsing / presentation | Planned |
| **6.3** | Comic archive reader (CBZ **and** CBR required) | Planned |
| **6.4** | Book document reader (PDF/EPUB) | Planned |
| **6.5** | Reading progress and Continue Reading | Planned |
| **6.6** | Performance, diagnostics, and Windows runtime validation | Planned |
| **Release** | M6 release and documentation | Planned |

→ [M6 plan](docs/roadmap/m6-plan.md)  
→ [Books & comics architecture](docs/architecture/books-comics.md)  
→ [ADR-024–027 (Proposed)](docs/architecture/decisions/README.md#m6--books--comics)  
→ **Next:** Phase 6.2  

**Not silent M6 scope:** M5 deferred music features (playlists, shuffle/repeat, favourites redesign, lyrics, etc.) remain a separate backlog — see [m5-complete.md §4](docs/release/m5-complete.md).
