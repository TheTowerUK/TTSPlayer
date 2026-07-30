# ADR-029: Metadata Precedence, Provenance, and Matching

**Status:** Proposed  
**Date:** 2026-07-29  
**Milestone:** M7 Phase 7.0  
**Authors:** M7 planning

---

## Context

TTSPlayer already defines **local** metadata precedence for music ([ADR-021](./ADR-021-music-metadata-precedence-and-identity.md)) and books/comics ([ADR-025](./ADR-025-book-comic-identity-and-metadata-precedence.md)) at scan time. M7 adds optional external provider data that must:

- Enrich presentation without replacing authoritative local identity
- Survive provider refresh without undoing explicit user corrections
- Avoid silent attachment of incorrect artwork or descriptions
- Remain diagnosable without exposing secrets or raw provider payloads

Forces:

- Users expect local filenames and folder layout to remain meaningful when providers are disabled
- Wrong poster art on Continue Watching or library grids is highly visible
- Items can be renamed or moved (new md5 id) — enrichment links can orphan
- Multiple providers may be added over time — provenance must be per-field

---

## Decision

### 1. Layered precedence (display merge)

For presentation fields, resolve in order (highest wins):

1. **User override** (with explicit field lock)
2. **Local sidecar metadata** (when supported)
3. **Embedded file metadata** (tags, EPUB OPF, ComicInfo.xml)
4. **Filesystem / catalogue-derived** (indexer output in `MediaItem`)
5. **External provider enrichment** (enrichment store overlay)
6. **Fallback** (filename stem, neutral placeholder)

**Identity fields** (`id`, `file_path`, `media_kind`) are never sourced from layers 5–6.

### 2. Field locks

User corrections persist `lockedFields` on the enrichment record. Provider refresh **must skip** locked fields. Clearing a lock returns the field to normal precedence.

### 3. Match states and confidence

Persist for each enriched item:

| State | Auto-apply / persistence (Phase 7.3) |
|---|---|
| `linked_by_identifier` (ISBN, embedded provider id) | Yes — **explicit ISBN refresh only** → `matchMethod.identifier`, confidence `1.0` |
| `linked_high_confidence` | **Not written in Phase 7.3** — reserved for future approved auto-match workflow; transient evaluation may recommend `highConfidenceCandidate` |
| `linked_manual` | User authoritative — **all user-confirmed search selections** persist here, including high-band scores |
| `ambiguous` | **Never** auto-apply provider fields |
| `unmatched` | Local only |
| `ignored` | No automatic retry until cleared |
| `stale` | Prompt re-match after id/path change |

Store `matchMethod`, `confidence` (0.0–1.0), `providerId`, `providerRecordId`.

**Default auto-match threshold:** conservative — Phase 7.3 plan defines **high confidence ≥ 0.85** as a **transient evaluation band only**; search candidates require explicit user confirmation and persist as `linked_manual`. Only explicit ISBN lookup may persist automatically as `linked_by_identifier`. See [m7-phase-7.3-plan.md](../../roadmap/m7-phase-7.3-plan.md).

### 4. Provenance

Each enriched field stores `{ value, source, providerId?, fetchedAt? }`. UI and diagnostics may show provider attribution where licensing requires it.

### 5. Raw provider payload

**Do not persist** full raw API responses by default. Store normalized fields only. Exception requires documented license/debug need, size cap, and exclusion from diagnostics export.

### 6. Artwork precedence

Extend artwork resolution:

1. User-selected local artwork (locked)
2. Local sidecar
3. Embedded artwork (when implemented)
4. Provider artwork **disk cache** (downloaded bytes)
5. Placeholder

Never block item rendering on provider artwork failure. Never hotlink provider URLs directly in widgets — cache first.

### 7. Catalogue replace behaviour

When item ids disappear after rescan: prune enrichment records. When a user renames/moves media (new id): prior enrichment becomes orphaned — detect as `stale`, do not auto-transfer without confirmation.

---

## Rationale

- Extends ADR-021/025 rather than replacing them — scanner rules unchanged
- Field locks prevent the common "provider refresh undid my fix" failure mode
- Confidence gating prevents silent wrong-match damage
- Normalized storage limits schema coupling and diagnostic leakage
- Artwork cache-first respects provider hotlink policies and offline use

---

## Consequences

### Positive

- Deterministic merge testable in unit tests
- User trust preserved when providers disagree with local names
- Clear diagnostics buckets (matched, ambiguous, ignored, stale)

### Negative

- Presentation layer complexity — view models between `MediaItem` and UI
- Lock management UX required in settings/detail

### Neutral

- Search index must append provider keywords without replacing local blob (Phase 7.5)
- Existing `ArtworkService` gains provider cache source

---

## Alternatives considered

### Alternative A — Provider overwrites catalogue fields on match

Update `MediaItem` title/year in memory from provider automatically.

**Rejected because:** Blurs local authority; lost on rescan; conflicts with ADR-021/025; hard to revert.

### Alternative B — Auto-apply all single search results

First result wins when provider returns one hit.

**Rejected because:** Single results can still be wrong edition/year; unacceptable for video and comic artwork.

### Alternative C — Store raw JSON blobs for replay

Keep full provider responses for forward compatibility.

**Rejected as default because:** License uncertainty, export leakage risk, storage growth — optional debug mode only.

---

## Related documents

- [M7 plan](../../roadmap/m7-plan.md)
- [Metadata enrichment architecture](../metadata-enrichment.md)
- [ADR-028 External Metadata Enrichment Boundary](./ADR-028-external-metadata-enrichment-boundary.md)
- [ADR-021 Music Metadata Precedence](./ADR-021-music-metadata-precedence-and-identity.md)
- [ADR-025 Book/Comic Identity and Metadata Precedence](./ADR-025-book-comic-identity-and-metadata-precedence.md)
- [ADR-015 Artwork and Image Decode Caching](./ADR-015-artwork-and-image-decode-caching.md)
