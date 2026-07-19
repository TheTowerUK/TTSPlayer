# Music (M5 — Planned / Proposed)



**Status:** **Planned / Proposed** — Phase 5.0 planning complete (2026-07-19); no implementation

**Related roadmap:** [M5 — Music](../roadmap/m5-plan.md)

**Predecessor baseline:** M4 complete — `v0.5.0`



→ [M5 plan](../roadmap/m5-plan.md)

→ [Playback (M4 accepted)](./playback.md)

→ [Library experience (M4 accepted)](./library.md)

→ [Caching (M4 accepted)](./caching.md)

→ [Diagnostics (M4 accepted)](./diagnostics.md)



**Proposed ADRs (M5.0 — not Accepted):**



- [ADR-020: Music Catalogue Schema and Media Kind](./decisions/ADR-020-music-catalogue-schema-and-media-kind.md)

- [ADR-021: Music Metadata Precedence and Identity](./decisions/ADR-021-music-metadata-precedence-and-identity.md)

- [ADR-022: Music Queue and Listening State](./decisions/ADR-022-music-queue-and-listening-state.md)

- [ADR-023: Music Player Surface Architecture](./decisions/ADR-023-music-player-surface-architecture.md)



---



## 1. Purpose and scope



M5 adds **music listening** to TTSPlayer: index audio files in the existing folder-tree catalogue, enrich items with optional embedded tags, expose artist/album/track browsing, and provide queue-based audio playback with application-managed listening state.



**In scope (M5 milestone):** catalogue extension, music browsing UI, audio playback and queue, required listening state, search presentation, artwork, performance, diagnostics, release validation.



**Out of scope:** books/comics (M6), multi-device sync, cloud metadata APIs, mobile release, M4 dashboard cosmetic debt, user accounts, transcoding.



---



## 2. Existing M4 platform capabilities reused



| Component | M5 reuse |

|---|---|

| `backend/indexer.py` | Extend with audio extensions and tag extraction |

| `catalog.json` folder tree | Same structure; items gain `media_kind` + optional music fields |

| `CatalogService` | Single load/replace lifecycle; no second catalogue |

| `MediaLocationResolver` | Resolve audio paths to playable URIs |

| `SettingsRepository` | Music preferences (shuffle default, etc.) when needed |

| `LibraryMetadataRepository` | Pattern for favourites; extend or parallel envelope |

| `SearchService` | Extend index fields; same invalidation on catalogue replace |

| `ArtworkService` | Album art from embedded/sidecar/folder rules |

| `CatalogCacheCoordinator` | Same replace → invalidate artwork/search |

| `PlaybackService` | Extend for audio session + queue; preserve video path |

| `DiagnosticsService` | Add music/queue summary sections |

| Provider health / fallback | Unchanged |

| Windows runtime harness pattern | New `PHASE_5x_RUNTIME` matrices |



---



## 3. Music domain terminology



| Term | Meaning |

|---|---|

| **Track** | Single audio file (`MediaItem` with `media_kind: audio`) |

| **Album** | Logical grouping of tracks sharing album identity key (see §5) |

| **Artist** | Performing artist; may differ from album artist |

| **Album artist** | Album-level attribution; drives compilation handling |

| **Compilation** | Album where track artists differ from album artist |

| **Disc** | Physical/logical disc within a multi-disc album |

| **Library** | Top-level configured root or folder branch — same as today |

| **Queue** | Ordered list of track ids for current listening session |

| **Continue Listening** | Resume position for in-progress music tracks (app state) |

| **Recently played** | Chronological music play history (app state) |

| **Unknown artist / album** | Fallback when tags and folder hints absent |



---



## 4. Proposed catalogue and metadata model



Current `MediaItem` fields (M4): `id`, `title`, `year`, `duration_seconds`, `file_path`, `thumbnail_path`, `size_bytes`, `status`, `added_at`.



**Proposed additions (all optional except `media_kind` for indexed audio):**



| Field | Type | Source |

|---|---|---|

| `media_kind` | `video` \| `audio` \| `image` | Indexer from extension |

| `artist` | string? | Tags → folder → null |

| `album` | string? | Tags → folder → null |

