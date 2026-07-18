# M4 — User Experience and Platform Integration

**Status:** **COMPLETE** — automated validation 2026-07-18  
**Date:** July 2026  
**Development version:** `v0.5.0-dev`  
**Branch:** `m4-development`  
**Predecessor:** M3.5 — tag `m3.5-complete` (2026-07-07)  
**Recommended tag:** `m4-complete` (after Step 4 manual QA sign-off)

→ [M4 plan](../roadmap/m4-plan.md)  
→ [Phase 4.7 closure spec](../roadmap/m4-phase-4.7-release-documentation.md)  
→ [v0.5.0-dev development cycle](./v0.5.0-dev.md)  
→ [M4 foundation snapshot — Phases 4.1–4.3](./m4-foundation-complete.md)  
→ [Release index](./README.md)

---

## Summary

M4 delivers a **polished, configurable personal media application** on top of the M3.5 provider-neutral architecture. Settings, provider visibility, library browsing, playback controls, performance caching, and in-app diagnostics were implemented in seven ordered sub-phases without replacing filesystem-driven libraries or M3.5 fallback semantics.

The milestone closes with reconciled architecture documentation, nineteen accepted ADRs, **624** automated tests, and six opt-in Windows runtime harness suites.

---

## Delivered by sub-phase

| Phase | Focus | Key deliverables |
|---|---|---|
| **Init** | Planning | M4 roadmap, architecture planning docs, ADR framework, release tracker |
| **4.1** | Provider Management | Provider Status panel, health model, refresh/retry, ADR-001–003 |
| **4.2** | Settings Framework | `SettingsRepository`, grouped settings UI, migration, ADR-004–006 |
| **4.3** | Library Experience | Favourites, sort/filter, breadcrumbs, search presentation, ADR-007–009 |
| **4.4** | Playback Improvements | Speed, audio/subtitle tracks, error taxonomy, keyboard shortcuts, ADR-010–013 |
| **4.5** | Performance and Caching | Cache invalidation, artwork LRU, search index lifecycle, scroll tuning, ADR-014–016 |
| **4.6** | Diagnostics and Supportability | `DiagnosticsService`, read-only UI, clipboard export, ADR-017–019 |
| **4.7** | Release and Documentation | Audit, regression, release docs, milestone closure |

---

## Major architecture changes

| Area | Change |
|---|---|
| Settings | Versioned envelope persistence; repository-first; legacy migration |
| Provider visibility | Operational status on dashboard; configuration in Settings (ADR-003 boundary) |
| Library metadata | External favourites/sort preferences; immutable catalogue discipline |
| Playback | Session rate override; track selection; resolver-aware fatal errors |
| Caching | `CatalogCacheCoordinator`; bounded artwork LRU; deferred search index rebuild |
| Diagnostics | Read-only runtime snapshot; redacted clipboard export; no telemetry |

M3/M3.5 preserved: filesystem-driven folder tree, last-good catalogue on failed refresh, `MediaLocationResolver` at consumption boundaries, Continue Watching resume keys.

---

## ADRs introduced (001–019)

| ADR | Title | Phase |
|---|---|---|
| 001 | Provider Health Model | 4.1 |
| 002 | Provider Refresh Lifecycle | 4.1 |
| 003 | Provider Status Presentation | 4.1 |
| 004 | Settings Storage and Versioning | 4.2 |
| 005 | Settings Information Architecture | 4.2 |
| 006 | Settings Validation and Apply Behaviour | 4.2 |
| 007 | Library Metadata and Favourites | 4.3 |
| 008 | Library Sorting and Filtering | 4.3 |
| 009 | Library Navigation and Breadcrumbs | 4.3 |
| 010 | Playback State Extensions | 4.4 |
| 011 | Playback Preferences | 4.4 |
| 012 | Track Selection | 4.4 |
| 013 | Playback Error Taxonomy | 4.4 |
| 014 | Catalogue Revision Cache Invalidation | 4.5 |
| 015 | Artwork and Image Decode Caching | 4.5 |
| 016 | Search Index and Large-Library Browsing | 4.5 |
| 017 | Diagnostics Architecture | 4.6 |
| 018 | Runtime Snapshot Model | 4.6 |
| 019 | Diagnostics Export and Support Strategy | 4.6 |

→ [ADR index](../architecture/decisions/README.md)

---

## Validation evidence

**Date:** 2026-07-18 · **Platform:** Windows

### Automated regression

| Check | Result |
|---|---|
| `flutter test` | **624 passed**, **8 skipped**, **0 failed** |
| `flutter analyze` | **89** existing findings (baseline); no new M4 errors |
| `PHASE_45_BENCHMARK=1` | **4 passed** (informational; opt-in) |

### Windows runtime harnesses

