# ADR-022: Music Queue and Listening State

**Status:** Accepted

**Date:** 2026-07-19

**Partially Accepted:** 2026-07-21 (M5.4 planning — listening history scope locked)

**Accepted:** 2026-07-23 (M5.5 — playback session persistence complete)

**Milestone:** M5 Phase 5.0 / 5.3–5.5

**Authors:** M5 planning pass

---

## Acceptance scope

| Scope | Status | Evidence / target |
|---|---|---|
| In-memory queue (next/previous, album/artist seeding) | **Accepted** (M5.3) | `PlaybackQueue`, `MusicPlaybackQueueController`, `MusicQueueSeeding` |
| Listening history persistence | **Accepted** (M5.4) | `MusicListeningRepository` at `ttsplayer_music_listening_v1` — [Phase 5.4 spec](../../roadmap/m5-phase-5.4-listening-history-continue-listening.md) |
| Continue Listening / Recently Played | **Accepted** (M5.4) | Music landing only; isolated from video `position_*` keys |
| Video namespace unchanged | **Accepted** | Audio never writes video resume keys |
| Queue persistence across app restart | **Accepted** (M5.5) | `MusicPlaybackSessionRepository` at `ttsplayer_music_queue_v1` — [Phase 5.5 spec](../../roadmap/m5-phase-5.5-playback-session-persistence.md) |
| Music favourites envelope | **Deferred** | Remains in `LibraryMetadataRepository` pattern for now |
| Playlists | **Deferred** | Post-M5 |

---

## Final decision (Accepted 2026-07-23)

1. **Separate versioned envelopes** — listening history (`ttsplayer_music_listening_v1`) and playback session (`ttsplayer_music_queue_v1`) are independent; neither clear operation clears the other.
2. **Playback-session identity is track ID only** — never rematch by title, artist, album, or path; metadata is not duplicated into the session envelope.
3. **Queue and active track persist** — ordered `queueTrackIds` and `activeTrackId` survive application restart when IDs still resolve.
4. **Position persists with throttle and lifecycle flush** — 5 s throttle while playing; immediate on seek jump, pause, active-track change, clear, dispose, and app lifecycle background transitions.
5. **Cold-start queue restoration is silent** — after catalogue load, `MusicPlaybackSessionRestorer` hydrates the live queue without preparing or starting the engine.
6. **Autoplay is prohibited** — restored playback starts only after explicit user Play; prior playing/paused engine state is not restored.
7. **Catalogue reconciliation removes invalid entries** — non-audio, missing, and non-playable IDs are pruned; surviving order retained; active fallback + position zero when the active track is removed; empty session when none survive.
8. **Listening history, playback session, and video resume remain isolated** — distinct storage keys and repositories; audio never writes `position_*` / `duration_*`.

**Deferred outside this ADR acceptance (future scope):** music favourites envelope extension, playlists, shuffle/repeat persistence, video queue persistence.

---

## Implementation notes

**M5.3 (2026-07-20):** In-memory queue ordering, coordinator transport, and contextual album/artist queue seeding implemented.

**M5.4 Steps 2–9 / closure (2026-07-21–22):** Listening history repository, coordinator, Continue Listening / Recently Played UI, clear history, diagnostics, integration and Windows runtime validation. Queue persistence remained deferred until Phase 5.5.

**M5.5 Steps 1–5 (2026-07-22):** `MusicPlaybackSession` envelope; `MusicPlaybackSessionRepository`; `MusicPlaybackSessionCoordinator` (debounce/throttle/immediate); catalogue `validateAgainstCatalog`; `MusicPlaybackSessionRestorer` cold-start hydrate with deferred seek; `MusicPlaybackSessionLifecycleObserver`; Music Playback Session diagnostics section.

**M5.5 Step 6 (2026-07-23):** Windows runtime harness PS1–PS16 (`PHASE_55_RUNTIME=1`); focused and full regression green; Release build succeeded; ADR promoted to **Accepted**. → [Phase 5.5 closure](../../roadmap/m5-phase-5.5-closure-report.md)

---

## Context

Video resume uses `PlaybackService` keys (`position_*`, `duration_*`) and **Continue Watching** on the dashboard. Music requires:

- An ordered **queue** with next/previous
- **Recently played** and **Continue Listening** distinct from video
- **Favourites** for tracks/albums/artists (deferred envelope)
- Survival across app restart (queue persistence — **delivered in M5.5**)
- Reconciliation when `catalog.json` is replaced (stale track ids)

M4 established `LibraryMetadataRepository` for favourites with **prune on catalogue replacement only** (ADR-007). Music state follows the same lifecycle discipline.

---

## Decision

1. Introduce **`MusicListeningRepository`** (M5.4) — persistence-only, versioned JSON in `shared_preferences` at `ttsplayer_music_listening_v1`, separate from video resume keys and from settings configuration.

2. **Listening history envelope (M5.4):**

   ```json
   {
     "stateVersion": 1,
     "records": [
       {
         "trackId": "<MediaItem.id>",
         "title": "...",
         "artist": "...",
         "album": "...",
         "duration": 240,
         "lastPosition": 142,
         "completed": false,
         "completedAt": null,
         "lastPlayedAt": "ISO-8601"
       }
     ]
   }
   ```

3. **Identity:** all references use catalogue track `id` only — resolve through current `Catalog`. Snapshot metadata is display fallback only; never used to rematch missing items.

4. **Prune on catalogue replacement:** remove history entries whose ids are absent; retain entries when the same `trackId` still resolves after rescan; silent UI; single listener notification (same hook as ADR-007 / cache coordinator).

5. **Queue persistence (M5.5):** `MusicPlaybackSessionRepository` at `ttsplayer_music_queue_v1`; coordinator debounced/throttled saves; cold-start restore without autoplay; catalogue prune of invalid IDs.

6. **Video namespace unchanged** — no reuse of `position_*` for music; prevents Continue Watching collisions.

7. **Playlists:** deferred post-M5 — do not partially implement in this envelope.

---

## Rationale

- Separates music listening state from video resume semantics (different UX policies).
- Repository pattern matches proven M4.3 favourites architecture.
- Prune-on-replace avoids ghost entries without filesystem polling.
- Separate session envelope keeps queue identity lean (IDs only) while listening history retains display snapshots.

---

## Consequences

### Positive

- Clear ownership and test boundaries
- Catalogue replace behaviour consistent with favourites and search invalidation
- Queue survives restart without forcing playback or navigation

### Negative

- Two local envelopes to reason about (listening vs session)
- Favourites/playlists remain deferred beyond this ADR’s Accepted status for queue/history

### Neutral

- Original monolithic `MusicStateRepository` envelope split delivered as listening history then playback session

---

## Alternatives considered

### Alternative A — Ephemeral queue only (no persistence)

**Rejected for M5 milestone:** Poor desktop UX; superseded by M5.5 delivery.

### Alternative B — Store queue in catalogue JSON

**Rejected because:** Application state must not mutate scanner output.

### Alternative C — Fully Accepted ADR at M5.4 closure

**Rejected because:** Queue persistence was explicitly deferred outside Phase 5.4; Accepted after M5.5 DoD met.

---

## Related documents

- [ADR-007](./ADR-007-library-metadata-and-favourites.md)
- [Phase 5.4 spec](../../roadmap/m5-phase-5.4-listening-history-continue-listening.md)
- [Phase 5.5 spec](../../roadmap/m5-phase-5.5-playback-session-persistence.md)
- [music.md](../music.md) · §11
- [caching.md](../caching.md) — catalogue replacement lifecycle
