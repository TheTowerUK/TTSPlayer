# ADR-022: Music Queue and Listening State



**Status:** Proposed

**Date:** 2026-07-19

**Milestone:** M5 Phase 5.0 / 5.3–5.4

**Authors:** M5 planning pass

**Implementation note (M5.3 Step 2–3, 2026-07-20):** In-memory queue ordering, coordinator transport, and **contextual album/artist queue seeding** are **implemented** (`PlaybackQueue`, `MusicPlaybackQueueController`, `MusicQueueSeeding`). The persistent `MusicStateRepository` envelope (favourites, recently played, continue listening, saved queue) remains **deferred** per this ADR.



---



## Context



Video resume uses `PlaybackService` keys (`position_*`, `duration_*`) and **Continue Watching** on the dashboard. Music requires:



- An ordered **queue** with next/previous

- **Recently played** and **Continue Listening** distinct from video

- **Favourites** for tracks/albums/artists

- Survival across app restart (queue persistence — proposed **required** for M5)

- Reconciliation when `catalog.json` is replaced (stale track ids)



M4 established `LibraryMetadataRepository` for favourites with **prune on catalogue replacement only** (ADR-007). Music state should follow the same lifecycle discipline.



---



## Decision



1. Introduce **`MusicStateRepository`** (name TBD in spec) — persistence-only, versioned JSON in `shared_preferences`, separate from video resume keys and from settings configuration.



2. **Envelope sections (proposed):**



   ```json

   {

     "stateVersion": 1,

     "favourites": { "tracks": [], "albums": [], "artists": [] },

     "recentlyPlayed": [{ "trackId": "...", "playedAt": "ISO-8601" }],

     "continueListening": [{ "trackId": "...", "positionSeconds": 0, "updatedAt": "ISO-8601" }],

     "queue": {

       "trackIds": [],

       "currentIndex": 0,

       "shuffle": false,

       "repeat": "off",

       "savedAt": "ISO-8601"

     }

   }

   ```



3. **Identity:** all references use catalogue track `id` only — resolve through current `Catalog`.



4. **Prune on catalogue replacement:** remove favourite, history, continue, and queue entries whose ids are absent; silent UI; single listener notification (same hook as ADR-007 / cache coordinator).



5. **Queue persistence:** save on queue mutation debounced; restore on startup if ids still valid; empty queue if all ids stale.



6. **Video namespace unchanged** — no reuse of `position_*` for music; prevents Continue Watching collisions.



7. **Playlists:** deferred post-M5 — do not partially implement in this envelope.



---



## Rationale



- Separates music listening state from video resume semantics (different UX policies).

- Repository pattern matches proven M4.3 favourites architecture.

- Prune-on-replace avoids ghost entries without filesystem polling.

- Queue persistence is expected for desktop music apps; cost is bounded JSON size.



---



## Consequences



### Positive



- Clear ownership and test boundaries

- Catalogue replace behaviour consistent with favourites and search invalidation



### Negative



- Additional persistence surface to migrate/version

- Large queues increase prefs payload — cap length in 5.3 spec



### Neutral



- May merge into extended `LibraryMetadataRepository` if envelope versioning aligns — decision in 5.4 spec



---



## Alternatives considered



### Alternative A — Ephemeral queue only (no persistence)



**Rejected for M5:** Poor desktop UX; user expectation to resume queue.



### Alternative B — Store queue in catalogue JSON



**Rejected because:** Application state must not mutate scanner output.



---



## Related documents



- [ADR-007](./ADR-007-library-metadata-and-favourites.md)

- [music.md](../music.md) · §11

- [caching.md](../caching.md) — catalogue replacement lifecycle
