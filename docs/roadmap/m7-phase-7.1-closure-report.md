# M7 Phase 7.1 — Enrichment Persistence Closure Report

**Phase:** 7.1 — Enrichment models, provenance and persistence
**Milestone:** M7 — Metadata Enrichment and Library Experience
**Branch:** `m7-development`
**Status:** ✅ **Complete**
**Closure date:** 2026-07-29

→ [M7 plan](./m7-plan.md) · [Metadata enrichment architecture](../architecture/metadata-enrichment.md) · [ADR-028/029 Proposed](../architecture/decisions/README.md#m7--metadata-enrichment)

---

## Objective

Deliver the local persistence foundation for optional metadata enrichment — domain models, field provenance, match states, versioned storage, repository lifecycle, catalogue-replacement pruning, and automated tests — **without** provider HTTP, credentials, or UI.

---

## Delivered

| Area | Location |
|---|---|
| Match state / method enums | `client/ttsplayer/lib/features/metadata_enrichment/models/` |
| Field provenance model | `enrichment_field_value.dart`, `enrichment_field_source.dart` |
| Enrichment record | `metadata_enrichment_record.dart` |
| Repository | `metadata_enrichment_repository.dart` |
| Catalogue pruning | `CatalogCacheCoordinator.validateAgainstCatalog` hook |
| Composition root | `main.dart` initialize + `ChangeNotifierProvider` |
| Tests | `metadata_enrichment_record_test.dart`, `metadata_enrichment_repository_test.dart` |

---

## Persisted schema — `ttsplayer_metadata_enrichment_v1`

```json
{
  "stateVersion": 1,
  "records": [
    {
      "itemId": "<catalogue item id>",
      "matchState": "linked_high_confidence",
      "providerId": "open_library",
      "providerRecordId": "OL123W",
      "providerMediaType": "book",
      "matchMethod": "automatic",
      "confidence": 0.95,
      "fields": {
        "description": {
          "value": "...",
          "source": "provider",
          "providerId": "open_library",
          "updatedAt": "2026-07-29T10:00:00.000Z"
        }
      },
      "fetchedAt": "2026-07-29T10:00:00.000Z",
      "expiresAt": "2026-08-29T10:00:00.000Z",
      "lockedFields": ["title"],
      "lastErrorCategory": "rate_limited"
    }
  ]
}
```

**Storage mechanism:** `SharedPreferences` (same as reading progress / listening history). Enrichment records are bounded by catalogue item count; future migration to SQLite if record volume or field size exceeds practical SharedPreferences limits (not triggered in 7.1).

**Explicitly excluded from persistence:** credentials, authorization headers, full local paths, raw provider payloads, artwork bytes.

**Field locks:** `lockedFields` on the record is authoritative. `EnrichmentFieldValue.locked` is derived during normalization and serialization — the two must not disagree after `normalized()`.

---

## Migration and corrupt-state policy

| Condition | Behaviour |
|---|---|
| Absent store | Empty repository |
| Valid `stateVersion: 1` | Load records |
| Malformed JSON | Empty repository + warning |
| Wrong root type | Empty repository + warning |
| Missing `stateVersion` | Empty repository + warning |
| Unsupported `stateVersion` (≠ 1) | Empty repository + warning — no reinterpretation |
| Malformed individual record | Skip record; preserve valid siblings |
| Duplicate `itemId` on load | Keep record with latest `fetchedAt`; equal timestamps → higher `confidence` → lexicographically greater `providerRecordId` → more `fields` → incumbent |

Pruning failures do not block catalogue load (wrapped in try/catch at coordinator boundary).

---

## Catalogue replacement pruning

On successful catalogue replacement via `CatalogCacheCoordinator.onCatalogReplaced`:

1. Collect all current catalogue item ids (`catalog.allItems`)
2. Remove enrichment records whose `itemId` is absent
3. Persist if changed
4. No provider calls

**Rename/move limitation:** Item identity is md5(path). Renamed or moved files receive a new id; enrichment for the old id is pruned on the next catalogue replace. Automatic transfer to the new id is **out of scope** for Phase 7.1 (Phase 7.3 stale handling).

---

## Test evidence

| Suite | Result |
|---|---|
| `metadata_enrichment_record_test.dart` | 13 passed |
| `metadata_enrichment_repository_test.dart` | 22 passed |
| Full `flutter test` | **1446 passed, 18 skipped** (2026-07-29) |

Coverage includes: serialization round-trip, all match states/methods, recovery paths, pruning, coordinator integration, isolation from favourites/listening/reading/video keys.

---

## Remaining work (Phase 7.2+)

- Provider abstraction interface and fake HTTP adapter
- One books provider after dedicated evaluation
- Matching algorithms, confidence scoring, manual correction UI
- Artwork download cache
- OS-backed credential storage evaluation (Phase 7.7)
- Enriched detail presentation and search blob extension
- Diagnostics enrichment section

**ADR-028 and ADR-029 remain Proposed** — implementation validates persistence shape but acceptance deferred to provider-integration phase closure.

---

## Validation

Run during closure:

```powershell
flutter test test/metadata_enrichment_record_test.dart test/metadata_enrichment_repository_test.dart
flutter test
git diff --check
```

No Windows runtime harness required (no user-visible behaviour change).
