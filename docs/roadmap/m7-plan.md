# M7 — Metadata Enrichment and Library Experience

**Status:** 🟡 **Planning** (Phase 7.0 — architecture only; no implementation started)
**Branch:** `m7-development`
**Development version:** `v0.8.0-dev` (not bumped in pubspec during planning)
**Baseline:** M6 — tags `v0.7.0` / `m6-complete` (2026-07-29) — commit `356a5e7`
**Predecessor release:** [m6-complete.md](../release/m6-complete.md)

→ [Metadata enrichment architecture](../architecture/metadata-enrichment.md)
→ [M6 complete](../release/m6-complete.md)
→ [Post-M6 UX tracker](./post-milestone-ux-workflow-review.md)
→ [Roadmap principles](./principles.md)
→ [Architecture index](../architecture/README.md)
→ [ADR framework](../architecture/decisions/README.md)

> **Scope note:** M7 adds **optional external metadata enrichment** to improve library presentation. Local files and the local catalogue remain authoritative for identity, browsing, opening, playing, and reading. External providers enrich; they do not replace.

> **Milestone renumbering:** Prior roadmap entries labelled **M7 — Multi-device Experience** are renumbered to **M8**. See [mobile-delivery.md](./mobile-delivery.md#m8--multi-device-experience).

---

## Mission

M7 improves the richness and usability of personal media libraries through **optional external metadata providers**, while preserving the core TTSPlayer principle:

> Local files and the local catalogue remain the source of truth.

External metadata must enrich local catalogue presentation. It must not become mandatory for identifying, browsing, opening, playing, or reading local media.

---

## Engineering principles (M7)

1. **Local authority** — file path, media identity, media kind, library membership, play/open capability, and locally derived fields remain authoritative unless the user explicitly overrides them.
2. **Optional enrichment** — every provider is opt-in; the app remains fully usable offline, without credentials, and when providers fail.
3. **Architecture before implementation** — ADRs and architecture docs precede provider integration code.
4. **Separate enrichment persistence** — provider payloads and provenance live outside `catalog.json`; the scanner catalogue remains filesystem-derived.
5. **No silent low-confidence matches** — ambiguous or weak matches require confirmation or remain unmatched; wrong artwork is worse than a placeholder.
6. **Reuse M4–M6 infrastructure** — settings envelope, diagnostics redaction, artwork cache patterns, search index lifecycle, catalogue replacement coordination.
7. **One vertical slice first** — one media category and one provider family in the first live integration; expand only after precedence, matching, and cache contracts are proven.
8. **Provider evaluation from current sources** — final provider selection uses official documentation in a dedicated evaluation step; popularity alone is not sufficient.
9. **Video and music must not regress** — enrichment work must not break playback, Continue Watching, listening history, or reading progress.
10. **Record durable decisions as ADRs** — see [Proposed ADRs](#proposed-adrs-m70-assessment).

---

## Architectural principle — local authority

The following remain **locally authoritative** (never overwritten by provider refresh without explicit precedence policy):

| Domain | Authoritative source |
|---|---|
| File path / media URI | Catalogue `file_path` + resolver mapping |
| Media identity | Stable md5(path) item `id` |
| Media kind | Indexer `media_kind` + client inference |
| Library membership | Folder tree position |
| File existence / playability | Scanner `status` + client `isPlayable` |
| Duration / page count (when local) | ffprobe, archive inspection, reader-derived |
| Playback / reading state | Application persistence (progress, queue, sessions) |
| Favourites | `ttsplayer_library_metadata_v1` |
| Local title overrides | User enrichment store (M7+) |
| Local artwork overrides | User-selected / sidecar / embedded |
| Local sidecar metadata | Sidecar files beside media |

External providers may supply **presentation enrichment** only: descriptions, posters, cast/crew, genres, release dates, ratings, series relationships, identifiers, language, publisher/studio/label, and richer search terms.

---

## Repository audit summary (Phase 7.0)

### Backend catalogue / indexer

| Component | Role |
|---|---|
| `backend/indexer.py` | Emits catalogue v4 (`SCANNER_VERSION` 0.5.0); atomic write; full scan + `--library-path` subtree rescan |
| `document_metadata.py` | EPUB OPF, CBZ ComicInfo.xml, PDF filename stem |
| `music_metadata.py` | ffprobe tags + folder heuristics + filename parsing |

**Emitted per kind:** base fields (`id`, `title`, `year`, `duration_seconds`, `file_path`, `thumbnail_path` always null, `size_bytes`, `status`, `media_kind`, `added_at`) plus kind-specific merges (music: artist/album/track keys; book: author; comic: author/series/page_count).

**Not implemented:** `missing`/`unavailable` status; remote enrichment; PDF embedded metadata.

### Client models and presentation

| Component | Role |
|---|---|
| `MediaItem` | Parses catalogue fields; `inferMediaKind()` routing |
| `ArtworkService` | Sidecar → folder art → placeholder; LRU 500; no network |
| `SearchService` | Title, path, library, extension, kind-specific fields in blob |
| `LibraryMetadataRepository` | Favourites only (`ttsplayer_library_metadata_v1`) |
| Detail screens | Per-kind presentation (video, music, book, comic) |

### Precedence ADRs (local, accepted)

| ADR | Scope |
|---|---|
| [ADR-021](../architecture/decisions/ADR-021-music-metadata-precedence-and-identity.md) | Music tag → folder → filename fallbacks; path-derived id |
| [ADR-025](../architecture/decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) | Book/comic embedded → filename; no remote APIs in M6 |

### Settings, diagnostics, persistence

| Component | Role |
|---|---|
| `SettingsRepository` | `ttsplayer_settings_v1` — no credential storage today |
| `DiagnosticsRedaction` | Path/URL/stack redaction; provider kind labels only |
| `CatalogCacheCoordinator` | Invalidates artwork, search, favourites reconciliation on catalogue replace |

### Current metadata sources

| Source | Examples |
|---|---|
| Filesystem names | Folder names, filename stems |
| Folder structure | Music artist/album heuristics; library membership |
| Indexer inspection | ffprobe duration/tags; ComicInfo.xml; EPUB OPF |
| Embedded file tags | ID3/Vorbis via ffprobe; EPUB Dublin Core |
| Local sidecar files | Named artwork sidecars (excluded from index) |
| Application state | Favourites, playback/reading/listening progress |
| Remote sources | **Catalogue HTTP fetch only** — no metadata APIs |

---

## Enrichment boundary assessment

### Option A — Backend / indexer enrichment

Scanner queries providers during scan and writes enrichment into catalogue or companion files.

| Pros | Cons |
|---|---|
| One enrichment pass for all clients | Longer scans; rate limits during bulk operations |
| Centralised credentials on NAS | Credentials on server; privacy concern |
| Stable offline catalogue for mobile | Catalogue growth; couples scanner to provider churn |
| Simpler client | Harder manual correction UX on desktop |

### Option B — Client-side enrichment

Flutter app enriches on demand; stores enrichment locally.

| Pros | Cons |
|---|---|
| Incremental lookup; user-specific config | Duplicated work across clients |
| Interactive matching / correction | Weaker shared offline enrichment |
| Credentials stay on user device | Provider coupling in client |
| Aligns with existing user-state persistence | UI complexity |

### Option C — Hybrid

Backend optional bulk pass; client handles interactive matching, correction, refresh.

| Pros | Cons |
|---|---|
| Best offline story when backend enriches | Two enrichment paths to maintain |
| Client correction without rescan | Sync semantics between stores |
| Mobile can consume pre-enriched sidecar | Highest design complexity |

### Recommendation — client-primary hybrid (smallest practical)

**Phase M7 primary boundary: Option B with a designed path to Option C.**

| Layer | M7 responsibility |
|---|---|
| **Client** | Provider abstraction, matching UI, enrichment persistence, artwork download/cache, settings/credentials, diagnostics |
| **Catalogue (`catalog.json`)** | Filesystem-derived only — unchanged authority model |
| **Enrichment store (new)** | Client-side `ttsplayer_metadata_enrichment_v1` keyed by stable item `id` |
| **Backend bulk enrichment** | **Approved deferral** to post-M7 or optional Phase 7.7 stretch — not required for first vertical slice |

**Rationale:** Settings and user state already live on the client; manual match correction is inherently client UX; mobile clients (future M8) will require client-side enrichment consumption regardless; keeping providers out of `catalog.json` preserves atomic scan semantics and local authority; avoids NAS credential storage in the first implementation.

**Future backend assist (non-blocking):** Optional `--enrich` indexer flag writing a **separate** `enrichment.json` sidecar per library root — clients merge by item id. Not implemented in M7 unless Phase 7.7 stretch is explicitly approved.

---

## Metadata layering and precedence

Proposed deterministic layer order (highest wins for **display**; identity fields except user override remain path-locked):

| Layer | Source | Examples | Mutable by provider refresh? |
|---|---|---|---|
| 1 | **User override** | Locked title, locked artwork, manual provider link | No — refresh skips locked fields |
| 2 | **Local sidecar metadata** | `.nfo`, future sidecar JSON | No |
| 3 | **Embedded file metadata** | ID3, EPUB OPF, ComicInfo.xml | No |
| 4 | **Filesystem / catalogue-derived** | Indexer title, folder heuristics, `added_at` | No |
| 5 | **External provider enrichment** | Description, poster URL, cast, genres | Yes — when not locked |
| 6 | **Fallback display** | Filename stem, placeholders | N/A |

### Field classification

| Class | Fields | Notes |
|---|---|---|
| **Authoritative identity** | `id`, `file_path`, `media_kind` | Never provider-sourced |
| **Locally derived** | Indexer `title`, `year`, music tags, book `author`, comic `series` | Provider may suggest; never silently replace |
| **Enriched presentation** | Description, backdrop, cast, external genres, ratings | Provider-primary when matched |
| **User-editable overrides** | Display title, artwork selection, provider link | Persisted with lock flags |
| **Provenance** | Per-field `source` + `providerId` + `fetchedAt` | Stored in enrichment record |
| **Calculated** | Search blob, artwork resolution result | Derived at runtime |

**Migration from ADR-021 / ADR-025:** Scanner precedence rules remain in force for catalogue emission. M7 adds a **presentation overlay** that never mutates `catalog.json` on provider refresh.

---

## Identity and matching architecture

### Goal

Link local items to remote records **without** making remote identifiers authoritative.

### Match states

| State | Meaning | UX |
|---|---|---|
| `linked_by_identifier` | ISBN, MusicBrainz ID, TMDB ID in embedded tags | Auto-apply if configured |
| `linked_high_confidence` | Strong multi-field match | Auto-apply if user enabled auto-match |
| `linked_manual` | User selected from search results | Always respected |
| `ambiguous` | Multiple plausible results | Confirmation required |
| `unmatched` | No acceptable candidate | Local metadata only |
| `ignored` | User dismissed enrichment for item | No automatic retries unless cleared |
| `stale` | Prior link invalid after rename/move | Re-match or manual review |

### Signals (combinable, weighted)

- Normalized title, year, season/episode, track/disc numbers
- Artist/album, author, series/volume/issue
- ISBN / embedded IDs (ASIN, ISRC, ISNI where present)
- Folder structure and filename parsing
- Duration (weak signal for video/music)
- Manual selection (authoritative)

### Confidence policy

- Persist `matchMethod`, `confidence` (0.0–1.0), and `providerRecordId` in enrichment store.
- **Reject** auto-apply below configurable threshold (default conservative).
- Never auto-apply ambiguous multi-result sets.
- Renamed/moved files: item `id` changes → orphan enrichment detected on catalogue replace → mark stale, do not auto-attach to new id.

---

## Metadata storage model

### Enrichment record (proposed)

Keyed by catalogue item `id` (md5 of path at match time):

```json
{
  "schemaVersion": 1,
  "itemId": "<catalogue item id>",
  "providerId": "open_library",
  "providerRecordId": "OL123456W",
  "providerMediaType": "book",
  "matchMethod": "isbn_exact",
  "confidence": 1.0,
  "lockedFields": ["title", "artwork"],
  "ignored": false,
  "fetchedAt": "ISO-8601",
  "expiresAt": "ISO-8601",
  "lastError": null,
  "fields": {
    "description": { "value": "...", "source": "provider" },
    "coverUrl": { "value": "https://...", "source": "provider" }
  }
}
```

### Storage location

| Store | Contents | Owner |
|---|---|---|
| `catalog.json` | Filesystem-derived catalogue | Indexer / HTTP provider |
| `ttsplayer_metadata_enrichment_v1` | Enrichment records + locks | Client |
| `ttsplayer_library_metadata_v1` | Favourites (existing) | Client |
| Artwork disk cache | Downloaded provider images | Client |
| Raw provider payload | **Not stored by default** | — |

**Raw payload policy:** Store normalized fields only unless a specific provider license or debugging need requires retention — then cap size, redact in diagnostics, exclude from export.

### Invalidation

- Catalogue replace: prune enrichment for absent ids; mark orphans; never block catalogue load.
- Provider disabled: retain cache (default) or delete per user setting.
- Credential removal: stop refresh; retain cached enrichment unless user clears.
- Schema migration: versioned envelope with corrupt-state recovery (empty safe default).

---

## Artwork architecture

### Precedence (extends ADR-015 / ArtworkService)

1. User-selected local artwork (locked)
2. Local sidecar (stem match, named sidecars)
3. Embedded artwork (future: ID3/APIC, EPUB cover)
4. Cached external artwork (downloaded from provider)
5. Provider image URL (transient — fetch to cache before display)
6. Generated thumbnails (future scanner feature)
7. Placeholder

### Policies

- External artwork **never** prevents item display — placeholder on any failure.
- Download on explicit policy: auto-download setting OR on-demand when detail/card visible.
- LRU + disk quota for provider cache (separate from decode LRU 500).
- Stale replacement only when user refreshes or lock not set.
- Attribution per provider ToS — surface in settings/about when required.
- Cleanup: remove cache entries when enrichment record deleted or item pruned.

---

## Refresh and rescan behaviour

| Event | Provider calls? | Behaviour |
|---|---|---|
| App launch / catalogue load | **No** | Load local catalogue + enrichment store only |
| Full rescan | **No** (M7 default) | Reconcile enrichment ids; prune orphans |
| Manual metadata refresh | **Yes** | Bounded batch queue; progress + cancel |
| Detail screen open | **Optional** | Stale-while-revalidate if enabled and online |
| Provider/credential change | **On next explicit refresh** | No automatic bulk |
| Clear enrichment | **No** | Local delete only |
| Clear artwork cache | **No** | Local delete only |

**Queue:** Per-provider throttling, exponential backoff, retry eligibility flag, observable progress in diagnostics.

---

## Settings and privacy

### New settings group (proposed): `metadataProviders`

| Setting | Purpose |
|---|---|
| `externalMetadataEnabled` | Master opt-in (default **off**) |
| `providersByMediaKind` | Enable per kind |
| `autoMatchEnabled` | Auto-apply high-confidence only |
| `autoDownloadArtwork` | Fetch posters/covers to cache |
| `refreshIntervalDays` | Stale threshold for optional revalidate |
| `preferredLanguage` / `preferredRegion` | Provider query localization |
| `adultContentFilter` | Where provider supports it |
| `meteredNetworkPolicy` | Block/auto on metered connections |
| `onDisable` | Retain vs delete cached enrichment/artwork |

### Credentials

- Credentials require an **OS-backed secure-storage mechanism**; they must not be stored in `catalog.json`, logs, diagnostics exports, SharedPreferences/plain settings JSON, or the repository.
- **Windows storage must be evaluated during Phase 7.7 implementation.** Likely candidates include **Windows Credential Manager** or **DPAPI-backed secure storage**.
- **Application-managed reversible encryption is not an acceptable fallback** without a separately approved key-protection design.
- **Until secure storage is available, provider credentials must not be persisted** — session-only entry or re-prompt on each use until a durable mechanism is implemented and reviewed.
- Diagnostics: `credentialConfigured: true/false` only (never the secret itself).

### Data transmission disclosure (opt-in screen)

When matching, the app may send to configured providers: normalized title, year, author/artist, series/issue, ISBN if locally known, and file **basename** (not full path). Full paths are never transmitted.

---

## Diagnostics and observability

Safe enrichment section in runtime snapshot:

- Enabled providers (ids only)
- Credential configured: yes/no per provider
- Enrichment record counts by state (matched, ambiguous, ignored, stale, error)
- Pending queue size
- Last successful refresh timestamp
- Last error category (auth, rate_limit, network, parse, not_found)
- Artwork cache size / entry count

**Never expose:** API keys, auth headers, raw payloads, full local paths, query strings with secrets.

---

## Failure and fallback policy

| Failure | Behaviour |
|---|---|
| Offline | Use cached enrichment + local metadata |
| DNS/TLS | Same; surface non-blocking banner in settings/enrichment UI |
| Auth failure | Disable provider calls; settings prompt to re-enter key |
| Quota / rate limit | Backoff; show category in diagnostics |
| Malformed response | Skip record; log safe category |
| Provider schema change | Adapter version pin; graceful degrade |
| Image download fail | Placeholder; retain text enrichment |
| Ambiguous match | No auto-apply; local presentation |
| Provider disabled post-enrichment | Retain cache per user policy |

Provider errors are **never** catalogue or playback failures.

---

## Provider scope assessment

Evaluate categories separately — no single provider model forced across all media.

### Video (films, TV, seasons, episodes)

Likely needs: title, year, season/episode, cast, poster, backdrop, synopsis, content ratings.

**Risk:** High visibility of wrong matches; complex numbering; multiple editions.

### Music (artists, albums, tracks)

Likely needs: artist, album, track, genre, release date, cover art, MBID.

**Risk:** Compilations / Various Artists (ADR-021 deferred); remasters and duplicate albums.

### Books

Likely needs: title, authors, series, volume, publisher, date, description, cover, ISBN.

**Risk:** Lower than video; EPUB/ISBN signals available; smaller artwork licensing surface.

### Comics

Likely needs: series, issue, creators, publisher, date, description, cover.

**Risk:** Filename parsing variance; issue numbering gaps; niche series coverage.

### Provider evaluation criteria (for dedicated evaluation phase)

Record for each candidate using **current official documentation**:

- Supported media types
- API stability and versioning
- Licensing, attribution, commercial-use conditions
- Authentication model and key issuance
- Cost, quotas, rate limits
- Image use conditions and hotlinking policy
- Data quality and regional availability
- Privacy policy and data retention
- Matching identifiers supported
- Search quality for ambiguous titles
- Offline caching rights
- Provider longevity / maintenance signals
- Flutter and/or Python integration suitability

**No final provider selection in Phase 7.0.**

---

## Recommended first vertical slice

**Books** — safest first live integration.

| Factor | Books |
|---|---|
| Match signals | Title + author + ISBN (EPUB/embedded) |
| Wrong-match impact | Lower than video poster on dashboard |
| Existing foundation | ADR-025, EPUB OPF extraction, book detail screen |
| Complexity | No season/episode graph |
| User correction | Straightforward search + pick |

Music is the second candidate; video and comics deferred until matching UX and artwork cache are proven.

---

## Phase structure

| Sub-phase | Focus | Status |
|---|---|---|
| **7.0** | Planning, provider research criteria, architecture, Proposed ADRs | 🟡 **In progress** |
| **7.1** | Enrichment models, provenance schema, persistence repository | Planned |
| **7.2** | Provider abstraction + **books** vertical slice (one provider after evaluation) | Planned |
| **7.3** | Matching, confidence scoring, manual correction, ignore/stale | Planned |
| **7.4** | Artwork enrichment, download cache, precedence integration | Planned |
| **7.5** | Search enrichment terms, filtered browsing, enriched detail surfaces | Planned |
| **7.6** | UX/workflow refinements ([post-M6 tracker](./post-milestone-ux-workflow-review.md)) | Planned |
| **7.7** | Privacy, diagnostics, performance, resilience, optional backend assist design | Planned |
| **7.8** | Windows runtime validation and milestone closure | Planned |

### Phase 7.0 — Planning and Architecture

**Objective:** Establish M7 architecture without production provider code.

**Deliverables:**

- [m7-plan.md](./m7-plan.md) (this document)
- [metadata-enrichment.md](../architecture/metadata-enrichment.md)
- [ADR-028 Proposed](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md)
- [ADR-029 Proposed](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md)
- [v0.8.0-dev.md](../release/v0.8.0-dev.md)
- Roadmap and milestone index updates

**Out of scope:** Provider dependencies, API clients, schema migrations in production code, UI implementation.

**Definition of done:** Architecture reviewed; ADRs Proposed; no pubspec version bump; no provider packages added.

---

## Scope boundaries

### Required for M7

- Enrichment data model and client persistence
- Provider abstraction interface
- One books provider vertical slice (after evaluation)
- Matching states, confidence, manual correction
- Artwork download cache with precedence
- Settings opt-in; OS-backed credential secure storage (evaluated in Phase 7.7 — no persistence until approved mechanism exists)
- Diagnostics enrichment section
- Precedence-aware detail presentation for enriched kinds
- Test fakes for provider HTTP
- Windows runtime harness extensions (provider-disabled baseline minimum)

### Optional stretch

- Second media kind (music) in same milestone
- Backend `--enrich` companion file
- Embedded artwork extraction (ID3/APIC)
- PDF embedded metadata in indexer

### Approved deferral

- Video and comic provider integrations (until books slice validated)
- Backend bulk enrichment pipeline
- Multi-device enrichment sync (M8)
- Full-text or OCR search inside books
- Automatic file rename from provider metadata

### Out of scope

- Cloud media storage, multi-user profiles, account sync
- Social features, recommendation engines with remote user tracking
- DRM services, purchases, streaming-service integration
- Automatic file/folder restructuring
- Destructive metadata writes into source files
- Replacing local catalogue identity with provider identity
- Mobile release (M8)
- Server-hosted public access

---

## Post-M6 UX tracker disposition

| Item | M7 placement | Rationale |
|---|---|---|
| Continue Watching aspect ratio | **Phase 7.6** | Presentation fix; independent of providers; batch with workflow polish |
| Literature folder rescan | **Phase 7.6** | Scanner/indexer UX parity; uses existing `--library-path`; not metadata-specific |
| Direct open/play vs detail screen | **Phase 7.6** | Navigation policy; orthogonal to enrichment |

These are **not** Phase 7.0–7.2 blockers. Phase 7.6 is the dedicated UX/workflow batch — not bundled into provider integration phases.

---

## Proposed ADRs (M7.0 assessment)

| ADR | Title | Status |
|---|---|---|
| [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) | External Metadata Enrichment Boundary | **Proposed** |
| [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md) | Metadata Precedence, Provenance, and Matching | **Proposed** |

Consolidated into two ADRs to avoid overlap: boundary/storage in 028; precedence/matching/artwork in 029.

---

## Testing strategy

### Models and persistence

- Serialization round-trip; schema migration; corrupt file recovery
- Provenance per field; user lock respected on refresh
- Expiry and disabled-provider retention policies

### Matching

- ISBN / identifier exact match
- Normalized title + author; year disambiguation
- Ambiguous multi-result → no auto-apply
- Low-confidence rejection
- Manual link; ignored item; moved file → stale

### Provider integration (fake HTTP only in CI)

- Success, empty, malformed, 401, 429, timeout
- Retry/backoff, cancellation, pagination, localization headers

### UI

- Opt-in gate; settings; match confirmation; manual correction
- Offline fallback; local precedence in detail views
- Artwork fallback chain; accessibility

### Isolation / regression

- Browse/play/read with providers disabled
- No provider calls on ordinary catalogue load
- No credentials in diagnostics export
- Video/music/reading history unchanged

### Runtime validation (Windows harness)

- Provider-disabled baseline (required)
- Fake local metadata provider server (Phase 7.2+)
- Cache reuse offline; ambiguous manual match; artwork fallback; credential redaction

Live-provider tests: optional, manually gated, excluded from CI.

---

## Related documents

- [Metadata enrichment architecture](../architecture/metadata-enrichment.md)
- [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) · [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md)
- [M8 — Multi-device Experience](./mobile-delivery.md#m8--multi-device-experience) (renumbered)
- [v0.8.0-dev tracker](../release/v0.8.0-dev.md)
