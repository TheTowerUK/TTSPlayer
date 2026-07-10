# M4 — User Experience and Platform Integration

**Status:** Planning  
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
| **4.1** | Provider Management | Planned |
| **4.2** | Settings Framework | Planned |
| **4.3** | Library Experience | Planned |
| **4.4** | Playback Improvements | Planned |
| **4.5** | Performance and Caching | Planned |
| **4.6** | Diagnostics and Supportability | Planned |
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

- Update [provider-management.md](../architecture/provider-management.md) from planning → accepted
- ADR if status model or refresh semantics require a new cross-layer contract

→ Architecture: [provider-management.md](../architecture/provider-management.md)

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

**Note:** Provider settings already exist (`MediaProviderSettingsScreen`, `MediaProviderConfigService`). M4.2 **evolves** them — do not rebuild from scratch.

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

- Update [settings.md](../architecture/settings.md)
- Settings schema section in release tracker

→ Architecture: [settings.md](../architecture/settings.md)

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

- Update [library.md](../architecture/library.md)
- Note any ADR for favourites storage model

→ Architecture: [library.md](../architecture/library.md)

---

### Phase 4.4 — Playback Improvements

**Objective:** Refine playback UX and multi-track handling on top of existing resume and resolver integration.

**Scope:**

- Resume experience refinement
- Playback speed
- Subtitle track selection
- Audio track selection
- Chapter navigation where supported by the player stack
- Playback history refinement
- Clearer playback errors
- Improved player controls

**Note:** Resume-position persistence already exists (`PlaybackService` + `shared_preferences`). M4.4 **refines** — do not reimplement.

**Out of scope:**

- Transcoding or server-side stream manipulation
- DRM
- Cast / DLNA unless separately approved

**Dependencies:** Phase 4.2 (playback preferences); [playback architecture](../architecture/playback.md).

**Definition of done:**

- Resume behaviour preserved or improved without data loss
- Track selection works for supported containers on Windows (`media_kit`)
- Playback errors surface resolver and network context where relevant
- Player controls meet design-system touch targets

**Validation expectations:**

- Playback service tests for resume read/write
- Manual validation: local file and HTTPS stream with seek

**Documentation outputs:**

- Update [playback.md](../architecture/playback.md)

→ Architecture: [playback.md](../architecture/playback.md)

---

### Phase 4.5 — Performance and Caching

**Objective:** Keep large libraries responsive through deliberate caching and lazy rendering.

**Scope:**

- Catalogue cache strategy
- Artwork and thumbnail caching
- Lazy rendering in grids and lists
- Background refresh where safe
- Large-library responsiveness
- Cache invalidation rules
- Memory and startup performance

**Out of scope:**

- SQLite catalogue store (unless ADR-approved — out of scope for M4 v1)
- Background indexer daemon
- CDN or edge caching

**Dependencies:** Phases 4.1–4.3 (know what to cache and when to invalidate); architecture note TBD if cache layer is new.

**Definition of done:**

- Measurable improvement or documented baseline for large-folder scroll
- Artwork cache does not block UI thread on cold start
- Cache invalidation tied to rescan and provider refresh events
- Memory bounds documented

**Validation expectations:**

- Performance smoke on large mock catalogue
- No regression in catalogue load time for demo catalogue

**Documentation outputs:**

- Cache strategy section in relevant architecture docs
- ADR if cache storage format or invalidation contract is significant

---

### Phase 4.6 — Diagnostics and Supportability

**Objective:** Make common failures diagnosable from within the application.

**Scope:**

- Diagnostics screen
- Active provider and source information
- Catalogue status
- Resolver configuration summary
- Item counts
- Last refresh timestamp
- Cache health indicators
- Application version and build information
- Readable network/TLS errors (build on M3.5 `remote_fetch_errors`)
- Optional diagnostic export (plain text / JSON — no secrets)

**Out of scope:**

- Remote telemetry or crash reporting services
- Automatic log upload

**Dependencies:** Phases 4.1, 4.2, 4.5; [diagnostics architecture](../architecture/diagnostics.md).

**Definition of done:**

- Diagnostics screen reachable from Settings
- Shows enough context to debug catalogue, provider, and resolver issues without reading source
- Export optional and clearly labelled

**Validation expectations:**

- Widget smoke for diagnostics screen
- Manual: reproduce HTTPS failure and confirm readable message in diagnostics

**Documentation outputs:**

- Update [diagnostics.md](../architecture/diagnostics.md)

→ Architecture: [diagnostics.md](../architecture/diagnostics.md)

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