| `album_artist` | string? | Tags → artist → null |

| `track_title` | string? | Tags; else filename stem |

| `track_number` | int? | Tags |

| `disc_number` | int? | Tags (default 1) |

| `genre` | string? | Tags |

| `date` | string? | Tags (year or full date) |

| `compilation` | bool? | Tags or heuristic |



**Display title precedence:** `track_title` → tag title → existing `title` (filename stem).



**Backward compatibility:** Absent `media_kind` implies **video** for legacy video extensions, **image** for image extensions. Clients must tolerate unknown fields.



**Catalogue version:** **Proposed** increment to `catalogue_version: 3` when schema ships (currently `2`) — ADR-020 remains **Proposed** until Phase 5.1 accepts it after audit.



---



## 5. Identity and grouping rules



| Entity | Identity key (proposed) |

|---|---|

| Track | Existing path-derived `id` (md5 of file path) — **stable across rescans** |

| Album | Normalized `(album_artist_or_artist, album, optional disc)` — **derived view**, not stored as filesystem node |

| Artist | Normalized display name from track `artist` or `album_artist` |



**Normalization (proposed):** trim whitespace; case-fold for grouping keys; preserve original casing for display.



**Compilation:** When `compilation` true or album artist is various-artists sentinel, group under **Various Artists** for artist browse; album browse uses album name + album artist key.



**Duplicates:** Same album name from different folders remain **separate** unless user later requests cross-folder merge (out of scope — filesystem is truth).



---



## 6. Folder structure versus embedded-tag precedence



| Metadata | Precedence (highest first) |

|---|---|

| Track title | Embedded tag → filename stem |

| Artist | Embedded tag → parent folder name (heuristic) → Unknown Artist |

| Album | Embedded tag → parent folder name → Unknown Album |

| Album artist | Embedded tag → artist → folder heuristic |

| Track/disc numbers | Embedded tag only |

| Duration | Embedded tag → ffprobe → null |

| Year/date | Embedded tag → null |



**Folder heuristics (non-binding until 5.1 spec):** common layouts `Artist/Album/tracks`, `Album/tracks`, flat folder — indexer documents supported layouts; ambiguous layouts fall back without error.



**Disagreement:** When filename suggests different album than tags, **tags win** for grouping; filename remains available in diagnostics only.



---



## 7. Unknown and incomplete metadata behaviour



- Items **always appear** if indexed and status is playable — never hidden for missing tags.

- UI shows **Unknown Artist** / **Unknown Album** placeholders.

- Search indexes filename and all present tag fields.

- Sort: track number when present, else filename, else title.

- Missing artwork → neutral placeholder ([graceful degradation](../.cursor/rules/graceful-degradation.mdc) principle).



---



## 8. Artwork ownership and fallback rules



Reuse `ArtworkService` pipeline (ADR-015). Proposed precedence for **album art**:



1. Embedded picture in audio file (first front cover)

2. Sidecar in same folder (`cover.jpg`, `folder.jpg`, `album.jpg` — align with existing sidecar rules)

3. Parent folder image sidecar

4. Neutral music placeholder (1:1 per [design-system](../design/design-system.md))



**Per-track vs per-album:** Cache key includes album identity + source path to avoid cross-album bleed. Embedded art decoded through existing LRU budget.



---



## 9. Music library navigation model



Music browsing is a **derived view** over catalogue items — not new filesystem folders.



```

Dashboard / Libraries

    └── Library folder (filesystem)

            └── [Music entry when audio items detected]

                    ├── Artists

                    ├── Albums

                    └── Tracks (flat list scoped to library branch)

    Artist detail → Albums by artist → Album detail → Track list → Play

    Album detail → Track list → Play album

    Search → Music results → detail/play

```



**Coexistence with video:** Mixed folders may offer both **Browse folders** (existing `FolderScreen`) and **Browse music** when audio items exist. Do not hide video items in folder view.



**Dashboard:** Optional **Recently Played** / **Continue Listening** music rows — separate from video Continue Watching (different state keys).



---



## 10. Playback and queue architecture options



| Option | Description | Assessment |

|---|---|---|

