# M7 Phase 7.4.5 — Book Metadata Artwork Workflow Integration

**Status:** Complete (2026-08-03) — uncommitted for review
**Branch:** `m7-development`
**Prerequisite:** [Phase 7.4.4 closure](./m7-phase-7.4.4-closure-report.md)
**Implementation commit:** pending review

→ [M7 plan](./m7-plan.md) · [Phase 7.4 plan](./m7-phase-7.4-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.4.5 | `8874e7c` — `docs(m7.4): close Phase 7.4.4 resolver and precedence` |
| Phase 7.4.4 implementation | `ea55036` |
| Working tree before 7.4.5 | Clean |
| Divergence vs `origin/m6-development` | `0 27` |
| `.git/objects` write issue | Not observed |

---

## Objective

Integrate explicit book-cover download and refresh into the book metadata enrichment workflow — coordinator-owned operations, enrichment persistence, lifecycle protection, bounded UI messages. No item-detail poster or browse-card wiring (7.4.6).

---

## Workflow architecture

**`BookMetadataArtworkCoordinator`** composes:

- `MetadataEnrichmentRepository` — artwork field merge only
- `MetadataArtworkDownloadService` — validated cache writes
- `MetadataArtworkDownloadGenerationGuard` — item-scoped invalidation
- `MetadataArtworkCacheRepository` — already-cached detection (`peekLookup`)

Widgets call the coordinator only; no URL construction, HTTP, or cache file manipulation in UI.

---

## Result types

`BookMetadataArtworkWorkflowResult` sealed hierarchy:

| Outcome | Type |
|---|---|
| Downloaded | `BookMetadataArtworkDownloaded` |
| Refreshed | `BookMetadataArtworkRefreshed` |
| Already cached | `BookMetadataArtworkAlreadyCached` |
| Not linked / no reference | `BookMetadataArtworkNotLinked` / `BookMetadataArtworkNoArtworkAvailable` |
| Identity changed | `BookMetadataArtworkIdentityChanged` |
| Provider/validation/disk failure | `BookMetadataArtworkProviderFailure` / `BookMetadataArtworkValidationFailure` / `BookMetadataArtworkDiskFailure` |
| Persistence failure | `BookMetadataArtworkPersistenceFailure` |
| Refresh retained prior cache | `BookMetadataArtworkPriorCacheRetained` |

---

## UI integration

`BookMetadataEnrichmentSection` exposes:

- Cover status via `MetadataArtworkPresentation`
- **Download cover** / **Refresh cover** actions
- Pending disables all actions (shared `_PendingOperation`)
- Bounded messages via `MetadataEnrichmentUiMessages.artworkWorkflowMessage`
- Artwork generation invalidated on item change, unlink, ignore, resume, candidate link

**Not wired:** item-detail poster, browse cards, automatic download on link.

---

## Action matrix

| State | Status | Action |
|---|---|---|
| Unlinked | Cover unavailable | None |
| Linked, no reference | Cover unavailable | None |
| Linked, available | Cover available | Download |
| Linked, downloaded | Cover downloaded | Refresh |
| Linked, stale | Cover stale | Refresh |
| Linked, failed | Cover download failed | Download (retry) |
| Pending | — | Disabled |

---

## Lifecycle

| Event | Behaviour |
|---|---|
| Link | Reference persisted (7.4.2); no auto-download |
| Relink | Invalidates in-flight ops via generation bump |
| Unlink / ignore | Provider artwork ineligible; in-flight ops rejected |
| Download | One HTTP via download service; merges artwork fields only |
| Refresh failure | Prior cache retained (`BookMetadataArtworkPriorCacheRetained`) |
| Already cached | Zero HTTP; no enrichment rewrite when unchanged |

---

## Duplicate-operation protection

- Pending UI disables actions
- Coordinator coalesces concurrent downloads for same cache key + operation type
- Separate items remain independent

---

## Tests

| Suite | Count |
|---|---|
| New coordinator tests | 10 |
| New presentation tests | 3 |
| New section artwork widget tests | 7 (includes Completer-gated download/refresh pending) |
| Full `flutter test` | **1735 passed, 20 skipped, 0 failed** (pending tests add +2) |

Artwork HTTP in coordinator tests: invoked only in explicit download/refresh cases; already-cached path: **0 new HTTP**.
Metadata search invocation from artwork widget tests: **0**.
Pending widget tests: **1 workflow invocation**, **1 HTTP** via fake client after Completer completes; second tap does not re-invoke.

---

## Known limitations

- `BookMetadataArtworkCoordinator` not registered in production `main.dart` (dev-gated section only)
- Item-detail poster / browse cards still use `ArtworkService` directly (7.4.6)
- No automatic download on metadata link

---

## ADR status

- **ADR-029:** Proposed (unchanged)
- **ADR-015:** Accepted (unchanged)

---

## Next task

**Phase 7.4.6 — Presentation integration:** wire `MetadataArtworkResolver` to item detail and browse cards.

→ [Phase 7.4 plan](./m7-phase-7.4-plan.md)
