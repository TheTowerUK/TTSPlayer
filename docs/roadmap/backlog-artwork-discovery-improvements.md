# Backlog — Artwork Discovery Improvements

**Status:** Tracked — not blocking M3.5 or Phase 4  
**Observed:** 2026-07-05 (Windows regression)  
**Area:** `ArtworkService` discovery — not `MediaLocationResolver`

→ [Windows regression checklist](../release/m3.5-media-access-complete.md#windows-regression-checklist)  
→ [ArtworkService](../../client/ttsplayer/lib/services/artwork/artwork_service.dart)

---

## Observation

During M3.5 Windows regression, **most artwork loads correctly**. Some media files with matching image filenames in the same folder do **not** display artwork.

This behaviour appears **independent of MediaLocationResolver** and should be investigated as an `ArtworkService` matching issue.

---

## Why this is not M3.5

M3.5 changed only the **load** step:

```
Filesystem path  →  MediaLocationResolver  →  Resolved URI  →  Image.file / Image.network
```

Artwork **discovery** is unchanged:

```
Filesystem  →  ArtworkService  →  ArtworkCandidate (filePath)
```

If some images work and some do not, the resolver is functioning; the sidecar discovery algorithm is the likely cause. This is a pre-existing or separate issue that the abstraction may have made more noticeable — **not a Phase 3b regression**.

**M3.5 verdict:** ✔ Artwork loading functional · ⚠ Existing matching inconsistency observed — **does not fail M3.5**.

---

## Possible investigations (Phase 4.x)

- Verify case-sensitive vs case-insensitive filename matching on Windows
- Confirm support for common sidecar names:
  - `{stem}.jpg` / `{stem}.png` (e.g. `movie.jpg` beside `movie.mp4`)
  - `folder.jpg`, `cover.jpg`, `poster.jpg`
- Check whether extensions are normalised correctly when building candidate paths
- Log why a candidate was rejected (missing file vs not tried) to aid diagnosis
- Compare indexer sidecar basenames with `ArtworkService._sidecarBasenames` for drift

---

## Scope

| In scope | Out of scope |
|---|---|
| `ArtworkService` candidate generation | `MediaLocationResolver` |
| Sidecar / folder art matching rules | HTTP artwork provider (Phase 4+) |
| Diagnostic logging for rejected candidates | Catalogue schema changes |

---

## Acceptance (when picked up)

- Reproduce at least one failing filename pair from regression (media + sidecar on disk)
- Fix or document intentional exclusion
- Unit test covering the reported case
