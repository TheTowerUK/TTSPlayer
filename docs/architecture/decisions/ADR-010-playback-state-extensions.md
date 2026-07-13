# ADR-010: Playback State Extensions

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.4  
**Authors:** M4 documentation pass

---

## Context

M3 established `PlaybackService` as the sole owner of playback lifecycle: open, seek, pause, resume persistence, and error surfacing. M3.5 added resolver integration at the playback boundary without changing that authority.

Phase 4.4 adds **playback speed** and **embedded audio/subtitle track selection** — capabilities verified in [Gate 0](../../roadmap/m4-phase-4.4-gate0-capability-audit.md). These features introduce new mutable state that must not leak into `PlayerScreen` or other widgets.

Constraints:

- Gate 0 verified `media_kit` APIs on Windows; `video_player` has no equivalent track/speed surface.
- `PlayerScreen` already uses `Consumer<PlaybackService>` and must continue to do so.
- Resume keys (`position_*`, `duration_*`) remain owned by `PlaybackService` — separate from speed/track session state.
- Continue Watching, item detail, and dashboard must observe the same playback truth.

---

## Decision

1. **`PlaybackService` remains the single playback authority.** All control operations flow:

   ```
   PlayerScreen  →  PlaybackService  →  media_kit | video_player
   ```

   Widgets must not import or call `media_kit` / `video_player` for control.

2. **Player UI reflects service state; it does not own playback state.**  
   `PlayerScreen` may hold presentation-only state (overlay visibility, hide timer). It must not cache playback rate, selected track ids, or error kinds locally.

3. **New service-owned session state** (Windows `media_kit` path only unless noted):

   | State | Type | Source |
   |---|---|---|
   | `playbackRate` | `double` | `media_kit` `state.rate`; fixed `1.0` on `video_player` |
   | `availableAudioTracks` | `List<PlaybackAudioTrack>` | Mapped from `state.tracks.audio` (exclude `auto` / `no`) |
   | `availableSubtitleTracks` | `List<PlaybackSubtitleTrack>` | Mapped from `state.tracks.subtitle` (exclude `auto` / `no`) |
   | `selectedAudioTrackId` | `String?` | `state.track.audio.id` |
   | `selectedSubtitleTrackId` | `String?` | `state.track.subtitle.id`; `no` means off |
   | `playbackErrorKind` | `PlaybackErrorKind?` | Playback-layer taxonomy ([ADR-013](./ADR-013-playback-error-taxonomy.md)) |

4. **Client-owned DTOs** — `PlaybackAudioTrack`, `PlaybackSubtitleTrack`, `PlaybackErrorKind` live in the client model layer. `PlayerScreen` consumes DTOs only; no re-export of `media_kit` track types.

5. **New control methods** on `PlaybackService`:

   - `setPlaybackRate(double rate)` — calls `media_kit` `setRate`; no-op on `video_player`
   - `selectAudioTrack(String trackId)` — resolves id → `setAudioTrack`
   - `selectSubtitleTrack(String? trackId)` — `null` or `'no'` → `SubtitleTrack.no()`

6. **Lifecycle and reset behaviour:**

   | Event | Behaviour |
   |---|---|
   | `play(item)` starts | Reset track lists; apply default rate from settings ([ADR-011](./ADR-011-playback-preferences.md)); after `open`, subscribe to track streams and populate DTO lists |
   | `play(item)` same generation | Ignore stale async callbacks via existing `_playGeneration` guard |
   | `stop()` | Dispose player; clear `currentItem`, errors, track lists, session rate override; **do not** clear resume prefs |
   | `retry()` | Same as `play` for current item; preserve explicit `startPosition` when provided |
   | Item completes | Existing position clear unchanged; track/rate state disposed with controller |
   | New item while playing | Full controller dispose + re-init; track selection does not carry over |
   | Platform without track APIs | Empty track lists; rate locked at `1.0`; controls hidden in UI ([ADR-012](./ADR-012-track-selection.md)) |

7. **`notifyListeners()`** fires on rate changes, track list updates, track selection changes, and existing position/buffering/error transitions — same `ChangeNotifier` contract as M3.

---

## Rationale

- Centralising speed and track state prevents divergence between player chrome, detail screen, and Continue Watching entry points.
- DTO mapping isolates `media_kit` from UI and keeps Gate 0 verification bounded to the service layer.
- Reset-on-new-item avoids applying wrong audio/subtitle ids across files.
- Reusing `_playGeneration` matches existing async-safe `play()` semantics.

---

## Consequences

### Positive

- Clear extension point for Phase 4.4 without rewriting M3 resume behaviour.
- Testable service contract independent of widget layout.
- Non-Windows platforms degrade gracefully (no crash, no fake controls).

### Negative

- `PlaybackService` grows; must stay cohesive and resist feature creep (chapters, external subs deferred).
- Track list population is async after `open` — UI must handle empty → populated transition.

### Neutral

- Session rate override vs settings default is specified in ADR-011.

---

## Alternatives considered

### Alternative A — Track state in `PlayerScreen`

**Rejected because:** Violates M3 authority model; duplicates state when entering from Continue Watching vs detail; harder to test.

### Alternative B — Separate `PlaybackTrackService`

**Rejected because:** Over-engineering for 4.4; splits lifecycle that must stay aligned with open/dispose in one service.

---

## Related documents

- [M4 Phase 4.4 specification](../../roadmap/m4-phase-4.4-playback-improvements.md)
- [Gate 0 capability audit](../../roadmap/m4-phase-4.4-gate0-capability-audit.md)
- [ADR-011: Playback Preferences](./ADR-011-playback-preferences.md)
- [ADR-012: Track Selection](./ADR-012-track-selection.md)
- [ADR-013: Playback Error Taxonomy](./ADR-013-playback-error-taxonomy.md)
- [playback.md](../playback.md)
