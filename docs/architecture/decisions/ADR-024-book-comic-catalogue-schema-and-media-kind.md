# ADR-024: Book/Comic Catalogue Schema and Media Kind

**Status:** **Accepted** (2026-07-28) — catalogue v4 implemented in Phase 6.1; **comic production extension amended to `.cbz` only** per [ADR-026 Accepted](./ADR-026-reader-surface-architecture.md)
**Date:** 2026-07-24 (proposed) / 2026-07-28 (accepted)
**Milestone:** M6 — Phase 6.1  
**Related:** [books-comics.md](../books-comics.md) · [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [m6-plan.md](../../roadmap/m6-plan.md) · [ADR-020](./ADR-020-music-catalogue-schema-and-media-kind.md) · [ADR-026](./ADR-026-reader-surface-architecture.md)

---

## Context

M5 introduced `media_kind: audio` and expanded the catalogue for music. M6 must index books and comics without inventing categories or breaking existing video/audio/image catalogues.

`.cbz` and `.cbr` were both considered primary comic archive formats during M6 planning. Gate 0 CBR investigation and [ADR-026 Accepted](./ADR-026-reader-surface-architecture.md) (2026-07-27) changed **production comic support to CBZ-only**. This ADR records the accepted catalogue architecture with that amendment.

---

## Decision

1. Distinct `media_kind` values: **`book`** and **`comic`** (alongside `video`, `audio`, `image`, `unknown`).
2. M6 **production** supported extensions:
   - Books: `.pdf`, `.epub`
   - Comics: **`.cbz`** (ZIP-based comic archive)
3. **Legacy `.cbr`:** not indexed on new scans; existing catalogue entries may remain until rescanned after external conversion to CBZ (client shows conversion guidance).
4. **`catalogue_version: 4`**, scanner **`0.5.0`**.
5. Emit `supported_extensions` including the new formats.
6. Unknown future kinds remain non-fatal on the client (`MediaKind.unknown`).
7. Client refuses catalogues with `catalogue_version` **greater than** `CatalogueInfo.maxSupportedCatalogueVersion` (currently 4) via `UnsupportedCatalogueVersionException`, preserving the previous catalogue through existing `CatalogService` error handling.
8. Do **not** invent a `media_type` / category field on folders.
9. **CBR/RAR production (superseded):** Original M6 planning required in-app CBR support. ADR-026 **Accepted** removed CBR from production scope. Historical Gate 0 investigation is archived under `docs/architecture/archive/unrar-evaluation/`.

---

## Consequences

### Positive

- Clear routing to comic vs book readers
- Additive catalogue evolution with an explicit version bump
- CBZ comic indexing in production; honest CBR disposition via ADR-026

### Negative / risks

- Older clients may ignore book/comic items until updated (acceptable)
- Legacy `.cbr` catalogue entries require user conversion + rescan

### Compatibility

- Existing `catalog.json` v2/v3 remains loadable
- Rescan required to surface book/comic items
- Video/audio/image emission unchanged
- Books/comics are not A/V-playable (`canStartAvPlayback == false`)

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Single `document` kind | Collapses different reader/progress models |
| Treat CBZ as `image` | Breaks browse semantics |
| CBZ-only comics; defer CBR in production | **Accepted** (2026-07-27) — ADR-026; external conversion for legacy libraries |
| `package:rar` for Windows | Published platforms omit Windows |
| Bundle UnRAR.exe as primary | Heavier ops; kept as Gate 0 fallback |
| Custom libarchive FFI as primary | More ownership; keep as alternate if UnRAR FFI fails |

---

## Acceptance criteria

- [x] Indexer emits `book` / `comic` with `.pdf`/`.epub`/`.cbz`
- [x] Client parses kinds without crashing on mixed catalogues
- [x] Automated tests cover emission + parse + mixed-media isolation
- [x] ~~Windows CBR approach Gate 0~~ → **Superseded** by ADR-026 (CBZ-only production)
- [x] Phase 6.1 review approved and committed
- [x] ADR-024 formal **Accepted** (2026-07-28; comic extension CBZ-only)
