# M4 Phase 4.4 — Playback Improvements (Implementation Specification — Draft)

**Status:** **Planning** — Gate 0 (Capability Audit) **not complete**  
**Milestone:** M4 — User Experience and Platform Integration  
**Branch:** `m4-development`  
**Development version:** `v0.5.0-dev`  
**Predecessor:** M4 foundation complete — [snapshot](../release/m4-foundation-complete.md) (Phases 4.1–4.3 closed 2026-07-13)  
**Implementation baseline:** playback unchanged since M3.5 closure; refine only — do not rebuild

→ [M4 plan](./m4-plan.md#phase-44--playback-improvements)  
→ [Playback architecture](../architecture/playback.md)  
→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)  
→ [v0.5.0-dev release tracker](../release/v0.5.0-dev.md)

**ADRs:** *Pending Gate 0* — no playback ADRs accepted until capability audit is complete.

Follow the M4 cadence extended for playback:

```
Inventory (this document)
        ↓
Capability Audit (Gate 0)
        ↓
ADRs
        ↓
Specification (finalise steps, acceptance criteria, validation matrix)
        ↓
Implementation
```

Phases 4.1–4.3 were entirely application architecture. Phase 4.4 depends heavily on **what `media_kit` (and secondarily `video_player`) can actually do on Windows**. ADRs must not promise features (e.g. chapter navigation) before the audit confirms the underlying API.

---

## Objective

Make playback **enjoyable and diagnosable** on top of the trustworthy foundation from Phases 4.1–4.3 — without reimplementing resume, resolver integration, or provider/settings behaviour.

| M4 first half (4.1–4.3) | M4 second half (4.4+) |
|---|---|
| Trustworthy providers, settings, libraries | Playback UX, responsiveness, diagnostics, release quality |
| Application-owned architecture | Player-stack-grounded capabilities |

---

## Architectural principles

### PlaybackService remains the single authority (since M3)

`PlaybackService` owns playback state: current item, position, duration, playing/buffering/completed, errors, and (when added) speed and track selection.

**Required call chain:**

```
PlayerScreen  →  PlaybackService  →  media_kit | video_player
```

**Forbidden:**

```
PlayerScreen  →  media_kit   // bypasses service
PlayerScreen  →  video_player
```

`PlayerScreen` may hold **presentation-only** state (e.g. controls overlay visibility, hide timer). It must not duplicate or own playback state that belongs in the service.

> **Player UI reflects `PlaybackService` state; it does not own playback state.**

This separation has served the project since M3. It becomes critical when adding playback speed, subtitle/audio track pickers, buffering presentation, retry, and chapters — otherwise state leaks into widgets and diverges across surfaces (detail screen, Continue Watching, player).

### Resolver and catalogue boundaries unchanged

- `MediaLocationResolver` resolves catalogue `file_path` → playable URI at the playback boundary.
- `CatalogService` / provider layer remain responsible for catalogue availability.
- Phase 4.4 does not change `catalog.json` schema or indexer output.

### Resume store evolution, not replacement

Resume keys (`position_*`, `duration_*` in `shared_preferences`) and `ResumeInfo` / Continue Watching logic already ship in M3. Phase 4.4 **refines** UX and may extend metadata — it does not reimplement persistence from scratch.

---

## Error handling — three layers

Each layer explains **only its own responsibility**. Do not surface provider catalogue diagnostics inside the player, or player codec messages inside the library manager.

| Layer | Owner | Example user message | When shown |
|---|---|---|---|
| **Provider** | `CatalogService`, dashboard Provider Status | "HTTPS catalogue unavailable" | Catalogue load / refresh failures |
| **Resolver** | `MediaLocationResolver` | "Media location could not be resolved" | `ResolvedMediaLocation` not playable before player init |
| **Playback** | `PlaybackService` | "This video could not be played." | Open/init/seek/decode failures after URI is resolved |

**Phase 4.4 intent:** enrich playback-layer messages with **resolver-aware context** where the failure is still a playback-boundary problem (e.g. local file missing after scan, HTTPS 404/TLS/timeout) — without mixing in catalogue-provider operational copy.

Provider and resolver messages stay on browse/settings surfaces unless the user is already in a playback flow, in which case the player shows the **playback-layer** wording derived from resolver/playback status — not raw provider diagnostics.