| **A — Shared adaptive player** | One `PlayerScreen` adapts video vs audio layout | Risk: video complexity; queue UI cramped |

| **B — Dedicated music player** | Separate `MusicPlayerScreen`; shared `PlaybackService` | Clear UX; some duplication |

| **C — Staged hybrid** *(recommended)* | Extend `PlaybackService` with queue + audio mode; dedicated music player UI; video keeps existing screen | Balances reuse and clarity |



**Recommendation (5.0):** **Option C — staged hybrid** per ADR-023.



```

Music UI  ─┐

Video UI  ─┼→  PlaybackService  →  MediaLocationResolver  →  media_kit (Windows)

           │         ↑

           └──  QueueController (new, owned by service or collaborator)

```



- Queue: ordered track ids, current index, shuffle/repeat state

- `playTrack`, `playAlbum`, `enqueue`, `next`, `previous`, `seek`

- Video `play(item)` path unchanged for `media_kind: video`



**Background/minimized playback:** Document expectation for Windows desktop (audio continues when navigating) — OS media controls deferred post-M5 unless Gate 0 proves trivial.



---



## 11. Application state model



Separate from `catalog.json` and separate from video resume keys where policies differ.



| State | Storage (proposed) | Owner |

|---|---|---|

| Video resume | `shared_preferences` `position_*` | `PlaybackService` (existing) |

| Video Continue Watching | Derived from video resume | Dashboard (existing) |

| Music favourites | `LibraryMetadataRepository` extension or `MusicStateRepository` | Repository |

| Recently played music | App-managed list (cap N) | Repository |

| Continue Listening | Per-track position keys `music_position_*` | Repository + service |

| Queue | Persisted envelope (ADR-022) | Repository |

| Play counts | Deferred | — |

| Playlists | Deferred | — |



**Prune on catalogue replace:** Same lifecycle as favourites — remove entries whose track ids absent from new catalogue.



---



## 12. Search and indexing implications



Extend existing `SearchService` — **no second index**.



**Additional indexed fields:** artist, album, album artist, genre, track title, filename.



**Presentation:** Result type badge (Music vs Video); navigate to music detail or play.



**Performance:** Index build counted in diagnostics; defer rebuild on catalogue replace (ADR-016 pattern).



**Filtering:** Phase 5.2 may add music-only filter in search UI; engine remains unified.



---



## 13. Cache and performance implications



| Area | Consideration |

|---|---|

| Catalogue size | 10k+ tracks — client parse must stay O(n) single pass |

| Artist/album indexes | Build derived maps lazily or on catalogue load — measure in 5.5 |

| Artwork | Many small embedded images — LRU eviction critical |

| Queue | Cap max queue length (TBD in ADR-022) |

| UI lists | `ListView`/`GridView` with cache extent tuning from 4.5 |

| Catalogue replace | Drop derived indexes; prune state; invalidate artwork/search |



---



## 14. Diagnostics and supportability



Extend `RuntimeDiagnosticsSnapshot` (no secrets):



| Field (proposed) | Example |

|---|---|

| Audio item count | `1240` |

| Album count (derived) | `86` |

| Queue length | `12` |

| Queue persistence | `enabled` |

| Last playback error kind | `backendFailed` (redacted detail) |



Clipboard export adds **Music** section. Redaction rules unchanged (ADR-019).



---



## 15. Provider and media-access compatibility



Audio files use the **same** catalogue paths and resolver as video:



- Local: `file://`

- HTTPS: ranged streaming via Caddy



No audio-specific provider type. Provider failure surfaces via existing Provider Status — not music-specific banners.



---



## 16. Backward compatibility



| Scenario | Behaviour |

|---|---|

| Old catalogue (no `media_kind`) | Client infers from extension |

| Old client, new catalogue | Unknown fields ignored by old clients if any |

| Mixed library scan | Video/image items unchanged |

| Bundled mock catalogue | Update mock when 5.1 ships; until then video-only mock valid |



---



## 17. Migration and schema-version considerations



1. Bump `CATALOGUE_VERSION` in indexer when music fields ship.

2. Client checks `catalogue_version` — if unsupported, banner + retain last-good (existing pattern).

