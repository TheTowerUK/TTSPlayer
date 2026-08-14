# M7 Phase 7.5 — Metadata-Aware Search and Detail Presentation

**Status:** Complete (2026-08-14)
**Branch:** `m7-development`
**Prerequisite:** Phase 7.4 complete
**Implementation commits:** `230c6c5`, `bc32e0c`, `8601e9b`, `a99643e`, `74defde`, `7c1f27e`, `fcb3a4b`

→ [Phase 7.5 plan](./m7-phase-7.5-search-detail-presentation.md) · [M7 plan](./m7-plan.md) · [Metadata enrichment architecture](../architecture/metadata-enrichment.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

---

## Outcome

Phase 7.5 is complete. Persisted, accepted enrichment now participates in deterministic local search and shared search/detail presentation while catalogue identity, local-first precedence, provider-operation gating, and the Phase 7.4 artwork resolver remain authoritative.

No catalogue schema, provider contract, ranking weight, package dependency, playback path, or automatic/background enrichment behaviour changed.

---

## Delivered

| Step | Outcome |
|---|---|
| 7.5.2 | Shared `MetadataPresentationService` / immutable `MediaItemPresentation` projection with precedence, provenance, and accepted-match gating |
| 7.5.3 | Persisted enrichment indexing, deterministic additive ranking, lazy invalidation, and zero-dependency `SearchService()` compatibility |
| 7.5.4 | Live enriched book detail presentation with catalogue fallback and collapsible description |
| 7.5.5 | Projected search-row title/metadata and coalesced mounted active-query refresh |
| 7.5.6 | Opt-in Windows R1–R12 runtime harness covering search, detail, lifecycle, persistence, isolation, provider-call safety, and artwork integration |
| 7.5.7 | Final validation, documentation reconciliation, and ADR-029 acceptance |

---

## Preserved invariants

- Catalogue identity and catalogue search terms remain independently authoritative.
- Enrichment terms append; they never replace local terms.
- Provider-sourced presentation is limited to accepted linked match states; user overrides remain visible independently.
- Search remains local and makes zero provider calls.
- Ranking weights and deterministic tie-breaking remain unchanged from 7.5.3.
- `SearchService()` remains valid without enrichment dependencies.
- Artwork continues through `ArtworkPresentationService` / `MetadataArtworkResolver`; widgets do not hotlink or download.
- Feature gating controls provider operations, not readability of accepted persisted data.
- Non-book media remains isolated from book enrichment presentation.

---

## Validation

| Check | Result |
|---|---|
| Phase 7.5.3 focused search tests | **68 passed, 0 failed** |
| Phase 7.5.4 focused item-detail tests | **8 passed, 0 failed** |
| Phase 7.5.4 related regression | **131 passed, 0 failed** |
| Phase 7.5.5 focused regression | **118 passed, 0 failed** |
| Phase 7.5.6 gated Windows runtime | **12 passed, 0 failed** — R1–R12 |
| Phase 7.5.6 focused analysis | **No issues found** |
| Default full Flutter suite | **1836 passed, 21 skipped, 0 failed** |
| Windows release build | **Passed** — `ttsplayer.exe` produced on 2026-08-14 |

The default suite's additional skip is the intentionally gated Phase 7.5 runtime harness when `PHASE_75_RUNTIME` is unset.

---

## Lifecycle readiness

Enrichment notifications mark the search index dirty for a lazy rebuild. Mounted non-empty search queries rerun through the existing generation-safe path, and item detail rebuilds from the live repository projection. Unlink, ignore/resume, relink, catalogue pruning, and restart persistence are covered by the Windows harness.

---

## Deferred by design

- Subtitle indexing until an explicit ranking tier is approved
- Grid/card title overlays
- Production provider/coordinator activation and automatic enrichment
- Subject/genre browse facets and description search/snippets
- Provider-backed video, music, or comic presentation
- Enrichment series schema/provider mapping and user lock-editor UX
- Backend enrichment sidecars or catalogue schema changes

These are not Phase 7.5 readiness blockers.

---

## ADR status

ADR-029 is **Accepted**. Its acceptance gate is satisfied: the shared projection is implemented, precedence is tested, search and detail consume the projection, lifecycle behaviour is validated, and the Windows runtime matrix passes.

ADR-028 remains Proposed; production provider/backend-boundary decisions are outside Phase 7.5.

---

## Milestone readiness decision

Phase 7.5 is ready to close. The next M7 phase may begin from `m7-development`; no Phase 7.5 follow-up is required before progression.
