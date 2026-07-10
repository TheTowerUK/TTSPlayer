# Playback (M4 planning)

**Status:** Planning — M4 Phase 4.4  
**Related roadmap phase:** [M4 Phase 4.4 — Playback Improvements](../roadmap/m4-plan.md#phase-44--playback-improvements)

→ [Media access abstraction](./media-access-abstraction.md)  
→ [Path mapping](./path-mapping.md)

---

## Purpose

Refine playback UX, multi-track handling, and error presentation on top of M3 playback and M3.5 resolver integration — without reimplementing resume or provider-neutral URI resolution.

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

**Not in baseline:** playback speed UI, subtitle/audio track picker, chapter navigation, refined player chrome, structured playback history beyond Continue Watching.

---

## M4 goals

| Area | Intent |
|---|---|
| Resume UX | Clearer resume prompt; optional start-from-beginning |
| Speed | Variable playback speed where `media_kit` supports it |
| Subtitles | Track selection for supported containers |
| Audio tracks | Multi-audio selection |
| Chapters | Navigate when metadata available |
| History | Refine Continue Watching inputs |
| Errors | Surface resolver, TLS, and 404 context |
| Controls | Improved layout, keyboard shortcuts on desktop |

---

## Proposed responsibilities

| Component | M4.4 role |
|---|---|
| `PlaybackService` | Track APIs, speed, enriched error types |
| Player UI | Controls overlay, track menus |
| Resume store | Evolve existing prefs — same keys where possible |
| `MediaLocationResolver` | Unchanged contract unless HTTPS error detail needs extension |

---

## Data / state considerations

- Resume keys remain per `MediaItem.id`
- Playback history for Continue Watching may share resume store or extend with timestamps
- Speed preference may default from [settings.md](./settings.md)

---

## Failure handling

- Unresolved URI: message distinguishes local missing file vs HTTPS 404 vs TLS failure
- Unsupported track type: disable control; do not crash player
- Seek failure on stream: user-visible message; retain last position

---

## Testing considerations

- Resume read/write unit tests (existing patterns)
- Mock resolver failures for error message copy
- Manual: local MP4 + HTTPS MKV with multiple audio tracks

---

## Open decisions

1. **Chapter support** — `media_kit` capability audit before promising UI?
2. **Subtitle discovery** — external sidecar vs embedded only for v1?
3. **History granularity** — item-level only vs position threshold for Continue Watching?

---

## Out of scope

- Transcoding
- DRM
- Live TV / HLS adaptive streaming (unless already supported incidentally)
- Cast / DLNA

---

## Related documents

- [settings.md](./settings.md)
- [diagnostics.md](./diagnostics.md)