---

## Phase steps

| Step | Name | Status | Output |
|---|---|---|---|
| **0** | **Capability Audit** | **Gate 0 — in progress (this doc)** | Verified API matrix; design decisions for in/out of 4.4 |
| **1** | Specification | Blocked on Step 0 | Final acceptance criteria, validation matrix, step breakdown |
| **2** | ADRs | Blocked on Step 0 | Accepted decisions only for audited capabilities |
| **3** | PlaybackService extensions | Not started | Speed, tracks, enriched errors, buffering hooks — per audit |
| **4** | Player UI | Not started | Controls, pickers, keyboard shortcuts — reflects service state |
| **5** | Tests | Not started | Unit + widget tests; mock resolver failures |
| **6** | Windows runtime validation | Not started | Opt-in harness (`PHASE_44_RUNTIME=1`) — pattern from 4.3 |
| **7** | Closure | Not started | Update `playback.md`, release tracker, phase status in `m4-plan.md` |

---

## Gate 0 — Capability Audit

**Purpose:** Ground Phase 4.4 in verified player capabilities before ADRs or the final specification commit to features.

**Audit chain:**

```
PlaybackService (required surface)
        ↓
media_kit ^1.2.6 (Windows primary)
video_player (non-Windows fallback — note gaps)
        ↓
Supported API / Unsupported API / Unknown
        ↓
Design decisions (in 4.4 vs defer)
```

### Pre-audit matrix (package inspection + prior analysis)

*Statuses: **Verified** (runtime or API confirmed), **Probably** (API exists; runtime not yet validated on TNAS fixtures), **Unknown** (no stable Dart API or behaviour unconfirmed), **N/A** (non-Windows `video_player` path).*

| Capability | Windows (`media_kit` 1.2.6) | Non-Windows (`video_player`) | Audit action |
|---|---|---|---|
| Play / pause / seek | **Verified** — shipped M3 | **Verified** — shipped M3 | No audit needed |
| Buffering state | **Verified** — `state.buffering` wired | **Verified** — `value.isBuffering` | No audit needed |
| Resume / position persist | **Verified** — `shared_preferences` | Same | No audit needed |
| HTTPS seek (Range) | **Verified** — M3.5 TNAS validation | Platform-dependent | No audit needed for 4.4 |
| **Playback speed** | **Probably** — `Player.setRate(double)` in public API | **N/A / limited** — no first-class speed API in `video_player` | Runtime: local MP4 + HTTPS MKV; confirm rate persists across pause/seek |
| **Audio tracks** | **Probably** — `setAudioTrack`, `state.tracks.audio`, `stream.tracks.audio` | **Unknown / likely unsupported** | Runtime: multi-audio MKV; list tracks after `open`; switch and confirm output |
| **Subtitle tracks** | **Probably** — `setSubtitleTrack`, embedded + `SubtitleTrack.uri` | **Unknown / likely unsupported** | Runtime: embedded subs + optional external VTT; confirm disable (null track) |
| **Chapters** | **Unknown** — no chapter types/methods in `media_kit` public `Player` API; only low-level libmpv `MPV_EVENT_CHAPTER_CHANGE` in generated bindings | **N/A** | Spike: ffprobe chapter metadata vs any mpv property workaround; **do not ADR chapter UI until resolved** |
| External subtitle sidecars | **Probably** — `SubtitleTrack.uri` | **Defer** | Confirm NAS HTTPS path + local file; out of scope if audit shows fragility |
| Screenshot / frame grab | API exists (`screenshot`) | N/A | Out of 4.4 scope |
| Keyboard shortcuts | Application concern | Application concern | Design in Step 1; no player API audit |

### Audit completion criteria (Gate 0 exit)

- [ ] Each **Probably** row has a Windows runtime note (pass/fail/limitation) on at least one fixture file.
- [ ] **Chapters** row resolved to **Supported**, **Unsupported**, or **Defer beyond M4** with written rationale.
- [ ] Platform matrix documented: which 4.4 features are **Windows-only** vs gracefully hidden on `video_player` platforms.
- [ ] `PlaybackService` extension surface drafted (method names, state fields, error enums) — still no UI work.
- [ ] Proposed ADR list revised to match audit outcomes only.