| Phase | Env var | Passed | Skipped |
|---|---|---|---|
| 4.1 Provider | `PHASE_41_RUNTIME=1` | 10 | 0 |
| 4.2 Settings | `PHASE_42_RUNTIME=1` | 13 | 0 |
| 4.3 Library | `PHASE_43_RUNTIME=1` | 27 | 0 |
| 4.4 Playback | `PHASE_44_RUNTIME=1` | 11 | 18 |
| 4.5 Performance | `PHASE_45_RUNTIME=1` | 20 | 2 |
| 4.6 Diagnostics | `PHASE_46_RUNTIME=1` | 10 | 1 |

Playback harness skips are expected: `flutter test` cannot initialise `media_kit_video` platform channel — media-backed scenarios require desktop manual QA ([Step 4 checklist](../roadmap/m4-phase-4.7-release-documentation.md#step-4--manual-windows-qa)).

---

## Documentation produced

| Category | Documents |
|---|---|
| Roadmap | [m4-plan.md](../roadmap/m4-plan.md), phase specs 4.1–4.7, Gate 0 audit, baseline audit |
| Architecture | provider-management, settings, library, playback, caching, diagnostics |
| ADRs | ADR-001 through ADR-019 |
| Design | [design-system.md](../design/design-system.md) updates (dashboard, known visual debt) |
| Release | [v0.5.0-dev.md](./v0.5.0-dev.md), [m4-foundation-complete.md](./m4-foundation-complete.md), this summary |

---

## Deferred items (not blockers)

| Item | Tracking |
|---|---|
| Continue Watching artwork stretch | [M4 plan Phase 4.7 observations](../roadmap/m4-plan.md#phase-47--release-and-documentation) |
| Dashboard card consistency | Same |
| Settings footer overflow in narrow widget test | Baseline issue (4.6 closure) |
| File-based diagnostics export | ADR-019 — clipboard only for M4 |
| Theme mode toggle | Post–4.2 optional |
| Scroll restoration for folder grids | Post–4.3 optional |
| `pubspec.yaml` semver bump | Deferred to `m4-complete` / `v0.5.0` tag decision |

---

## M4 retrospective (factual metrics)

| Metric | Value |
|---|---|
| Sub-phases completed | **8** (Init + 4.1–4.7) |
| Implementation phases | **7** (4.1–4.7) |
| ADRs introduced | **19** (ADR-001–019), all **Accepted** |
| Architecture planning docs | **6** (4.1–4.6 domains) |
| Phase specification documents | **8** (4.1–4.7 + Gate 0 + baseline audit) |
| Final automated test count | **624 passed**, **8 skipped** |
| Runtime validation phases | **6** harness suites (4.1–4.6) |
| Runtime scenarios (automated) | **91 passed**, **21 skipped** (aggregate) |
| `flutter analyze` baseline | **89** findings (pre-existing) |
| Major user-visible capabilities | Provider status, settings framework, favourites/sort/filter, playback speed/tracks, artwork LRU, diagnostics export |
| Deferred UX items recorded | **2** (artwork stretch, dashboard card consistency) |

---

## M4 completion criteria

| Criterion | Met |
|---|---|
| Settings coherent and persistent | ✅ |
| Provider state visible and manageable | ✅ |
| Library browsing polished | ✅ |
| Playback controls and track handling improved | ✅ |
| Large libraries remain responsive | ✅ |
| Common failures diagnosable in-app | ✅ |
| Windows local and HTTPS paths regression-safe | ✅ |
| Release documentation complete | ✅ |

---

## What M4 is not

- Not a content-type expansion milestone (music, books, images remain M5+)
- Not mobile platform delivery
- Not TMDB, transcoding, accounts, or virtual libraries
- Not a semver `v0.5.0` stable release until separately tagged

---

## Next steps

1. Execute [manual Windows QA checklist](../roadmap/m4-phase-4.7-release-documentation.md#step-4--manual-windows-qa) — 17 points; confidence pass only
2. Apply [release tagging sequence](../roadmap/m4-phase-4.7-release-documentation.md#release-tagging-sequence-after-qa-sign-off) — `pubspec.yaml` → `0.5.0`, then `m4-complete` / `v0.5.0` tags
3. Observe [release discipline](../roadmap/m4-phase-4.7-release-documentation.md#release-discipline--no-m4-drift) — no new M4 features; cosmetic findings → next milestone
4. Begin M5 planning when ready — [roadmap](../roadmap/roadmap.md)

---

## Related documents

| Document | Purpose |
|---|---|
| [v0.5.0-dev.md](./v0.5.0-dev.md) | Full development cycle with phase retrospectives |
| [m4-foundation-complete.md](./m4-foundation-complete.md) | Archive snapshot at 4.3 closure |
| [M3.5 release snapshot](./m3.5-media-access-complete.md) | Predecessor milestone |
