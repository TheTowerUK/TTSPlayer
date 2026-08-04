# M7 Phase 7.5 — Metadata-Aware Search and Detail Presentation

**Status:** APPROVED (Step 7.5.1) — ready for implementation  
**Step:** 7.5.1 — Repository audit and detailed planning (no production code)  
**Prerequisite:** Phase 7.4 complete — [7.4.6 closure](./m7-phase-7.4.6-closure-report.md) · commits `56789e8`, `1fd4c2c`  
**Branch:** `m7-development`  
**Related ADRs:** [ADR-029](../architecture/decisions/ADR-029-metadata-precedence-provenance-and-matching.md) (Proposed — Accept only after 7.5 validation; see §29), [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) (Proposed), [ADR-016](../architecture/decisions/ADR-016-search-index-lifecycle.md) (Accepted), [ADR-025](../architecture/decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) (Accepted)

→ [M7 plan](./m7-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

---

## 1. Status: APPROVED (PLANNING complete)

Phase 7.5.1 audits repository truth and locks architecture, matching boundaries, presentation precedence, lifecycle, and test strategy. **No production code, dependency, catalogue schema, or provider-wiring changes in this step.**

**Review outcome (2026-08-04):** Architecture approved. Preserved invariants, structured search-field caution, dirty-index lifecycle, and feature-gate readability rule are locked below before production implementation.

| Check | Value (2026-08-04 audit) |
|---|---|
| Branch | `m7-development` (tracks `origin/m7-development`) |
| HEAD | `1fd4c2c` — `docs(m7.4): close artwork presentation integration` |
| Prior feat | `56789e8` — `feat(m7.4): wire artwork resolver into presentation surfaces` |
| Working tree | Clean (no uncommitted source/docs at audit start) |
| Flutter / Dart | 3.44.8 / 3.12.2 |
| Full regression | **1762** passed, **20** skipped, **0** failed |
| Windows release | Succeeded (known non-blocking `media_kit_libs_windows_video` CMP0175 warnings) |

---

## 2. Context and dependencies

Phase 7.1–7.4 delivered:

| Phase | Delivered (relevant to 7.5) |
|---|---|
| **7.1** | `MetadataEnrichmentRecord`, field provenance, locks, `MetadataEnrichmentRepository`, catalogue prune |
| **7.2** | Open Library adapter, `NormalizedBookMetadata`, `EnrichmentBookFieldKeys`, refresh service |
| **7.3** | Matching coordinator, candidate review, match-state UI on book detail, ignore/unlink/relink/resume |
| **7.4** | Artwork reference/cache/resolver; `ArtworkPresentationService` + `ResolvedMediaArtworkImage` on detail, cards, search, CW, favourites |

**Still missing (this phase):** a display/search merge that projects persisted enrichment **text fields** onto search and item detail while preserving catalogue identity and local-first precedence.

**Hard constraints carried forward:**

- Local-first precedence (ADR-029)
- `MediaItem` / catalogue identity authoritative (`id`, `file_path`, `media_kind`)
- No automatic or background provider retrieval
- No provider calls during ordinary search, browse, navigation, or rendering
- Deterministic offline behaviour
- Explicit provenance and match-state boundaries
- Safe fallback to catalogue metadata
- Existing artwork resolver behaviour unchanged in contract
- Compatible with all media kinds; **first enrichment text slice remains books**
- Feature gate remains development-default-off until a later activation step

---

## 3. Current repository audit

### 3.1 Search architecture

| Component | Path | Current behaviour |
|---|---|---|
| **`SearchService`** | `client/ttsplayer/lib/features/search/search_service.dart` | In-memory index, lazy per `Catalog.catalogueIdentity` (ADR-016). `maxResults = 100`. Token AND match on `searchBlob`. Ranking via integer `_score`. |
| **Index entry** | `…/models/search_index_entry.dart` | Holds `MediaItem`, library/parent/fileName, `searchBlob`. |
| **Result** | `…/models/search_result.dart` | Ranked hit + folder context; identity = `item.id`. |
| **Filters** | `…/models/search_filters.dart` | Optional `libraryName`, `extension`, `mediaKind`. |
| **Normalization** | `SearchService._normalize` / `_tokenize` | Lowercase; `/` → `\`; whitespace-split tokens; empty query → `[]`. |
| **Blob contents today** | `_entryForItem` | `title`, fileName, path, library, parent folder, extension; music: artist/album/albumArtist/genre; book/comic: **catalogue** `author`/`series` only. **No enrichment fields.** |
| **Ranking today** | `_score` | Exact title 100 → prefix 80 → contains 60; filename 40; path 30; library/parent 20; extension token 10. Tie-break: title A–Z. |
| **Cache lifecycle** | `ensureIndex` / `onCatalogReplaced` / `invalidateIndex` | Build deferred until first search; catalogue replace clears index; rebuild on next search. No enrichment awareness. |
| **`SearchScreen`** | `…/search_screen.dart` | Debounced 150 ms; generation counter; recent queries (5); filters; navigates via `catalog.findItemById` → `ItemDetailScreen` / music track detail. Does **not** watch enrichment repository. |
| **`SearchResultRow`** | `…/widgets/search_result_row.dart` | Shows `item.title`, music/book-comic secondary line from **catalogue** fields, folder context, kind/extension chips. Artwork via `ResolvedMediaArtworkImage` (7.4.6). No provenance/match-state UI. |
| **Grouping** | `search_result_grouper.dart` | Groups by library preserving score order. |
| **Navigation** | `search_navigation.dart` | `openSearchScreen`. |
| **Dashboard entry** | `dashboard_quick_search_bar.dart` | Opens search. |

**Result identity:** Catalogue `MediaItem.id` only. Navigation re-resolves from live catalogue — enrichment never changes identity or route target.

### 3.2 Item-detail architecture

| Component | Path | Current behaviour |
|---|---|---|
| **`ItemDetailScreen`** | `lib/screens/item_detail_screen.dart` | `StatelessWidget({required MediaItem item})`. Body: poster → metadata panel → **`BookMetadataEnrichmentSection`** → play → file info. App bar / title = `item.title` (catalogue). |
| **`_MetadataPanel`** | same file | Kind, year, duration, extension; books/comics: catalogue `author`/`series`/`pageCount`; audio: artist/album. **No enrichment field reads.** |
| **Artwork** | `_PosterArea` | `ResolvedMediaArtworkImage` → `ArtworkPresentationService` / `MetadataArtworkResolver` (local > provider cache). |
| **`BookMetadataEnrichmentSection`** | `…/widgets/book_metadata_enrichment_section.dart` | Books only; gated by `MetadataEnrichmentFeatureConfig`. Shows match label/explanation, attribution, cover status, actions. Watches `MetadataEnrichmentRepository`. **Does not render `record.fields`.** Lifecycle: generation counter, dialog dismiss, artwork invalidate on item-id change / dispose. |
| **Match-state UI** | `…/presentation/metadata_match_state_presentation.dart` | Labels/icons/action matrix for all `EnrichmentMatchState` values + no-record. |
| **Candidate UI** | candidate dialog/card + presentation mappers | Review/select/relink only; not browse presentation. |
| **Item lifecycle** | Detail screen holds navigated snapshot | No live catalogue rebind by id. Enrichment section handles item-id change via `didUpdateWidget`. |

### 3.3 Metadata enrichment architecture

| Component | Path | Notes |
|---|---|---|
| **`MetadataEnrichmentRepository`** | `…/services/metadata_enrichment_repository.dart` | `ChangeNotifier`; key `ttsplayer_metadata_enrichment_v1`; `getByItemId` / `upsert` / `remove` / `validateAgainstCatalog`; `notifyListeners` on successful load/persist. |
| **`MetadataEnrichmentRecord`** | `…/models/metadata_enrichment_record.dart` | `itemId`, `matchState`, linkage, `fields`, `lockedFields`, `artworkReference`, recovery parsers. |
| **`EnrichmentFieldValue`** | `…/models/enrichment_field_value.dart` | `{ value, source, providerId?, updatedAt?, locked }` — sources: `provider` \| `user_override`. |
| **`EnrichmentBookFieldKeys`** | `…/models/enrichment_book_field_keys.dart` | `title`, `subtitle`, `authors`, `description`, `publishers`, `publicationDate`, `publicationYear`, `languages`, `subjects`, `isbn10`, `isbn13`. **No `series` key today.** |
| **`EnrichmentMatchState`** | `…/models/enrichment_match_state.dart` | unmatched, linkedByIdentifier, linkedHighConfidence, linkedManual, ambiguous, ignored, stale. |
| **Mapper / transitions** | `book_metadata_enrichment_mapper.dart`, `book_metadata_match_transition.dart` | Persist/merge provider fields with locks; unlink/ignore clear provider fields but **retain userOverride + locked**; `isProviderLinked` = linkedByIdentifier \| linkedManual \| linkedHighConfidence. |
| **Coordinator / refresh** | matching coordinator, refresh service | Explicit ISBN/search/select/relink/unlink/ignore/resume only. |
| **Production wiring** | `main.dart` | Repository + feature config provided; **`BookMetadataMatchingCoordinator?` = null**; **no** `BookMetadataArtworkCoordinator` provider; Open Library not composition-rooted. Feature flag **defaults off**. |

### 3.4 Existing projection / merge logic

| Exists | Role | Gap vs 7.5 |
|---|---|---|
| `BookMetadataEnrichmentMapper.mergeProviderFields` | Persistence-time field merge | Not a UI projection |
| `BookMetadataMatchTransition.applyRelink` | Relink field retention | Persistence only |
| `MetadataArtworkResolver` / `ArtworkPresentationService` | Artwork precedence | Artwork only |
| `MusicLibraryProjection` / `ContinueReadingProjection` | Unrelated domains | Do not reuse for books enrichment |
| **`MetadataPresentationService`** | Proposed in architecture docs | **Not implemented** |
| `EnrichedMediaItem` / `MediaPresentation` / `DisplayMetadata` | — | **Do not exist** |

**Conclusion:** A new immutable presentation projection is **required**. Duplicated ad-hoc merge in SearchService and ItemDetailScreen must be avoided — both must consume one resolver.

### 3.5 Cache and lifecycle integration

| Concern | Current | 7.5 impact |
|---|---|---|
| `main.dart` | `SearchService`, enrichment repo, `CatalogCacheCoordinator` on catalogue replace | Wire presentation service; connect enrichment → search refresh |
| Catalogue replace | Invalidate search index; prune enrichment orphans | Presentation falls back to catalogue; pruned records disappear from search overlay |
| Enrichment `notifyListeners` | Detail enrichment section rebuilds; artwork widgets rebuild | Search screen must also refresh active query; index enrichment terms must refresh |
| App restart | Enrichment reloaded via `initialize()`; search index empty until first search | Projection must read repository after load; index rebuild includes enrichment overlay |
| Item detail snapshot | Holds `MediaItem` from navigation | Projection must still use navigated item identity + live enrichment by `item.id` |

### 3.6 Tests and runtime harnesses

| Area | Primary files |
|---|---|
| Search unit | `test/search_service_test.dart`, `book_comic_search_test.dart`, `music_search_list_hardening_test.dart` |
| Search lifecycle | `test/search_service_lifecycle_test.dart` |
| Search presentation | `test/search_presentation_test.dart` |
| Item detail + enrichment gate | `test/item_detail_screen_test.dart` |
| Enrichment section / match states | `test/book_metadata_enrichment_section_test.dart`, `book_metadata_lifecycle_polish_test.dart` |
| Artwork presentation (7.4.6) | `test/artwork_presentation_integration_test.dart` (+ resolver/cache suite) |
| Enrichment repo lifecycle | `test/metadata_enrichment_repository_test.dart` |
| Windows runtime (extend) | `test/phase_736_metadata_matching_windows_runtime_test.dart` + `test/support/phase_736_*` — env `PHASE_736_RUNTIME=1`, tag `phase736-runtime` |
| Planned but absent | Phase 7.4.7 artwork Windows harness |

---

## 4. Objectives

1. Introduce a single **immutable enriched presentation projection** that merges catalogue `MediaItem` with persisted enrichment overlays per ADR-029.
2. Extend **local search** so persisted book enrichment fields participate in matching and deterministic ranking — **without any provider I/O**.
3. Surface enriched book fields on **item detail** (and bounded secondary search presentation) with safe catalogue fallbacks.
4. Preserve artwork resolver behaviour and match-state management UI from Phases 7.3–7.4.
5. Keep offline, feature-gated, and non-book catalogue behaviour regression-free.

---

## 5. In scope

- `MetadataPresentationService` (name locked for implementation; docs historically TBD) + immutable projection type(s)
- Field precedence matrix implementation for supported book display/search fields
- Search index blob **append** of enrichment keywords (never replace local terms)
- Search ranking tiers for enrichment-only hits
- Search result secondary-line presentation for books (author/series/year) from projection — **no provenance clutter**
- Item-detail enriched metadata rendering (title overlay policy, authors, subtitle, publisher, year, ISBN, subjects, collapsible description)
- Match-state gating for when provider fields may influence search/display
- Enrichment-repository notification → search index / active query refresh
- Catalogue replacement + restart behaviour for projection + search
- Corrupt / missing enrichment recovery (skip bad fields; catalogue remains usable)
- Automated tests + Windows opt-in runtime harness extension
- Planning/closure documentation updates for this phase

---

## 6. Out of scope

- Production Open Library / coordinator composition-root activation (remains deferred unless a later explicit step)
- Automatic / background enrichment or artwork download
- Provider calls from search, browse, cards, or detail **render** paths
- Catalogue schema or `indexer.py` changes
- Mutating `MediaItem` / writing provider data into `catalog.json`
- Video / music / comic provider enrichment slices
- New browse-by-subject / genre facet UI (“filtered browsing” = existing search filters only)
- Description indexing or search snippets
- Relevance ML / fuzzy scoring beyond deterministic integer tiers
- Changing artwork precedence or download workflow (7.4 contract stands)
- User field-lock editing UI beyond what 7.3 already exposes (locks respected in merge; dedicated lock editor deferred)
- Sidecar / embedded text layers beyond what catalogue already exposes (slots reserved; no new extractors)
- Deferred music transport controls / artwork aspect-ratio improvements
- README.md changes
- Dependency / Flutter SDK bumps

---

## 7. Architectural principles

1. **Catalogue identity is law** — projection never changes `id`, `file_path`, `media_kind`, or playability.
2. **One merge owner** — `MetadataPresentationService` is the only place that resolves display/search text overlays.
3. **Append, never replace (search blob)** — local terms remain searchable even when enrichment disagrees.
4. **Linked-or-override for provider text** — provider fields participate only when match state is provider-linked **or** the field source is `user_override`.
5. **No network on the read path** — search/build/project/render use memory + SharedPreferences-loaded store only.
6. **Artwork stays on its path** — continue using `ArtworkPresentationService`; do not fold artwork into the text projection.
7. **Kind-safe** — non-books receive identity-preserving passthrough projections (catalogue fields only).
8. **Persisted presentation is gate-independent** — disabling live provider retrieval / enrichment development actions must **not** hide previously accepted provider metadata or user overrides. The feature gate stops **provider operations**; readable projection and local search overlays continue from the enrichment store.
9. **Determinism** — ranking and merge outcomes must be unit-testable without clocks/network (except persisted timestamps already on records).
10. **Structured search fields for ranking** — projection exposes classified enrichment terms (titles, authors, series, publishers, ISBNs, subjects). A flattened keyword list may exist for broad matching, but `SearchService` must be able to identify **which field class matched** so ranking tiers stay deterministic.

---

## 8. Enriched presentation projection

### 8.1 Recommended types

| Type | Responsibility |
|---|---|
| **`MetadataPresentationService`** | Pure/merge service: `present(MediaItem, {MetadataEnrichmentRecord? record})` → projection. Optional helper `presentForId` via repository lookup. **No HTTP. No persistence writes.** |
| **`MediaItemPresentation`** (immutable) | Resolved display strings + provenance metadata for UI/tests. Holds original `MediaItem` reference for identity/actions. |
| **`PresentedField`** (optional small value type) | `{ String? value, EnrichmentFieldSource? source, String? providerId, bool fromCatalogue }` for fields that show provenance on detail. |

Place under e.g. `lib/features/metadata_enrichment/presentation/` (or `lib/services/metadata/`) — keep import direction: presentation/search → enrichment models; enrichment must not import UI screens.

### 8.2 Projection contents (books slice)

| Field | Projection property | Notes |
|---|---|---|
| Identity | `item` | Always catalogue `MediaItem` |
| Display title | `displayTitle` | Precedence-resolved; identity title for filesystem ops remains `item.title` when needed |
| Display authors | `displayAuthors` / `authorLine` | Resolved author list + joined line for UI |
| Display series | `displaySeries` | Catalogue `series` until an enrichment series key exists |
| Subtitle | `subtitle` | Enrichment-only today |
| Publisher line | `publisherLine` | Enrichment publishers |
| Year | `yearLabel` | Enrichment publication year vs catalogue `year` |
| ISBN line | `isbnLine` | Prefer ISBN-13 then ISBN-10 |
| Subjects | `subjects` | Bounded list for detail chips (cap e.g. 12) |
| Description | `description` | Detail only; may be truncated for initial collapse |
| Match state | `matchState` | From record or “none” |

### 8.3 Structured search fields (required for ranking)

Do **not** reduce all enrichment matches to one generic low-priority blob. Ranking distinguishes catalogue title, enriched title, author/series, ISBN, and general subject matches. Projection therefore exposes **classified** searchable terms:

```dart
class MediaItemPresentation {
  final MediaItem item;
  final String displayTitle;
  final List<String> displayAuthors;
  final String? displaySeries;
  // … other display fields …

  /// Enrichment (and override) terms classified for SearchService scoring.
  final List<String> enrichedTitles;      // title + subtitle when eligible
  final List<String> enrichedAuthors;
  final List<String> enrichedSeries;      // empty until enrichment series key exists
  final List<String> enrichedPublishers;
  final List<String> enrichedIsbns;
  final List<String> enrichedSubjects;    // capped
  final List<String> enrichedYears;       // optional short year tokens

  /// Optional flatten of the lists above for broad token AND matching only.
  /// Must not be the sole input to ranking tiers.
  final String searchKeywords;
}
```

**Index construction rules:**

1. Catalogue fields remain **independently** indexed in the existing local blob (title, path, library, catalogue author/series, …).
2. Enrichment terms **append** — never replace catalogue terms.
3. `SearchService` scores using catalogue fields **and** the classified enrichment lists (exact/prefix/contains per class).
4. `searchKeywords` may feed broad token matching; field-class scores come from the structured lists.

Non-books: `displayTitle = item.title`; classified enrichment lists empty; `searchKeywords` empty.

### 8.4 Why a new projection (not mutate MediaItem)

ADR-029 Alternative A (overwrite catalogue fields) was rejected. Projection keeps `MediaItem` pristine for playback, progress, favourites, and rescan identity while allowing enriched **presentation**.

---

## 9. Field precedence matrix

Resolve each **presentation** field highest → lowest:

| Priority | Layer | Book sources in v1 |
|---|---|---|
| 1 | User override | `EnrichmentFieldValue` with `source == userOverride` (and/or key in `lockedFields`) |
| 2 | Local sidecar | Reserved — not exposed as separate client layer yet |
| 3 | Embedded file metadata | Already folded into catalogue `MediaItem` at scan (ADR-025) |
| 4 | Filesystem / catalogue | `MediaItem.title`, `author`, `series`, `year`, … |
| 5 | External enrichment | Provider-sourced fields when match state is provider-linked |
| 6 | Fallback | Filename stem for title; omit optional fields |

**Identity fields** (`id`, `file_path`, `media_kind`, `status`, size/path display): **always catalogue** — never layers 5–6.

| Display field | Layer 1 | Layer 4 (catalogue) | Layer 5 (linked provider) | Fallback |
|---|---|---|---|---|
| Title | override `title` | `item.title` | enrichment `title` | filename stem (`item.title` already) |
| Subtitle | override | — | `subtitle` | omit |
| Author(s) | override `authors` | `item.author` | `authors` | omit |
| Series | — (no key yet) | `item.series` | — | omit |
| Publisher | override | — | `publishers` | omit |
| Year | override year | `item.year` | `publicationYear` | omit |
| ISBN | override | — | isbn13 / isbn10 | omit |
| Subjects | override | — | `subjects` | omit |
| Description | override | — | `description` | omit |
| Artwork | (7.4 path) | local ArtworkService | provider cache | placeholder |

**Series note:** Catalogue series remains authoritative until a future enrichment key is added; do not invent series from subjects.

---

## 10. Search matching boundary

**Decision A — accepted:** Persisted enrichment fields **participate in local query matching**. No provider calls.

| Rule | Behaviour |
|---|---|
| Catalogue terms | Always indexed (existing blob) |
| User-override fields | Always eligible for keyword append when non-empty |
| Provider fields | Eligible **only** when `EnrichmentMatchState` ∈ {`linkedByIdentifier`, `linkedManual`, `linkedHighConfidence`} |
| `ambiguous` / `unmatched` / `ignored` / `stale` | Do **not** append provider fields; user overrides still append |
| Display of results | Still catalogue-backed `MediaItem` identity; row title may use projection `displayTitle` |
| Offline | Matching uses repository memory only |

Rationale: ISBN / author / enriched title searches are primary user value once a book is linked; requiring display-only enrichment would leave linked books hard to find by ISBN.

---

## 11. Searchable-field matrix

| Field | Index in 7.5? | Rationale |
|---|---|---|
| Enriched title | **Yes** | High intent |
| Subtitle | **Yes** | Short; useful |
| Authors / contributors | **Yes** | Primary book discoverability |
| Series | **Catalogue only** | No enrichment key yet |
| Publishers | **Yes** | Bounded strings |
| Publication year | **Yes** | Short token |
| ISBN-10 / ISBN-13 | **Yes** | Exact identifier lookup |
| Subjects | **Yes, capped** | Append at most **N=8** subject tokens per item |
| Description | **No** | Long text; cost/noise; detail-only (Decision G) |
| Languages | **No** (initial) | Low search value vs noise |
| publicationDate (full) | **No** if year present | Prefer year token |

Blob construction: normalize and **append** enrichment keywords after local blob; never remove local terms.

---

## 12. Search ranking rules

Keep integer, deterministic scoring. Extend `_score` (or equivalent) with explicit tiers, scoring catalogue fields and **classified** enrichment lists separately (not a single generic enrichment blob):

| Tier | Condition | Score contribution (proposed) |
|---|---|---|
| 1 | Exact catalogue title | **100** (unchanged) |
| 2 | Catalogue title prefix | **80** |
| 3 | Catalogue title contains | **60** |
| 4 | Filename / path / library / parent / extension | **40 / 30 / 20 / 10** (unchanged) |
| 5 | Exact enriched display title (≠ catalogue title) | **55** |
| 6 | Enriched title prefix/contains | **45 / 35** |
| 7 | Author / series (catalogue or enriched) token match | **25** |
| 8 | ISBN exact (normalized digits) | **70** |
| 9 | Publisher / subject / year token | **15** |

**Ordering:** higher score first; tie-break catalogue title A–Z (unchanged).

**Enrichment-only matches** (hit solely via tiers 5–9, no catalogue title/path contribution) therefore rank **below** strong catalogue title matches, and ISBN exact sits between title-contains and filename — intentional for identifier lookup without overtaking exact local titles.

Do **not** introduce TF-IDF, edit-distance, or non-deterministic boosting.

---

## 13. Search result presentation

| Element | Behaviour |
|---|---|
| Primary title | `MediaItemPresentation.displayTitle` when projection available; else `item.title` |
| Secondary line (books) | Author · series · year from projection (omit empties) |
| Folder context | Unchanged (`library · parent`) |
| Kind / extension / status | Unchanged from catalogue |
| Artwork | Unchanged `ResolvedMediaArtworkImage` |
| Provenance / match state | **Hidden** on rows (Decision E) |
| Description | **Never** on rows |
| Navigation | Still `item.id` → live catalogue resolve → detail |

Filters (library / extension / mediaKind) unchanged and apply before scoring.

---

## 14. Item-detail presentation

| Region | Behaviour |
|---|---|
| App bar / hero title | Projection `displayTitle` |
| Catalogue metadata chips | Prefer projection author/series/year when richer; keep extension/pageCount/status from catalogue |
| New enriched block (books) | Subtitle, publishers, ISBN, subjects (chips), collapsible description |
| `BookMetadataEnrichmentSection` | Remains management surface (match state, actions, artwork download) — not replaced |
| Provenance | Per-field subtle source hint **in enriched block / management section only** (e.g. “Open Library”, “Your override”) — not on every chip in the hero |
| Non-books | Unchanged catalogue detail |
| Artwork | Unchanged resolver path |
| Play / Open | Still gated by `item.status.isPlayable` |

**Feature-gate rule (locked):** Persisted presentation data is readable independently of whether live provider retrieval is currently enabled. Disabling enrichment/provider access stops provider operations (ISBN lookup, search, download/refresh) but must **not** hide previously accepted metadata or user overrides. Detail and search overlays continue from the enrichment store; management/action surfaces remain gated as today.

---

## 15. Match-state behaviour

| State | Search keywords (provider fields) | Detail enriched provider fields | Management UI (existing) |
|---|---|---|---|
| **linkedByIdentifier** | Yes | Yes | Linked by ISBN actions |
| **linkedHighConfidence** | Yes | Yes | Safe render (reserved write path) |
| **linkedManual** | Yes | Yes | Manual link actions |
| **ambiguous** | No (overrides only) | No provider fields; prompt review | Review required |
| **unmatched** | Overrides only | Overrides only | Lookup/search/ignore |
| **ignored** | Overrides only | Overrides only; no provider | Resume only |
| **stale** | No provider fields | Show catalogue + stale badge via management; do not present stale provider text as authoritative | Rematch prompt (existing) |
| **No record** | Catalogue only | Catalogue only | Not linked |

User-override fields always eligible for search append and display regardless of state (retained across unlink).

---

## 16. Provenance presentation

**Decision E — accepted:**

| Surface | Provenance / match state |
|---|---|
| Search result rows | Hidden |
| Browse cards | Hidden (cards remain artwork + catalogue/projection title only if later wired; **cards title overlay optional deferred** — default keep card title as catalogue unless cheap shared projection is already in hand) |
| Item detail enriched block | Light source labels / tooltips |
| `BookMetadataEnrichmentSection` | Full match-state label + provider attribution (existing) |

**Cards decision for 7.5:** Prefer **detail + search first**. Card title overlay is **optional stretch** only if projection is shared and tests stay green — not required for DoD.

---

## 17. Description and long-text handling

**Decision G — accepted:**

- Detail only
- Collapsed by default with “Show more” / expand when length > ~280 characters (exact constant in implementation)
- Not indexed
- Not shown as search snippets
- Empty/missing → omit section
- Corrupt/empty trimmed values skipped

---

## 18. Repository notification and cache lifecycle

| Event | Required behaviour |
|---|---|
| Enrichment `upsert` / `remove` / prune | `notifyListeners` (existing) |
| Search index | Mark **dirty** on enrichment notification; rebuild remains **lazy** (next `ensureIndex` / search) |
| Active `SearchScreen` query | Rerun current query after invalidation when mounted |
| Item detail | `context.watch` repository (section already does); metadata panel rebuilds from projection |
| Artwork | Unchanged 7.4 path |
| Feature gate off | Projection + search overlays still read persisted store; provider ops stay gated |

**Locked search refresh strategy:**

1. `SearchService` listens to `MetadataEnrichmentRepository` (composition-root wiring).
2. An enrichment notification **marks the index dirty** (coalesce multiple notifications during one operation where practical — e.g. single dirty flag / generation bump, not N immediate rebuilds).
3. Index rebuild remains **lazy** — do not rebuild the entire index synchronously on every field mutation.
4. Active `SearchScreen` reruns the current query after invalidation (generation-safe, same as catalogue search ownership).
5. Index build reads enrichment via existing repository contract (local, in-memory after load; no provider I/O).
6. Catalogue fields stay independently indexed; enrichment classified terms append on rebuild.

Avoid provider/network in all of the above.

---

## 19. Catalogue replacement behaviour

1. `CatalogCacheCoordinator.onCatalogReplaced` invalidates search index (existing).
2. Enrichment prune via `validateAgainstCatalog` (existing) — orphan ids removed; `notifyListeners`.
3. Projection for removed ids naturally unavailable.
4. Surviving ids keep enrichment; next search rebuild includes their keywords.
5. Stale rename/move (new md5 id): old record pruned — no silent transfer (ADR-029); user rematches.

Failed prune must not block catalogue usability (existing try/catch).

---

## 20. Offline and provider-call guarantees

| Path | May call provider? |
|---|---|
| Search typing / filter / index build | **No** |
| Search result render | **No** |
| Item detail render / projection | **No** |
| Browse / navigation | **No** |
| Explicit ISBN / search / download actions in enrichment section | **Yes** (existing 7.3/7.4 only; unchanged) |

Offline with linked records: enriched search + detail presentation continue from SharedPreferences store. Offline without records: catalogue-only behaviour identical to pre-7.5.

---

## 21. Error handling and corrupt-record recovery

| Failure | Behaviour |
|---|---|
| Missing enrichment record | Catalogue-only projection |
| Unknown match state / field source | Existing parsers default safely; projection ignores unusable fields |
| Malformed field value | Skip field; keep others |
| Empty trimmed enrichment value | Treat as absent |
| Repository load failure | Existing recovery; search/detail remain catalogue-only |
| Search index build failure | Existing `SearchIndexBuildException` snackbar path |
| Projection throws | Must not; pure functions with null-safe fallbacks |

---

## 22. Accessibility and responsive behaviour

- Search rows: semantics continue to include title + secondary metadata + folder context; include projected author when present.
- Detail description expand/collapse: labelled button, keyboard reachable.
- Match-state management controls retain existing large targets / focus behaviour.
- Narrow widths: reuse existing detail column layout; description wraps; subjects wrap as chips.
- No colour-only status — keep icons/labels from `MetadataMatchStatePresentation`.

---

## 23. Performance considerations

| Topic | Guidance |
|---|---|
| Index build | O(items); enrichment lookup should be O(1) map snapshot, not linear scan per field |
| Description | Not in blob — avoids large string growth |
| Subjects cap | Max 8 in search keywords; max 12 chips on detail |
| Search debounce | Keep 150 ms |
| maxResults | Keep 100 |
| Rebuild on enrichment | Invalidate+lazy rebuild acceptable for v1; optimize to per-id patch only if measurements demand |
| Projection | Cheap pure merge; safe to compute per row; memoization optional, not required for DoD |

---

## 24. Test strategy

### Unit

- Precedence matrix cases (override > catalogue > provider > fallback)
- Match-state gating for provider fields
- Search keyword append (local retained; enrichment appended)
- Ranking tiers (exact catalogue > enrichment-only author/ISBN)
- ISBN normalization match
- Non-book passthrough
- Corrupt/empty field skip

### Widget / presentation

- Item detail shows enriched fields when linked; falls back when unlinked
- Description collapsed/expand
- Search rows show projected title/author without provenance chips
- Enrichment notify refreshes visible search results
- Feature-gate / management section regressions from 7.3 suite remain green
- Artwork integration tests remain green (no regress)

### Lifecycle

- Catalogue replace clears enrichment keywords for pruned ids
- Restart: load repository → search finds ISBN from persisted record without provider
- Cross-item isolation (enrich A ≠ affect B)

### Isolation

- Presentation/search modules must not import Open Library HTTP adapters
- No network in default `flutter test`

---

## 25. Windows runtime validation matrix

Extend Phase 7.3.6 harness pattern (new file preferred: `phase_75_search_detail_windows_runtime_test.dart`).

| ID | Scenario |
|---|---|
| R1 | Gate off / no records — search + detail catalogue-only baseline |
| R2 | Seed linked book with enriched title/author/ISBN — search by ISBN hits item |
| R3 | Search by enriched author ranks below exact catalogue title twin when both match differently |
| R4 | Detail shows enriched subtitle/publisher/ISBN/description expand |
| R5 | Unlink → provider fields leave search; user override (if any) remains |
| R6 | Ignore → no provider search keywords; resume restores unmatched (no auto provider) |
| R7 | Relink → new keywords replace prior provider keywords after refresh |
| R8 | Catalogue replace pruning removes orphan search keywords |
| R9 | No HTTP during search typing / detail open (scripted counters) |
| R10 | Artwork still resolves via 7.4 path on search row + detail |
| R11 | Non-book search/detail unchanged |
| R12 | App restart reload: persisted enrichment still searchable |

```powershell
cd client\ttsplayer
$env:PHASE_75_RUNTIME='1'
flutter test test/phase_75_search_detail_windows_runtime_test.dart --tags phase75-runtime
Remove-Item Env:PHASE_75_RUNTIME
```

Default CI remains skip-when-unset.

---

## 26. Manual QA checklist

- [ ] Linked book findable by ISBN offline
- [ ] Linked book findable by enriched author
- [ ] Exact local title still ranks above enrichment-only hit
- [ ] Detail shows enriched fields; Open Book still works
- [ ] Unlink clears enriched provider presentation; catalogue title/author return
- [ ] Ignored book does not match provider-only terms
- [ ] Search filters (Book kind / extension / library) still work
- [ ] Description expands/collapses; absent description omits section
- [ ] Search rows uncluttered (no provenance badges)
- [ ] Management section still supports ISBN/search/relink/unlink/ignore/resume when gate on + coordinator provided in test harness
- [ ] Video/music/comic smoke: browse, search, play/open unchanged
- [ ] Windows release build still succeeds

---

## 27. Definition of Done

Phase 7.5 is done when:

1. **Projection service** merges MediaItem + enrichment per §9 with identity fields unchanged.
2. **Search** appends bounded enrichment keywords and ranks per §12 with **zero** provider calls on search paths.
3. **Item detail** presents enriched book fields with catalogue fallback and collapsible description.
4. **Match-state / override gating** matches §15.
5. **Provenance** limited to detail/management per §16.
6. **Lifecycle:** enrichment changes refresh search/detail; catalogue replace/restart behave per §18–19.
7. **Artwork** path unchanged in contract; 7.4.6 tests remain green.
8. **Automated tests** for precedence, search, detail, lifecycle, isolation pass; full suite green.
9. **Windows runtime harness** (§25) passes when gated on.
10. **Docs** updated (this plan → closure; m7-plan / architecture / v0.8.0-dev).
11. **No** dependency, catalogue schema, README, or unrelated playback changes.
12. **No** automatic/background enrichment enabled.

---

## 28. Implementation steps and proposed commit sequence

| Step | Focus | Proposed commit style |
|---|---|---|
| **7.5.1** | Audit + plan (this document) | `docs(m7.5): plan metadata-aware search and detail presentation` |
| **7.5.2** | `MetadataPresentationService` + `MediaItemPresentation` + precedence unit tests | `feat(m7.5): add metadata presentation projection` |
| **7.5.3** | Search blob append, ranking tiers, enrichment invalidation, search unit/lifecycle tests | `feat(m7.5): index persisted enrichment terms for local search` |
| **7.5.4** | Item-detail enriched surfaces + description collapse + presentation tests | `feat(m7.5): render enriched book fields on item detail` |
| **7.5.5** | Search row projected title/secondary line + refresh-on-enrichment | `feat(m7.5): present enrichment overlays in search results` |
| **7.5.6** | Windows runtime harness R1–R12 | `test(m7.5): add Windows search/detail enrichment runtime harness` |
| **7.5.7** | Closure report + tracker/architecture status updates | `docs(m7.5): close metadata-aware search and detail presentation` |

Optional stretch (same phase only if ahead of schedule): browse card title overlay via shared projection — separate tiny commit, not required for DoD.

---

## 29. Risks, decisions, known limitations, and deferred work

### Locked decisions (7.5.1)

| ID | Decision |
|---|---|
| A | Persisted enrichment participates in **local** search matching; **never** invokes a provider |
| B | Searchable: title, subtitle, authors, publishers, year, ISBNs, capped subjects — **not** description/languages |
| C | Precedence = ADR-029 layers; identity never from provider |
| D | Provider text only for `linkedByIdentifier` / `linkedHighConfidence` / `linkedManual`; overrides always visible even when provider data excluded |
| E | Provenance on detail/management only; search may show enriched title/author/series without provenance clutter |
| F | Deterministic tiered ranking via **structured** enrichment field lists; catalogue title first; ISBN elevated |
| G | Description detail-only, collapsible; no snippets/indexing |
| H | Feature gate stops **provider operations** only; persisted presentation + overrides remain readable |
| I | Enrichment notify → mark search index dirty → lazy rebuild; coalesce bursts; active search reruns query |

### Invariants to preserve exactly through implementation

1. Catalogue fields remain independently indexed.
2. Enrichment terms append to the search document — never replace catalogue terms.
3. Overrides remain visible even when provider data is excluded.
4. Provider text is limited to accepted linked states.
5. Search results remain uncluttered (no provenance/match-state controls on rows).
6. Description remains detail-only (not indexed).

### ADR-029 Accept gate

Keep ADR-029 **Proposed** through 7.5.1. Move to **Accepted** only after all of:

1. Projection service implemented
2. Precedence verified by tests
3. Search and detail both use the shared projection
4. Lifecycle behaviour validated
5. Windows runtime matrix passes

### Risks

| Risk | Mitigation |
|---|---|
| Search index rebuild cost on every enrichment edit | Dirty flag + lazy rebuild; coalesce notifications |
| Generic blob collapsing ranking tiers | Structured enrichment field lists on projection (§8.3) |
| Title disagreement (provider vs filename) confuses users | Keep path/filename searchable; show light provenance on detail |
| Feature-gate hiding accepted metadata | Locked decision H — gate operations, not persisted presentation |
| Duplicate merge logic creeping into widgets | Enforce single service; tests fail if widgets read `record.fields` directly |
| `linkedHighConfidence` rarely written | Still handle in gating for forward compatibility |
| Series only on catalogue | Document limitation; do not fake series from subjects |

### Deferred

- Card grid title overlays (stretch)
- Enrichment `series` field key + Open Library series mapping
- Production provider/coordinator wiring in `main.dart`
- Subject/genre facet browsing
- Description search / snippets
- Video/music/comic enrichment presentation
- User lock editor UX
- Sidecar/embedded text layers beyond catalogue
- ADR-029 Accept (after §29 Accept gate)

### Known limitations

- Enrichment section still requires test/harness coordinator wiring for live actions
- Item detail holds MediaItem snapshot (projection uses that snapshot + live enrichment by id)
- Subjects may be noisy depending on provider data quality — hard caps apply

---

## Audit appendix — key constructors / APIs

```
SearchService()
SearchService.searchCatalog(Catalog, String, SearchFilters) → Future<List<SearchResult>>
SearchService.search(String, SearchFilters) → List<SearchResult>
SearchService.onCatalogReplaced(Catalog)
SearchService.ensureIndex(Catalog)

SearchResultRow({required SearchResult result, required String displayContext,
                 required VoidCallback onOpen, VoidCallback? onBrowseFolder, VoidCallback? onPlay})

ItemDetailScreen({required MediaItem item})
BookMetadataEnrichmentSection({required MediaItem item})

MetadataEnrichmentRepository({List<MetadataEnrichmentRecord>? initialRecords})
MetadataEnrichmentRepository.getByItemId(String) → MetadataEnrichmentRecord?
MetadataEnrichmentRepository.upsert / remove / validateAgainstCatalog / initialize

MetadataEnrichmentRecord({required itemId, required matchState, fields, lockedFields, …})
EnrichmentFieldValue({required value, required source, providerId, updatedAt, locked})
```

Proposed new API (implementation step 7.5.2):

```
MetadataPresentationService.present(MediaItem item, {MetadataEnrichmentRecord? record})
  → MediaItemPresentation
  // includes display* fields + classified enrichedTitles/Authors/Series/
  // Publishers/Isbns/Subjects (+ optional searchKeywords flatten)
```
