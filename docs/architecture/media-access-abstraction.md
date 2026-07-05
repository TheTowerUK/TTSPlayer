# Media Access Abstraction

**Status:** Proposed — Phase 2.5 (documentation gate before Flutter resolver)  
**Cycle:** `v0.4.0-dev` / M3.5

→ [Path mapping](./path-mapping.md) (HTTP serving layer rules)  
→ [M3.5 goals](../roadmap/network-client-foundation.md)  
→ [Phase status](../deployment/m35-phase-status.md)

---

## Problem

TTSPlayer must **not** be coupled to a specific storage backend — TNAS, Caddy, SMB, a mapped drive, or a local path. Today, playback and artwork code use catalogue `file_path` values directly in places. That breaks on mobile, couples the client to Windows filesystem semantics, and embeds deployment assumptions (e.g. “always Caddy on TNAS”).

The catalogue correctly stores **filesystem paths** from the indexer. Playback must not consume them raw.

---

## Goal

Introduce a **provider-neutral** media access model:

```
Storage source  →  Media access provider  →  Resolved playable URI
```

Browsing continues to use catalogue paths and folder names. **Play**, **preflight**, and **artwork loading** request a resolved URI through a single abstraction.

---

## Supported provider types

| Provider | Example catalogue path | Resolver output (typical) |
|---|---|---|
| **Local filesystem** | `D:\Media\Videos\a.mp4` | `file://` URI |
| **Windows mapped drive** | `Y:\Media\Videos\a.mp4` | `file://` URI on Windows desktop; HTTP URI on mobile if HTTP provider configured |
| **UNC / SMB** | `\\MEDIATNAS-B725\Media\Videos\a.mp4` | `file://` / UNC URI on Windows desktop; HTTP URI on mobile |
| **HTTP serving layer** | (same fs path in catalogue) | `https://host:8443/media/Videos/a.mp4` |
| **NAS deployment profile** | TNAS + Caddy (reference) | HTTP URI via configured base URL + [path mapping](./path-mapping.md) |

A **NAS deployment profile** is configuration (media roots + base URL + mapping rules), not a hard-coded code path. TNAS + Caddy is the **first reference implementation**, not the only one.

---

## Core rule

> The catalogue may contain filesystem paths. **Playback must never use raw paths directly.**

All play, preflight, and stream-oriented artwork requests go through:

### `MediaLocationResolver`

(Final Dart name may be `MediaLocationResolver` or `MediaUriResolver` — one public entry point.)

---

## Resolver contract

### Inputs

| Input | Source |
|---|---|
| Catalogue `file_path` | `MediaItem.filePath` (or sidecar path) |
| Configured media roots | `ttsplayer.config.json` / app settings |
| Active access provider | User or platform-selected profile |
| Platform target | Windows desktop, Android, iOS, … |

### Output — `ResolvedMediaLocation`

| Field | Purpose |
|---|---|
| `uri` | Playable URI (`file://`, `http://`, `https://`) |
| `providerType` | Which provider produced the URI |
| `status` | Resolved, fallback, or unresolved |
| `errorReason` | Human-readable reason when unresolved |

Optional metadata (future): `confidence`, cache hint, whether local existence check was skipped.

### Status values (initial set)

| Status | Meaning |
|---|---|
| `resolved` | URI is ready for the player |
| `unresolved` | No provider could map the path; show error, do not guess |
| `fallback` | Secondary provider used (e.g. HTTP when UNC unavailable) — log for diagnostics |

---

## Provider selection (high level)

```
MediaLocationResolver.resolve(filePath)
  │
  ├─ Already http(s) URL?  → pass through (resolved)
  │
  ├─ Platform + settings
  │    ├─ Desktop + local/UNC available  → LocalFileProvider
  │    └─ Mobile or HTTP-only mode       → HttpServingProvider
  │
  └─ HttpServingProvider
       strip media root → encode segments → base URL + /media/
       (rules in path-mapping.md)
```

Provider implementations are **pluggable**. Adding a new NAS or CDN means a new provider + config, not changes scattered through `PlaybackService`.

---

## What stays unchanged

| Layer | Unchanged |
|---|---|
| **Indexer** | Still emits filesystem paths only |
| **catalog.json schema** | No `stream_url` field required for M3.5 |
| **Folder browsing** | Still driven by catalogue tree |
| **Filesystem-is-truth** | Folder names and paths from scanner |

---

## Current code (pre-abstraction)

Today these touch raw paths — **Phase 3 refactors them to call the resolver**:

| Location | Current behaviour |
|---|---|
| `PlaybackService.play()` | `checkFilePresence(filePath)` then `mediaUriForPlayback(filePath)` |
| `playback_platform.dart` | Thin URI normalisation only |
| `ArtworkService` | Local file existence checks on sidecar paths |

No player or network startup changes until this document is **accepted** (Phase 2.5 gate).

---

## Phase relationship

| Phase | Scope | Status |
|---|---|---|
| **1** | Serving-layer docs, `caddy.config`, local Caddy validation | ✅ Complete locally |
| **2** | TNAS deployment validation (smoke tests on NAS) | ⛔ Blocked — operational |
| **2.5** | **Media access abstraction** (this document) | 🎯 Document & accept |
| **3** | Flutter `MediaLocationResolver` + provider implementations | ⛔ Blocked until **2.5 accepted** |

Phase 2 (TNAS + Caddy) is an **optional reference implementation** for the HTTP provider — it validates [path-mapping.md](./path-mapping.md) but is not a prerequisite to *accepting* the abstraction doc.

Phase 3 implementation should still use Phase 2 results to integration-test the HTTP provider when available.

---

## Acceptance criteria (Phase 2.5 gate)

Phase 2.5 is **accepted** when:

1. This document is reviewed and linked from roadmap / phase status
2. Provider types and resolver contract are agreed
3. TNAS/Caddy is explicitly labelled a reference deployment, not a hard dependency
4. Phase 3 scope is clear: resolver + providers only — no ad-hoc HTTP in `PlaybackService`

Only then: begin Phase 3 Flutter implementation.

---

## Phase 3 implementation notes (future — not started)

- `MediaLocationResolver` as a dedicated service (or module under `services/media_access/`)
- `LocalFileProvider`, `HttpServingProvider` as first two implementations
- `PlaybackService` and `ArtworkService` call resolver; no direct `File(path)` for play paths on network mode
- Unit tests per provider + platform matrix
- Settings: NAS base URL, active provider profile

---

## References

| Document | Role |
|---|---|
| [path-mapping.md](./path-mapping.md) | HTTP provider path → URL rules |
| [tnas-caddy-deploy-checklist.md](../deployment/tnas-caddy-deploy-checklist.md) | Reference HTTP deployment |
| [m35-pre-implementation-review.md](../roadmap/m35-pre-implementation-review.md) | Client gap analysis |
| `playback_service.dart` | Current play path (to refactor) |
