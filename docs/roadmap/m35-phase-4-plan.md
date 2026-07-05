# M3.5 Phase 4 — Network Catalogue & Provider Configuration

**Status:** Active — opened 2026-07-05  
**Cycle:** `v0.4.0-dev`  
**Predecessor:** [M3.5 final acceptance](../release/m3.5-media-access-complete.md#m35-final-acceptance) — tag `m3.5-media-access-complete` @ `fa0f66a`

→ [Media access abstraction](../architecture/media-access-abstraction.md)  
→ [Path mapping](../architecture/path-mapping.md)  
→ [Phase status](../deployment/m35-phase-status.md)  
→ [M3.5 release snapshot](../release/m3.5-media-access-complete.md)

---

## M3.5 closure policy

**M3.5 is closed** except for critical bug fixes in the resolver, playback wiring, or reference-provider docs.

Do **not** add “one more improvement” to M3.5. New work — even small enhancements — is **Phase 4** or **backlog** (e.g. [artwork discovery](./backlog-artwork-discovery-improvements.md), TLS follow-up).

That discipline keeps milestones meaningful and project history easy to follow.

---

## Objective

**Network Catalogue & Provider Configuration**

M3.5 answered: *Can TTSPlayer access media through a provider-neutral abstraction?* → **Yes.**

Phase 4 answers: *How do users configure and use multiple providers seamlessly?*

The focus shifts from **proving the architecture** to **expanding capability**.

---

## In scope

| Item | Detail |
|---|---|
| HTTP catalogue loading | `CatalogService` fetch from URL with timeout; preserve last-good catalogue |
| Configurable media providers | Local filesystem, SMB/UNC, HTTP serving layer |
| Provider selection & fallback | Preference order when multiple providers can serve a path |
| Settings UI | Media roots, HTTP base URL, active provider profile |
| HTTPS / TLS refinement | Resolve TNAS `:8443` `tls internal` issue; trust / cert workflow |

All consumption continues through existing **`MediaLocationResolver`** — no ad-hoc URI logic in playback or artwork.

---

## Out of scope (Phase 4)

| Item | Deferred to |
|---|---|
| Artwork sidecar matching improvements | [Backlog — Phase 4.x](./backlog-artwork-discovery-improvements.md) |
| Scanner changes | Later milestone |
| SQLite / catalogue schema changes | Not required for HTTP fetch |
| App Store / Play Store polish | Post smoke-build |
| Automatic provider discovery | Future enhancement |

---

## Architecture (unchanged from M3.5)

```
Catalogue source (local file or HTTP URL)
    ↓
CatalogService
    ↓
Catalogue tree (filesystem paths unchanged)
    ↓
MediaLocationResolver  ← provider config applied here
    ↓
Playback / Artwork
```

Phase 4 adds **how the catalogue is loaded** and **how providers are configured** — not a new playback path.

---

## Suggested implementation order

1. **Provider configuration model** — persist roots, HTTP base URL, mode (`localPreferred` / `httpRequired`)
2. **Settings UI** — minimal desktop/mobile surfaces for provider config
3. **`CatalogService` HTTP path** — load `catalog.json` from configured URL; graceful degradation
4. **Provider preference & fallback** — resolver tries providers in user order
5. **TLS follow-up** — document and validate HTTPS on TNAS reference provider
6. **Integration tests** — HTTP catalogue + HTTP media play on home network

---

## Definition of done (Phase 4)

- [ ] User can configure at least one HTTP provider (base URL + catalogue endpoint)
- [ ] App loads catalogue over HTTP with timeout; failed fetch keeps previous catalogue
- [ ] Playback and artwork use resolver with configured HTTP base on non-Windows (or when HTTP preferred)
- [ ] Settings survive app restart (`shared_preferences` or equivalent)
- [ ] Windows local/UNC workflow unchanged (regression spot-check)
- [ ] Docs updated: phase status, deployment notes for HTTPS when resolved

---

## References

| File | Role |
|---|---|
| `client/ttsplayer/lib/services/media_access/` | Resolver + providers (M3.5) |
| `client/ttsplayer/lib/services/catalog_service.dart` | HTTP fetch integration point |
| `client/ttsplayer/lib/services/playback_service.dart` | Already wired to resolver |
| `backend/Caddyfile` | TNAS reference HTTP provider |
| `docs/deployment/tnas-caddy-deploy-checklist.md` | Reference provider validation |
