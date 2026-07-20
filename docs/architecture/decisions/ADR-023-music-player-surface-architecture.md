# ADR-023: Music Player Surface Architecture



**Status:** Accepted

**Date:** 2026-07-19

**Accepted:** 2026-07-20 (M5.3 Step 2 validation)

**Milestone:** M5 Phase 5.0 / 5.3

**Authors:** M5 planning pass

---

## Implementation evidence (acceptance)

| Requirement | Evidence |
|---|---|
| Shared `PlaybackService` authority | `MusicPlayerScreen` uses `PlaybackService` only; no direct `media_kit` in UI |
| Dedicated music surface | `MusicPlayerScreen` with artwork, transport, error/replay states |
| Video screen unchanged | `PlayerScreen` regression tests pass; no queue UI on video |
| Single session | Video replaces music and vice versa; queue cleared on video session |
| Route close stops playback | `onPlayerRouteClosed()` → stop + clear; widget/integration tests |
| Audio excluded from Continue Watching | `isContinueWatchingEligible` gate; coordinator + integration tests |
| Windows validation | `PHASE_53_RUNTIME=1` — single-track (Step 1) and three-track queue (Step 2) |

Flutter suite at acceptance: **730 passed**, 12 skipped, 0 failed.



---



## Context



M4 **`PlayerScreen`** is video-oriented: fullscreen video surface, embedded subtitle/audio track menus, speed control, auto-hide overlays, and keyboard shortcuts tied to video popups ([playback.md](../playback.md)).



Music playback needs queue controls (next/previous, shuffle, repeat), album art prominence, and navigation while listening — without regressing video playback or duplicating resolver/session logic in UI widgets.



Three architectural options were evaluated in [music.md](../music.md#10-playback-and-queue-architecture-options).



---



## Decision



Adopt **staged hybrid (Option C)** for M5:



1. **`PlaybackService` remains sole playback authority** — extend with queue operations and audio session mode; UI widgets do not call `media_kit` directly.



2. **New `MusicPlayerScreen`** (or equivalent route) for audio UX — queue bar, album art, track info, shuffle/repeat.



3. **Existing `PlayerScreen` unchanged** for `media_kind: video` — no queue UI embedded in video layout in M5.



4. **Shared session backend** on Windows — same `media_kit` player instance policy TBD in Gate 0: either single player with mode switch or coordinated stop-before-play; must not leave two simultaneous outputs.



5. **Navigation while playing:** music may continue when user browses library (desktop); video behaviour unchanged.



6. **Future unification** (post-M5) possible if adaptive layout proves maintainable — not in M5 scope.



---



## Rationale



- Video player complexity is high after M4.4; forcing one adaptive screen increases regression risk.

- Queue UX differs materially from video — dedicated layout matches user expectations.

- Service-layer sharing preserves ADR-010 authority model and ADR-013 error taxonomy.



---



## Consequences



### Positive



- Clear test matrix: video regression isolated to `PlayerScreen`

- Music UI can iterate without touching video shortcuts/popups



### Negative



- Two player routes to maintain

- Must define transition if user opens video while music plays (stop music — document in 5.3)



### Neutral



- Diagnostics report active mode (`video` vs `music`)



---



## Alternatives considered



### Alternative A — Single adaptive `PlayerScreen`



**Rejected for M5:** High regression surface; queue + video overlays interact poorly.



### Alternative B — Fully separate `MusicPlaybackService`



**Rejected because:** Duplicates resolver, error mapping, and diagnostics; violates reuse principle.



---



## Related documents



- [music.md](../music.md) · §9–§10

- [playback.md](../playback.md)

- [ADR-010](./ADR-010-playback-state-extensions.md)

- [M5 plan](../../roadmap/m5-plan.md) · Phase 5.3
