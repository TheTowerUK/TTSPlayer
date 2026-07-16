# M4 — User Experience and Platform Integration

**Status:** Active development (`v0.5.0-dev`) — **Phase 4.5 complete; Phase 4.6 next**
**Branch:** `m4-development`
**Development version:** `v0.5.0-dev`
**Predecessor:** M3.5 Media Access Platform
**M3.5 status:** ✅ Complete — tag `m3.5-complete`

→ [Release tracker](../release/v0.5.0-dev.md)
→ [M3.5 release snapshot](../release/m3.5-media-access-complete.md)
→ [Roadmap principles](./principles.md)
→ [Architecture index](../architecture/README.md)

> **Phase numbering note:** M4 sub-phases **4.1–4.7** are distinct from M3.5 **Phase 4** (network catalogue and provider configuration, complete 2026-07-07). See [M3.5 Phase 4 plan](./m35-phase-4-plan.md) for the closed network-client cycle.

---

## Mission

M4 transitions TTSPlayer from a functional personal media platform into a **polished, configurable media application**.

It builds upon the provider-neutral catalogue and media access architecture completed during M3.5 while preserving:

- Local-first operation
- Filesystem-driven libraries
- Provider-neutral media access
- Graceful network fallback
- Backward compatibility where practical
- Small, independently testable delivery phases

---

## Engineering principles

1. **Architecture before implementation** — document cross-layer behaviour before code changes.
2. **Documentation before code** — each sub-phase begins with an updated architecture note or ADR where decisions are non-obvious.
3. **Small, independently testable phases** — one primary responsibility per sub-phase; clear definition of done.
4. **No speculative platform expansion** — no cloud sync, accounts, transcoding, or mobile platform work unless explicitly approved.
5. **Preserve the filesystem as the source of library structure** — no virtual libraries, invented categories, or cross-folder aggregation.
6. **Graceful degradation when remote services are unavailable** — retain last-good catalogue; surface recoverable errors.
7. **Validate each phase before beginning the next** — unit tests, `flutter analyze`, and Windows regression where applicable.
8. **Separate observations from release blockers** — backlog items do not fail a sub-phase.
9. **Prefer incremental evolution over broad rewrites** — evolve existing services and screens; do not rebuild working M3/M3.5 capabilities.
10. **Record significant architectural decisions using ADRs** — see [ADR framework](../architecture/decisions/README.md).

---

## Phase structure

Implement in order unless a documented dependency allows parallel documentation work. Each sub-phase includes objective, scope, boundaries, dependencies, definition of done, validation, and documentation outputs.

| Sub-phase | Focus | Status |
|---|---|---|
| **4.1** | Provider Management | ✅ Complete (2026-07-12) |
| **4.2** | Settings Framework | ✅ Complete (2026-07-12) |
| **4.3** | Library Experience | ✅ Complete (2026-07-13) |
| **4.4** | Playback Improvements | ✅ Complete (2026-07-14) | [spec](./m4-phase-4.4-playback-improvements.md) |
| **4.5** | Performance and Caching | ✅ Complete (2026-07-16) — [spec](./m4-phase-4.5-performance-caching.md) · [caching](../architecture/caching.md) |
| **4.6** | Diagnostics and Supportability | **In progress** — [spec](./m4-phase-4.6-diagnostics-supportability.md) · Step 2 data layer ✅ |
| **4.7** | Release and Documentation | Planned |

---

### Phase 4.1 — Provider Management

**Objective:** Refine visibility, status, and user interaction around the **existing** provider architecture — not reimplement M3.5 network access.

**Scope:**

- Consolidate provider status and selection behaviour in one coherent surface
- Expose the active catalogue provider clearly
- Support explicit refresh and retry actions
- Represent provider health and failure state (success, degraded, unavailable)
- Preserve automatic fallback behaviour from M3.5

**Important boundary — already shipped in M3.5:**

M3.5 implemented provider configuration, local/HTTP catalogue loading, startup selection, fallback, `MediaLocationResolver` wiring, and HTTPS enforcement. M4.1 **refines management, visibility, status, and user interaction** around that architecture.

**Out of scope:**

