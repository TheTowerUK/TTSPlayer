# ADR-024: Book/Comic Catalogue Schema and Media Kind

**Status:** Proposed (catalogue implementation landed in Phase 6.1; CBR reader stack Gate 0 **FAIL** for `package:unrar` 2026-07-25 — Accept deferred)  
**Date:** 2026-07-24  
**Milestone:** M6 — Phase 6.1  
**Related:** [books-comics.md](../books-comics.md) · [cbr-rar-evaluation.md](../cbr-rar-evaluation.md) · [m6-plan.md](../../roadmap/m6-plan.md) · [ADR-020](./ADR-020-music-catalogue-schema-and-media-kind.md)

---

## Context

M5 introduced `media_kind: audio` and expanded the catalogue for music. M6 must index books and comics without inventing categories or breaking existing video/audio/image catalogues.

`.cbz` and `.cbr` are the two primary comic archive formats. Both belong in M6 baseline product scope. CBR’s greater technical risk is an **implementation and dependency** concern, not optional product scope.

---

## Decision

1. Distinct `media_kind` values: **`book`** and **`comic`** (alongside `video`, `audio`, `image`, `unknown`).
2. M6 supported extensions:
   - Books: `.pdf`, `.epub`
   - Comics: **`.cbz`** and **`.cbr`** — **both required**
3. **`catalogue_version: 4`**, scanner **`0.5.0`**.
4. Emit `supported_extensions` including the new formats.
5. Unknown future kinds remain non-fatal on the client (`MediaKind.unknown`).
6. Client refuses catalogues with `catalogue_version` **greater than** `CatalogueInfo.maxSupportedCatalogueVersion` (currently 4) via `UnsupportedCatalogueVersionException`, preserving the previous catalogue through existing `CatalogService` error handling.
7. Do **not** invent a `media_type` / category field on folders.
8. Do **not** silently defer `.cbr`. Any later deferral requires an explicit documented decision, rationale, known limitation, and approval before M6 closure.
9. **Windows CBR/RAR approach (Phase 6.1 — provisional preferred, not Gate-0 validated):**
   - **Provisional preferred:** [`package:unrar`](https://pub.dev/packages/unrar) — Dart FFI to the **official UnRAR library** (RARLab). Published docs claim Windows / macOS / Linux support, list + selective extract APIs, and RAR4/RAR5.
   - **Not preferred for Windows:** [`package:rar`](https://pub.dev/packages/rar) — published platform support is Android / iOS / macOS / Web only; do not treat it as a Windows implementation without evidence.
   - **Documented fallbacks:** bundled UnRAR CLI (subprocess), or first-party FFI to UnRAR / libarchive if Gate 0 rejects `unrar`.
   - **Dependency is not added in Phase 6.1.** Phase **6.3 Gate 0** (Release spike + fixtures + licensing) is **blocking** before CBR reader Accept. See [cbr-rar-evaluation.md](../cbr-rar-evaluation.md).

---

## Consequences

### Positive

- Clear routing to future comic vs book readers
- Additive catalogue evolution with an explicit version bump
- Both primary comic formats indexed today
- Honest Windows CBR plan (provisional + Gate 0) rather than assuming an unsupported plugin platform

### Negative / risks

- Older clients may ignore book/comic items until updated (acceptable)
- `package:unrar` is early (`0.1.x`) and unverified until Gate 0
- Packaging / UnRAR redistribution diligence remains open until 6.3

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
| CBZ-only comics; defer CBR | Rejected — both formats are primary |
| `package:rar` for Windows | Published platforms omit Windows |
| Bundle UnRAR.exe as primary | Heavier ops; kept as Gate 0 fallback |
| Custom libarchive FFI as primary | More ownership; keep as alternate if UnRAR FFI fails |

---

## Acceptance criteria

- [x] Indexer emits `book` / `comic` with `.pdf`/`.epub`/`.cbz`/`.cbr`
- [x] Client parses kinds without crashing on mixed catalogues
- [x] Automated tests cover emission + parse + mixed-media isolation
- [x] Windows CBR approach recorded as **provisional preferred** with Gate 0 defined (not falsely marked validated)
- [x] Caddy/media allowlists aligned (incl. pre-existing audio gap)
- [x] Phase 6.1 review approved and committed
- [ ] Phase 6.3 Gate 0 passes before CBR reader Accept
- [ ] ADR-024 formal **Accepted** (remains Proposed until Gate 0 / explicit Accept)
