# ADR-027: Reading Progress and Continue Reading

**Status:** Accepted  
**Date:** 2026-07-24  
**Accepted:** 2026-07-27 (Phase 6.5 implementation and diagnostics validated)  
**Milestone:** M6 — Phase 6.0 / 6.5  
**Related:** [books-comics.md](../books-comics.md) · [ADR-022](./ADR-022-music-queue-and-listening-state.md) · [ADR-014](./ADR-014-playback-position-persistence.md)

---

## Context

Video resume and music listening/session state already use application-managed persistence with isolated preference keys and catalogue-replacement pruning. Books/comics need the same class of behaviour: remember where the user left off and surface Continue Reading **without** inventing filesystem folders.

---

## Decision

1. Introduce a **versioned reading-progress repository** owned by the application (not `catalog.json`).
2. Store progress keyed by stable media item `id` with a format-appropriate location:
   - Comics: page index (and optional archive entry name)
   - PDF: page index
   - EPUB: spine id + positional offset (exact schema locked at 6.5)
3. Persist timestamps for Continue Reading ordering.
4. Use a **dedicated preference key namespace** that never writes video `position_*` or music listening/session keys.
5. On catalogue replacement, **prune** progress entries whose ids are absent (same coordinator pattern as favourites / listening history).
6. Continue Reading is an **application-managed derived view**, clearly labelled — never presented as a real folder.
7. Diagnostics may expose aggregate counts only; redacted (no titles/paths in export by default).

---

## Consequences

### Positive

- Parity with video/music resume UX
- Clear isolation and prune semantics
- Aligns with filesystem-is-truth (derived view is app state)

### Negative / risks

- Path rename loses progress (same as other id-based state)
- EPUB location schema complexity — keep minimal for v1

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Embed progress in catalogue | Catalogue is scanner-owned; would break atomic rescan model |
| Reuse video position keys | Namespace collision and wrong units |
| Sync across devices in M6 | M7 scope |

---

## Acceptance criteria

- [x] Progress survives process restart
- [x] Resume opens the correct location in the reader
- [x] Continue Reading excludes completed items; detail offers Read Again / Start from Beginning
- [x] Catalogue replacement prunes stale ids; metadata snapshots refresh
- [x] Isolated preference key (`ttsplayer_reading_progress_v1`); no writes to video/music keys
- [x] Diagnostics aggregates only; no paths, hrefs, entry names, or raw JSON in export

**Note:** Accepting ADR-027 does **not** resolve CBR UnRAR redistribution (Phase 6.3 closure remains separate).