3. No migration of user state required for M5 launch (new keys).

4. Full rescan populates music metadata; library rescans merge branch per existing indexer rules.



---



## 18. Error and degraded-state behaviour



| Failure | Behaviour |

|---|---|

| Tag read fails | Emit item with folder/filename fallbacks; log warning in indexer |

| Unsupported audio codec | `status: unavailable` or skip at index — document in 5.1 |

| Playback init fails | ADR-013 taxonomy; skip to next queue item if policy allows |

| Missing file in queue | Remove on play attempt; notify user |

| Catalogue replace mid-play | Pause; prune queue; offer restart |



---



## 19. Testing and Windows runtime strategy



| Layer | Approach |

|---|---|

| Indexer | Fixture libraries: flat, tagged, tagless, compilation, multi-disc |

| Models | Parse tests for optional fields |

| Derived views | Unit tests for album/artist grouping keys |

| Queue | Service tests with fake session controls |

| UI | Widget tests for music browse screens |

| Integration | Catalogue replace → state prune |

| Windows runtime | `PHASE_51_RUNTIME` … `PHASE_55_RUNTIME` opt-in gates (mirrors M4) |

| Manual QA | Play local + HTTPS audio; video regression checklist in 5.6 |



**Gate 0 (before 5.3):** Verify `media_kit` audio-only playback on Windows — same channel limitations as 4.4 video audit.



---



## 20. Security and privacy considerations



- No upload of play history or tags.

- Diagnostics export excludes full paths (existing redaction).

- HTTPS audio uses same TLS rules as video.

- Embedded tags may contain free text — treat as untrusted display strings (no HTML rendering).



---



## 21. Deferred capabilities



| Capability | Target |

|---|---|

| User-defined playlists | Post-M5 or late M5 if scheduled |

| Play counts | Post-M5 |

| Gapless playback | Investigate; defer default |

| OS media session / taskbar controls | Post-M5 |

| MusicBrainz / external enrichment | Out of scope unless approved |

| Cross-folder “virtual album” merge | Out of scope |

| M4 dashboard card consistency | Deferred UX debt |

| Lyrics | Out of scope |



---



## 22. Open questions requiring ADRs



| Question | ADR |

|---|---|

| Schema shape and version bump | ADR-020 |

| Tag vs folder precedence and grouping keys | ADR-021 |

| Queue persistence and prune rules | ADR-022 |

| Dedicated vs shared player UI | ADR-023 |

| Exact audio extension list | Phase 5.1 spec (may amend ADR-020) |

| Shuffle algorithm (true shuffle vs Fisher-Yates) | Phase 5.3 spec |

| Resume threshold for Continue Listening | Phase 5.4 spec |



---



## 23. Initial architecture recommendation



1. **Single catalogue** — extend items with `media_kind` and optional music fields; bump `catalogue_version`.

2. **Indexer tag extraction** — ffprobe/metadata pass with graceful fallback; standard library only on scanner.

3. **Derived music views** — artist/album indexes built client-side from items (no invented catalogue folders).

4. **Staged hybrid player** — extend `PlaybackService` + new music player screen; leave video `PlayerScreen` intact.

5. **Application state repository** — extend metadata repository pattern for favourites, history, queue persistence.

6. **Reuse search/artwork/cache/diagnostics** — extend, do not duplicate.

7. **Windows-first validation** — Gate 0 audio audit before queue implementation; runtime harness per phase.

8. **Strict video regression** — parallel harness execution through M5.



---



## Related documents



| Document | Role |

|---|---|

| [M5 plan](../roadmap/m5-plan.md) | Phase breakdown and DoD |

| [ADR-020](./decisions/ADR-020-music-catalogue-schema-and-media-kind.md) | Schema proposal |

| [ADR-021](./decisions/ADR-021-music-metadata-precedence-and-identity.md) | Metadata rules |

| [ADR-022](./decisions/ADR-022-music-queue-and-listening-state.md) | State and queue |

| [ADR-023](./decisions/ADR-023-music-player-surface-architecture.md) | Player UI |

| [Item status model](../../.cursor/rules/item-status-model.mdc) | Status values for unavailable audio |
