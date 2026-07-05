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

Do **not** add “one more improvement” to M3.5. New work — even small enhancements — is **Phase 4** or **backlog** (e.g. [artwork discovery](./backlog-artwork-discovery-improvements.md)).

---

## Objective

**Network Catalogue & Provider Configuration**

| Milestone | Question | Answer |
|---|---|---|
| **M3.5** | Can TTSPlayer access media through a provider-neutral abstraction? | **Yes** |
| **Phase 4** | How do users configure and use multiple providers seamlessly? | *In progress* |

The focus shifts from **proving the architecture** to **expanding capability**.

---

## Development cadence (carry forward from M3.5)

Use the same discipline that made M3.5 successful:

1. **Define the architecture first** — document before code where behaviour crosses layers
2. **Build in small, testable sub-phases** — one responsibility per phase; clear definition of done
3. **Validate on real hardware** where appropriate (TNAS reference provider)
4. **Separate observations from release blockers** — backlog items do not fail a sub-phase
5. **Close each sub-phase** before piling on the next capability

Phase 4 starts from a stable foundation — no unresolved design questions from M3.5.

---

## Sub-phases

Implement in order. Each sub-phase has a **single responsibility** and its own definition of done.

| Sub-phase | Focus | Status |
|---|---|---|
| **4.1** | HTTP catalogue provider (`CatalogService.loadFromUrl()`) | ✅ **Complete** — not wired to startup |
| **4.2** | Media provider configuration model | ✅ **Complete** — not wired to startup selection |
| **4.3** | Settings UI | ⛔ Not started |
| **4.4** | Provider selection & fallback | ⛔ Not started |
| **4.5** | HTTPS/TLS refinement and production validation | ⛔ Not started |

Wire sub-phases in **separate commits** where possible — same rollback discipline as M3.5 Phase 3a / 3b.

---

### Phase 4.1 — HTTP catalogue provider — complete

**Status:** Complete — HTTP catalogue loading exists; **not wired into startup or settings**.

**Implementation discipline:** `loadFromUrl()` is an explicit capability, not a replacement for local loading. The app behaves exactly as before unless `loadFromUrl()` is called (e.g. manual URL entry on dashboard).

**Scope:** Add HTTP catalogue loading capability. Local catalogue startup remains the default.

**Out of scope:** Settings UI (4.3), provider selection / fallback (4.4), global resolver changes, changing default startup to HTTP.

**Rules:**

- Preserve local catalogue startup as default
- Fail gracefully if HTTP catalogue is unavailable — retain last-good catalogue; dismissible banner only
- Explicit fetch timeout (15s recommended)

**Definition of done:**

- [x] `CatalogService.loadFromUrl()` with bounded timeout (15s default)
- [x] Success path: valid JSON loads catalogue
- [x] Failure paths: invalid JSON, non-200, timeout, network — previous catalogue preserved
- [x] Unit tests for 200, invalid JSON, HTTP error, timeout, network failure
- [x] No settings UI; no global provider selection changes; `loadOnStartup` unchanged
- [x] `flutter analyze` clean; tests pass

---

### Phase 4.2 — Media provider configuration model — complete

**Status:** Complete — model and persistence exist; **`load()` not called at startup**; no settings UI.

**Scope:** Persisted `MediaProviderConfig` — local and HTTP catalogue provider definitions plus `MediaAccessConfig` for the resolver.

**Out of scope:** Settings UI (4.3), fallback ordering (4.4), startup catalogue selection from saved config.

**Definition of done:**

- [x] Configuration model with `fromJson` / `toJson` and validation
- [x] Defaults match current behaviour (`Y:\Media`, UNC, `/volume1/Media`)
- [x] `MediaLocationResolver` reads `mediaAccess` from `MediaProviderConfigService` (defaults until `load()` is wired)
- [x] Unit tests for validation, JSON round-trip, load/save, invalid fallback
- [x] No settings screen; `CatalogService.loadOnStartup` unchanged

---

### Phase 4.3 — Settings UI

**Scope:** Minimal UI to edit provider configuration — media roots, HTTP catalogue URL, HTTP media base URL, access mode.

**Out of scope:** Provider fallback ordering (4.4), automatic discovery.

**Definition of done:**

- [ ] User can view and edit provider settings
- [ ] Changes persist across app restart
- [ ] Invalid URLs show inline validation; do not corrupt saved config
- [ ] Desktop-first; layout usable on constrained windows
- [ ] Existing local catalogue workflow still reachable without HTTP config

---

### Phase 4.4 — Provider selection & fallback

**Scope:** When multiple providers could serve a path, try user preference order; surface unresolved state with reason.

**Out of scope:** TLS (4.5), catalogue schema changes.

**Definition of done:**

- [ ] Documented preference order (e.g. local → HTTP, or user-configured)
- [ ] Resolver attempts fallback when primary provider returns unresolved
- [ ] Unit tests for preference matrix (Windows local + HTTP configured, non-Windows HTTP required)
- [ ] Playback and artwork use same resolver config — no duplicated logic

---

### Phase 4.5 — HTTPS/TLS refinement and production validation

**Scope:** Resolve TNAS `:8443` `tls internal` Windows handshake issue; validate HTTPS catalogue and media; update deployment docs.

**Out of scope:** New provider types.

**Definition of done:**

- [ ] HTTPS smoke tests pass on TNAS (`/catalog.json`, `/media/`, Range 206)
- [ ] Documented trust/cert workflow for Windows and mobile
- [ ] [Phase status](../deployment/m35-phase-status.md) updated with HTTPS results
- [ ] Optional checkpoint tag: `m35-serving-layer` or Phase 4 HTTPS note

---

## Architecture (unchanged from M3.5)

```
Catalogue source (local file or HTTP URL)
    ↓
CatalogService                    ← 4.1
    ↓
Catalogue tree (filesystem paths unchanged)
    ↓
MediaAccessConfig                 ← 4.2, 4.3
    ↓
MediaLocationResolver             ← 4.4 (fallback)
    ↓
Playback / Artwork
```

---

## Phase 4 overall definition of done

All sub-phases 4.1–4.5 complete, plus:

- [ ] Windows local/UNC workflow unchanged (regression spot-check)
- [ ] HTTP catalogue + HTTP media path validated on home network
- [ ] Docs and phase status current

---

## Out of scope (Phase 4)

| Item | Deferred to |
|---|---|
| Artwork sidecar matching | [Backlog — Phase 4.x](./backlog-artwork-discovery-improvements.md) |
| Scanner changes | Later milestone |
| SQLite / catalogue schema changes | Not required |
| Automatic provider discovery | Future enhancement |

---

## References

| File | Role |
|---|---|
| `client/ttsplayer/lib/services/media_access/` | Resolver + providers (M3.5) |
| `client/ttsplayer/lib/services/catalog_service.dart` | 4.1 HTTP fetch |
| `client/ttsplayer/lib/services/playback_service.dart` | Already wired to resolver |
| `backend/Caddyfile` | TNAS reference HTTP provider |
| `docs/deployment/tnas-caddy-deploy-checklist.md` | Reference provider validation |
