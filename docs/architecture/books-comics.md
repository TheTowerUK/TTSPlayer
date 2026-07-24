# Books & Comics Architecture (M6)

**Status:** Active — Phase 6.2 browse/presentation complete; Phase 6.3 reader next (2026-07-24)  
**Milestone plan:** [m6-plan.md](../roadmap/m6-plan.md)  
**Related ADRs:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [ADR-025](./decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md) · [ADR-027](./decisions/ADR-027-reading-progress-and-continue-reading.md)

> Phases 6.1–6.2 are implemented on `m6-development`. Reader surfaces (6.3+) and progress (6.5) remain planned until those phases close and ADRs are Accepted.

---

## Purpose

Describe how books and comics fit into TTSPlayer’s existing folder-first, provider-neutral platform without inventing categories, parallel catalogues, or silent absorption of deferred music work.

---

## Design constraints (inherited)

| Constraint | Implication for books/comics |
|---|---|
| Filesystem is truth | Folder names are the only library categories |
| Catalogue principle | No “All Books” / “Comics” virtual roots as fake folders |
| Graceful degradation | Missing cover/metadata still shows the item |
| Item status model | Status gates playability/openability; unknown status safe |
| Local-first | Readers work offline against local/NAS/HTTPS media |
| Reuse infrastructure | Providers, resolver, search, artwork, cache, diagnostics |

---

## Content model (proposed)

### Media kinds

| Kind | Typical formats (M6 baseline) | Primary surface |
|---|---|---|
| `comic` | **`.cbz`**, **`.cbr`** (both required) | Comic archive reader (Phase 6.3) |
| `book` | `.pdf`, `.epub` | Document reader (Phase 6.4) |
| existing | `video`, `audio`, `image`, `unknown` | Unchanged |

**Recommendation:** Keep `book` and `comic` distinct. Presentation, progress units, and reader stacks differ enough that a single `document` kind would force awkward branching.

**Comic formats:** `.cbz` (ZIP) and `.cbr` (RAR) are the two primary comic archive formats and are **required M6 baseline scope**. CBR is an implementation/dependency risk, not optional product scope. Any later deferral of CBR requires an explicit documented decision, rationale, known limitation, and approval before M6 closure.

**CBR/RAR stack (Phase 6.1):** **Provisional preferred** — `package:unrar` (Dart FFI to official UnRAR). **Not** `package:rar` for Windows (published platforms omit Windows). See [cbr-rar-evaluation.md](./cbr-rar-evaluation.md). Not wired into the app until Phase 6.3 **Gate 0** passes.

### Catalogue versions

| Version | Scanner | Content |
|---|---|---|
| 3 | 0.4.0 | Video / audio / image + music metadata |
| **4** | **0.5.0** | + book / comic kinds and extensions |

Client `CatalogueInfo.maxSupportedCatalogueVersion` is **4**. Higher versions throw `UnsupportedCatalogueVersionException`.

### What is not a comic in initial M6 scope

Loose image sequences in a folder remain `image` items (M4 behaviour). Promoting folders of images to “virtual comics” invents structure and is out of scope unless separately approved.

---

## Catalogue and scanner

### Indexer responsibilities

- Discover supported book/comic extensions under the scanned root
- Emit `media_kind` of `book` or `comic`
- Preserve folder tree as-is; prune empty branches per existing rules
- Prefer lightweight metadata (filename stem as title; optional embedded title if cheap and reliable)
- Never invent category labels from format
- Continue atomic write of `catalog.json`

### Client responsibilities

- Parse new kinds with unknown-kind safety (default presentation, not crash)
- Present books/comics in folder browse, search, and detail with kind labels/icons (Phase 6.2)
- Route open actions by kind to the correct reader **when readers exist** (6.3/6.4); until then show a non-reader stub and refuse A/V playback
- Keep `SupportedExtensions` and catalogue `supported_extensions` in sync

### Browse and presentation (Phase 6.2)

| Surface | Behaviour |
|---|---|
| Folder browse | `.pdf`/`.epub` → Book; `.cbz`/`.cbr` → Comic; mixed folders show all kinds; filters `Books` / `Comics` |
| Cards / list rows | Kind badge + subtitle (author/series when present); distinct literature vs comics placeholders |
| Search | Kind chips in TYPE filter row; author/series in search blob (6.1); no path leakage |
| Item detail | Available metadata only; primary action disabled (“Reader available in a later phase”) |
| Isolation | Books/comics never open video player, music player, or image viewer |

