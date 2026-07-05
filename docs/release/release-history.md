# Release History

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
