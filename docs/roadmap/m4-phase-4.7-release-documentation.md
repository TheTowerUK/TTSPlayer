# M4 Phase 4.7 — Release and Documentation

**Status:** **COMPLETE** (2026-07-18)  
**Related roadmap phase:** [M4 Phase 4.7 — Release and Documentation](./m4-plan.md#phase-47--release-and-documentation)  
**Release snapshot:** [M4 release summary](../release/m4-release-summary.md)

→ [v0.5.0-dev tracker](../release/v0.5.0-dev.md)  
→ [M4 plan](./m4-plan.md)

---

## Objective

Close M4 with validated documentation and release artefacts. No new feature work — consolidation, audit, regression evidence, and milestone closure only.

---

## Step 1 — Release audit

**Objective:** Confirm implementation, architecture, and release documentation describe the same product.

### Architecture review

| Document | Status at closure |
|---|---|
| [provider-management.md](../architecture/provider-management.md) | Implemented / Accepted (4.1) |
| [settings.md](../architecture/settings.md) | Implemented / Accepted (4.2) |
| [library.md](../architecture/library.md) | Implemented / Accepted (4.3) |
| [playback.md](../architecture/playback.md) | Implemented / Accepted (4.4) |
| [caching.md](../architecture/caching.md) | Implemented / Accepted (4.5) |
| [diagnostics.md](../architecture/diagnostics.md) | Implemented / Accepted (4.6) |

### ADR reconciliation

| Range | Phase | Index status |
|---|---|---|
| ADR-001–003 | 4.1 Provider Management | Accepted |
| ADR-004–006 | 4.2 Settings Framework | Accepted |
| ADR-007–009 | 4.3 Library Experience | Accepted |
| ADR-010–013 | 4.4 Playback Improvements | Accepted |
| ADR-014–016 | 4.5 Performance and Caching | Accepted |
| ADR-017–019 | 4.6 Diagnostics and Supportability | Accepted |

**Verdict:** No ADR remains **Proposed** that should be **Accepted** at M4 closure. ADR index reconciled in [decisions/README.md](../architecture/decisions/README.md).

### Roadmap reconciliation

| Item | Action |
|---|---|
| [m4-plan.md](./m4-plan.md) phase table | 4.1–4.7 marked complete; duplicate 4.7 row removed |
| [MILESTONES.md](../../MILESTONES.md) | M4 status updated to complete |
| [roadmap.md](./roadmap.md) | M4 section updated |
| Phase specs 4.1–4.6 | Already marked complete at respective closures |
| [m4-foundation-complete.md](../release/m4-foundation-complete.md) | Historical archive (4.1–4.3); unchanged |

### Release notes reconciliation

| Document | Action |
|---|---|
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | Phase 4.7 closure; validation table; M4 retrospective |
| [release-history.md](../release/release-history.md) | M4 entry added |
| [m4-release-summary.md](../release/m4-release-summary.md) | **New** — permanent milestone archive |
| [release/README.md](../release/README.md) | M4 snapshot linked |

### Documentation index validation

| Index | Verdict |
|---|---|
| [docs/README.md](../README.md) | M4 status updated |
| [architecture/README.md](../architecture/README.md) | All M4 planning docs → Implemented / Accepted |
| [release/README.md](../release/README.md) | M4 release snapshot added |

### Broken link check

Manual review of M4 cross-links in release tracker, architecture index, and phase specs — no broken relative links found in audited paths.

### Deferred items audit

| Item | Classification |
|---|---|
| Continue Watching artwork stretch | Deferred UX polish — [m4-plan.md](./m4-plan.md#phase-47--release-and-documentation) |
| Dashboard card consistency | Deferred UX polish — same |
| Settings footer overflow (~6.5 px) | Existing baseline — widget-test viewport only (4.6 closure) |
| Phase 4.4 media-backed playback in `flutter test` | Known platform limit — desktop manual QA |
| `pubspec.yaml` version `0.4.0-dev.1` vs `v0.5.0-dev` naming | Version bump deferred to `m4-complete` tag decision |

**Deliverable:** Documentation baseline confirmed.

---

## Step 2 — Repository audit

**Objective:** Review repository hygiene — not application behaviour.

| Check | Finding |
|---|---|
| Folder structure | Matches project layout in stack rules — `backend/`, `client/ttsplayer/`, `docs/`, `assets/` |
| Obsolete files | None removed — `m4-rich-media-libraries.md` retained with superseded note |
| Dead documentation | [media-access-abstraction.md](../architecture/media-access-abstraction.md) Phase 3a section updated from stale "in progress" |
| Duplicated docs | `m4-foundation-complete.md` is intentional archive; not duplicate of release summary |
| Stale comments | No `TODO` / `FIXME` in `client/ttsplayer/lib/` or `backend/` |
| Deprecated assets | None flagged |
| Unused architecture documents | All M4 architecture docs referenced from index |

**Deliverable:** Repository considered release-clean.

---

## Step 3 — Final regression validation

**Date:** 2026-07-18 · **Platform:** Windows

### Automated suite

| Check | Result |
|---|---|
| `flutter test` (normal suite) | **624 passed**, **8 skipped**, **0 failed** |
| `flutter analyze` | **89** existing info/warning findings; **0 new M4 errors** |
| `git diff --check` | Clean (no whitespace errors) |

### Opt-in Windows runtime harnesses

| Harness | Env var | Result |
|---|---|---|
| Phase 4.1 | `PHASE_41_RUNTIME=1` | **10 passed**, **0 skipped** |
| Phase 4.2 | `PHASE_42_RUNTIME=1` | **13 passed**, **0 skipped** |
| Phase 4.3 | `PHASE_43_RUNTIME=1` | **27 passed**, **0 skipped** |
| Phase 4.4 | `PHASE_44_RUNTIME=1` | **11 passed**, **18 skipped** (media_kit channel — expected) |
| Phase 4.5 | `PHASE_45_RUNTIME=1` | **20 passed**, **2 skipped** (optional live catalogue) |
| Phase 4.6 | `PHASE_46_RUNTIME=1` | **10 passed**, **1 skipped** (optional live catalogue) |

**Coverage areas validated (automated):** startup wiring, dashboard assembly, provider switching, catalogue lifecycle, playback service state, diagnostics capture/export, settings persistence, search index lifecycle, artwork cache, favourites, folder sort/filter, keyboard shortcuts (widget harness).

**Deliverable:** Final release evidence recorded in [M4 release summary](../release/m4-release-summary.md#validation-evidence).

---

## Step 4 — Manual Windows QA

**Objective:** Structured confidence check before milestone tag — not a bug-hunt phase.

Execute on Windows desktop (`flutter run -d windows`) against local and/or HTTPS catalogues. Check off before applying `m4-complete` tag.

### Checklist

| # | Area | Check |
|---|---|---|
| 1 | Startup | App launches; bundled or last-good catalogue visible |
| 2 | Refresh | Explicit catalogue refresh succeeds; failed refresh retains last-good |
| 3 | Provider changes | Switch local ↔ HTTPS; Provider Status reflects state |
| 4 | Diagnostics | Settings → View diagnostics; sections populate; Copy works |
| 5 | Playback | Play local file; first frame renders |
| 6 | Seeking | Forward/back seek; position updates |
| 7 | Subtitles | Subtitle menu when tracks present |
| 8 | Audio tracks | Audio track menu when tracks present |
| 9 | Artwork | Sidecar/placeholder on dashboard and detail |
| 10 | Continue Watching | Resume row updates after partial watch |
| 11 | Recently Added | Carousel shows newest items when `added_at` present |
| 12 | Libraries | Library cards open correct folders |
| 13 | Keyboard shortcuts | Ctrl+F search; player popup Esc-first; dashboard navigation |
| 14 | Settings | Save playback/network; persistence after restart |
| 15 | Scrolling | Large folder scroll; dashboard carousels |
| 16 | High DPI | Readable layout at 125%/150% scaling |
| 17 | Window sizes | 900×420 minimum; wide layout without overflow |

**Classification at documentation closure:** Checklist **provided**; execute before annotated tag. Automated gates above are **green**.

---

## Step 5 — Release documentation

### Finalized documents

| Document | Status |
|---|---|
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | M4 cycle closed |
| [m4-release-summary.md](../release/m4-release-summary.md) | **New** — permanent archive |
| [release-history.md](../release/release-history.md) | M4 entry |
| [m4-plan.md](./m4-plan.md) | M4 complete |
| [architecture/README.md](../architecture/README.md) | M4 section complete |

---

## Step 6 — Milestone closure

### Definition of done reconciliation

| Criterion | Verdict |
|---|---|
| All M4 phases complete (Init + 4.1–4.7) | **Satisfied** |
| Documentation reconciled | **Satisfied** — Step 1 |
| Architecture reconciled | **Satisfied** — all M4 docs Accepted |
| ADRs reconciled | **Satisfied** — ADR-001–019 Accepted |
| Regression complete | **Satisfied** — Step 3 |
| Runtime validation complete | **Satisfied** — six harness suites |
| Release documentation complete | **Satisfied** — Step 5 |
| Known deferred work documented | **Satisfied** — artwork stretch, dashboard consistency |
| No release blockers | **Satisfied** |
| Milestone formally closed | **Satisfied** — this document |
| README intentionally excluded | **Preserved** — unstaged local edits |

### Git status at closure

Branch `m4-development` — documentation closure commit follows Step 6. `README.md` excluded per project convention.

### Tag decision (deferred to maintainer)

| Tag | Meaning |
|---|---|
| `m4-complete` | Recommended when manual QA (Step 4) signed off |
| `v0.5.0` | Semver stable — separate decision from dev-cycle closure |

**Phase 4.7: COMPLETE.** **M4 milestone: COMPLETE** (documentation and automated validation).

---

## Related documents

| Document | Purpose |
|---|---|
| [M4 release summary](../release/m4-release-summary.md) | Permanent milestone archive + retrospective |
| [v0.5.0-dev.md](../release/v0.5.0-dev.md) | Development cycle tracker |
| [m4-plan.md](./m4-plan.md) | Master M4 roadmap |