Until exit criteria are met, sections below labelled *provisional* are inventory and intent only.

---

## Current baseline inventory

*Everything in this section is **already shipped** unless marked **not wired**.*

### Playback stack

| Piece | Location | Behaviour |
|---|---|---|
| Platform gate | `services/playback_platform.dart` | `useMediaKitPlayback` → Windows desktop uses `media_kit`; else `video_player` |
| Authority | `services/playback_service.dart` | `ChangeNotifier`; ~800 lines; dual backend init/dispose |
| Player UI | `screens/player_screen.dart` | `Consumer<PlaybackService>`; calls service only |
| Detail entry | `screens/item_detail_screen.dart` | Resume / Start over → `PlayerScreen(startPosition: …)` |
| Continue Watching | `features/dashboard/widgets/continue_watching_section.dart` | `getContinueWatching(catalog)` → `PlayerScreen` |
| Resolver | `services/media_access/media_location_resolver.dart` | Invoked inside `play()`; unresolved → error before player init |

### Resume and Continue Watching

| Feature | Implementation |
|---|---|
| Position keys | `position_{itemId}`, `duration_{itemId}` in `shared_preferences` |
| Throttled save | Every 5 s while playing; flush on pause/stop |
| Clear on complete | Position cleared when `isCompleted` |
| `ResumeInfo` | `minResumePosition` 30 s; `nearEndWindow` 2 min; `shouldOffer` gate |
| Detail UX | "Resume from *m:ss*" + "Start from beginning" when `shouldOffer` |
| Auto-resume in `play()` | When `startPosition == null`, seeks to saved position if eligible |
| Continue Watching | Max 8 by saved position desc; requires playable item in catalogue |
| Dashboard refresh | `resumeDataVersion` bumps on persist/clear |

### Playback controls (player chrome)

| Control | Status |
|---|---|
| Play / pause | Wired |
| Seek bar | Wired |
| −10 s / +30 s | Wired |
| Buffering indicator | Wired (overlay text + spinner) |
| Auto-hide overlay | 4 s timer; pinned while init/buffering/error |
| Preparing / error / completed views | Wired |
| Retry | `service.retry()` |
| Back / stop | `stop()` on dispose and back |
| **Playback speed** | **Not wired** |
| **Audio track picker** | **Not wired** |
| **Subtitle track picker** | **Not wired** |
| **Chapter navigation** | **Not wired** |
| **Keyboard shortcuts** | **Not wired** (dashboard has `Ctrl+F`; player has none) |
| Artwork in player | Not present (browse/detail only via `ArtworkService`) |

### Error and preflight handling

| Stage | Behaviour |
|---|---|
| Item status | `MediaItemStatus.isPlayable` gate in `play()` |
| Resolver | `!location.isPlayable` → `location.errorReason` or `playbackFailedMessage` |
| Local presence | `checkFilePresence` before init; missing file → dedicated message |
| Init timeout | 15 s on `open` / `initialize` / duration probe |
| Friendly mapping | `_friendlyError` — timeout, missing file, permission, network, codec hints |
| Player copy | `playbackFailedMessage` + `playbackFailedNote` on error view |
| Logging | Structured `[PlaybackService]` debug lines; init probe labels |

**Gap vs three-layer model:** resolver failures sometimes surface through playback messages (correct layer placement) but copy is not yet consistently resolver-aware across all `ResolvedMediaLocation` statuses.

### Tests (existing)

| File | Coverage |
|---|---|
| `test/playback_preflight_test.dart` | File presence, resolver gate, init probe labelling |
| `test/continue_watching_test.dart` | Resume eligibility, dashboard entries, `resumeDataVersion` |
| `test/dashboard_service_test.dart` | Continue Watching integration |
| `test/media_access_wiring_test.dart` | Resolver + playback boundary |

**Gap:** minimal `PlayerScreen` widget tests; no track/speed tests; no Phase 4.4 runtime harness yet.

### Dependencies (playback-related)

```yaml
# client/ttsplayer/pubspec.yaml
media_kit: ^1.2.6
media_kit_video: ^2.0.1
media_kit_libs_windows_video: ^1.0.11
video_player: ...
shared_preferences: ...
```

---

## Provisional scope (pending Gate 0)

*Do not treat this as committed scope until Capability Audit exit criteria are met.*

