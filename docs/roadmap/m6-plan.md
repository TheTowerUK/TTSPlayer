# M6 — Books & Comics

**Status:** **CLOSURE AUDIT COMPLETE** (2026-07-28) — Phases 6.0–6.6 and **6.4C** complete on `m6-development`; **release finalisation pending** (no tags/version bump in audit)
**Comic format:** **CBZ-only** production — CBR removed; external conversion + rescan for legacy libraries (ADR-026 **Accepted**)
**Branch:** `m6-development`  
**Development version:** `v0.7.0-dev` (proposed; app remains `0.6.0+1` until release)  
**Predecessor:** M5 — tags `v0.6.0` / `m5-complete` (2026-07-24)  
**Phase 6.1:** ✅ Complete (2026-07-24) — catalogue v4 / books & comics indexing  
**Phase 6.2:** ✅ Complete (2026-07-24) — browse / search / detail presentation (no readers)  
**Phase 6.3:** ✅ **Complete** — CBZ-only comic reader; ADR-026 **Accepted**; CBR removed from production scope.
**Phase 6.4C:** ✅ **Complete** (2026-07-28) — [m6-phase-6.4-comic-reading-experience.md](./m6-phase-6.4-comic-reading-experience.md) — comic reading experience closure (CBZ production reader UX, progress, resilience, diagnostics, Windows runtime).

→ [Books & comics architecture](../architecture/books-comics.md)
→ [Comic reading experience closure plan (6.4C)](./m6-phase-6.4-comic-reading-experience.md)
→ [M5 complete](../release/m5-complete.md)  
→ [Roadmap principles](./principles.md)  
→ [Architecture index](../architecture/README.md)  
→ [ADR framework](../architecture/decisions/README.md)

> **Scope note:** M6 adds a **reading experience** for books and comic archives on the existing folder-tree platform. It does **not** invent virtual libraries, replace video/music workflows, absorb deferred music features, or deliver multi-device sync.

---

## Mission

M6 extends TTSPlayer from a **video + music** personal media application into a platform that also supports **books and comics**: index supported document/archive formats in the existing catalogue, browse them without inventing categories, open dedicated readers, and remember reading progress — while preserving:

- Filesystem-driven library structure (folder names remain the categories)
- Provider-neutral media access (local, UNC, HTTPS)
- Single catalogue, search, artwork, caching, and diagnostics stack
- Backward-compatible catalogue evolution
- Graceful degradation when metadata or readers are incomplete
- Incremental, independently testable sub-phases
- No regression to video Continue Watching or music listening/session behaviour

---

## Engineering principles (M6)

