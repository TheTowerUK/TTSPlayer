# ADR-026: Reader Surface Architecture

**Status:** **Accepted** (2026-07-27)  
**Date:** 2026-07-24 (proposed) / 2026-07-27 (accepted — CBZ-only comic production scope)  
**Milestone:** M6 — Phase 6.3 ✅ **Complete**; Phase 6.4 ✅ **Complete**  
**Related:** [books-comics.md](../books-comics.md) · [ADR-023](./ADR-023-music-player-surface-architecture.md)

---

## Context

Video uses `video_player` / MediaKit on `PlayerScreen`. Music uses a dedicated listening surface and queue (ADR-022/023). Books and comics need paged/document navigation, not continuous A/V playback.

During Phase 6.3, native CBR/RAR support was evaluated (UnRAR CLI and official `UnRAR64.dll` FFI). Engineering validation passed, but bundled redistribution of RARLab binaries was not approved for public distribution. TTSPlayer does not modify the user's library; requiring a proprietary third-party binary for a single archive variant was rejected as a production dependency.

**Final product decision (2026-07-27):** TTSPlayer supports **CBZ** as the production comic archive format. Existing CBR/RAR files are converted externally to ZIP-based CBZ by the library owner, then rescanned.

---

## Decision

1. **Dedicated reader surfaces:** comic reader (`.cbz` only) and book reader (PDF/EPUB).
2. Readers share chrome patterns but not video/music controllers.
3. Open actions route by `media_kind`.
4. All media access uses **MediaLocationResolver**.
5. Comics use `ComicArchiveSource` with in-process lazy CBZ/ZIP only.
6. **CBR/RAR is not supported.** Legacy `.cbr` catalogue items show conversion guidance; Open Comic is disabled. TTSPlayer does not convert archives.
7. CBZ failure modes: missing file, corrupt ZIP, empty archive, unsafe paths — dismissible errors, never crash.
8. **No bundled UnRAR dependency** in builds or packaging.

---

## Validation record

| Format | Status |
|---|---|
| CBZ | Production; unit + Windows runtime validated |
| CBR | Removed from production scope |
| PDF/EPUB | Phase 6.4 complete |
| Reading progress | Phase 6.5 complete |
| Reader hardening | Phase 6.6 complete |

---

## Supersedes

Proposed UnRAR production backend — archived under `docs/architecture/archive/unrar-evaluation/`.