- New cloud provider integrations
- Authentication
- Transcoding
- Multi-user provider configurations

**Dependencies:** M3.5 complete; [provider-management architecture](../architecture/provider-management.md).

**Definition of done:**

- Active provider is visible from a dedicated management surface or consolidated status area
- User can trigger catalogue refresh/retry without losing last-good catalogue
- Provider failure states are readable and actionable
- M3.5 fallback behaviour unchanged under regression tests

**Validation expectations:**

- Unit/widget tests for status presentation and refresh actions
- Windows smoke: local preferred, HTTP fallback, HTTP-required modes
- No regression in `CatalogService` provider selection order

**Documentation outputs:**

- [Phase 4.1 implementation specification](./m4-phase-4.1-provider-management.md)
- Update [provider-management.md](../architecture/provider-management.md) from planning → accepted at phase close
- [ADR-001](../architecture/decisions/ADR-001-provider-health-model.md), [ADR-002](../architecture/decisions/ADR-002-provider-refresh-lifecycle.md), [ADR-003](../architecture/decisions/ADR-003-provider-status-presentation.md)

→ Architecture: [provider-management.md](../architecture/provider-management.md)
→ Specification: [m4-phase-4.1-provider-management.md](./m4-phase-4.1-provider-management.md)

---

### Phase 4.2 — Settings Framework

**Objective:** Organise existing provider settings into a broader, coherent settings architecture with persistent versioned preferences.

**Scope:**

- General settings
- Library settings
- Playback preferences
- Network behaviour
- Debug and diagnostics options
- Persistent versioned settings schema
- Migration and reset behaviour

**Note:** Provider settings evolved into `SettingsScreen` + `MediaProviderSettingsForm` (Phase 4.2 complete). `MediaProviderConfigService` remains during dual-write transition.

**Out of scope:**

- Account or profile settings
- Cloud-backed preference sync
- Per-user role configuration

**Dependencies:** Phase 4.1 (provider status vocabulary); [settings architecture](../architecture/settings.md).

**Definition of done:**

- Settings grouped into navigable sections with consistent layout
- All M3.5 provider settings remain functional after migration
- Settings schema version recorded; reset-to-defaults path documented
- No silent loss of user configuration on upgrade

**Validation expectations:**

- Migration tests for existing `shared_preferences` keys
- Manual validation: configure providers, restart app, confirm persistence

**Documentation outputs:**

- [Phase 4.2 implementation specification](./m4-phase-4.2-settings-framework.md)
- Update [settings.md](../architecture/settings.md) from planning → accepted at phase close
- [ADR-004](../architecture/decisions/ADR-004-settings-storage-and-versioning.md), [ADR-005](../architecture/decisions/ADR-005-settings-information-architecture.md), [ADR-006](../architecture/decisions/ADR-006-settings-validation-and-apply-behaviour.md)

→ Architecture: [settings.md](../architecture/settings.md)
→ Specification: [m4-phase-4.2-settings-framework.md](./m4-phase-4.2-settings-framework.md)

---

### Phase 4.3 — Library Experience

**Objective:** Polish browsing and navigation without altering the filesystem-driven library model.

**Scope:**

- Improved browsing and navigation
- Sorting and filtering (within folder context — no cross-library virtual views)
- Search refinement
- Favourites (user-curated app state — not filesystem locations)
- Continue Watching improvements
- Recently Added improvements
- Breadcrumbs
- Better empty and error states
- Consistent artwork presentation

**Out of scope:**

- Virtual libraries aggregating across folders
- Hardcoded category labels (Movies, TV, etc.)
- TMDB or external metadata
- Image-library viewer (deferred — see [superseded draft](./m4-rich-media-libraries.md))

**Dependencies:** Phase 4.2 (settings for sort/filter defaults); [library architecture](../architecture/library.md).

**Definition of done:**

- Folder tree navigation unchanged in principle; polish does not invent hierarchy
- Search, Continue Watching, and Recently Added remain catalogue-driven
- Favourites stored as app state with clear labelling
- Empty and error states offer recovery actions

**Validation expectations:**

- Widget tests for sort/filter and breadcrumb behaviour
- Regression: `FolderScreen`, dashboard sections, global search

