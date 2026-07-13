# ADR-007: Library Metadata and Favourites

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.3  
**Authors:** M4 documentation pass

---

## Context

Phase 4.3 introduces **user-curated library metadata** — starting with favourites — without modifying the filesystem, `catalog.json`, or the folder-tree catalogue model.

Constraints:

- The filesystem and scanner output remain the authoritative source for what media exists (catalogue principle, filesystem-is-truth rules).
- Phase 4.2 established `SettingsRepository` for **configuration** (providers, network timeout). Favourites are **user metadata**, not configuration.
- `PlaybackService` already owns per-item progress keys (`position_*`, `duration_*`). Favourites must not share that namespace.
- Item and folder identities in the catalogue are stable **per path** (`id` is derived from path at scan time). Renames and moves produce new ids.
- Local and HTTP catalogues must behave the same — identity keys must come from catalogue fields, not OS-specific path parsing in the UI.

---

## Decision

1. Introduce **`LibraryMetadataRepository`** — a persistence-only component for user-owned library metadata, separate from `SettingsRepository` and runtime catalogue services.

2. Store metadata at **`ttsplayer_library_metadata_v1`** in `shared_preferences` as versioned JSON:

   ```json
   {
     "metadataVersion": 1,
     "favourites": {
       "items": [{ "id": "<MediaItem.id>", "favouritedAt": "ISO-8601" }],
       "folders": [{ "id": "<MediaFolder.id>", "favouritedAt": "ISO-8601" }]
     }
   }
   ```

3. **Favourites** are bookmarks only — they do not create virtual folders, alter scan output, or appear as filesystem locations.

4. **Stable identity:** favourite records reference catalogue `id` fields only. Resolution always goes through `Catalog.findItemById` / `Catalog.findFolderById` (new lookup helper) on the **current** catalogue.

5. **Stale handling — prune on catalogue replacement only:**

   Pruning runs **once per successful catalogue replacement**, not on arbitrary navigation events (opening a folder, popping routes, or dashboard refresh without a new catalogue).

   ```
   Catalogue replacement completes (CatalogService)
           ↓
   LibraryMetadataRepository.validateAgainstCatalog(catalog)
           ↓
   Favourite ids absent from current tree are removed from storage
           ↓
   Repository notifies listeners once
   ```

   - Trigger: `CatalogService` signals catalogue replace (same lifecycle hook used for search index invalidation / artwork cache clear).
   - Pruning is silent in the UI — no crash, no blocking dialog.
   - Optionally log a debug line with pruned count; no Phase 4.6 diagnostics surface in 4.3.
   - Between replacements, a favourite for a temporarily missing id may remain stored; it is not pruned mid-session until the next replacement event.

6. **Presentation:**
   - Dashboard **Favourites** section when the resolved list is non-empty: show the **first 10** resolved entries (`favouritedAt` descending); **View all** opens a dedicated favourites browse surface with the full list.
   - Favourite toggle on `ItemDetailScreen` and folder context (app bar or card menu).
   - Empty favourites: dashboard section hidden or compact empty prompt — not a fake library root.

7. **Extensibility:** the envelope shape reserves room for future `ratings`, `tags`, and `hidden` entries in later phases — not implemented in 4.3.

8. **Explicit exclusion:** favourites do **not** live in `SettingsRepository`, `catalog.json`, or the indexer.

---

## Rationale

- Separating configuration (`SettingsRepository`) from user metadata (`LibraryMetadataRepository`) matches ADR-004's category split and keeps reset semantics clear — "reset all settings" must not wipe favourites unless a separate destructive action is added later.
- Catalogue `id` keys work across local paths and HTTP-served catalogues because both are produced by the same indexer schema.
- Prune-on-replacement avoids unbounded stale lists without requiring filesystem watchers or move detection. Repository `initialize()` / `load()` must not independently prune against the catalogue — only `validateAgainstCatalog` after a successful catalogue replacement does.

---

## Consequences

### Positive

- Clear ownership boundary for future ratings, tags, and hidden-state metadata.
- Favourites survive app restart without touching the catalogue file.
- Provider and settings behaviour from Phases 4.1–4.2 remain unchanged.

### Negative

- Renamed or moved files lose favourites silently (new id) — acceptable for 4.3; no move-tracking without indexer support.
- A second repository adds migration and test surface area.

### Neutral

- Dual persistence keys (`ttsplayer_settings_v1`, `ttsplayer_library_metadata_v1`) follow the same pattern as playback progress keys.

---

## Alternatives considered

### Alternative A — Store favourites in `SettingsRepository.general`

**Rejected because:** favourites are user content bookmarks, not configuration. Mixing them complicates reset semantics and envelope versioning.

### Alternative B — Filesystem sidecar files (e.g. `.favourite`)

**Rejected because:** violates local-first read-only catalogue principle; breaks HTTP-only clients; requires write access to media roots.

### Alternative C — Path-based favourite keys instead of catalogue ids

**Rejected because:** path normalization differs across platforms; catalogue `id` is already the canonical stable key per scan revision.

---

## Related documents

- [M4 Phase 4.3 specification](../../roadmap/m4-phase-4.3-library-experience.md)
- [ADR-004: Settings Storage and Versioning](./ADR-004-settings-storage-and-versioning.md)
- [library.md](../library.md)
- [Catalogue principle](../../../.cursor/rules/catalogue-principle.mdc)
