# ADR-002: Provider Refresh Lifecycle

**Status:** Accepted  
**Date:** 2026-07-12  
**Milestone:** M4 Phase 4.1  
**Authors:** TTSPlayer M4 documentation pass

---

## Context

TTSPlayer has two distinct “refresh” concepts that users conflate:

| Action | Mechanism today | Effect |
|---|---|---|
| **Refresh catalogue** | `CatalogService.rescan()` | Re-reads `catalog.json` from configured providers (local file or HTTPS) |
| **Full scan** | `ScannerService.runScan()` | Runs Python indexer on disk → then `rescan()` |

Adding posters or new files on disk requires a **full scan**. Picking up an updated `catalog.json` after an external indexer run requires **catalogue refresh** only.

M3.5 `rescan()` already:

- Sets `_isLoading` for the duration
- Iterates providers via `_tryProviderCatalogue`
- Preserves catalogue + sets `errorMessage` when all providers fail
- Clears fallback flag on success

Gaps: user-facing naming, per-provider `loading` state, single-flight guard, aligned Retry labelling.

Artwork sidecars are rediscovered when catalogue replacement succeeds via `onCatalogReplaced` → `ArtworkService.clearCache()` (2026-07-12).

---

## Decision

### 1. Catalogue refresh operation

**Catalogue refresh** is the user-facing name for re-running the **provider chain** to reload `catalog.json`. Implementation reuses `CatalogService.rescan()` logic (or a thin public alias `refreshCatalogue()` delegating to the same code path).

Refresh **does not**:

- Run `indexer.py`
- Modify `MediaProviderConfig`
- Clear the catalogue when all providers fail
- Invoke `onCatalogReplaced` / artwork cache clear on failure

Refresh **does**:

- Set per-provider `loading` during attempts (ADR-001)
- Replace catalogue on first successful provider in order
- Invoke `onCatalogReplaced` **only** on successful replacement (artwork cache clear)
- Update `lastCatalogueLoadAt`, snapshot, and fallback flags

### 2. M3.5 semantics preserved (non-negotiable)

Full provider-chain refresh **must not change** existing behaviour:

| Rule | Requirement |
|---|---|
| **Provider ordering** | `CatalogueProviderSelector.orderedProviders()` — legacy locals prepended under `localPreferred` only |
| **`localPreferred`** | Try locals then configured providers; demo fallback when **all** fail on **startup** |
| **`httpRequired`** | HTTP catalogue providers only; locals excluded (`skipped` in snapshot) |
| **Last-good catalogue** | If every provider fails during refresh/rescan, retain current `_catalog` |
| **Demo fallback** | When all providers fail on cold start (`localPreferred`), load bundled demo and set `isUsingFallback` |
| **Artwork cache** | Clear **only** after successful catalogue replacement — never on failed attempt |

Regression tests: `provider_selection_test.dart`, `catalog_service_http_test.dart`, `catalog_service_artwork_cache_test.dart`.

### 3. Provider attempt order

Unchanged from M3.5:

```
CatalogueProviderSelector.orderedProviders(
  config: activeProviderConfig,
  legacyLocalProviders: [scanner config path, saved pref path] // localPreferred only
)
```

User refresh always attempts the **full ordered chain** until first success — not “active provider only.”

Providers after the first success are not attempted; they remain **`idle`** (ADR-001).

### 4. Concurrency

Only **one** catalogue refresh may run at a time. If `isLoading` is true, subsequent refresh requests are ignored (UI disables button).

Scanner subprocess and catalogue refresh are independent; scanner completion calls `rescan()` which follows these rules.

### 5. UI labelling

| User label | Action |
|---|---|
| **Refresh catalogue** | Provider chain reload (`rescan` / `refreshCatalogue`) |
| **Run full scan** | `ScannerService.runScan()` *(unchanged)* |
| **Rescan this folder** | `ScannerService.runLibraryScan()` *(unchanged)* |

Dashboard banner **Retry** for catalogue errors → catalogue refresh, not full scan.

### 6. Startup vs manual refresh

`loadOnStartup()` and manual refresh share the same instrumentation and snapshot update. Startup additionally applies demo fallback when all providers fail under `localPreferred`.

---

## Rationale

- Reusing `rescan()` minimises regression risk
- Full-chain refresh retries preferred local sources when NAS remounts
- Artwork invalidation tied to replacement prevents stale sidecar clears on failure

---

## Consequences

### Positive

- Clear user vocabulary; low implementation surface
- M3.5 contract explicitly documented for reviewers

### Negative

- Full-chain refresh slower than active-only when many providers (acceptable)

### Neutral

- `rescan()` may remain the internal method name

---

## Alternatives considered

### Alternative A — Refresh active provider only

**Rejected because:** breaks localPreferred recovery semantics.

### Alternative B — Merge scanner and provider refresh

**Rejected because:** indexer is heavy and Windows-only.

### Alternative C — Clear artwork cache on any refresh attempt

**Rejected because:** failed refresh would drop cached sidecars while catalogue unchanged.

---

## Related documents

- [M4 Phase 4.1 specification](../../roadmap/m4-phase-4.1-provider-management.md)
- [ADR-001: Provider Health Model](./ADR-001-provider-health-model.md)
- [ADR-003: Provider Status Presentation](./ADR-003-provider-status-presentation.md)
- [Provider management architecture](../provider-management.md)
