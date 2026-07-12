# ADR-001: Provider Health Model

**Status:** Accepted  
**Date:** 2026-07-12  
**Milestone:** M4 Phase 4.1  
**Authors:** TTSPlayer M4 documentation pass

---

## Context

M3.5 delivers a working multi-provider catalogue load path: `CatalogueProviderSelector` orders attempts, `CatalogService` tries each provider, retains the last-good catalogue on failure, and falls back to the demo asset when all providers fail on startup (`localPreferred`).

That behaviour is **correct but invisible**. The UI only exposes:

- A coarse three-way `CatalogueSourceKind` (Live NAS / Fallback NAS / Demo)
- A single `errorMessage` on the most recent failure
- `isUsingFallback` for demo mode

Users cannot see which configured provider is active, which providers failed in the chain, or whether the current catalogue is **degraded** (loaded from a fallback provider while a preferred source is unavailable). Phase 4.6 diagnostics will reuse this vocabulary for detailed views.

Constraints:

- No persistence format change for `MediaProviderConfig`
- Health is derived from load attempts, not from filesystem polling
- Graceful degradation must remain — failed refresh never clears a working catalogue

---

## Decision

Introduce a **session-scoped provider attempt lifecycle model** with these elements:

### 1. Health enum (`CatalogueProviderHealth`)

Each value describes **per-provider attempt lifecycle and final outcome** for the most recent load cycle. Values include **transient** states (in-flight) and **settled** states (after the cycle completes).

| Value | Kind | Meaning |
|---|---|---|
| `idle` | Settled / initial | Not attempted this session yet, **or** not reached in this cycle because an earlier provider succeeded (short-circuit) |
| `loading` | Transient | Attempt in progress for this provider |
| `success` | Settled | **Active** catalogue source; first provider to succeed in the chain for this cycle |
| `degraded` | Settled | **Active** catalogue source; succeeded after one or more **earlier** providers `failed` in the **same** cycle |
| `failed` | Settled | Attempted in this cycle; did not load the catalogue |
| `skipped` | Settled | **Never attempted** — excluded from the chain by configuration or selector rules |

#### When `degraded` applies

All of the following:

1. This provider is the **active catalogue source** (`isActive`).
2. At least one provider **earlier in selector order** was attempted and returned `failed` in the **same** load cycle.
3. Access mode is `localPreferred` (ordered fallback chain).

Does **not** apply when the first provider in order succeeds, or for manual `loadFromFile` / `loadFromUrl` (single-source load).

#### When `skipped` applies

**Configuration / selector exclusion only**, for example:

- Local file providers omitted from the attempt list under `httpRequired`.

#### When `skipped` does **not** apply

- Providers **after** the first success in a chain — those remain **`idle`** (not attempted this cycle; not an error).
- Failed attempts — use **`failed`**.

Exactly **one** provider (or none when demo/bundled without config success) may be `success` or `degraded` at a time — that provider is **active**.

After a cycle completes, transient `loading` settles to final outcomes; UI reads settled states except during an in-flight refresh.

### 2. Per-provider attempt record (`CatalogueProviderAttemptRecord`)

| Field | Separates |
|---|---|
| `definition` | **Configured provider identity** (`MediaCatalogueProviderDefinition`) |
| `health` | **Attempt status** |
| `lastError` | **Error information** (user-readable; null unless `failed`) |
| `lastAttemptAt` | **Attempt timestamp** (null if never tried) |
| `lastSuccessAt` | **Success timestamp** (null if never loaded a catalogue) |
| `isActive` | **Active catalogue source** flag (`success` or `degraded`) |

### 3. Aggregate snapshot (`CatalogueProviderSnapshot`)

Exposed read-only from `CatalogService`:

| Field | Separates |
|---|---|
| `providers` | Ordered attempt records (identity + status per row) |
| `activeProvider` | Current **active catalogue source** definition |
| `loadedCatalogueIdentity` | Active catalogue revision |
| `catalogPath` | Loaded location (delegates to existing getter where possible) |
| `accessMode` | Configuration context |
| `lastLoadStartedAt` | Start of most recent load cycle |
| `lastCatalogueLoadAt` | Last successful catalogue **replacement** |
| `lastCycleError` | Snapshot-level error when chain failed but catalogue retained |
| `sessionStartedAt` | First provider attempt this app session |
| `isDemoFallback` | **Demo fallback** (`isUsingFallback`) |
| `isDegradedLoad` | **Degraded fallback** (active provider is `degraded`) |
| `demoActiveWithoutProvider` | Demo active with no config provider success |

### 4. Persistence

**Session-only.** Health snapshots are **not** written to `shared_preferences`. On app restart, providers begin `idle` until the next load attempt.

Demo/bundled catalogue: when active with no matching provider success, `activeProvider` is null; `isDemoFallback` remains authoritative.

---

## Rationale

- **Separate from config** — provider list stays in `MediaProviderConfig`; health is ephemeral observation
- **Degraded vs success** — communicates fallback without hiding that a preferred source failed
- **Skipped vs idle** — skipped means “rules prevented attempt”; idle means “not tried yet or chain stopped early”
- **Session scope** — avoids migration and misleading historical errors

Aligns with [M4 plan](../../roadmap/m4-plan.md) engineering principles.

---

## Consequences

### Positive

- Single vocabulary for dashboard (4.1), banners, and diagnostics (4.6)
- Testable pure model — snapshot from mocked attempt sequences
- No change to M3.5 selection order or fallback rules

### Negative

- Health resets on app restart
- Slight memory overhead for attempt list (typically ≤ 5 providers)

### Neutral

- `CatalogueSourceKind` may remain internally until ADR-003 UI lands

---

## Alternatives considered

### Alternative A — Persist last health per provider in `shared_preferences`

**Rejected because:** stale failure badges after NAS recovery.

### Alternative B — Binary healthy/unhealthy only

**Rejected because:** cannot represent degraded, skipped, or short-circuit idle.

### Alternative C — Use `skipped` for short-circuit providers

**Rejected because:** conflates configuration exclusion with normal chain success; `idle` is clearer.

### Alternative D — Poll provider URLs/files on a timer

**Rejected because:** out of scope; contradicts zero-bloat principle.

---

## Related documents

- [M4 Phase 4.1 specification](../../roadmap/m4-phase-4.1-provider-management.md)
- [Provider management architecture](../provider-management.md)
- [ADR-002: Provider Refresh Lifecycle](./ADR-002-provider-refresh-lifecycle.md)
- [ADR-003: Provider Status Presentation](./ADR-003-provider-status-presentation.md)
- [Diagnostics planning (Phase 4.6)](../diagnostics.md)
