# Playback (M4 planning)

**Status:** Planning — M4 Phase 4.4 · **Gate 0 complete** (2026-07-13)  
**Related roadmap phase:** [M4 Phase 4.4 — Playback Improvements](../roadmap/m4-phase-4.4-playback-improvements.md)  
**Gate 0 audit:** [m4-phase-4.4-gate0-capability-audit.md](../roadmap/m4-phase-4.4-gate0-capability-audit.md)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [Path mapping](./path-mapping.md)  
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)

---

## Purpose

Refine playback UX, multi-track handling, and error presentation on top of M3 playback and M3.5 resolver integration — without reimplementing resume or provider-neutral URI resolution.

Phase 4.4 follows an extended cadence (see [implementation spec](../roadmap/m4-phase-4.4-playback-improvements.md)):

```
Inventory → Capability Audit (Gate 0) → ADRs → Specification → Implementation
```

Playback depends on **`media_kit`** on Windows. ADRs must not commit to features (e.g. chapters) until the audit confirms the underlying API.

---

## Architectural principles

### PlaybackService is the single authority (since M3)

```
PlayerScreen  →  PlaybackService  →  media_kit | video_player
```

**Player UI reflects `PlaybackService` state; it does not own playback state.**

`PlayerScreen` must not call `media_kit` or `video_player` directly for control operations. Presentation-only UI state (overlay visibility) stays in the widget.

### Three-layer error taxonomy

| Layer | Example message |
|---|---|
| Provider | "HTTPS catalogue unavailable" |
| Resolver | "Media location could not be resolved" |
| Playback | "This video could not be played." |

Each layer describes only its own responsibility. See [Phase 4.4 spec — Error handling](../roadmap/m4-phase-4.4-playback-improvements.md#error-handling--three-layers).

---

## Current baseline (M3 + M3.5)

| Capability | State |
|---|---|
| `PlaybackService` | Windows: `media_kit`; other platforms: `video_player` |
| `MediaLocationResolver` | Resolves catalogue `file_path` → `file://` or HTTPS media URL |
| Resume position | Saved per item in `shared_preferences`; restored on play |
| Preflight / timeout | Playback start guards and error recovery from M2/M3 |
| HTTP Range | Seeking over HTTPS validated on TNAS (M3.5) |
| Player screen | Full-screen playback with basic controls |
| Item status gate | `MediaItemStatus.isPlayable` — single Play button authority |

**Not in baseline:** playback speed UI, subtitle/audio track picker, chapter navigation, player keyboard shortcuts, resolver-aware playback error copy.

Full inventory: [Phase 4.4 spec — Current baseline inventory](../roadmap/m4-phase-4.4-playback-improvements.md#current-baseline-inventory).

---

## Gate 0 — Capability Audit (complete)

| Feature | Outcome |
|---|---|
| Playback speed | **Verified** — `setRate` on Windows local MP4 |
| Audio tracks | **API verified** — switch validated at 4.4 closure with NAS MKV |
| Subtitle tracks | **API verified** — embedded subs; `SubtitleTrack.no()` |
| Chapters | **Defer beyond M4** — no public Dart API |

Full matrix and harness: [Gate 0 audit](../roadmap/m4-phase-4.4-gate0-capability-audit.md).

---

## M4.4 goals (Gate 0 confirmed)

| Area | Intent |
|---|---|
| Resume UX | Clearer resume prompt; preserve existing prefs keys |
| Speed | Variable playback speed where audit confirms `media_kit` support |
| Subtitles | Embedded track selection when audit confirms |
| Audio tracks | Multi-audio selection when audit confirms |
| Chapters | **Deferred beyond M4** |
| Errors | Resolver-aware playback-layer messages |
| Controls | Improved layout, keyboard shortcuts on desktop |

---

## Proposed responsibilities

| Component | M4.4 role |
|---|---|
| `PlaybackService` | Track APIs, speed, enriched error types — **single authority** |
| Player UI | Controls overlay, track menus — **reflects service state only** |
| Resume store | Evolve existing prefs — same keys where possible |
| `MediaLocationResolver` | Unchanged contract; playback layer consumes `ResolvedMediaLocation` |

---

## Data / state considerations

- Resume keys remain per `MediaItem.id`
- Speed preference may default from [settings.md](./settings.md) if speed ships
- Continue Watching continues to use existing resume store

---

## Failure handling

- Unresolved URI: playback layer shows resolver-derived message — not provider dashboard copy
- Unsupported track type: disable control; do not crash player
- Seek failure on stream: user-visible message; retain last position

---

## Testing considerations

- Resume read/write unit tests (existing patterns)
- Mock resolver failures for playback-layer message copy
- Windows runtime harness (Phase 4.4) — pattern from Phase 4.3
- Manual: local MP4 + HTTPS MKV with multiple audio tracks (audit fixtures)

---

## Open decisions (Step 1 specification)

1. **External subtitle sidecars** — defer 4.4 unless NAS VTT audit passes at closure
2. **Default playback speed in settings** — optional if speed ships
3. **HTTPS `setRate`** — re-validate on TNAS before 4.4 closure

---

## Out of scope

- Transcoding
- DRM
- Live TV / HLS adaptive streaming (unless already supported incidentally)
- Cast / DLNA
- Diagnostics export (Phase 4.6)

---

## Related documents

- [M4 Phase 4.4 implementation spec](../roadmap/m4-phase-4.4-playback-improvements.md)
- [M4 Phase 4.4 Gate 0 audit](../roadmap/m4-phase-4.4-gate0-capability-audit.md)
- [settings.md](./settings.md)
- [diagnostics.md](./diagnostics.md)
