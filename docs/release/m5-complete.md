# M5 — Music — Milestone Complete

**Status:** ✅ **COMPLETE** — 2026-07-24  
**Branch:** `m5-development`  
**Baseline:** M4 — `v0.5.0`  
**Recommended tags:** `m5-complete` · `v0.6.0`  
**Application version:** `0.6.0+1`

→ [M5 plan](../roadmap/m5-plan.md)  
→ [Music architecture](../architecture/music.md)  
→ [Phase 5.6 closure](../roadmap/m5-phase-5.6-closure-report.md)  
→ [Release index](./README.md)

---

## 1. Executive summary

Milestone 5 extends TTSPlayer from a polished video-first personal media app into a platform that also supports **music listening**: schema-v3 catalogue indexing with `media_kind` and optional tags, artist/album/track browsing, queue-based audio playback, Continue Listening / Recently Played, persistent playback sessions, and large-library performance hardening.

All seven planned sub-phases (5.0–5.6) are complete. ADR-020–023 are **Accepted**. Automated regression is green (**1138** passed / **14** skipped). Windows Release builds successfully with libmpv. Opt-in runtime harnesses cover Phases 5.3–5.6.

**M5 does not** ship playlists, favourites redesign, shuffle/repeat, lyrics, equaliser, gapless/crossfade, remote metadata APIs, or mobile-specific optimisation — those remain deferred (see §4).

---

## 2. Objectives

| Objective | Outcome |
|---|---|
| Index audio in the existing folder-tree catalogue | ✅ `catalogue_version: 3`, `media_kind`, music metadata |
| Browse by artist / album / track | ✅ Music library surfaces |
| Play with queue next/previous | ✅ Shared `PlaybackService` + music queue |
| Application-managed listening state | ✅ History + session persistence (ADR-022) |
| Reuse M4 infrastructure | ✅ Search, artwork, cache, diagnostics, providers |
| No video regression | ✅ Isolated keys; runtime + suite coverage |
| Scale to ~40k audio | ✅ Phase 5.6 fixtures + runtime |

---

## 3. Delivered scope

### Major features

| Area | Delivered |
|---|---|
| **Music catalogue** | Scanner 0.4.0 · schema v3 · `media_kind` · grouping keys |
| **Metadata** | Tag precedence (ADR-021) · graceful fallbacks |
| **Browsing** | Artists / albums / tracks · detail screens · search presentation |
| **Playback** | Dedicated `MusicPlayerScreen` · audio MediaKit session |
| **Queue** | In-memory queue · next/previous · album/artist seeding |
| **Listening history** | Continue Listening · Recently Played · clear history |
| **Session persistence** | Queue + active track + position across restart (no autoplay) |
| **Performance** | Projection indexes · memoisation · lazy lists · search ownership |
| **Runtime validation** | Opt-in Windows harnesses for 5.3–5.6 |

### Architecture changes

```text
Catalogue (schema v3)
    ↓
MusicLibraryService identity memoisation
    ↓
Immutable MusicLibraryProjection
    ↓
Browse / Search / Artwork
    ↓
PlaybackService + MusicPlaybackQueueController
    ↓
MusicListeningCoordinator → listening history
    ↓
MusicPlaybackSessionCoordinator → session persistence
    ↓
Diagnostics (aggregate, redacted)
```

**Ownership:** catalogue is filesystem truth; projection is derived/immutable/non-persistent; listening and session state are application-managed and isolated from video resume keys.

### ADRs

| ADR | Title | Status |
|---|---|---|
| 020 | Music Catalogue Schema and Media Kind | Accepted (M5.1) |
| 021 | Music Metadata Precedence and Identity | Accepted (M5.1) |
| 022 | Music Queue and Listening State | Accepted (M5.5) |
| 023 | Music Player Surface Architecture | Accepted (M5.3) |

---

## 4. Deferred scope (carried forward)

| Item | Notes |
|---|---|
| Playlists / playlist persistence | Explicit M5 exclusion |
| Favourites redesign (music) | Deferred beyond M5.4 |
| Shuffle / repeat (+ persistence) | Deferred from 5.3/5.6 |
| Autoplay on restore | Explicitly rejected |
| Lyrics, equaliser, gapless, crossfade | Out of scope |
| Remote artwork / MusicBrainz / TMDB | Out of scope |
| Database-backed indexing / isolate projection | Only if future scale requires ADR |
| Mobile-specific music optimisation | M7 / later |
| Video queue persistence | Out of scope |
| Books / comics | **M6** |

---

## 5. Phase summary

| Phase | Status | Evidence | Commit | Verified |
|---|---|---|---|---|
| **5.0** Planning | ✅ Complete | [m5-plan.md](../roadmap/m5-plan.md) · music.md · ADR drafts | `e6fe8f0` | ✅ |
| **5.1** Catalogue & metadata | ✅ Complete | [5.1 spec](../roadmap/m5-phase-5.1-music-catalogue-metadata.md) · ADR-020/021 | `9824f4e` | ✅ |
| **5.2** Library browsing | ✅ Complete | [5.2 spec](../roadmap/m5-phase-5.2-music-library-experience.md) | `b2eb063` | ✅ |
| **5.3** Playback & queue | ✅ Complete | [5.3 spec](../roadmap/m5-phase-5.3-music-playback-queue.md) · ADR-023 · runtime | `5c83f1e` / docs `7c516aa` | ✅ |
| **5.4** Listening history | ✅ Complete | [closure](../roadmap/m5-phase-5.4-closure-report.md) | `26b96dc` | ✅ |
| **5.5** Session persistence | ✅ Complete | [closure](../roadmap/m5-phase-5.5-closure-report.md) · ADR-022 Accepted | `44221ee` | ✅ |
| **5.6** Performance & UX | ✅ Complete | [closure](../roadmap/m5-phase-5.6-closure-report.md) | `314c796` | ✅ |
| **Release / docs** | ✅ Complete | This document | *(closure commits)* | ✅ |