No virtual “All Books” / “All Comics” libraries.

### Versioning

- Likely `catalogue_version: 4` when book/comic kinds and extensions ship (ADR-024)
- Older clients must ignore unknown kinds safely; older catalogues remain loadable

---

## Identity and metadata (proposed)

Aligned with music ADR-021 patterns:

| Field | Source of truth |
|---|---|
| Stable item `id` | Path-derived (existing MD5-of-path pattern) |
| Display title | Filename stem unless richer metadata is explicitly trusted |
| Cover / thumbnail | Optional; placeholder on miss |
| Series / volume / author | Optional enrichment only — never invent folders |

Remote metadata APIs are out of M6 scope.

---

## Reader architecture (proposed)

### Surfaces

| Surface | Role |
|---|---|
| Folder / detail | Discover and open |
| Comic reader | Paged image sequence from archive |
| Book reader | Document navigation (PDF pages / EPUB spine) |
| Continue Reading | Application-managed list of in-progress items |

Video `PlayerScreen` and music listening surfaces are **not** reused for reading. Shared design tokens and chrome patterns are encouraged; shared playback controllers are forbidden.

### Access path

All opens go through `MediaLocationResolver` / existing provider config so local, UNC, and HTTPS catalogues behave consistently.

### Extraction / decode

- **CBZ:** ZIP entry list → decode pages lazily (required; reader in 6.3)
- **CBR:** RAR via **provisional preferred** stack `package:unrar` (official UnRAR Dart FFI). `package:rar` is **not** preferred for Windows (no published Windows platform support). Gate 0 in Phase 6.3 is blocking — see [cbr-rar-evaluation.md](./cbr-rar-evaluation.md).
- **Indexer metadata (6.1):** CBZ may read ComicInfo.xml; CBR uses filename title only until the reader stack is wired.
- **Failure modes:** unsupported, encrypted, corrupt, or multi-volume archives fail gracefully — no crash; catalogue browse/playback elsewhere unaffected
- **PDF/EPUB:** Via vetted Flutter/Windows-capable packages (spike before Accept in 6.4)

Temp files must be session-scoped or LRU-cached with a documented wipe policy (open question in m6-plan).

### Comic reader validation

Comic reader DoD requires Windows runtime validation of **both** CBZ and CBR fixtures (open + page navigation).

---

## Reading state (proposed)

| Concern | Owner |
|---|---|
| What files exist | Catalogue / filesystem |
| Last page / position | Application reading-progress store |
| Continue Reading order | Derived from reading-progress timestamps |
| Favourites (future) | Not required for M6 DoD |

**Isolation:** Reading-progress preference keys must not collide with:

- Video `position_*`
- Music listening history / session persistence
- Favourites

Catalogue replacement must prune stale reading-progress entries using the same coordinator pattern as M5.

---

## Search and diagnostics

- Search indexes book/comic titles like other items; kind label for presentation
- Diagnostics expose aggregate counts (items indexed, opens, progress entries) with redaction parity to music
- No new diagnostics pipeline

---

## Cross-platform notes

- **Primary gate:** Windows (desktop)
- Android/iOS: architecture should not preclude later parity; not required for M6 DoD
- Native reader plugins must be documented in release notes when required

---

## Test and validation strategy

| Layer | Expectation |
|---|---|
| Unit | Indexer kinds/extensions; identity; progress repository |
| Widget | Browse labels; reader chrome; Continue Reading |
| Integration | Catalogue replace prune; key isolation |
| Opt-in Windows runtime | Open comic/book; page turn; resume after restart |
| Regression | Full Flutter suite + video/music focused suites |

---

## Relationship to deferred M5 music work

Music playlists, shuffle/repeat, lyrics, favourites redesign, and related items remain on the **music backlog**. They are not prerequisites for books/comics and must not be smuggled into M6 phases.

---

## Implementation map (by phase)

| Phase | Architecture focus |
|---|---|
| 6.1 | Schema, kinds, indexer, client models |
| 6.2 | Browse / detail / search presentation — ✅ Complete (kind badges, folder filters, search kind chips, detail stub, placeholders; no readers) |
| 6.3 | Comic reader |
| 6.4 | Book reader |
| 6.5 | Reading progress + Continue Reading |
| 6.6 | Performance, diagnostics, runtime matrix |
| Release | Governance and tags |

---

## Open decisions

See [m6-plan.md — Open questions](../roadmap/m6-plan.md#open-questions-resolve-before-or-during-early-phases).