**Documentation outputs:**

- [Phase 4.3 implementation specification](./m4-phase-4.3-library-experience.md)
- Update [library.md](../architecture/library.md) from planning → accepted at phase close
- [ADR-007](../architecture/decisions/ADR-007-library-metadata-and-favourites.md), [ADR-008](../architecture/decisions/ADR-008-library-sorting-and-filtering.md), [ADR-009](../architecture/decisions/ADR-009-library-navigation-and-breadcrumbs.md)

→ Architecture: [library.md](../architecture/library.md)
→ Specification: [m4-phase-4.3-library-experience.md](./m4-phase-4.3-library-experience.md)

---

### Phase 4.4 — Playback Improvements

**Status:** ✅ **Complete** (2026-07-14) — Gate 0 · specification · ADR-010–013 · implementation · validation · closure.

**Objective:** Refine playback UX and multi-track handling on top of existing resume and resolver integration.

**Cadence (playback-specific):**

```
Inventory → Capability Audit → ADRs → Specification → Implementation
```

**Steps:**

0. Capability Audit — **complete** ([audit](./m4-phase-4.4-gate0-capability-audit.md))
1. Specification + ADRs — **complete** ([spec](./m4-phase-4.4-playback-improvements.md), ADR-010–013)
2. PlaybackService extensions — **complete**
3. Settings integration — **complete**
4. Player UI — **complete**
5. Integration audit — **complete** (`964fb78`)
6. Windows runtime validation — **complete** (`11b3607`)
7. Closure — **complete** (2026-07-14)

**Scope (Gate 0 confirmed):**

- Resume experience refinement
- Playback speed — Windows only; `setRate` verified
- Subtitle / audio track selection — embedded, Windows only; API verified
- Chapter navigation — **deferred beyond M4**
- Clearer resolver-aware playback errors
- Improved player controls and desktop keyboard shortcuts

**Note:** Resume-position persistence already exists (`PlaybackService` + `shared_preferences`). M4.4 **refines** — do not reimplement. `PlaybackService` remains the single playback authority; `PlayerScreen` reflects service state only.

**Out of scope:**

- Transcoding or server-side stream manipulation
- DRM
- Cast / DLNA unless separately approved
- Chapters (no `media_kit` Dart API)

**Dependencies:** Phase 4.2 (optional default speed in settings); [playback architecture](../architecture/playback.md).

**Definition of done:**

- Gate 0 capability audit complete
- Resume behaviour preserved or improved without data loss
- Track/speed features (if in scope) work on Windows test fixtures
- Playback errors use provider / resolver / playback layer taxonomy
- `PlayerScreen` never bypasses `PlaybackService` to reach `media_kit` / `video_player`

**Validation expectations:**

- Playback service tests for resume read/write
- Phase 4.4 Windows runtime harness (opt-in)
- Manual validation: local file and HTTPS stream with seek; multi-audio MKV per audit

**Documentation outputs:**