### Likely in Phase 4.4

| Area | Intent |
|---|---|
| Resume UX polish | Clearer copy; preserve existing keys |
| Playback speed | If audit confirms `setRate` on Windows fixtures |
| Embedded audio/subtitle pickers | If audit confirms track enumeration and switching |
| Resolver-aware playback errors | Playback-layer messages mapped from resolver/HTTP/TLS context |
| Player controls | Layout polish, desktop keyboard shortcuts (space, arrows, etc.) |
| Buffering presentation | Optional refinement using existing `isBuffering` |
| Default speed in settings | Optional — only if speed ships; via `SettingsRepository` |

### Deferred (explicit)

| Item | Reason |
|---|---|
| **Chapter navigation** | **Unknown** `media_kit` Dart API — audit first; likely defer if unsupported |
| External subtitle sidecars | Depends on audit; secondary to embedded tracks |
| HLS / adaptive streaming | Out of MVP / M4 scope |
| Transcoding, DRM, cast | Out of scope per `m4-plan.md` |
| Rich playback history beyond Continue Watching | Phase 4.5+ / separate spec |
| Performance caching | Phase 4.5 |
| Deep diagnostics export | Phase 4.6 — link to Provider Status, do not duplicate |
| SQLite playback history | Out of 0.1 / current M4 scope |

---

## Provisional ADRs (blocked)

*Titles are placeholders. Accept only after Gate 0.*

| ID | Topic | Depends on audit |
|---|---|---|
| ADR-010 (proposed) | Playback authority and UI boundary | Always — principle already established; formalise |
| ADR-011 (proposed) | Playback error taxonomy (provider / resolver / playback) | Resolver status matrix |
| ADR-012 (proposed) | Playback speed | `setRate` runtime pass |
| ADR-013 (proposed) | Audio and subtitle track selection | Track enumeration runtime pass |
| ADR-014 (proposed) | Chapter navigation | **Do not draft until chapters row resolved** |

---

## Specification outline (Step 1 — blocked)

Final specification will add, per audited feature:

- `PlaybackService` public API additions (speed, tracks, error types)
- State fields exposed to UI (`ChangeNotifier` contract)
- Settings keys (if default speed stored)
- Player UI wireframe behaviours (no direct player imports)
- Keyboard shortcut table (Windows desktop)
- Unit test scenarios
- Windows runtime validation matrix (L1–Ln)
- Definition of done aligned with [m4-plan.md](./m4-plan.md#phase-44--playback-improvements)

---

## Validation expectations (preview)

| Class | Intent |
|---|---|
| Unit | Resume read/write preserved; new service methods; resolver failure → playback-layer message |
| Widget | `PlayerScreen` renders error/retry; controls call service mocks only |
| Windows runtime | Opt-in harness; local MP4, HTTPS MKV, multi-audio, subtitles per audit fixtures |
| Manual | TNAS HTTPS seek regression; Continue Watching still populates after polish |

Pattern: follow Phase 4.3 harness conventions (`PHASE_43_RUNTIME=1`) for Phase 4.4.

---

## Definition of done (preview — finalise at Step 1)

- Gate 0 capability audit complete with written outcomes
- ADRs accepted only for audited capabilities
- Resume behaviour preserved without data migration
- `PlayerScreen` never imports or controls `media_kit` / `video_player` directly
- Track/speed features (if in scope) work on Windows test fixtures; hidden or disabled elsewhere without crash
- Playback errors use three-layer taxonomy at correct boundary
- `flutter test` green; Phase 4.4 runtime harness pass when enabled
- `playback.md` updated from planning → accepted at closure

---

## Related documents

- [playback.md](../architecture/playback.md) — architecture companion (planning)
- [media-access-abstraction.md](../architecture/media-access-abstraction.md) — resolver contract
- [settings.md](../architecture/settings.md) — optional default speed preference
- [m4-foundation-complete.md](../release/m4-foundation-complete.md) — pre-4.4 snapshot
- [mvp-scope rule](../../.cursor/rules/mvp-scope.mdc) — requirement 9 (resume position)

---

## Document history

| Date | Change |
|---|---|
| 2026-07-13 | Initial draft: inventory, Gate 0 audit, principles, provisional scope. ADRs and final spec blocked on audit. |
