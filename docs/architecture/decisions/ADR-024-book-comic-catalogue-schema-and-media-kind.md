# ADR-024: Book/Comic Catalogue Schema and Media Kind

**Status:** Proposed  
**Date:** 2026-07-24  
**Milestone:** M6 — Phase 6.0 / 6.1  
**Related:** [books-comics.md](../books-comics.md) · [m6-plan.md](../../roadmap/m6-plan.md) · [ADR-020](./ADR-020-music-catalogue-schema-and-media-kind.md)

---

## Context

M5 introduced `media_kind: audio` and expanded the catalogue for music. M6 must index books and comics without inventing categories or breaking existing video/audio/image catalogues.

The scanner today supports video, audio, and image extensions (`CATALOGUE_VERSION = 3`). Book/comic formats (PDF, EPUB, CBZ, CBR) are not indexed.

`.cbz` and `.cbr` are the two primary comic archive formats used by personal libraries. Both belong in M6 baseline product scope. CBR’s greater technical risk is an **implementation and dependency** concern, not a reason to treat the format as optional.

---

## Decision (proposed)

1. Introduce distinct `media_kind` values: **`book`** and **`comic`**.
2. M6 supported extensions:
   - Books: `.pdf`, `.epub`
   - Comics: **`.cbz`** and **`.cbr`** — **both required** baseline formats
3. Bump **`catalogue_version` to `4`** when these kinds/extensions ship, and bump scanner version accordingly.
4. Emit `supported_extensions` including the new formats so clients can reconcile allowlists.
5. Unknown future kinds remain non-fatal on the client (safe default presentation).
6. Do **not** invent a `media_type` / category field on folders.
7. Do **not** silently defer `.cbr`. Any later deferral requires an explicit documented decision, rationale, known limitation, and approval before M6 closure.
8. Phase 6.0 or early Phase 6.1 must evaluate and select a Windows-compatible RAR/CBR solution (licensing, maintenance, packaging, extraction security, performance, testability).

---

## Consequences

### Positive

- Clear routing to comic vs book readers
- Additive catalogue evolution with an explicit version bump
- Consistent with ADR-020’s kind-based model
- Comic libraries that use either primary archive format are first-class

### Negative / risks

- Older clients may ignore book/comic items until updated (acceptable)
- CBR/RAR requires a vetted Windows dependency stack — higher packaging and security diligence than ZIP/CBZ (mitigate with early selection + fixtures; product scope remains required)

### Compatibility

- Existing `catalog.json` v3 remains loadable
- Rescan required to surface book/comic items
- Video/audio/image emission unchanged

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Single `document` kind | Collapses different reader/progress models |
| Treat CBZ as `image` | Breaks browse semantics; comics are archives, not single images |
| CBZ-only comics; defer CBR | Rejected for M6 baseline — both formats are primary; CBR risk is implementation, not scope optionality |
| No catalogue_version bump | Harder for clients to detect capability |

---

## Acceptance criteria (for later Accept)

- [ ] Indexer emits `book` / `comic` with correct extensions including **both** `.cbz` and `.cbr`
- [ ] Client parses kinds without crashing on mixed catalogues
- [ ] Automated tests cover emission + parse + mixed-media isolation
- [ ] Windows RAR/CBR implementation selected and documented (or explicitly handed as early-6.1 blocking prerequisite with criteria)
- [ ] Docs updated; Caddy/media allowlists aligned if applicable
