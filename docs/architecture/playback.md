# Playback (M4 Phase 4.4 — accepted)

**Status:** **Implemented and accepted** — Phase 4.4 complete (2026-07-14)
**Related roadmap phase:** [M4 Phase 4.4 — Playback Improvements](../roadmap/m4-phase-4.4-playback-improvements.md)
**Gate 0 audit:** [m4-phase-4.4-gate0-capability-audit.md](../roadmap/m4-phase-4.4-gate0-capability-audit.md)

→ [Media access abstraction](./media-access-abstraction.md)
→ [Path mapping](./path-mapping.md)
→ [Settings](./settings.md)
→ [M4 foundation snapshot](../release/m4-foundation-complete.md)

**ADRs (Accepted 2026-07-13; implemented Phase 4.4):**

- [ADR-010: Playback State Extensions](./decisions/ADR-010-playback-state-extensions.md)
- [ADR-011: Playback Preferences](./decisions/ADR-011-playback-preferences.md)
- [ADR-012: Track Selection](./decisions/ADR-012-track-selection.md)
- [ADR-013: Playback Error Taxonomy](./decisions/ADR-013-playback-error-taxonomy.md)

---

## Purpose

`PlaybackService` is the sole authority for playback lifecycle on top of M3 resume persistence and M3.5 resolver integration. Phase 4.4 adds Windows playback speed, embedded audio/subtitle selection, capability-gated player controls, keyboard shortcuts, and a formal three-layer error taxonomy — without changing catalogue schema, resume keys, or provider/settings behaviour.

Capabilities are limited to [Gate 0 verified outcomes](../roadmap/m4-phase-4.4-gate0-capability-audit.md). Chapters and external subtitle sidecars remain deferred.

---

## Architecture

### Authority model ([ADR-010](./decisions/ADR-010-playback-state-extensions.md))

```
PlayerScreen  →  PlaybackService  →  PlaybackSessionControls  →  media_kit | video_player
```

- `PlayerScreen` reflects service state; it does not own rate, track selection, or fatal error state.
- `PlayerScreen` must not import `media_kit` or `video_player`.
- Presentation-only UI state (overlay visibility, hide timer, open menus) stays in the player widget.

### Backend routing

| Platform | Engine | Session controls |
|---|---|---|
| Windows desktop | `media_kit` | `MediaKitSessionControls` — rate, embedded tracks |
| Other | `video_player` | `UnsupportedSessionControls` — rate locked at `1.0`, no track APIs |

### Three-layer errors ([ADR-013](./decisions/ADR-013-playback-error-taxonomy.md))

| Layer | Owner | User surface |
|---|---|---|
| Provider | `CatalogService` / dashboard | Provider Status — not in player |
| Resolver | `MediaLocationResolver` | Mapped to playback copy before init |
| Playback | `PlaybackService` | Player error view; `PlaybackErrorKind` drives copy |

Resolver failures in the player show playback-layer messaging plus a one-line hint toward Provider Status — not provider diagnostic banners.

---

## Playback lifecycle

### `play(item, { startPosition })`

1. Resolve `item.filePath` via `MediaLocationResolver`; unresolved → fatal `resolverFailed`.
2. Check local file presence; missing → fatal `fileMissing`.
3. Initialise player (`media_kit` or `video_player`).
4. Apply **saved default playback speed** from settings ([ADR-011](./decisions/ADR-011-playback-preferences.md)); clears any prior session override.
5. Persist duration; seek to `startPosition` when provided, else eligible saved resume position, else zero.
6. Start playback; subscribe to track streams on Windows; populate DTO lists.

### `retry({ startPosition })`

Clears fatal error state and notifies listeners **before** re-entering `play()` for the current item. Does not refresh the catalogue. A failed retry surfaces the newly mapped error; successful retry restores playback.

### `stop()`

Disposes the controller, clears `currentItem`, fatal errors, track lists, and **session rate override**. Does **not** clear resume keys (`position_*`, `duration_*`).

### Watch Again (completed state)

Seek to zero and resume play within the **same session**. Retains session `playbackRate` and track selections — does not call `play()` (no default-rate re-application, no track reset).

### New item / different `play()`

Full controller dispose and re-init. Track lists and selections reset. Session rate override cleared; latest **saved default** applied on successful init.

---

## Playback speed ([ADR-011](./decisions/ADR-011-playback-preferences.md))

