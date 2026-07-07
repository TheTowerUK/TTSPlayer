# GitHub milestone issues (create on GitHub)

Use **Issues → New issue** (or `gh issue create` when the CLI is available). Suggested labels: `milestone`, `M4` / `M5` / etc.

---

## M4 — Rich Media Libraries

**Title:** `M4: Rich media libraries — image browsing and viewer`

**Labels:** `milestone`, `M4`, `enhancement`

**Body:**

### Summary

First content-domain expansion after M3.5: treat indexed still images as first-class browse and view experiences, still rooted in the user's folder structure.

### Goals

- [ ] Route image items to a dedicated viewer (not `VideoPlayerController`)
- [ ] Full-screen image viewer with prev/next within folder context
- [ ] Image-optimised grid layouts (1:1 / fit) using existing design tokens
- [ ] Search distinguishes video vs image (icon only — no hardcoded category labels)
- [ ] Large folders remain usable (lazy grids)

### Non-goals

- RAW/HEIC, photo editing, AI tagging, virtual libraries, TMDB-style metadata
- Music (M5), books (M6)

### References

- [docs/roadmap/m4-rich-media-libraries.md](../roadmap/m4-rich-media-libraries.md)
- [docs/roadmap/principles.md](../roadmap/principles.md)

### Acceptance

- [ ] Image folders browse and open without regressing video playback
- [ ] `flutter analyze` clean; tests for routing and viewer smoke paths

---

## M5 — Music Library

**Title:** `M5: Music library — audio playback and browsing`

**Labels:** `milestone`, `M5`, `enhancement`

**Body:**

### Summary

Audio playback and library browsing from the existing folder-tree catalogue. Folder names remain labels; no invented “Music” section beyond what exists on disk.

### Goals

- [ ] Index supported audio extensions in scanner (define set in indexer)
- [ ] Audio playback service (separate from video pipeline)
- [ ] Folder/grid browse for audio items
- [ ] Resume or position memory (scope TBD)

### Non-goals

- Spotify-style playlists, lyrics, scrobbling, external metadata APIs

### References

- [docs/roadmap/roadmap.md](../roadmap/roadmap.md#m5--music-library)

### Acceptance

- [ ] Play common formats from local and HTTPS-resolved paths
- [ ] Video and existing dashboard behaviour unchanged

---

## M6 — Books & Comics

**Title:** `M6: Books and comics — reading experience`

**Labels:** `milestone`, `M6`, `enhancement`

**Body:**

### Summary

Reading experience for books and comic archives from user folders. Format support and viewer scope to be refined when M6 is scheduled.

### Goals

- [ ] Define supported formats (e.g. PDF, CBZ — TBD)
- [ ] Reader screen with folder context navigation
- [ ] Graceful handling of missing metadata

### Non-goals

- Calibre integration, store, DRM breaking

### References

- [docs/roadmap/roadmap.md](../roadmap/roadmap.md#m6--books--comics)

---

## M7 — Multi-device Experience

**Title:** `M7: Multi-device ecosystem — remote control and shared state`

**Labels:** `milestone`, `M7`, `enhancement`

**Body:**

### Summary

Multi-device features **after** M3.5 network access is stable on mobile: remote control, discovery, shared resume/history, profiles, cast/TV companion behaviour.

### Goals

- [ ] Define minimum mobile parity (HTTPS browse + play on home network)
- [ ] Remote control / companion protocol (TBD)
- [ ] Shared resume or watch history sync (TBD — local-first default)

### Non-goals

- Cloud accounts, proprietary sync backends without user control

### References

- [docs/roadmap/mobile-delivery.md](../roadmap/mobile-delivery.md)
- [docs/roadmap/roadmap.md](../roadmap/roadmap.md#m7--multi-device-experience)

---

## Optional: GitHub Projects board

1. **Projects → New project → Board**
2. Columns: `Backlog` | `M4` | `M5` | `M6` | `M7` | `In progress` | `Done`
3. Add the issues above; link PRs to issues as work starts.