- [Phase 4.4 Gate 0 audit](./m4-phase-4.4-gate0-capability-audit.md) (complete)
- [Phase 4.4 implementation specification](./m4-phase-4.4-playback-improvements.md) (complete)
- ADR-010–013 ([index](../architecture/decisions/README.md#index)) — implemented
- [playback.md](../architecture/playback.md) — accepted at closure

→ Architecture: [playback.md](../architecture/playback.md)
→ Gate 0: [m4-phase-4.4-gate0-capability-audit.md](./m4-phase-4.4-gate0-capability-audit.md)
→ Specification: [m4-phase-4.4-playback-improvements.md](./m4-phase-4.4-playback-improvements.md)

---

### Phase 4.5 — Performance and Caching — ✅ complete

**Status:** Baseline audit ✅ · Specification **accepted** · ADR-014–016 **implemented** · Steps 0–8 **complete** · Closure 2026-07-16.

**Closure validation:** Normal suite **556 passed / 7 skipped**; runtime **20 passed / 2 skipped** (`PHASE_45_RUNTIME=1`); benchmarks informational (`PHASE_45_BENCHMARK=1`).

**Objective:** Keep large libraries responsive through deliberate caching and lazy rendering.

**Cadence:**

```
Baseline Audit → ADRs → Invalidation → Artwork → Search → Scroll tuning → Benchmarks → Runtime → Closure
```

**Steps:**

0. Performance baseline audit — **complete** ([audit](./m4-phase-4.5-baseline-audit.md))
1. Specification + ADRs — **complete** ([spec](./m4-phase-4.5-performance-caching.md), ADR-014–016)
2. Cache invalidation orchestration — **complete**
3. Artwork candidate bounds + image decode — **complete**
4. Search index lifecycle + startup deferral — **complete**
5. Large-folder scroll tuning + memory hooks — **complete**
6. Integration tests + micro-benchmarks — **complete**
7. Windows runtime validation — **complete**
8. Closure — **complete**

**Scope:**

- Catalogue-derived cache invalidation on successful replace
- Bounded artwork candidate LRU + image decode sizing
- Shared deferred `SearchService` index rebuild
- Large-folder scroll verification and tuning
- Memory and startup performance baselines

**Out of scope:**

- SQLite catalogue store (unless ADR-approved — out of scope for M4 v1)
- Background indexer daemon
- CDN or edge caching
- Disk thumbnail cache
- Search pagination UI

**Dependencies:** Phases 4.1–4.4; [caching architecture](../architecture/caching.md).

**Definition of done:**

- Measurable targets met or documented (see [spec](./m4-phase-4.5-performance-caching.md#measurable-success-criteria))
- Artwork cache bounded; ImageCache budget configured
- Search index deferred off dashboard critical path
- Cache invalidation tied to successful rescan/provider refresh only
- No regression on bundled catalogue startup

**Validation expectations:**

- Micro-benchmarks on synthetic 5k-item fixture
- Opt-in Phase 4.5 Windows runtime harness (`PHASE_45_RUNTIME`)
- Manual scroll QA on large real folder (release follow-up)

**Documentation outputs:**

- [Phase 4.5 baseline audit](./m4-phase-4.5-baseline-audit.md) (complete)
- [Phase 4.5 implementation specification](./m4-phase-4.5-performance-caching.md) (accepted)
- [caching.md](../architecture/caching.md) — **accepted at closure**
- ADR-014–016 ([index](../architecture/decisions/README.md#index))

→ Architecture: [caching.md](../architecture/caching.md)
→ Baseline: [m4-phase-4.5-baseline-audit.md](./m4-phase-4.5-baseline-audit.md)
→ Specification: [m4-phase-4.5-performance-caching.md](./m4-phase-4.5-performance-caching.md)

---

### Phase 4.6 — Diagnostics and Supportability

**Status:** **In progress** — Step 2 data layer complete (2026-07-16).

**Objective:** Improve application supportability by exposing internal runtime state that **already exists** — provider health, catalogue summary, cache bounds, search lifecycle, playback capabilities — in a read-only Diagnostics experience. Consume existing instrumentation; do not create duplicate monitoring systems.

**Scope:**

- `DiagnosticsService` + `RuntimeDiagnosticsSnapshot` (ADR-017, ADR-018)
- Read-only Diagnostics screen from Settings → Diagnostics & Advanced
- Clipboard export (plain text per ADR-019); optional Windows file save
- Promote diagnostics-facing getters on `ArtworkService` and `SearchService`
- Redaction: no personal paths, secrets, or stack traces
- Windows runtime validation (`PHASE_46_RUNTIME=1`)

**Out of scope:**

- Remote telemetry or crash reporting
- Automatic log upload
- Log ring buffer
- Reset diagnostic counters UI
- Test-only metrics (`FolderPresentationMetrics`, benchmark harnesses) in production UI
- JSON export (deferred)

**Dependencies:** Phases 4.1, 4.2, 4.5; [diagnostics architecture](../architecture/diagnostics.md).

**Definition of done:** See [Phase 4.6 specification](./m4-phase-4.6-diagnostics-supportability.md#definition-of-done-phase-46-final).

**Validation expectations:**

- Unit, widget, and integration tests for snapshot, screen, and export
- `PHASE_46_RUNTIME=1` matrix D1–D10 on Windows
- Manual: HTTPS/TLS failure shows readable provider error without certificate dump

**Documentation outputs:**

- [Phase 4.6 implementation specification](./m4-phase-4.6-diagnostics-supportability.md) ✅ Step 1
- [diagnostics.md](../architecture/diagnostics.md) — proposed → accepted at closure
- [ADR-017](../architecture/decisions/ADR-017-diagnostics-architecture.md), [ADR-018](../architecture/decisions/ADR-018-runtime-snapshot-model.md), [ADR-019](../architecture/decisions/ADR-019-diagnostics-export-support-strategy.md)

→ Architecture: [diagnostics.md](../architecture/diagnostics.md)  
→ Specification: [m4-phase-4.6-diagnostics-supportability.md](./m4-phase-4.6-diagnostics-supportability.md)

---

### Phase 4.7 — Release and Documentation

**Objective:** Close M4 with validated documentation and release artefacts.

**Scope:**

- Cross-phase validation
- Windows regression validation (local + HTTPS paths)
- Documentation alignment across roadmap, architecture, release, and milestones
- Release notes
- Version review (`v0.5.0-dev` → stable tag decision)
- Roadmap closure
- M4 archival
- Release/tag preparation

**Out of scope:**

- New feature work
- Mobile platform release

**Dependencies:** Phases 4.1–4.6 complete.

**Definition of done:**

- All M4 completion criteria met (below)
- `flutter analyze` clean; test suite passing
- Release snapshot written; milestone tagged
- Historical M3/M3.5 records unchanged

**Validation expectations:**

- Full Windows regression checklist executed
- TNAS HTTPS smoke optional but recommended if provider changes touched network layer

**Documentation outputs:**

- Updated [release history](../release/release-history.md)
- M4 release snapshot (new doc at closure)
- [roadmap.md](./roadmap.md) and [MILESTONES.md](../../MILESTONES.md) updated

---

## Cross-phase constraints

| Constraint | Rationale |
|---|---|
| No user accounts | Local-first personal app |
| No cloud synchronisation | Out of scope for M4 |
| No server-side transcoding | Zero-bloat principle |
| No multi-user profiles | Out of scope for M4 |
| No plugin marketplace | Out of scope |
| No Chromecast or DLNA | Unless separately approved |
| No mobile platform expansion during M4 | Windows-first polish milestone |
| Do not replace filesystem-driven library model | [Catalogue principle](../../.cursor/rules/catalogue-principle.mdc) |
| Do not duplicate M3 or M3.5 completed work | Incremental evolution only |

---

## Delivery cadence

Each sub-phase follows the lifecycle proven during M3.5:

1. **Plan** — update roadmap phase section and architecture planning doc
2. **Document architecture** — ADR if decision is significant
3. **Implement** — focused commits per sub-phase
4. **Test** — unit/widget tests; `flutter analyze`
5. **Hardware/runtime validation** — Windows; TNAS HTTPS when network behaviour changes
6. **Update documentation** — architecture doc status, release tracker, phase table
7. **Commit and close the sub-phase** — do not start next phase until definition of done is met

---

## M4 completion criteria

M4 is complete when:

- [ ] Settings are coherent and persistent
- [ ] Provider state is visible and manageable
- [ ] Library browsing is polished
- [ ] Playback controls and track handling are improved
- [ ] Large libraries remain responsive
- [ ] Common failures are diagnosable from within the application
- [ ] Windows local and HTTPS media paths remain regression-safe
- [ ] Release documentation is complete

---

## Related documents

| Document | Purpose |
|---|---|
| [v0.5.0-dev release tracker](../release/v0.5.0-dev.md) | Phase status and validation |
| [M3.5 Phase 4 plan](./m35-phase-4-plan.md) | Closed network catalogue cycle (do not duplicate) |
| [M3 Personal Media Experience](./m3-personal-media-experience.md) | M3 baseline features |
| [m4-rich-media-libraries.md](./m4-rich-media-libraries.md) | Superseded content-expansion draft — not current M4 scope |
| [ADR framework](../architecture/decisions/README.md) | Decision records |