| Concept | Behaviour |
|---|---|
| **Saved default** | `playback.defaultPlaybackSpeed` in `ttsplayer_settings_v1`; presets `0.5`–`2.0` |
| **Application** | Applied on each new `play()` / `retry()` preparation after successful init |
| **Session override** | In-player `setPlaybackRate` marks session override; survives pause, seek, and Watch Again |
| **Persistence** | Session changes do not auto-save; user saves default explicitly in Settings |
| **Settings UI** | Editable dropdown + Save when `playbackSpeedSettingsSupported`; otherwise read-only stored value, Save disabled, preference preserved |
| **Player UI** | Speed menu when `canChangePlaybackRate`; `,` / `.` keyboard presets when supported |

`stop()` clears session override. The next `play()` or `retry()` loads the latest saved default.

---

## Embedded track selection ([ADR-012](./decisions/ADR-012-track-selection.md))

| Control | Visibility | Service API |
|---|---|---|
| Audio menu | `canSelectAudioTracks` (≥ 2 tracks) | `selectAudioTrack` |
| Subtitle menu | `canSelectSubtitleTracks` (≥ 1 track) | `selectSubtitleTrack`, `disableSubtitles` |
| Off entry | Subtitle menu | `disableSubtitles` → `SubtitleTrack.no()` equivalent |

- Embedded tracks only — no sidecar discovery.
- Track lists populate asynchronously after `open`; enumeration failure is non-fatal (empty lists, controls hidden).
- Stale selected audio/subtitle IDs are cleared when absent from a newly synced track list.
- New `play()` clears prior track state; selections do not carry across items.
- **Non-fatal action failures** (`setPlaybackRate`, track select/disable) return `PlaybackActionResult` failure → SnackBar feedback only; they do not set fatal `errorMessage` / `playbackErrorKind`.

---

## Player UI behaviour

### Capability gates

Controls render only when the service reports capability — never disabled placeholders on unsupported platforms.

### Keyboard (desktop, player focused)

| Key | Action |
|---|---|
| `Space` | Toggle play/pause |
| `←` / `→` | Seek −10 s / +30 s |
| `Esc` | Close open popup menu first; second `Esc` exits player |
| `,` / `.` | Step playback rate down/up when `canChangePlaybackRate` |
| `a` / `s` | Open audio / subtitle menu when capability available |

Shortcuts are **ignored** while a popup menu or text field owns focus.

### Auto-hide

Transport chrome pins while initialising, buffering, paused, in error/completed state, or while a popup menu is open. Closing a menu resumes the normal auto-hide timer.

### Fatal error view

Uses `PlaybackErrorMessages.forKind(playbackErrorKind)` with **Try Again** (`retry()`) and **Go Back**. Distinct from non-fatal rate/track SnackBars.

---

## Resume and progress

| Concern | Behaviour |
|---|---|
| Storage | `position_{itemId}` / `duration_{itemId}` in `shared_preferences` |
| Resume offer | `ResumeInfo` thresholds unchanged (`minResumePosition`, `nearEndWindow`) |
| Detail screen | Resume prompt + optional Start from beginning (`startPosition: Duration.zero`) |
| Continue Watching | `getContinueWatching` eligibility unchanged |
| Completion | Clears persisted progress for the item (existing M3 behaviour) |
| Settings reset | Reset playback / reset all does **not** touch resume keys |

---

## Validation boundaries

### Automated (default `flutter test`)

Service, integration, widget, and settings tests cover rate lifecycle, retry, tracks, errors, resume regression, keyboard/menus, and platform-aware settings. **486 passed**, **5 skipped** (opt-in harnesses only).

### Gate 0 harness (`GATE0_MEDIA_KIT=1`)

Direct `media_kit` `Player()` audit — third-party capability only; does not exercise `PlaybackService` or `PlayerScreen`.

### Phase 4.4 runtime harness (`PHASE_44_RUNTIME=1`)

App-level validation through `PlaybackService` and player UI (`phase_44_windows_runtime_test.dart`).

| Category | Step 6 outcome |
|---|---|
| Executable without real media init | **11 passed** — errors, settings, resume eligibility, unsupported-platform settings UI |
| Skipped in `flutter test` embedding | **18 skipped** — media-backed playback (P1–P4, P5–P9, P11–P15, P22–P24) |
| Fixture not configured | P4, P5, P24 (`GATE0_HTTPS_URI`, `GATE0_MULTI_AUDIO_URI`) |
| Invalid fixture | P7–P9 (`GATE0_SUBTITLED_URI` not MKV) |

