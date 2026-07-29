# Release History

## M6 — Books & Comics

**Version:** `v0.7.0`
**Milestone:** M6 — **Complete** 2026-07-29
**Tags:** `v0.7.0` / `m6-complete`

### Added

- Catalogue schema v4 and scanner 0.5.0 with `book` and `comic` media kinds
- Book/comic browse filters, search presentation, and detail actions
- CBZ comic reader (lazy archive, fit modes, progress, per-page resilience)
- PDF and EPUB book readers on Windows
- Shared reading progress repository and Continue Reading (ADR-027)
- Reader diagnostics and hardening (cache bounds, lazy loaders)
- Opt-in Windows runtime harnesses P62–P66

### Changed

- ADR-024–027 Accepted; production comics **CBZ-only** (ADR-026)
- CBR/RAR native support removed; external conversion guidance for legacy items

### Known limitations

- CBZ-only comics; convert CBR externally and rescan
- EPUB full-archive memory model for very large files
- No bookmarks, annotations, dual-page, RTL, or cloud sync
- PDF password UI deferred

→ [M6 complete](./m6-complete.md)

---

## M5 — Music

**Version:** `v0.6.0`  
**Milestone:** M5 — **Complete** 2026-07-24  
**Tags:** `v0.6.0` / `m5-complete`

### Added

- Music catalogue indexing (`media_kind`, schema v3, scanner 0.4.0)
- Artist / album / track browsing and detail surfaces
- Dedicated music player with in-memory queue (next/previous, album/artist seeding)
- Continue Listening and Recently Played (music-only persistence)
- Playback session persistence (queue, active track, position; no autoplay)
- Large-library performance fixtures, projection indexes, search/list hardening
- Opt-in Windows runtime harnesses for Phases 5.3–5.6

### Changed

- ADR-020–023 Accepted; music projection memoised by catalogue identity
- Diagnostics extended with music listening and playback-session aggregates (redacted)

### Known limitations

- No shuffle/repeat, playlists, or music favourites redesign
- Stale schema-v2 catalogues require rescan for music
- Some scanner durations may be null until MediaKit loads the file

→ [M5 complete](./m5-complete.md)

---

## M4 — User Experience and Platform Integration

**Date:** July 2026  
**Milestone:** M4 — **Complete** 2026-07-18  
**Tag:** `m4-complete` (recommended after manual QA sign-off)

→ [Full release snapshot](./m4-release-summary.md)  
→ [Phase 4.7 closure spec](../roadmap/m4-phase-4.7-release-documentation.md)

### Added

- Provider Management — health model, status panel, refresh/retry (ADR-001–003)
- Settings Framework — versioned envelope, grouped UI, migration (ADR-004–006)
- Library Experience — favourites, sort/filter, breadcrumbs, search presentation (ADR-007–009)
- Playback Improvements — speed, audio/subtitle tracks, error taxonomy (ADR-010–013)
- Performance and Caching — cache invalidation, artwork LRU, search index lifecycle (ADR-014–016)
- Diagnostics and Supportability — runtime snapshot, read-only UI, clipboard export (ADR-017–019)

### Validation (2026-07-18)

- `flutter test`: **624 passed**, **8 skipped**
- Six Windows runtime harness suites (Phases 4.1–4.6)
- `flutter analyze`: **89** baseline findings; no new M4 errors

### Deferred (not blockers)

- Continue Watching artwork stretch — dashboard UX polish
- Dashboard card consistency — future UX pass
- Manual Windows QA checklist — execute before tag

---

## M3.5 – Media Access Foundation

**Date:** July 2026  
**Milestone:** M3.5 — **Accepted** 2026-07-05  
**Tag:** `m3.5-media-access-complete`

→ [Full release snapshot](./m3.5-media-access-complete.md)  
→ [Final acceptance](./m3.5-media-access-complete.md#m35-final-acceptance)

### Added

- Provider-neutral media access architecture
- `MediaLocationResolver` with local filesystem and HTTP serving providers
- Playback and artwork integration at consumption boundaries
- Canonical path mapping specification
- Caddy reference serving layer and TNAS deployment docs
- Resolver and integration unit tests

### Acceptance (2026-07-05)

- Windows regression: **PASS**
- TNAS reference HTTP provider validated on `:8443` (TLS deferred)
- Artwork: functional; discovery observation tracked in backlog (non-blocking)

Phase 4 may begin.

### Not included (Phase 4+)

- HTTP catalogue loading
- Runtime provider selection UI
- Scanner changes

### Deferred (not required for M3.5 acceptance)

- HTTPS / `tls internal` on TNAS
- HTTP catalogue loading, provider settings UI (Phase 4)

---

## v0.3.0 – Personal Media Experience

**Date:** July 2026  
**Milestone:** M3  
**Tag:** `m3-complete` / `v0.3.0`

→ [Full release snapshot](./v0.3.0.md)

### Added

- Dashboard overview panel (scan summary, totals, largest library)
- Recently Added section powered by indexer `added_at`
- Featured Folders section (catalogue-driven ranking)
- Global search with Ctrl+F shortcut
- Artwork pipeline (`ArtworkService`, sidecar rules, design tokens)
- Premium card components and live Continue Watching refresh
- Library Manager and scoped library rescan
- Item status model in catalogue and client

### Changed

- Indexer bumped to 0.3.3 with `added_at` merge on full and library rescans
- Dashboard unified scroll layout with visible carousel scrollbars
- Artwork sidecars excluded from video folder listings

### Fixed

- Dashboard vertical scroll on constrained windows
- Continue Watching updates without app restart
- Scoped scan preserves folder context after library rescan

---

## v0.2.0 – First Playable Release

**Date:** July 2026  
**Milestone:** M2

### Added

- Local media scanner
- Folder reflection
- Catalogue versioning
- NAS support
- Video playback
- Resume playback
- Dashboard
- Premium UI framework

### Changed

- Scanner rewritten for folder tree architecture
- Atomic catalogue writes
- Live progress reporting

### Fixed

- Windows playback implementation
- Rescan stability
- Graceful scanner recovery
- Playback timeout handling