---

## 6. Validation summary

| Validation | Result |
|---|---|
| `flutter analyze` | No new errors (pre-existing infos/warnings only; ~154 findings) |
| Full `flutter test` | **1138 passed** · **14 skipped** · **0 failed** |
| Phase 5.3 runtime (`PHASE_53_RUNTIME`) | Archived harness — music player + queue |
| Phase 5.4 runtime (`PHASE_54_RUNTIME`) | Archived harness — listening history |
| Phase 5.5 runtime (`PHASE_55_RUNTIME`) | Archived harness — session PS1–PS16 |
| Phase 5.6 runtime (`PHASE_56_RUNTIME`) | P56-RT1–RT20 pass; optional live catalogue documented |
| Windows Release build | ✅ `ttsplayer.exe` + `libmpv-2.dll` |
| Documentation review | ✅ Roadmap, architecture, ADRs, release notes reconciled |
| README.md | Intentionally unstaged (separate from milestone commits) |

---

## 7. Architecture summary

Confirmed at closure:

- **Catalogue** remains authoritative (filesystem + scanner).
- **Projection** is derived, in-memory, immutable, generation-scoped, non-persistent.
- **Browse/search** consume the memoised projection; search owns publish generation.
- **Artwork** uses existing candidate precedence + LRU + Flutter `imageCache` + square fallback.
- **Playback** is a single shared `PlaybackService` (audio vs video session modes).
- **History** and **session** persist separately (`ttsplayer_music_listening_v1`, `ttsplayer_music_queue_v1`); video `position_*` keys untouched.
- **Diagnostics** expose aggregates only; exports remain redacted.

---

## 8. Performance summary

Informational workstation medians (Phase 5.6 final):

| Operation | Scale | Median |
|---|---|---|
| Projection build | 1,010 audio | ~5 ms |
| Projection build | 10,010 audio | ~34 ms |
| Projection build | 40,010 audio | ~176 ms |
| Title/artist/album search | 10k | ~4–6 ms |
| Artist list initial pump | 58 artists | ~11 mounted tiles |
| Live catalogue projection | ~42k audio | ~463 ms (optional) |

Correctness is the closure gate; timings remain informational with documented watch bands.

---

## 9. Runtime validation summary

| Harness | Gate | Tag | Outcome |
|---|---|---|---|
| Music player / queue | `PHASE_53_RUNTIME=1` | `phase53-runtime` | Validated M5.3 |
| Listening history | `PHASE_54_RUNTIME=1` | `phase54-runtime` | Validated M5.4 |
| Playback session | `PHASE_55_RUNTIME=1` | `phase55-runtime` | Validated M5.5 |
| Large-library music | `PHASE_56_RUNTIME=1` | `phase56-runtime` | Validated M5.6 |

Harnesses are **archived** (retained in tree, opt-in only — excluded from default suite via env gate).

---

## 10. Test summary

| Suite | Result |
|---|---|
| Default Flutter suite (closure) | 1138 passed / 14 skipped |
| Phase 5.6 focused baselines + hardening | 48 passed / 1 skipped (gate) |
| Phase 5.6 runtime (enabled) | 21 passed (incl. supporting mixed-media) |

---

## 11. Risks

| Risk | Status at closure |
|---|---|
| Missing/inconsistent tags | Mitigated (ADR-021 + UI fallbacks) |
| Large-library UX | Mitigated (5.6 projection/search/list hardening) |
| Queue restore after rescan | Mitigated (session reconcile prune) |
| Video regression | Mitigated (isolated keys + suite coverage) |
| Shuffle/repeat user expectation | **Deferred** — documented as known limitation |
| Duration null from scanner | Known observation — non-blocking |

---

## 12. Lessons learned

### What worked well

- Phased delivery with architecture-first ADRs
- Evidence-first optimisation (baseline → measure → change)
- Deterministic large fixtures without committing media
- Opt-in Windows runtime harness discipline
- Catalogue-as-truth + application-managed listening/session state

### Challenges

- Large-catalogue measurement noise on workstations
- Artwork decode edge cases under `flutter test` (corrupt-byte path excluded)
- Windows MediaKit / libmpv runtime setup for harnesses
- Keeping milestone DoD aligned when features (shuffle/favourites) were intentionally deferred

### Recommendations

- Retain phased methodology and closure reports per phase
- Continue evidence-first performance work
- Preserve env-gated runtime harnesses for future milestones
- Treat deferred music features as an explicit M6+ backlog, not silent gaps

---

## 13. Final verdict

**Milestone 5 is complete and ready to tag.**

Recommended tags:

```text
m5-complete
v0.6.0
```

Next milestone content work: **M6** (books/comics and related expansion) per roadmap — planning only after M5 tags land. Deferred music features may be scheduled independently when approved.

---

## Compatibility / upgrade notes

- Requires scanner **0.4.0+** and **catalogue schema v3** for music. Stale v2 catalogues must be rescanned.
- Existing video libraries, Continue Watching keys, providers, and settings are unchanged.
- Music listening/session preferences are new keys; clearing them does not affect video resume.
- `README.md` may still carry unstaged local edits — review separately before committing.
