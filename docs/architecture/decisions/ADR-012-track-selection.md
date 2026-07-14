# ADR-012: Track Selection

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.4  
**Authors:** M4 documentation pass

---

## Context

Gate 0 verified `media_kit` support for:

- Enumerating audio and subtitle tracks (`state.tracks`, `stream.tracks`)
- Selecting tracks (`setAudioTrack`, `setSubtitleTrack`)
- Disabling subtitles (`SubtitleTrack.no()`)

Gate 0 **deferred**:

- Chapter navigation (no public Dart API)
- External subtitle sidecars (`SubtitleTrack.uri` — not validated for NAS paths in Gate 0)

Phase 4.4 must expose embedded track selection in the player without mutating the catalogue, involving the resolver beyond existing URI resolution, or breaking non-Windows builds.

---

## Decision

1. **Embedded tracks only.** Phase 4.4 UI lists tracks reported by `media_kit` after `open`. No filesystem scan for `.srt` / `.vtt` sidecars; no `SubtitleTrack.uri` for external files.

2. **Windows-first implementation.** Track pickers render only when `PlaybackService` reports non-empty `availableAudioTracks` or `availableSubtitleTracks` on the `media_kit` path. On `video_player` platforms, pickers are **omitted** (not disabled placeholders that error).

3. **Control visibility rules:**

   | Condition | Audio picker | Subtitle picker |
   |---|---|---|
   | Windows + ≥ 2 real audio tracks | Enabled menu | — |
   | Windows + 1 real audio track | Hidden | — |
   | Windows + ≥ 1 embedded subtitle | — | Enabled menu + **Off** entry |
   | Windows + no embedded subs | — | Hidden |
   | Non-Windows | Hidden | Hidden |

4. **Behaviour when media changes** ([ADR-010](./ADR-010-playback-state-extensions.md)):

   - New `play()` clears prior track lists and selections.
   - After `open`, subscribe to `stream.tracks` until stable lists are emitted; update DTOs and `notifyListeners()`.
   - User selection calls `selectAudioTrack` / `selectSubtitleTrack` on the service only.
   - Invalid or stale track id after re-open → no-op with debug log; UI re-syncs from service state.

5. **Resolver independence.** Track selection operates on an already-open player session. `MediaLocationResolver` is unchanged. Resolver failures occur before track APIs are relevant.

6. **No catalogue mutation.** Track metadata is not written to `catalog.json`, favourites, or settings (except speed per ADR-011). Display labels use track `title` / `language` from the player when present; **PlayerScreen** falls back to `Audio N` / `Subtitle N` (1-based index) — not raw backend ids.

7. **External subtitle discovery is outside M4.** Any future sidecar support requires a new Gate audit and ADR — not Phase 4.4.

---

## Rationale

- Embedded-only matches Gate 0 verification and avoids NAS path / HTTPS sidecar edge cases in 4.4.
- Hiding controls when unavailable matches graceful degradation — no dead buttons.
- Per-item reset prevents cross-file track id bugs.

---

## Consequences

### Positive

- Bounded scope; testable with NAS MKV fixtures at closure.
- Clear deferral line for sidecars and chapters.

### Negative

- Users with external subtitle files only see no subtitle picker until a future phase.

### Neutral

- Multi-audio switch runtime validation deferred to Phase 4.4 closure harness (Gate 0 API-verified).

---

## Alternatives considered

### Alternative A — External sidecar discovery in 4.4

**Rejected because:** Gate 0 did not validate NAS HTTPS VTT; increases resolver and filesystem coupling.

### Alternative B — Show disabled pickers on non-Windows

**Rejected because:** Implies capability that does not exist; violates zero-bloat UX.

---

## Related documents

- [Gate 0 capability audit](../../roadmap/m4-phase-4.4-gate0-capability-audit.md)
- [M4 Phase 4.4 specification](../../roadmap/m4-phase-4.4-playback-improvements.md)
- [ADR-010: Playback State Extensions](./ADR-010-playback-state-extensions.md)
- [playback.md](../playback.md)