1. **Architecture before implementation** — document cross-layer behaviour and ADRs before code.
2. **Documentation before code** — each sub-phase begins with an architecture note or ADR where decisions are non-obvious.
3. **Filesystem and media files remain the source of truth** for what content exists and where it lives.
4. **Embedded / archive metadata enriches; it does not replace** folder structure.
5. **User reading state is application-managed** — progress, continue-reading, and reader preferences live outside `catalog.json`.
6. **Reuse M4/M5 infrastructure** — providers, settings, `MediaLocationResolver`, search, artwork, cache invalidation, diagnostics, Windows runtime harness patterns.
7. **No parallel systems** — no second catalogue, search service, or diagnostics pipeline for books/comics.
8. **Video and music must not regress** — readers must not corrupt video resume keys or music listening/session keys.
9. **Reader UI may differ from video/music UI** where the content model requires it (paged reading vs continuous playback).
10. **Record significant decisions as ADRs** — see [Proposed ADRs](#proposed-adrs-m60-assessment).
11. **Deferred M5 music features are not silent M6 scope** — playlists, shuffle/repeat, lyrics, etc. remain a separate backlog unless explicitly pulled in by a later approved plan.

---

## Explicit exclusions (M6 milestone)

| Exclusion | Notes |
|---|---|
| Music playlists / shuffle / repeat / lyrics / EQ / gapless | M5 deferrals — **music backlog**, not M6 |
| Music favourites redesign | M5 deferral — music backlog |
| Dedicated photo-gallery redesign | Images remain folder-browsable; roadmap deferred “images” as a library type |
| DRM / storefront / Kindle / Adobe Digital Editions | Out of scope |
| Cloud metadata APIs (Goodreads, Comic Vine, etc.) | Out of scope unless later approved |
| OCR, full-text search inside books, TTS narration of books | Out of scope |
| Multi-device reading sync | M7 |
| Mobile-first reader optimisation as primary gate | Windows-first; parity where practical later |
| Virtual “All Books” libraries that merge folders | Forbidden by filesystem-is-truth |
| Transcoding or server-side page rendering | Out of scope |

---

## Recommended product objective (Phase 6.0)

**Deliver a Windows-first books and comics reading experience** that:

1. Indexes supported book and comic formats into the existing folder-tree catalogue with explicit `media_kind` values.
2. Indexes and reads **both** primary comic archive formats — **`.cbz` and `.cbr`** — as required M6 baseline scope (not optional).
3. Lets users browse those items using the real folder structure (plus optional book/comic-aware detail surfaces).
4. Opens dedicated readers for comics (archive of images) and books (document formats).
5. Persists reading progress and exposes Continue Reading without inventing filesystem locations.
6. Leaves video and music behaviour unchanged.

### Candidate scope buckets

| Bucket | In M6? | Rationale |
|---|---|---|
| Comic archives **`.cbz` and `.cbr`** (both required) + paged reader | **Yes — core / baseline** | Primary comic archive formats; neither is optional product scope |
| Windows-compatible RAR/CBR extraction stack | **Yes — prerequisite** | Required to deliver `.cbr`; evaluate and select in 6.0 / early 6.1 |
| Books (`.pdf`, `.epub`) + document reader | **Yes — core** | Roadmap M6 title; distinct reader stack |
| Catalogue `media_kind` + extension expansion | **Yes — prerequisite** | Required for routing and search presentation |
| Reading progress / Continue Reading | **Yes — core** | Parity with video/music application state |
| Lightweight metadata from archives/tags | **Yes — limited** | Enrichment only; folder names remain primary |
| Music deferred features | **No** | Separate backlog |
| Image gallery polish | **No** | Explicitly deferred content axis |
| Loose image folders as virtual comics | **No** | Remain `image` items unless separately approved |
| Mobi/AZW/KF8 | **No (v1)** | DRM / ecosystem complexity — revisit later |
| Dual-page comic modes, manga RTL advanced UI | **Maybe late** | Only if core reader is stable |

**CBR deferral policy:** CBR must **not** be silently deferred. Any later removal from M6 would require an explicit documented decision, rationale, known-limitation entry, and approval **before** M6 closure.

---

## Phase structure

| Sub-phase | Focus | Status |
|---|---|---|
| **6.0** | Planning and Architecture | ✅ Complete |
| **6.1** | Catalogue schema, media kinds, indexer formats (+ RAR/CBR provisional preferred) | ✅ **Complete** |
| **6.2** | Books & comics library browsing / presentation | ✅ Complete |
| **6.3** | Comic archive reader (CBZ) | ✅ **Complete** — CBZ production format; CBR removed |
| **6.4** | Book document reader (PDF/EPUB) | ✅ **Complete** (2026-07-26) |
| **6.5** | Reading progress and Continue Reading | **Complete** (2026-07-27) — persistence, Continue Reading, diagnostics |
| **6.6** | Performance, diagnostics, and Windows runtime validation | ✅ Complete (2026-07-27) — lazy CBZ/EPUB, cache bounds, reader diagnostics, UX/a11y matrix |
| **6.4C** | Comic reading experience closure (UX, progress, resilience) | ✅ **Complete** (2026-07-28) — [spec](./m6-phase-6.4-comic-reading-experience.md) · distinct from repo Phase 6.4 book reader |
| **Release** | M6 release and documentation | ⏳ Pending — [closure audit](./m6-closure-report.md) |

---

### Phase 6.0 — Planning and Architecture

**Status:** ✅ **COMPLETE** (2026-07-24) — commit `b3e844a`

**Objective:** Define M6 scope, terminology, catalogue implications, reader architecture options, reading-state model, diagnostics, validation strategy, and milestone Definition of Done.

**Scope:**

- This roadmap and [books-comics.md](../architecture/books-comics.md)
- Proposed ADRs for durable cross-layer decisions
- Index updates (`MILESTONES.md`, architecture/release/roadmap indexes)
- Development release tracker for `v0.7.0-dev`
- Risk register and open questions
- **RAR/CBR solution evaluation criteria** (licensing, maintenance, packaging, extraction security, performance, testability) — selection may complete in Phase 6.0 or early Phase 6.1

**Out of scope:**

- Production feature implementation, schema emission, UI, readers (dependency spike/evaluation notes are allowed)

**Architecture impact:** Documentation and dependency evaluation only; no shipped reader behaviour change in 6.0.

**Implementation steps:** Docs + Proposed ADRs + index reconciliation; begin or complete Windows RAR/CBR candidate evaluation.

**Automated / runtime validation:** None required for docs-only; optional smoke of candidate RAR libraries during evaluation.

**Documentation updates:** Listed in [Documentation outputs](#documentation-outputs-phase-60).

**Definition of done:**

- [ ] `m6-plan.md` and `books-comics.md` reviewed and linked from indexes
- [ ] Sub-phases 6.1–6.6 + release defined with scope, out-of-scope, and phase DoD
- [ ] Proposed ADRs authored for genuine decision areas (not Accepted)
- [ ] Milestone-level DoD drafted; `.cbz` and `.cbr` both required baseline comic formats
- [ ] Risks and open questions recorded (CBR framed as implementation risk, not product-scope optionality)
- [ ] M5 deferrals explicitly excluded from silent M6 scope
- [ ] RAR/CBR evaluation started; selection either recorded in 6.0 or explicitly handed to early 6.1 as a blocking prerequisite
- [ ] No production feature code changed
- [ ] Planning review presented for agreement before implementation

**Dependencies:** M5 complete (`v0.6.0` / `m5-complete`).

---

### Phase 6.1 — Catalogue schema, media kinds, and indexer formats

**Status:** ✅ **COMPLETE** (2026-07-24)

**Objective:** Extend the scanner and catalogue model so books and comics are first-class indexed items with stable identity and `media_kind`, and record a provisional preferred Windows RAR/CBR approach for required `.cbr` support.

**Scope:**

- New `media_kind` values (`book`, `comic`) — ADR-024
- Supported extensions (comics: **`.cbz`**, **`.cbr`**; books: `.pdf`, `.epub`)
- Windows RAR/CBR approach recorded as **provisional preferred** (`package:unrar`) with Phase **6.3 Gate 0** blocking — see [cbr-rar-evaluation.md](../architecture/cbr-rar-evaluation.md)
- `catalogue_version: 4`, scanner `0.5.0`
- Client `MediaKind` / `SupportedExtensions` / inference updates
- Mixed-media isolation (video/audio/image unchanged)
- Deterministic fixture catalogues for tests (including `.cbz` and `.cbr` fixtures)

**Out of scope:** Full comic reader UI, reading progress UI, metadata scrapers, MOBI/AZW, treating loose image folders as comics.

**Architecture impact:** Scanner, catalogue schema, client models, search kind labels, Caddy allowlist sync; native/RAR dependency deferred to Gate 0 / 6.3.

**Definition of done:**

- [x] Supported book/comic extensions indexed with correct `media_kind` (including both `.cbz` and `.cbr`)
- [x] Windows-compatible RAR/CBR approach recorded as **provisional preferred** with Gate 0 defined (not falsely marked fully validated)
- [x] Unsupported formats omitted or skipped per existing policy
- [x] Client loads mixed catalogues without breaking video/audio/image
- [x] Automated tests pass; Windows mixed-catalogue scan validated
- [ ] ADR-024 remains **Proposed** until formal Accept (catalogue criteria met; CBR Gate 0 still open)

**Dependencies:** Phase 6.0 complete and agreed.

**Risks carried forward:** RAR/CBR packaging and Gate 0; large EPUB/PDF metadata cost; HTTPS Range for large PDFs.

---

### Phase 6.2 — Books & comics library browsing / presentation

**Objective:** Present book and comic items in folder browse and optional book/comic-aware detail surfaces without inventing categories.

**Status:** ✅ Complete (2026-07-24)

**Scope delivered:**

- Folder browse recognition of book/comic kinds (labels, icons, open actions)
- `LibraryFilter.books` / `LibraryFilter.comics` on folder browse
- Item detail for books/comics (title, author/series, format, page count, archive type; non-reader stub)
- Search kind chips (Book / Comic) + result labels; author/series search via Phase 6.1 haystack
- Distinct literature vs comics placeholder artwork (no archive/PDF/EPUB cover extraction)
- A/V isolation: `PlaybackService.play` refuses non-A/V; detail never routes to video/music players
- Opt-in Windows runtime: `PHASE_62_RUNTIME=1` · `test/phase_62_books_comics_windows_runtime_test.dart`

**Out of scope (unchanged):** Reader implementations; progress persistence; dashboard “All Comics” aggregates.

**Architecture impact:** Folder UI, detail screens, search result rows, presentation helper (`MediaKindPresentation`), artwork visual kinds.

**Automated tests:** `book_comic_presentation_test.dart`, search/filter extensions, video/music browse regression via full suite.

**Runtime:** Phase 6.2 Windows harness green (mixed folder, filters, search, detail stub, back nav, layout).

**Definition of done:**

- [x] Book/comic items visible in real folders with correct kind presentation
- [x] No invented parent groups
- [x] Search shows kind without leaking paths
- [x] Focused + full suite green
- [x] Windows runtime opt-in harness green

**Dependencies:** Phase 6.1.

---

### Phase 6.3 — Comic archive reader (CBZ)

**Status:** ✅ **Complete** (2026-07-27). ADR-026 **Accepted** — CBZ-only production comic format. CBR/RAR removed from scope; external conversion + rescan required for legacy libraries.

→ **Follow-on:** [Phase 6.4C — Comic reading experience closure](./m6-phase-6.4-comic-reading-experience.md) — ✅ **Complete** (2026-07-28); distinct from repo Phase 6.4 book reader below.

**Checkpoint record:**

| Item | Status |
|---|---|
| CBZ reader | Production format; runtime validated |
| CBR reader | **Removed from production scope** — conversion guidance in UI |
| Legacy `.cbr` in catalogue | Open Comic disabled; Continue Reading shows conversion guidance |
| UnRAR / native RAR dependency | **Removed** — no DLL, CLI, or packaging hooks |

**Objective:** Open `.cbz` comic archives in a dedicated paged reader on Windows, with graceful failure for bad archives.

**Scope:**

- Dedicated comic reader surface (ADR-026 Accepted)
- **CBZ (ZIP)** page extraction via lazy in-process reader
- Next/previous page, page indicator, fullscreen-friendly controls
- Path-safety, natural ordering, bounded page cache (Phase 6.6)
- Local + HTTPS file access via `MediaLocationResolver`
- Failure states: missing file; corrupt/invalid ZIP; empty archive; unsafe entry paths — user-visible recovery, **no crash**

**Definition of done:**

- [x] User can open a **CBZ** from browse/detail and turn pages
- [x] Windows runtime validation passes for CBZ fixtures
- [x] Unsupported/corrupt archives fail gracefully (no crash)
- [x] Legacy CBR items show conversion guidance; Open Comic disabled
- [x] No UnRAR dependency in build, packaging, or runtime
- [x] ADR-026 **Accepted**; Phase 6.3 marked complete

---

### Phase 6.4 — Book document reader (PDF/EPUB)

**Objective:** Open PDF and EPUB books in a dedicated document reader on Windows.

**Status (2026-07-26):** ✅ **Complete** — PDF/EPUB reader on Windows; opt-in harness validates ItemDetail → Open Book → PdfViewer render, page nav, zoom, close.

**Scope:**

- Dedicated book reader surface (shared shell chrome with comic reader per ADR-026)
- PDF: `pdfrx`; EPUB: TTSPlayer parser + `flutter_html`
- Page/chapter navigation; keyboard controls
- Local files; controlled failure before route
- Non-persistent location models (Phase 6.5 writes deferred)

**Out of scope:** Reading history / Continue Reading (6.5); PDF password UI (6.6); DRM.

**Gate 0:** [pdf-epub-evaluation.md](../architecture/pdf-epub-evaluation.md) — PDF **Pass**; EPUB **Conditional pass**.

**Definition of done:**

- [x] PDF and EPUB open and navigate on Windows for representative fixtures
- [x] Failures are non-fatal to the app
- [x] Video/music/comics unaffected
- [x] Suite + Release build green
- [x] Opt-in Windows harness (`PHASE_64_READER=1`)
- [x] Phase 6.4 review sign-off and commit
- [ ] EPUB full-ZIP memory replacement or bound (Phase 6.6)

**Dependencies:** Phase 6.2 complete; may proceed in parallel with Phase 6.3 closure items.

---

### Phase 6.5 — Reading progress and Continue Reading

**Objective:** Persist reading progress and expose Continue Reading for books/comics without inventing filesystem locations.

**Scope:**

- Versioned reading-progress repository (isolated preference key)
- Progress model (item id + location: page index / spine + offset — ADR-027)
- Resume on open; Continue Reading surface on an appropriate landing (not a fake folder)
- Catalogue replacement prune (same pattern as favourites / listening history)
- Diagnostics aggregates (counts only; redacted)

**Out of scope:** Multi-device sync; social reading; highlights/annotations cloud sync.

**Architecture impact:** New persistence envelope; catalogue cache coordinator hook; diagnostics section.

**Automated tests:** Repository, reconcile, UI, isolation from video/music keys.

**Runtime:** Opt-in Windows harness for persist → restart → resume.

**Definition of done:**

- [x] Progress survives restart
- [x] Stale ids pruned on catalogue replace
- [x] Video `position_*` and music listening/session keys untouched
- [x] Diagnostics redacted
- [x] Suite + Release green

**Dependencies:** At least one reader phase (6.3 or 6.4) complete.

---

### Phase 6.6 — Performance, diagnostics, and Windows runtime validation

**Objective:** Harden large libraries of documents/archives; complete opt-in runtime matrix; prepare for release.

**Scope:**

- Deterministic large fixtures (many small CBZ/**CBR**/PDF stubs where practical)
- **CBZ memory (required action):** measure representative large `.cbz` open + page-turn memory; either prove it remains within an agreed bound given current full-archive `package:archive` decode, or replace `CbzZipArchiveSource` with random-access ZIP I/O or session-scoped temp extraction
- Reader decoded-page cache bounds documented separately from archive-parser memory
- Diagnostics completeness
- Full Windows runtime matrix for M6 scenarios
- Full Flutter suite + analyze + Release build

**Out of scope:** New product features.

**Definition of done:**

- [ ] Runtime matrix pass or explicitly skipped optional live path
- [ ] No material regressions to M5 suites
- [ ] Docs updated with measured results

**Dependencies:** Phases 6.1–6.5 feature-complete for intended M6 scope.

---

### Release — M6 release and documentation

**Objective:** Close M6 with M4/M5 release discipline.

**Scope:** Audit, regression evidence, release summary, version bump (proposed `v0.7.0`), tags `m6-complete` / `v0.7.0`, index updates.

**Dependencies:** Phase 6.6 complete.

---

## Proposed ADRs (M6.0 assessment)

| ADR | Title | Status | Why needed |
|---|---|---|---|
| [ADR-024](../architecture/decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) | Book/Comic Catalogue Schema and Media Kind | **Accepted** (2026-07-28; comic production `.cbz` only per ADR-026) |
| [ADR-025](../architecture/decisions/ADR-025-book-comic-identity-and-metadata-precedence.md) | Book/Comic Identity and Metadata Precedence | **Accepted** (2026-07-28) |
| [ADR-026](../architecture/decisions/ADR-026-reader-surface-architecture.md) | Reader Surface Architecture | **Accepted** (CBZ-only comic production format; CBR removed) |
| [ADR-027](../architecture/decisions/ADR-027-reading-progress-and-continue-reading.md) | Reading Progress and Continue Reading | **Accepted** |

No M4/M5 ADRs require amendment for planning; implementation may reference ADR-007/014/020 patterns without superseding them.

---

## Milestone Definition of Done (M6)

**Audit:** ✅ Complete (2026-07-28) — full disposition matrix in [m6-closure-report.md](./m6-closure-report.md) §4.

M6 implementation is **complete** on `m6-development`. Original DoD items referencing **mandatory production CBR** are **superseded by ADR-026 Accepted** (CBZ-only). Historical wording is retained below where noted; closure dispositions apply.

### Architecture and ADR governance

- [x] ADR-024–027 **Accepted** (ADR-024 amended for CBZ-only comic production)
- [x] `books-comics.md` reflects implemented architecture
- [x] No parallel catalogue/search/diagnostics systems introduced

### Functional behaviour

- [x] Supported book and comic files indexed with correct `media_kind` (comics: **`.cbz`** production)
- [x] ~~Comics include `.cbz` and `.cbr`~~ → **Superseded:** `.cbz` indexed; legacy `.cbr` catalogue entries show conversion guidance
- [x] Users browse via real folders without invented categories
- [x] ~~Comic reader for both CBZ and CBR~~ → **Superseded:** CBZ production reader; CBR blocked (ADR-026)
- [x] Unsupported/corrupt comic archives fail gracefully
- [x] PDF/EPUB book reader open and navigate
- [x] Reading progress and Continue Reading
- [x] Missing metadata does not hide items

### Compatibility and isolation

- [x] Video Continue Watching and playback unchanged
- [x] Music playback, history, and session persistence unchanged
- [x] Reading-progress keys isolated from video/music namespaces

### Automated regression

- [x] Focused M6 suites pass
- [x] Full Flutter suite passes — **1402 passed, 19 skipped, 0 failed** (2026-07-28 audit)

### Windows runtime validation

- [x] Core M6 opt-in harnesses pass (P63–P66) on Windows
- [x] ~~Comic runtime CBZ + CBR fixtures~~ → **Superseded:** CBZ-only; CBR unavailable UI in widget tests
- [x] Windows Release build succeeds — no UnRAR/RAR dependency
- [ ] Phase 6.2 browse harness (P62) — **4/6 pass**; harness stale (provider gap) — **non-blocking**; refresh before release optional

### Performance and UX

- [x] Reader failures show recovery actions (informational large-catalogue baselines acceptable)

### Diagnostics and documentation

- [x] Redacted reading/reader diagnostics
- [ ] Release notes, `m6-complete.md`, indexes — **deferred** to release-finalisation task
- [ ] Version and tags (`m6-complete`, `v0.7.0`) — **deferred** to release-finalisation task
- [x] Working tree clean at audit entry

Each checkbox must point to a test, runtime scenario, document section, build result, or measured report at closure — see [m6-closure-report.md](./m6-closure-report.md).

---

## Risks

| Risk | Mitigation |
|---|---|
| Heavy reader plugins on Windows | Spike in 6.0 open questions; choose packages with Windows support; Gate-0 style spike before 6.3/6.4 acceptance |
| CBR/RAR implementation & dependency risk (licensing, packaging, security, performance, testability) | **Product scope remains required.** Gate 0 Candidate B Fail; Candidate E Conditional pass wired into reader. **Redistribution of UnRAR.exe unresolved/blocking** for production packaging — **no silent CBR deferral** |
| Large PDF memory use | Lazy page decode; informational performance gates; fixture size limits |
| HTTPS Range incomplete for some readers | Validate early; fall back to local cache only if ADR approves |
| Scope creep from M5 music deferrals | Explicit exclusion table; reject silent inclusion |
| Catalogue version migration | Additive kinds; unknown-kind client safety; document rescan requirement |
| Dual reader UX inconsistency | Shared shell chrome via ADR-026 |
| Bad comic archives (encrypted, corrupt, multi-volume) | Explicit failure fixtures; graceful UX; never crash or poison catalogue browse |

---

## Open questions (resolve before or during early phases)

1. **Which acceptable RAR/CBR implementation will be adopted for Windows?** → Candidate E (official UnRAR CLI) **Conditional pass** (2026-07-25). Candidate D remains escape hatch. **`package:rar` is not preferred for Windows**. See [cbr-rar-evaluation.md](../architecture/cbr-rar-evaluation.md).
2. Single `media_kind: document` vs separate `book` / `comic`? → **Resolved:** separate kinds (`book`, `comic`).
3. Which Flutter packages for PDF/EPUB on Windows are acceptable (license + maintenance)?
4. Should Continue Reading live on the dashboard, a Reading landing, or both (without fake folders)?
5. Temp extraction directory policy for comic archives (session-scoped wipe vs cache with LRU)?
6. Does catalogue_version bump to 4, or can kinds be additive on v3 with scanner version alone? → **Resolved:** `catalogue_version: 4`, scanner `0.5.0`.

**Resolved for M6 baseline (not open):**

- `.cbz` and `.cbr` are both **required** comic formats.
- Loose image-sequence folders are **not** treated as comics in initial M6 scope unless separately approved.
- Windows CBR: `package:unrar` Gate 0 **Fail**; no RAR dependency in app until a fallback passes Gate 0.

---

## Documentation outputs (Phase 6.0)

| Document | Action |
|---|---|
| [m6-plan.md](./m6-plan.md) | Create (this file) |
| [books-comics.md](../architecture/books-comics.md) | Create |
| ADR-024–027 | Create as **Proposed** |
| [MILESTONES.md](../../MILESTONES.md) | M6 in progress |
| Roadmap / architecture / release indexes | M6 planning entries |
| [v0.7.0-dev.md](../release/v0.7.0-dev.md) | Create development tracker |
| README roadmap table | Align M4/M5 complete + M6 planning |

---

## Handoff

**Current production (2026-07-28):** Comic reader is **CBZ-only** (ADR-026 Accepted). Phases 6.3, 6.4, 6.5, 6.6, and **6.4C** are complete on `m6-development`.

**Historical note:** Sections below that reference `.cbr` as required baseline scope, Gate 0 UnRAR, or UnRAR redistribution record **original M6 planning and investigation**. They are retained for audit. Current production architecture does not ship CBR/UnRAR tooling.

**Next:** M6 **release finalisation** (version bump, tags, `m6-complete.md`) — see [m6-closure-report.md](./m6-closure-report.md) §10.

**Post-release UX:** [Post-Milestone UX and Workflow Review](./post-milestone-ux-workflow-review.md) — tracked refinements, not blockers.