**Limitation:** `flutter test` lacks the `media_kit_video` platform channel required by `PlaybackService` when a **video** session creates `VideoController`. M5.3 Gate 0 adds **audio sessions** that open `Player` without `VideoController`, enabling real `PlaybackService` audio tests in `flutter test` on Windows.

---

## M5.3 Gate 0 — audio session mode (2026-07-20)

| Concept | Implementation |
|---|---|
| Session classification | `PlaybackSessionMode` from `MediaItem.isAudio` |
| Video surface | Required only when `requiresVideoSurface` is true |
| Audio init | `media_kit` `Player.open()` without `VideoController` |
| Continue Watching | Unchanged — `isContinueWatchingEligible` video-only |
| Harness | `PHASE_53_AUDIO_GATE=1` → `phase_53_audio_gate_windows_runtime_test.dart` |

→ [M5.3 phase spec](../roadmap/m5-phase-5.3-music-playback-queue.md)

---

## M5.3 Step 1 — dedicated music player (2026-07-20)

| Concept | Implementation |
|---|---|
| Player surface | `MusicPlayerScreen` — shared `PlaybackService`, no second engine |
| Session rule | One active session; opening music replaces video and vice versa |
| Auto-play | `autoPlay: true` on screen entry (matches `PlayerScreen`) |
| Route close | `dispose()` calls `stop()` — no background playback in Step 1 |
| Progress keys | Not written for audio (`isContinueWatchingEligible` gate) |
| Error copy | Kind-neutral `PlaybackErrorMessages` / `playbackFailedMessage` |
| Harness | `PHASE_53_RUNTIME=1` → `phase_53_music_player_windows_runtime_test.dart` |

**Deferred:** shuffle, repeat, Continue Listening, listening persistence, queue panel UI (later M5.3 steps).

---

## M5.3 Step 2 — in-memory queue core (2026-07-20)

| Concept | Implementation |
|---|---|
| Queue model | `PlaybackQueue` — ordered audio items, current index, generation |
| Coordinator | `MusicPlaybackQueueController` — app-scoped `ChangeNotifier` |
| One-track seed | Ungrouped contexts → `seedSingleTrack()` |
| Album / artist seed | **Play album/artist** and contextual track play → `seedAlbumQueue` / `seedArtistQueue` (Step 3) |
| Next | Advance when available; no wrap at final item |
| Previous | Restart current if position > 4 s; else prior item or seek to 0 on first |
| Completion | Auto-advance; duplicate completion events guarded |
| Route close | Stop + clear queue (post-frame dispose callback) |
| Video | Non-audio session clears music queue |
| Catalogue replace | Reconcile by item id via `CatalogCacheCoordinator` |
| Persistence | **Not implemented** — ADR-022 envelope deferred |

| Harness | `PHASE_53_RUNTIME=1` → queue transport + album/artist UI seeding in `phase_53_music_player_windows_runtime_test.dart` |

→ [M5.3 phase spec](../roadmap/m5-phase-5.3-music-playback-queue.md)

---

## M5.3 Step 3 — contextual queue seeding (2026-07-20)

| Concept | Implementation |
|---|---|
| Album order | Projection `MusicAlbum.tracks` (`compareTracksInAlbum`) |
| Artist order | `MusicArtist.tracksInAlbumOrder` (albums by year/title/key, then album tracks) |
| Navigation | `openMusicPlayerFromAlbum`, `openMusicPlayerFromAlbumTrack`, `openMusicPlayerFromArtist`, `openMusicPlayerFromArtistTrack` |
| Source descriptor | `MusicQueueSource` — kind + label + identity key (in-memory only) |
| Route guard | Pop existing `music:player:*` routes before push |
| Empty group | Snackbar; no queue created |

**Still deferred:** shuffle, repeat, queue panel, ADR-022 persistence envelope.

→ [M5.3 phase spec](../roadmap/m5-phase-5.3-music-playback-queue.md)

---

## Related documents

- [M4 Phase 4.4 implementation spec](../roadmap/m4-phase-4.4-playback-improvements.md)
- [Gate 0 audit](../roadmap/m4-phase-4.4-gate0-capability-audit.md)
- [settings.md](./settings.md)
- [diagnostics.md](./diagnostics.md) *(Phase 4.6)*
