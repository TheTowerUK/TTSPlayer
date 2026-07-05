# Release History

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
