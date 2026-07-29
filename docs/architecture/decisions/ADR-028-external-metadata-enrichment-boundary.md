# ADR-028: External Metadata Enrichment Boundary

**Status:** Proposed  
**Date:** 2026-07-29  
**Milestone:** M7 Phase 7.0  
**Authors:** M7 planning

---

## Context

M6 explicitly excluded cloud metadata APIs (Goodreads, Comic Vine, TMDB, MusicBrainz, etc.). M7 introduces **optional** external enrichment while preserving:

- Filesystem and `catalog.json` as the authority for what media exists and where it lives
- Atomic scanner writes and catalogue v4 compatibility
- Graceful offline operation without credentials
- Multi-client consumption of the same catalogue (desktop local scan, mobile HTTP reload)

Three enrichment execution boundaries were evaluated:

- **A — Backend/indexer:** providers queried during scan; results written into or beside the catalogue
- **B — Client-side:** Flutter enriches incrementally; stores results in client persistence
- **C — Hybrid:** backend bulk enrichment plus client interactive matching and correction

Forces:

- User settings and credentials already live on the client (`SettingsRepository`)
- Manual match correction is a client UX concern
- Mobile clients (future M8) cannot run the Python indexer but must display enriched libraries
- NAS credential storage raises privacy and operational risk
- Bulk scan-time enrichment risks provider rate limits and longer rescan times
- `catalog.json` must not grow with volatile provider payloads or become coupled to provider schema churn

---

## Decision

1. **M7 primary enrichment boundary is client-side (Option B).**
2. **`catalog.json` remains filesystem-derived only.** Provider data is never written into the catalogue by the indexer in M7.
3. **Enrichment persists in a separate client store** (`ttsplayer_metadata_enrichment_v1`, schema finalized in Phase 7.1), keyed by stable catalogue item `id`.
4. **Provider network calls occur only on explicit user-initiated refresh, configured background refresh, or optional detail-screen stale-while-revalidate** — never during ordinary catalogue load or rescan reload.
5. **Backend bulk enrichment (Option A/C server path) is deferred** beyond the first vertical slice. A future optional `enrichment.json` companion file keyed by item id may be added without changing this ADR's client authority model.
6. **Provider credentials require an OS-backed secure-storage mechanism** (not plain settings JSON or application-managed reversible encryption without a separately approved key-protection design). Windows options — likely Credential Manager or DPAPI-backed storage — are **evaluated during implementation** (Phase 7.7). **Until secure storage is available, credentials must not be persisted.**

---

## Rationale

**Why client-primary:**

- Aligns with existing user-state persistence (favourites, progress, listening) outside `catalog.json`
- Keeps scanner fast, deterministic, and provider-agnostic
- Supports interactive matching, ignore, and field locks without rescan
- Mobile clients can enrich or consume the same client-side store pattern without NAS secrets
- Smallest M7 implementation surface — one enrichment pipeline to test and diagnose

**Why not backend-primary for M7:**

- Credentials on NAS; harder rotation and audit
- Bulk enrichment during full library scan amplifies rate-limit and failure blast radius
- Couples indexer releases to provider adapter changes
- Does not remove the need for client-side correction UX

**Why defer hybrid server path:**

- Client-primary proves precedence, matching, and artwork contracts first
- Companion `enrichment.json` can be added later as an optimization for offline mobile without reversing local authority

---

## Consequences

### Positive

- Clear separation: scanner truth vs presentation enrichment
- Catalogue HTTP reload semantics unchanged for M3.5/mobile
- Provider failures isolated from scan and playback paths
- Incremental rollout per media kind and provider

### Negative

- Each client may perform its own provider queries unless a future backend companion is added
- Enrichment not automatically shared across devices until M8 sync or backend companion
- Additional client persistence schema and migration responsibility

### Neutral

- Search and artwork services gain a merge layer (Phase 7.4–7.5)
- Diagnostics gains enrichment section; credentials remain yes/no only

---

## Alternatives considered

### Alternative A — Backend/indexer enrichment

Write provider fields into `catalog.json` or a mandatory sidecar during every scan.

**Rejected because:** Violates separation of volatile provider data from atomic filesystem catalogue; increases scan duration and failure coupling; stores credentials on server; complicates manual correction.

### Alternative C — Full hybrid from M7 start

Implement backend bulk enrichment and client correction concurrently.

**Rejected because:** Two pipelines before precedence and matching contracts are proven; highest maintenance cost for uncertain mobile benefit in M7 timeframe.

---

## Related documents

- [M7 plan](../../roadmap/m7-plan.md)
- [Metadata enrichment architecture](../metadata-enrichment.md)
- [ADR-029](./ADR-029-metadata-precedence-provenance-and-matching.md)
- [ADR-014 Catalogue Revision Cache Invalidation](./ADR-014-catalogue-revision-cache-invalidation.md)
- [ADR-025 Book/Comic Identity and Metadata Precedence](./ADR-025-book-comic-identity-and-metadata-precedence.md)
