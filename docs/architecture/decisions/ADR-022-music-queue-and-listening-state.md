# ADR-022: Music Queue and Listening State

**Status:** Partially Accepted

**Date:** 2026-07-19

**Partially Accepted:** 2026-07-21 (M5.4 planning — listening history scope locked)

**Milestone:** M5 Phase 5.0 / 5.3–5.4

**Authors:** M5 planning pass

---

## Acceptance scope

| Scope | Status | Evidence / target |
|---|---|---|
| In-memory queue (next/previous, album/artist seeding) | **Accepted** (M5.3) | `PlaybackQueue`, `MusicPlaybackQueueController`, `MusicQueueSeeding` |
| Listening history persistence | **Accepted** (M5.4) | `MusicListeningRepository` at `ttsplayer_music_listening_v1` — [Phase 5.4 spec](../../roadmap/m5-phase-5.4-listening-history-continue-listening.md) |
| Continue Listening / Recently Played | **Accepted** (M5.4) | Music landing only; isolated from video `position_*` keys |
| Video namespace unchanged | **Accepted** | Audio never writes video resume keys |
| Queue persistence across app restart | **Deferred** | Not in Phase 5.4 — no queue serialization or restoration |
| Music favourites envelope | **Deferred** | Remains in `LibraryMetadataRepository` pattern for now |
| Playlists | **Deferred** | Post-M5 |

**Full Accepted status** for this ADR requires queue persistence to ship. Until then, status remains **Partially Accepted**.

---

## Implementation notes

**M5.3 (2026-07-20):** In-memory queue ordering, coordinator transport, and contextual album/artist queue seeding implemented.

**M5.4 Step 2 (2026-07-21):** `MusicListeningRepository` and `MusicListeningRecord` implemented with unit tests. Persistence-only — not yet wired to UI or catalogue reconciliation.

**M5.4 Step 3 (2026-07-21):** `MusicListeningCoordinator` wired to `PlaybackService` and `MusicPlaybackQueueController` in `main.dart`. Observes audio playback lifecycle; persists via `MusicListeningRepository` only. Video resume keys unchanged. Queue persistence, UI, and catalogue reconciliation remain deferred.

---

## Context

Video resume uses `PlaybackService` keys (`position_*`, `duration_*`) and **Continue Watching** on the dashboard. Music requires:

- An ordered **queue** with next/previous
- **Recently played** and **Continue Listening** distinct from video
- **Favourites** for tracks/albums/artists
- Survival across app restart (queue persistence — **deferred** outside M5.4)
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

5. **Queue persistence (deferred):** save on queue mutation debounced; restore on startup if ids still valid; empty queue if all ids stale — **not implemented in M5.4**.

6. **Video namespace unchanged** — no reuse of `position_*` for music; prevents Continue Watching collisions.

7. **Playlists:** deferred post-M5 — do not partially implement in this envelope.

---

## Rationale

- Separates music listening state from video resume semantics (different UX policies).
- Repository pattern matches proven M4.3 favourites architecture.
- Prune-on-replace avoids ghost entries without filesystem polling.
- Partial acceptance allows listening history to ship without blocking on queue persistence.

---

## Consequences

### Positive

- Clear ownership and test boundaries
- Catalogue replace behaviour consistent with favourites and search invalidation
- Listening history can validate independently of queue persistence

### Negative

- ADR remains open until queue persistence ships
- Two-phase delivery requires careful documentation of deferred scope

### Neutral

- Original monolithic `MusicStateRepository` envelope split: listening history ships first; queue/favourites may follow in later increments

---

## Alternatives considered

### Alternative A — Ephemeral queue only (no persistence)

**Rejected for M5 milestone:** Poor desktop UX long-term; deferred to post-5.4, not rejected permanently.

### Alternative B — Store queue in catalogue JSON

**Rejected because:** Application state must not mutate scanner output.

### Alternative C — Fully Accepted ADR at M5.4 closure

**Rejected because:** Queue persistence explicitly deferred outside Phase 5.4.

---

## Related documents

- [ADR-007](./ADR-007-library-metadata-and-favourites.md)
- [Phase 5.4 spec](../../roadmap/m5-phase-5.4-listening-history-continue-listening.md)
- [music.md](../music.md) · §11
- [caching.md](../caching.md) — catalogue replacement lifecycle
