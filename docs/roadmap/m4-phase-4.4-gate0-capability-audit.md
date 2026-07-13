# M4 Phase 4.4 — Gate 0 Capability Audit

**Status:** **Complete** (2026-07-13)  
**Package:** `media_kit` ^1.2.6 · `media_kit_video` ^2.0.1 (Windows desktop)  
**Harness:** `client/ttsplayer/test/gate0_media_kit_capability_test.dart`  
**Parent spec:** [m4-phase-4.4-playback-improvements.md](./m4-phase-4.4-playback-improvements.md)

→ [Playback architecture](../architecture/playback.md)  
→ [M4 plan](./m4-plan.md#phase-44--playback-improvements)

---

## Purpose

Verify what `media_kit` can provide on Windows **before** accepting playback ADRs or finalising the Phase 4.4 specification. No `PlaybackService` changes, no UI, no settings — audit only.

**Audit chain:**

```
PlaybackService (required future surface)
        ↓
media_kit 1.2.6 (Windows)
video_player (non-Windows fallback — gaps noted)
        ↓
Supported / Unsupported / Defer
        ↓
Design decisions for Phase 4.4
```

---

## How to reproduce

```powershell
cd client\ttsplayer
flutter build windows   # once — copies libmpv-2.dll into build output
$env:GATE0_MEDIA_KIT='1'
flutter test test/gate0_media_kit_capability_test.dart --tags gate0-mediakit
```

**Optional fixture overrides** (NAS or lab files):

| Variable | Purpose |
|---|---|
| `GATE0_LOCAL_URI` | Local MP4/MKV (`file://` or path) |
| `GATE0_HTTPS_URI` | HTTPS stream (TNAS) |
| `GATE0_MULTI_AUDIO_URI` | MKV with 2+ embedded audio tracks |
| `GATE0_SUBTITLED_URI` | MKV with embedded subtitle tracks |
| `GATE0_EXTERNAL_VTT_URI` | External WebVTT for `SubtitleTrack.uri` |
| `GATE0_CHAPTER_URI` | File with chapter metadata (ffprobe) |

Default local fixture: TNAS sample MP4 on `Y:\Media\…` (same path as M3.5 validation).

---

## Runtime results (2026-07-13)

| ID | Scenario | Fixture | Result |
|---|---|---|---|
| G0-API | Public `Player` control surface | Package survey | **Pass** — `setRate`, `setAudioTrack`, `setSubtitleTrack`, `seek`, `open` |
| G0-API | Chapter navigation API | Package survey | **Unsupported** — no Dart chapter types/methods on `Player` |
| G0-TRACKS | Track enumeration after `open` | Local MP4 (`Y:\Media\…`) | **Pass** — `state.tracks` / `stream.tracks` emit audio + video |
| G0-SPEED | `setRate` local — pause/seek persistence | Local MP4 | **Pass** — 1.5× holds across pause and seek |
| G0-SPEED | `setRate` HTTPS | `ttsplayer.local:8443` | **Skipped** — HTTPS fixture unreachable this session |
| G0-AUDIO | Switch between 2+ audio tracks | Default / sample MP4 | **Skipped** — fixture has single audio track; needs `GATE0_MULTI_AUDIO_URI` MKV |
| G0-SUB | Embedded subtitle select + `SubtitleTrack.no()` | Default MP4 | **Skipped** — no embedded subs on default fixture; needs `GATE0_SUBTITLED_URI` MKV |
| G0-SUB | External `SubtitleTrack.uri` | — | **Skipped** — set `GATE0_EXTERNAL_VTT_URI` |
| G0-CHAPTER | ffprobe metadata vs Dart API | — | **Skipped** — set `GATE0_CHAPTER_URI`; API gap confirmed regardless |

**Harness summary:** 4 passed · 5 skipped · 0 failed (opt-in `GATE0_MEDIA_KIT=1`).

---

## Phase 4.4 scope hand-off

*Definitive scope table — Gate 0 → Specification → ADRs → Implementation.*

| Capability | Verified | UX candidate | Phase |
|---|---|---|---|
| Playback speed | ✅ | ✅ | 4.4 |
| Audio tracks | ✅ | ✅ | 4.4 |
| Subtitle tracks | ✅ | ✅ | 4.4 |
| Chapters | ❌ | Deferred | Post-M4 |

**Verified** = confirmed on Windows via package survey and/or opt-in harness (`media_kit` directly — not through `PlaybackService`).  
**UX candidate** = eligible for player UI in Phase 4.4 (Windows-only where noted in the matrix below).  
**Deferred** = no public Dart chapter API on `Player`; technical blocker, not a product opinion.

---

## Verified capability matrix

| Capability | Windows (`media_kit`) | Non-Windows (`video_player`) | Phase 4.4 decision |
|---|---|---|---|
| Play / pause / seek | **Verified** (M3) | **Verified** (M3) | No change |
| Buffering state | **Verified** (M3) | **Verified** (M3) | UI polish only |
| Resume persistence | **Verified** (M3) | **Verified** (M3) | Refine UX only |
| HTTPS Range seek | **Verified** (M3.5) | Platform-dependent | No change |
| **Playback speed** | **Verified** — `setRate` + `state.rate` on local MP4 | **Unsupported** — no speed API | **In 4.4 — Windows only** |
| **Track enumeration** | **Verified** — `state.tracks` / `stream.tracks` | **Limited** — no track picker API | **In 4.4 — Windows only** |
| **Audio track switch** | **API verified** — `setAudioTrack`; runtime switch needs multi-audio MKV fixture | **Unsupported** | **In 4.4 — Windows only**; validate on NAS MKV before closure |
| **Subtitle select / disable** | **API verified** — `setSubtitleTrack`, `SubtitleTrack.no()`; embedded runtime needs subtitled MKV | **Unsupported** | **In 4.4 — embedded tracks, Windows only** |
| **External subtitles** | **API verified** — `SubtitleTrack.uri` | **Defer** | **Defer 4.4** unless NAS VTT audit passes |
| **Chapters** | **Unsupported** — no public Dart API; libmpv `MPV_EVENT_CHAPTER_CHANGE` not surfaced | **N/A** | **Defer beyond M4** |
| Keyboard shortcuts | App layer | App layer | **In 4.4** — no player API needed |
| Screenshot | API exists | N/A | **Out of 4.4** |

### Platform matrix (4.4 features)

| Feature | Windows | Android / iOS / other |
|---|---|---|
| Playback speed | Show control; `PlaybackService.setPlaybackRate` | Hide control; rate locked at 1.0 |
| Audio track picker | Show when `tracks.audio` has 2+ real tracks | Hide; no crash |
| Subtitle picker | Show when embedded subs exist | Hide; no crash |
| Chapter navigation | Not offered | Not offered |

---

## API survey notes (`media_kit` 1.2.6)

### Supported (public `Player` API)

- `setRate(double)` / `state.rate` / `stream.rate` (if exposed)
- `setAudioTrack(AudioTrack)` / `state.tracks.audio` / `state.track.audio`
- `setSubtitleTrack(SubtitleTrack)` / `state.tracks.subtitle` / `state.track.subtitle`
- `SubtitleTrack.no()`, `SubtitleTrack.uri()`, `SubtitleTrack.data()`
- `AudioTrack.no()`, `AudioTrack.auto()`, `AudioTrack.uri()`
- `state.buffering`, `state.position`, `state.duration`, `state.completed`

### Unsupported for TTSPlayer integration

- Chapter list, chapter titles, chapter seek — **no Dart types or methods**
- Low-level libmpv chapter events exist in generated bindings only; not exposed through `Player`

### `video_player` fallback gaps

- No `setRate`, no multi-track selection API
- Phase 4.4 track/speed features are **Windows-only** with graceful omission elsewhere

---

## Chapters — decision

**Outcome: Defer beyond M4.**

**Rationale:**

1. `media_kit` `Player` has no chapter metadata or navigation API in Dart.
2. Workarounds would require direct libmpv property access — outside stack rules and unsupported by the public package surface.
3. ffprobe may report chapters in container metadata, but TTSPlayer cannot drive chapter UI through `PlaybackService → media_kit` today.

**Revisit when:** `media_kit` adds a supported chapter API, or the project explicitly approves a non–public-API mpv bridge (not recommended).

---

## Draft `PlaybackService` extension surface

*Documentation only — not implemented. UI consumes these via `ChangeNotifier`.*

### State (read-only getters)

| Getter | Type | Source |
|---|---|---|
| `playbackRate` | `double` | `media_kit` `state.rate`; `1.0` on `video_player` |
| `availableAudioTracks` | `List<PlaybackAudioTrack>` | Mapped from `state.tracks.audio` (exclude `auto`/`no`) |
| `availableSubtitleTracks` | `List<PlaybackSubtitleTrack>` | Mapped from `state.tracks.subtitle` |
| `selectedAudioTrackId` | `String?` | `state.track.audio.id` |
| `selectedSubtitleTrackId` | `String?` | `state.track.subtitle.id` (`null` or `no` = off) |
| `playbackErrorKind` | `PlaybackErrorKind?` | Playback-layer taxonomy (see below) |

### Methods

| Method | Behaviour |
|---|---|
| `setPlaybackRate(double rate)` | Calls `media_kit` `setRate`; no-op / hidden on `video_player` |
| `selectAudioTrack(String trackId)` | Resolves id → `setAudioTrack` |
| `selectSubtitleTrack(String? trackId)` | `null` or `no` → `SubtitleTrack.no()` |
| Existing `play` / `seek` / `togglePlayPause` / `stop` / `retry` | Unchanged |

### Value types (client-owned, not `media_kit` re-exports)

```dart
class PlaybackAudioTrack {
  final String id;
  final String? title;
  final String? language;
}

class PlaybackSubtitleTrack {
  final String id;
  final String? title;
  final String? language;
}

enum PlaybackErrorKind {
  fileMissing,
  resolverFailed,
  network,
  timeout,
  unsupportedFormat,
  unknown,
}
```

`PlayerScreen` must not import `media_kit` types — service maps to these DTOs.

---

## Revised ADR list (ready to draft)

| ID | Topic | Gate 0 basis |
|---|---|---|
| **ADR-010** | Playback State Extensions | Principle + Gate 0 |
| **ADR-011** | Playback Preferences | Speed default verified |
| **ADR-012** | Track Selection | Embedded tracks API verified |
| **ADR-013** | Playback Error Taxonomy | Layer model |
| ~~ADR-014~~ | ~~Chapter navigation~~ | **Removed** — deferred beyond M4 |

---

## Gate 0 exit checklist

- [x] Each **Probably** row has a Windows runtime note (pass, skip, or API-only verification)
- [x] **Chapters** resolved — **Defer beyond M4**
- [x] Platform matrix documented (Windows-only speed/tracks)
- [x] `PlaybackService` extension surface drafted (above)
- [x] Proposed ADR list revised (ADR-010–013 only)

**Gate 0 is complete.** Phase 4.4 Step 1 (Specification) and Step 2 (ADRs) may proceed.

### Recommended before Phase 4.4 closure

Re-run harness with production fixtures when available:

- `GATE0_HTTPS_URI` — TNAS HTTPS MP4 (confirm `setRate` over Range)
- `GATE0_MULTI_AUDIO_URI` / `GATE0_SUBTITLED_URI` — NAS MKV samples
- `GATE0_EXTERNAL_VTT_URI` — optional sidecar decision

These are **closure validation** items, not Gate 0 blockers.

---

## Document history

| Date | Change |
|---|---|
| 2026-07-13 | Gate 0 complete — harness + matrix + PlaybackService draft + chapter deferral |
