# M7 Phase 7.4.6 — Presentation Integration

**Status:** Complete (2026-08-04) — uncommitted for review  
**Branch:** `m7-development`  
**Prerequisite:** [Phase 7.4.5 closure](./m7-phase-7.4.5-closure-report.md)  
**Implementation commit:** pending review

→ [M7 plan](./m7-plan.md) · [Phase 7.4 plan](./m7-phase-7.4-plan.md) · [Metadata enrichment](../architecture/metadata-enrichment.md)

---

## Initial repository state

| Check | Result |
|---|---|
| Branch | `m7-development` |
| HEAD before 7.4.6 | `185700d` — `docs(m7.4): close Phase 7.4.5 artwork workflow integration` |
| Phase 7.4.5 implementation | `54630ef` |
| Working tree before 7.4.6 | Clean |
| Divergence vs `origin/m6-development` | `0 29` |
| Feature gate | Development-only (`MetadataEnrichmentFeatureConfig`) unchanged |

---

## Objective

Wire the completed artwork resolver into presentation surfaces so downloaded provider covers display where eligible — without auto-download, provider URL exposure, or bypassing local-first precedence.

---

## Presentation architecture

```
ArtworkPresentationService
        │
MetadataArtworkResolver
        │
ArtworkService  (+ cache peek via MetadataArtworkCacheRepository)

ResolvedMediaArtworkImage  →  ArtworkImage
```

| Component | Role |
|---|---|
| **`ArtworkPresentationService`** | Single presentation entry point; loads enrichment record; calls resolver; never downloads |
| **`ResolvedMediaArtworkImage`** | Shared widget; watches enrichment repository; signature-keyed resolve gate; renders via `ArtworkImage` |
| **Enrichment section** | Remains sole owner of Download/Refresh controls (7.4.5) |

Widgets request one resolved candidate. They do not inspect cache keys, provider IDs, or `MetadataArtworkReference` fields.

---

## Resolver integration

- Precedence unchanged from 7.4.4: reserved user override → catalogue thumbnail → sidecar → reserved embedded → folder art → **provider cache** → placeholder
- Presentation uses `peekLookup` only (no access-time rewrite on resolve)
- `peekLookup` uses sync existence check for FakeAsync-safe / cheap hot-path reads
- Zero HTTP / zero download from presentation path

---

## Surfaces wired

| Surface | Integration |
|---|---|
| Item detail poster | `ResolvedMediaArtworkImage` |
| `TtsMediaCard` | `ResolvedMediaArtworkImage` |
| Search result row | `ResolvedMediaArtworkImage` |
| Continue Watching | `ResolvedMediaArtworkImage` |
| Favourites list tiles | `ResolvedMediaArtworkImage` |

**Intentionally unchanged (local `ArtworkService` only):** library cards, folder cards, music artwork thumbnails — non-book / folder surfaces must not receive provider artwork.

---

## Book-only behaviour

Provider cache eligibility remains resolver-owned (`MediaKind.book` + linked enrichment). Non-book media never displays provider artwork even if a rogue enrichment record exists.

---

## Lifecycle

| Event | Presentation result |
|---|---|
| Link + successful download | Provider cover appears after enrichment notify |
| Relink (new record/artwork) | Old path replaced when new cache eligible |
| Same record | Artwork retained |
| Changed artwork ID (not downloaded) | Local/placeholder until explicit download |
| Unlink / ignore | Provider artwork disappears |
| Resume (unlinked) | Unavailable until linked again |

---

## Performance

- One shared `ArtworkPresentationService` from `main.dart`
- Item-scoped resolve via `ValueKey(signature)` — no duplicate resolve on unrelated rebuilds
- Decode remains inside `ArtworkImage` with existing surface size hints
- No repository writes on resolve

---

## Failure handling

Missing cache, unsafe path, corrupt file, unavailable repository → fallback to local/placeholder. Exceptions are caught at the resolve gate; widgets always receive a candidate.

---

## Accessibility

Semantics labels, placeholder behaviour, keyboard/focus paths, and layouts unchanged — artwork swap only.

---

## Tests

`test/artwork_presentation_integration_test.dart` — 27 cases covering:

1–6 item detail · 7–12 browse · 13–17 lifecycle · 18–23 resolver usage/isolation

**HTTP count:** 0 · **Download count:** 0 (presentation path)

---

## Regression (2026-08-04)

| Suite | Result |
|---|---|
| Presentation integration | **27 passed** |
| Resolver / workflow / enrichment artwork / item detail / artwork service | **60 passed** |
| Full `flutter test` | **1762 passed, 20 skipped, 0 failed** |

---

## Deferred

| Item | Phase |
|---|---|
| Windows artwork runtime harness | **7.4.7** |
| Production Open Library activation | Later |
| Automatic downloads / background refresh | Out of scope |
| Embedded extraction / user artwork picker | Out of scope |

---

## ADR status

| ADR | Status |
|---|---|
| ADR-029 | Proposed (unchanged) |
| ADR-015 | Accepted (unchanged) |
| ADR-028 | Proposed (unchanged) |

---

## Scope confirmations

- No automatic downloads
- No provider URL exposure in UI
- No new packages / version bump / push
- Development feature gate retained
- Runtime harness deferred to 7.4.7

---

## Proposed commit split

1. `feat(m7.4): wire artwork resolver into presentation surfaces`
2. `docs(m7.4): close Phase 7.4.6 presentation integration`

---

## Recommended next task

**Phase 7.4.7** — Windows artwork runtime harness (`PHASE_74_RUNTIME=1`) and Phase 7.4 closure.
