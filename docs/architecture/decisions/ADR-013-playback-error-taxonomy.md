# ADR-013: Playback Error Taxonomy

**Status:** Accepted  
**Date:** 2026-07-13  
**Accepted:** 2026-07-13 (specification sign-off, pre-implementation)  
**Milestone:** M4 Phase 4.4  
**Authors:** M4 documentation pass

---

## Context

TTSPlayer surfaces failures at multiple layers: catalogue provider load (4.1 Provider Status), media URI resolution (M3.5), and player open/decode (M3 `PlaybackService`). Phase 4.4 improves playback UX and must **not** mix operational provider diagnostics into the player or codec errors into the library manager.

M3 already maps some failures in `_friendlyError` and resolver gates. Phase 4.4 formalises a three-layer model with consistent user-facing copy.

---

## Decision

1. **Three layers — each owns only its messaging:**

   ```
   Provider  →  Resolver  →  Playback
   ```

2. **Layer definitions:**

   | Layer | Owner | Responsibility | Shown where |
   |---|---|---|---|
   | **Provider** | `CatalogService`, dashboard Provider Status | Catalogue source unavailable, degraded load, refresh needed | Dashboard, Library Manager, provider banners — **not** player chrome |
   | **Resolver** | `MediaLocationResolver` | Catalogue path cannot become a playable URI (mapping, HTTPS config, TLS policy) | Pre-play boundary; in player flow, mapped to **playback-layer** copy ([ADR-010](./ADR-010-playback-state-extensions.md)) |
   | **Playback** | `PlaybackService` | Open/init/seek/decode/timeout after URI resolved | `PlayerScreen` error view, item-not-playable gate |

3. **Playback must not duplicate Provider Status diagnostics.** The player must not show "HTTPS catalogue unavailable", refresh timestamps, or provider mode labels. Those remain on dashboard Provider Status ([ADR-003](./ADR-003-provider-status-presentation.md)).

4. **`PlaybackErrorKind` enum** (service-internal; drives user string selection):

   | Kind | Typical cause |
   |---|---|
   | `fileMissing` | Local file absent after scan |
   | `resolverFailed` | `ResolvedMediaLocation` not playable |
   | `network` | Socket / HTTP failure during open |
   | `timeout` | 15 s init/open probe |
   | `unsupportedFormat` | Codec / platform exception |
   | `unknown` | Unclassified; safe generic copy |

5. **Example user-facing messages (playback layer only):**

   | Situation | Message |
   |---|---|
   | Local file missing | "This file is no longer available. It may have been moved or deleted since the last scan." |
   | Resolver / mapping failure | "This item could not be prepared for playback. Check your media access settings." |
   | Network error during open | "A network error occurred while opening this video. Check your connection to the NAS." |
   | Init timeout | "This video took too long to open. Try again or check the file on your NAS." |
   | Unsupported format / decode | "This video could not be played. The format may not be supported." |
   | Generic fallback | "This video could not be played." |

   Secondary note (existing `playbackFailedNote`) may remain beneath the primary message for codec context — not provider diagnostics.

6. **Provider layer examples** (unchanged surfaces — **not** shown in player):

   | Situation | Message |
   |---|---|
   | HTTPS catalogue down | "HTTPS catalogue unavailable" |
   | Degraded fallback | "Using last saved catalogue" (status chip) |

7. **Resolver layer examples** (for logs / future dedicated surfaces; player shows playback mapping):

   | Situation | Internal / debug label |
   |---|---|
   | Unmapped path | "Media location could not be resolved" |

8. **Item status gate** (`MediaItemStatus`) messages remain distinct from open failures — shown on detail screen before play; not mixed with Provider Status.

9. **Retry behaviour:** `PlaybackService.retry()` replays the playback layer only; it does not trigger catalogue refresh (provider layer action).

---

## Rationale

- Users in the player need actionable playback copy, not infrastructure status.
- Separating layers preserves 4.1 Provider Status investment and avoids duplicate refresh UX in the player.
- `PlaybackErrorKind` enables tests without brittle string equality on full paragraphs.

---

## Consequences

### Positive

- Consistent error UX across local and HTTPS paths in 4.4.
- Clear test matrix for resolver vs decode failures.

### Negative

- Some resolver detail is simplified in player copy by design.

### Neutral

- Phase 4.6 diagnostics may expose deeper detail — must link to Provider Status, not replace layer boundaries.
- **Implementation note (Step 4):** `_ErrorView` uses `PlaybackErrorMessages.forKind(playbackErrorKind)`; `resolverFailed` adds a one-line hint toward Provider Status without duplicating provider diagnostics.

---

## Alternatives considered

### Alternative A — Show full resolver exception text in player

**Rejected because:** Exposes internal paths and provider config; violates layer separation.

### Alternative B — Single generic error everywhere

**Rejected because:** M3 already differentiated missing file vs network; 4.4 refines rather than regresses.

---

## Related documents

- [M4 Phase 4.4 specification](../../roadmap/m4-phase-4.4-playback-improvements.md)
- [ADR-003: Provider Status Presentation](./ADR-003-provider-status-presentation.md)
- [ADR-010: Playback State Extensions](./ADR-010-playback-state-extensions.md)
- [media-access-abstraction.md](../media-access-abstraction.md)
- [playback.md](../playback.md)
