# ADR-020: Music Catalogue Schema and Media Kind



**Status:** Accepted

**Implementation (M5.1):** Scanner `0.4.0` emits `catalogue_version: 3` with `media_kind` on all newly indexed items. Client infers kind for legacy v2 catalogues via extension. See [Phase 5.1 spec](../../roadmap/m5-phase-5.1-music-catalogue-metadata.md).

**Date:** 2026-07-19

**Milestone:** M5 Phase 5.0 / 5.1

**Authors:** M5 planning pass



---



## Context



TTSPlayer's `catalog.json` (catalogue version **2**) indexes **video** and **image** files via extension. Items carry path-derived `id`, filename-based `title`, optional duration, status, and `added_at`. There is no explicit **media kind** field — kind is inferred from extension in the client.



M5 requires **audio** files in the same folder tree with optional embedded-tag metadata. The client must:



- Load mixed catalogues without breaking video/image behaviour

- Detect unsupported schema versions safely

- Avoid a second catalogue file or parallel item model



Constraints: filesystem-is-truth; atomic catalogue writes; scanner standard library only; backward compatibility with existing libraries and bundled mock data.



---



## Decision



1. **Bump `catalogue_version`** to **3** when music schema ships (exact integer finalized in Phase 5.1 spec).



2. Add required **`media_kind`** on every newly indexed item: `video`, `audio`, or `image`.



3. Add **optional music metadata fields** on items (see [music.md](../music.md#4-proposed-catalogue-and-metadata-model)) — none mandatory for index emission except `media_kind` for audio extensions.



4. **Legacy catalogues** without `media_kind`: client infers kind from extension using the same rules as today's indexer.



5. **Unsupported `catalogue_version`:** client retains last-good catalogue and surfaces recoverable error (existing `CatalogService` pattern).



6. **Single `catalog.json`** remains the only scanned catalogue — no per-domain catalogue files.



---



## Rationale



- Explicit `media_kind` avoids ambiguous extensions (e.g. `.m4a`, `.mp4`) and simplifies UI routing.

- Optional fields preserve graceful degradation when tags are missing.

- Version bump gives a clear compatibility gate without silent mis-parse.

- One catalogue preserves M3.5 provider loading, cache invalidation, and search lifecycle.



---



## Consequences



### Positive



- Unified load path for mixed libraries

- Clear client branching for browse vs music views

- Testable compatibility matrix (v2 video-only, v3 mixed)



### Negative



- Full rescan required to populate music metadata on existing libraries

- Client and indexer must ship together for v3 (or client tolerates absent fields)



### Neutral



- Mock/bundled catalogues updated when 5.1 implements



---



## Alternatives considered



### Alternative A — Separate `music_catalog.json`



**Rejected because:** Violates single-catalogue principle; duplicates provider, cache, and search infrastructure.



### Alternative B — Infer audio only from extension without `media_kind`



**Rejected because:** Ambiguous extensions and future formats; harder diagnostics and search presentation.



---



## Related documents



- [M5 plan](../../roadmap/m5-plan.md)

- [music.md](../music.md)

- [indexer.py](../../../backend/indexer.py) — `CATALOGUE_VERSION`, `SUPPORTED_EXTENSIONS`

- [media_item.dart](../../../client/ttsplayer/lib/models/media_item.dart)
