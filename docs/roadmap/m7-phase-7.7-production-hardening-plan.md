# M7 Phase 7.7 — Metadata Enrichment Production Hardening

**Status:** Complete (2026-09-09) — [closure report](./m7-phase-7.7-closure-report.md)

**Branch:** `m7-development`

**Baseline:** `22a43dd docs(m7.6): close UX and workflow refinements`
**Implementation:** `739748a`, `e250f24`, `1fc1d97`

→ [M7 plan](./m7-plan.md) · [Metadata enrichment architecture](../architecture/metadata-enrichment.md) · [ADR-028](../architecture/decisions/ADR-028-external-metadata-enrichment-boundary.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

---

## 1. Objective

Make the existing books metadata-enrichment slice safe, private, observable, resilient, and operationally bounded for production use. Phase 7.7 activates no new provider or media kind and does not change matching, metadata precedence, artwork precedence, catalogue authority, or search ranking.

Required outcomes:

1. Privacy and explicit provider opt-in.
2. A credential-security architecture decision.
3. Safe read-only enrichment diagnostics.
4. Resilience and failure-policy hardening.
5. Conservative, measurable operational limits.

Phase 7.8 retains the final Windows runtime matrix, fake-provider runtime validation, release/version work, and M7 closure.

## 2. Readiness audit

| Outcome | Existing evidence | Gap | Classification |
|---|---|---|---|
| Privacy and opt-in | Development feature gate defaults off; typed Open Library request models transmit ISBN/title/author/year; no ordinary read-path provider calls | No persisted `metadataProviders` settings group, disclosure/consent UI, production provider lifecycle, or disable-retention action | NOT IMPLEMENTED |
| Credential security | Credentials are absent from settings, enrichment records, provider adapter, logs, and diagnostics; Open Library needs no key | No secure-store abstraction or approved Windows storage decision | ARCHITECTURE DECISION REQUIRED |
| Enrichment diagnostics | M4 diagnostics has one read-only aggregator, immutable DTOs, centralized formatter/redaction, screen/export tests; enrichment repository exposes counts; artwork index exposes entry count | No enrichment DTO/section/wiring; no operational queue snapshot; no safe cache-byte aggregate | PARTIALLY SATISFIED |
| Resilience | Typed provider/transport failures; 15-second timeout; cancellation token; safe parsing; prior enrichment/cache retained on failures; catalogue pruning isolated; ambiguous matches require confirmation | No production gate, retry/throttle coordinator, bounded queue, global operational state, disabled-provider enforcement, or restart policy tests | PARTIALLY SATISFIED |
| Performance/operations | Search is local/deterministic; artwork validation caps one object at 8 MiB; cache defaults to 256 MiB with eviction; request limits are typed; repository exposes immutable records/counts | No provider concurrency/spacing/retry/queue budgets or diagnostics cost benchmarks | PARTIALLY SATISFIED |

### Existing implementation boundaries

- `ApplicationSettings` is a versioned, partially recovering JSON envelope, but has no metadata-provider group.
- `MetadataEnrichmentFeatureConfig.defaults` hides unfinished operational UI; `main.dart` supplies no production matching coordinator.
- `OpenLibraryBookMetadataProvider` and `HttpMetadataHttpTransport` already provide typed results, safe categories, injected cancellation, and timeouts.
- `BookMetadataRefreshService` and matching/artwork coordinators are explicit-operation services, not background workers.
- `MetadataEnrichmentRepository` persists normalized records locally, prunes by catalogue identity, and excludes credentials/raw payloads.
- `MetadataArtworkCacheRepository` maintains an indexed, quota-bound disk cache; the resolver retains local-first presentation.
- `SearchService` and item detail consume persisted projections only; neither may become a provider trigger.
- Scanner/catalogue load and replacement do not call providers and must remain independent.

## 3. Locked privacy and opt-in contract

### Settings shape

Add an optional `metadataProviders` group to `ApplicationSettings`:

| Field | Type/default | Contract |
|---|---|---|
| `externalMetadataEnabled` | `bool`, `false` | Master provider-operation gate |
| `enabledProviderIds` | set/list of stable IDs, empty | Per-provider operation gate; unknown IDs retained or ignored safely during parsing, never activated |
| `metadataRetentionOnDisable` | enum, `retain` | Retain accepted local enrichment or delete it after explicit confirmation |
| `artworkRetentionOnDisable` | enum, `retain` | Separate policy because artwork has independent disk cost and fallback behaviour |

The group is additive and optional. Existing `ttsplayer_settings_v1` envelopes without it recover to disabled defaults; no credential field is permitted. A settings-version bump is unnecessary if parsing remains additive and old readers ignore the new group, but this must be locked by round-trip and missing/invalid-group tests.

### Enable contract

- Open Library requires both the master opt-in and `open_library` in `enabledProviderIds` before any production request.
- First enable presents a disclosure and requires affirmative confirmation; merely opening Settings makes no request.
- Disclosure states that TTSPlayer sends normalized ISBN, title, author, and optional year to Open Library over HTTPS; the provider also receives the client IP and User-Agent as normal network metadata.
- TTSPlayer does not send full paths, directory names, catalogue trees, filenames, basenames, or locally derived filename stems. Filename-stem comparison remains local only.
- Enabling does not start a bulk/background refresh. Provider calls remain attached to explicit user actions.
- Declining or cancelling leaves settings unchanged and performs no provider call.

### Disable and retention contract

- Disable takes effect before any further request can begin and cancels/suppresses pending item operations.
- Default `retain` keeps accepted enrichment readable and searchable offline but disables refresh, matching, and download operations.
- `delete` requires separate confirmation and removes provider enrichment records. User-authored overrides must not be silently deleted; their treatment must follow the existing unlink/override model.
- Artwork retention is selected separately. Retain keeps validated local files; delete clears only provider artwork cache and references, never catalogue/local artwork.
- Disabling one provider affects only that provider's operations and provider-owned cached data.
- Re-enabling does not trigger work automatically.

### UI requirements

- Add a clearly labelled External metadata section to Settings.
- Show master state, provider state, disclosure, attribution/privacy link, and retention controls.
- Operational matching controls render only when the provider is enabled; accepted persisted presentation remains visible when disabled.
- Failure copy remains bounded and never displays raw exception text, URL queries, or local paths.

### Privacy tests

- Defaults and missing/invalid-group recovery are disabled.
- Settings round-trip contains no secret-shaped field.
- Enable requires disclosure confirmation and causes zero immediate requests.
- Every operation is blocked unless master and provider gates are enabled.
- Disable cancels/suppresses pending work and prevents later persistence from stale completion.
- Retain/delete behaviours cover enrichment and artwork independently.
- Provider requests contain only the approved Open Library fields.
- Catalogue load, rescan, search, detail render, and app restart cause zero provider calls.

## 4. Credential-security decision

### Threat model

Protect future provider API secrets at rest from casual filesystem inspection, copied settings/catalogues, diagnostics exports, and another local account. Do not claim protection from malware executing as the same user, a compromised process, administrator access, or secrets present briefly in process memory.

### Options

| Consideration | Windows Credential Manager | User-scoped DPAPI-backed blob |
|---|---|---|
| Platform fit | Native user credential vault; target-name based | Native cryptographic protection API; application owns blob storage |
| Flutter integration | FFI/plugin boundary; a maintained secure-storage plugin can abstract platforms | Custom FFI/plugin or package plus custom file/index lifecycle |
| At-rest scope | Current Windows user/logon credential set | Normally same user and computer unless roaming-profile behaviour applies |
| Packaging | Native dependency evaluation; current secure-storage package documents C++ ATL build requirement | Native API/FFI and application support-file permissions/lifecycle |
| Portability | Can sit behind a cross-platform interface | Windows-specific implementation and migration burden |
| Backup/restore | Vault/OS-account behaviour; not portable app data | Ciphertext is generally not useful after account/machine loss |
| Testing | Injectable store contract plus Windows integration test | Injectable cryptography/blob stores plus corruption, migration, and cleanup tests |
| Operational risk | Lower if a maintained, reviewed plugin is selected | Higher: TTSPlayer owns naming, files, atomicity, corruption, deletion, and migration |

### Recommendation

Phase 7.7.5 created [ADR-030](../architecture/decisions/ADR-030-windows-provider-credential-storage.md), which remains Proposed and prefers an OS credential-vault abstraction with Windows Credential Manager as the leading implementation target. A future implementation must evaluate its native/package boundary and Windows packaging requirements before the ADR can be accepted. Do not hand-roll raw DPAPI storage unless integration review fails and a separate native design is approved.

Implementation is deferred because the only approved production provider, Open Library, has no credential. Credentialed providers remain unsupported for persistent configuration. This decision does not block Open Library opt-in. The ADR must remain Proposed until an implementation, packaging test, delete/rotation behaviour, and diagnostics-leak audit exist.

Future NAS operation does not reuse desktop secrets automatically: NAS credentials require a separate server threat model and secret store. No secret is written to a catalogue or enrichment sidecar.

## 5. Safe enrichment diagnostics contract

### Ownership and derivation

- Extend the existing `RuntimeDiagnosticsSnapshot`; `DiagnosticsService` remains the only aggregator.
- Add an immutable `MetadataEnrichmentDiagnostics` DTO and one Settings diagnostics UI/export section.
- Derive repository state in one pass over in-memory records.
- Read cache entry count and total indexed bytes from the in-memory artwork index; never recursively scan the cache directory during capture.
- Read enabled provider IDs from settings and operation counters from an in-memory operational coordinator snapshot.
- No new diagnostics persistence. After restart, session-only operation fields may be unavailable until the first operation; persisted record/cache aggregates remain derivable.

### Allowed fields

- Section status (`complete`, `partial`, `unavailable`)
- Enabled provider IDs from an allow-listed/stable identifier set
- `credentialConfigured` boolean per provider; Open Library reports false/not-required
- Record counts by match state plus safe error-category counts
- Pending and in-flight operation counts
- Last successful refresh timestamp, if safely available
- Last safe error category
- Artwork-cache entry count and indexed byte total
- Retry/throttle state as counts/booleans, never request content

### Prohibited fields

Secrets, tokens, authorization/cookie headers, raw responses, titles, authors, ISBNs, item IDs, filenames, full paths, provider query strings/unsafe URLs, stack traces, and raw exception messages.

### Diagnostics tests

- DTO equality/copy/partial semantics and formatter ordering.
- Aggregation for empty, populated, corrupt/unavailable repository, disabled provider, and in-flight operation states.
- Export/screen use the same DTO and expose only allow-listed labels/counts.
- Secret/path/URL/query/raw-exception canaries absent from snapshot and export.
- Capture is read-only: no load, save, clear, reconcile, provider request, cache filesystem walk, or counter reset.

## 6. Resilience and failure contract

For every row, catalogue, scanner, search, reader, and playback remain available from local state and are never failed or delayed by the provider condition.

| Condition | User-visible outcome | Cache/persistence | Retry | Safe diagnostic category | Automatic retry |
|---|---|---|---|---|---|
| Offline / DNS | Non-blocking unavailable message; local presentation remains | Retain records/artwork | Eligible | `networkFailure` | Yes, bounded, only for an already explicit operation |
| TLS/handshake | Same bounded network message | Retain | Eligible after configuration/network change | `networkFailure` | No immediate loop |
| Authentication | Explain provider needs attention; disable its operations until corrected | Retain | After credential update | `authenticationFailure` | No |
| HTTP 429 | Show temporarily limited and retry timing when safe | Retain | Eligible after capped `Retry-After`/backoff | `rateLimited` | Yes, bounded |
| HTTP 5xx | Non-blocking provider unavailable | Retain | Eligible | `providerUnavailable` | Yes, bounded |
| Malformed/unsupported response | Generic incompatible-response message | Do not overwrite good data | Eligible after a later explicit action/version change | `parseFailure` | No |
| Provider schema drift | Graceful parse failure; local presentation | Retain | Eligible after adapter update | `parseFailure` | No |
| Artwork retrieval failure | Local artwork or placeholder; text enrichment retained | Retain prior valid artwork | Eligible | safe artwork failure category | Network/5xx/429 only, bounded |
| Ambiguous match | Candidate review; never auto-apply | No selected-provider persistence until confirmation | User may refine/retry | no error, ambiguous state | No |
| Cancelled refresh | Quiet cancelled state or bounded acknowledgement | No stale completion commit; retain prior data | Eligible | `cancelled` | No |
| Disabled provider | Matching/refresh/download controls unavailable | Apply chosen retention policy | Only after re-enable | disabled/not operational, not error | No |
| Stale cached data | Mark stale where current model supports it; continue local display | Retain until explicit refresh/delete | Eligible | stale state | No background retry in 7.7 |
| Restart mid-request | In-flight work is abandoned; no queue resurrection | Only atomic completed writes survive | User may explicitly retry | none or prior persisted category | No |
| Restart after success | Persisted normalized record/cache reloads offline | Retain | Normal explicit refresh | none | No |

Only transient network, 429, and 5xx failures from an already user-initiated operation may retry automatically. Auth, parse/schema, invalid request, ambiguous, disabled, and cancelled cases never auto-retry.

## 7. Proposed operational budgets

These are reviewable initial defaults and test targets, not service-level guarantees. Provider `Retry-After` and published policies may require stricter behaviour.

| Control | Proposed initial value | Strength and rationale | Test method |
|---|---|---|---|
| Concurrent requests | 1 per provider; 2 global maximum | Hard client limit; conservative for a personal desktop and prevents burst amplification | Fake transport records peak concurrency |
| Start spacing | At least 1 second per provider | Conservative default, configurable internally if provider policy is stricter | Injected clock asserts start times |
| Pending queue | 32 operations maximum | Safety cap, not a bulk-enrichment feature; excess explicit requests are rejected visibly | Boundary tests at 32/33 and cancellation frees capacity |
| Attempts | Initial attempt + 2 retries for transient categories only | Hard maximum avoids hidden retry loops | Scripted failure sequences assert call count/category |
| Backoff | 2 seconds, then 4 seconds; ordinary ceiling 30 seconds | Initial conservative policy; ceiling accommodates future tuning without long test waits | Injected scheduler/clock |
| `Retry-After` | Honour valid value, cap automatic wait at 5 minutes | Avoid hammering while preventing an invisible long-running job; beyond cap requires explicit retry | Header parsing and cap tests |
| Request timeout | 15 seconds | Existing adapter/transport default; retain unless runtime evidence requires change | Fake hanging transport and existing timeout tests |
| Cancellation | UI/state cancellation visible within 100 ms; stale completion never commits; network resource bounded by timeout | Hard state-safety target; current `http.Client` call is not guaranteed to abort mid-flight | Fake delayed transport plus generation/cancellation tests |
| Diagnostics capture | Target ≤50 ms for 10,000 records + 10,000 cache-index entries on reference test host | Informational regression budget; one in-memory pass, no disk walk | Synthetic benchmark, report distribution rather than flaky CI wall gate |
| Artwork measurement | O(index entries), zero content reads/stat walk | Hard algorithmic rule | Filesystem spy and large index fixture |
| Offline projection lookup | No network; target ≤100 ms to build presentation/search inputs for a 10,000-record synthetic catalogue | Network prohibition is hard; timing is informational | Provider-call spy plus existing search benchmark pattern |

No persistent distributed-job system, background scheduler, or automatic bulk refresh is introduced.

## 8. Sub-phase sequence

### 7.7.1 — Production-readiness audit and planning

**Objective:** Reconcile existing capabilities, lock contracts/budgets, and establish an implementation sequence.

**Scope:** This document and links from M7 roadmap, architecture, and release tracker.

**Files:** Planning documentation only.

**Tests:** Repository/source audit; `git diff --check`.

**Definition of Done:** Five outcomes classified; privacy, diagnostics, resilience, budgets, credentials, exclusions, and approval gates explicit.

**Exclusions:** All production code, packages, provider activation, diagnostics implementation.

**Dependencies:** Phase 7.6 closure.

### 7.7.2 — Privacy, explicit opt-in, and provider lifecycle

**Objective:** Replace the development-only operational gate with a persisted, default-off production opt-in and deterministic lifecycle.

**Scope:** Add settings model/repository migration, Settings UI disclosure, provider-operation gate, Open Library production composition, disable/cancel/retention behaviour.

**Expected components:** `application_settings.dart`, `settings_repository.dart`, Settings widgets, `main.dart`, feature/provider lifecycle configuration, matching/artwork coordinators.

**Tests:** Defaults/migration/round-trip, disclosure, zero-call enable, operation gating, disable race, retain/delete, restart, request-field privacy, ordinary-path isolation.

**Definition of Done:** Open Library can be explicitly enabled without credentials; default/decline/disable produces zero calls; disclosed fields match requests; cached presentation follows locked retention policy; no stale completion writes after disable.

**Exclusions:** Automatic/background refresh, new providers, credentials, ranking/precedence changes.

**Dependencies:** Approved 7.7.1 privacy contract.

### 7.7.3 — Safe enrichment diagnostics

**Objective:** Add one redacted, read-only enrichment section through existing diagnostics architecture.

**Scope:** DTO, aggregation, formatter, Settings diagnostics UI, repository/cache/operation safe getters.

**Expected components:** runtime diagnostics models, service, formatter, screen widgets, enrichment repository, artwork cache repository, provider lifecycle coordinator, composition root.

**Tests:** Model/service/widget/export/integration redaction, partial state, read-only non-mutation, indexed-size and cost tests.

**Definition of Done:** Required allow-listed aggregates appear consistently; prohibited data is absent; capture performs no writes/network/disk traversal; partial sources never break capture/export.

**Exclusions:** Logs upload, raw event history, persistent diagnostics database, secrets.

**Dependencies:** 7.7.2 settings/lifecycle state.

### 7.7.4 — Resilience, throttling, and operational hardening

**Objective:** Enforce the approved failure matrix and conservative operational limits around explicit provider work.

**Scope:** One bounded operation coordinator/queue, per-provider throttle, transient retry/backoff, cancellation/generation safety, restart abandonment, safe state exposed to diagnostics.

**Expected components:** New provider-operation coordinator/policy/clock abstractions, existing refresh/matching/artwork services, typed failure mapping, `main.dart`, focused tests.

**Tests:** Every failure row, concurrency/spacing/queue boundaries, retry categories/counts, `Retry-After`, timeout, cancellation race, restart, core-local isolation, synthetic performance observations.

**Definition of Done:** Budgets are enforced deterministically; only eligible transient failures retry; prior good data survives; disable/cancel prevents late commits; local catalogue/search/play/read paths remain unaffected.

**Exclusions:** Background scheduling, bulk enrichment, distributed jobs, new provider capabilities.

**Dependencies:** 7.7.2 gate and 7.7.3 diagnostic contract.

### 7.7.5 — Credential-security decision and Phase 7.7 reconciliation

**Objective:** Record the secure-storage direction and close Phase 7.7 without manufacturing a credential requirement.

**Scope:** Proposed credential-storage ADR, package/native feasibility and packaging evidence, privacy/diagnostics leak audit, focused/full tests, roadmap/architecture/release reconciliation.

**Expected components:** New ADR and documentation; production code only if separately approved after the ADR evaluation.

**Tests:** If no secure store is implemented, prove credentialed persistent configuration is absent/blocked. If separately approved, require contract, Windows integration, rotation/delete, corruption, packaging, and redaction tests.

**Definition of Done:** Decision and deferral/implementation status are explicit; Open Library release is not blocked; credentialed providers cannot persist insecurely; all 7.7 DoD evidence and 7.8 handoff are recorded.

**Exclusions:** ISBNdb, another provider, NAS secrets, backend enrichment, M7 release/version closure.

**Dependencies:** 7.7.2–7.7.4 complete.

**Completion:** Credential Manager selected as the Proposed future target; credential implementation remains deferred, Open Library remains credential-free, and the requirement-by-requirement result is recorded in the [Phase 7.7 closure report](./m7-phase-7.7-closure-report.md).

## 9. Cross-phase Definition of Done

- External metadata operations are default-off and require explicit provider opt-in.
- Open Library disclosure matches the exact request data; no local path/basename is transmitted.
- Existing accepted enrichment remains locally readable under the approved retain policy.
- Credentialed persistence is either OS-backed and separately evidenced or unavailable.
- Diagnostics are safe, aggregate-only, read-only, and resilient to partial sources.
- Failure/retry/cancellation behaviour matches the matrix and cannot fail core local media paths.
- Operational budgets are deterministic and tested without adding automatic enrichment.
- Catalogue schema, provider interfaces unless operationally necessary, matching scores, metadata/artwork precedence, and search weights remain stable.
- Phase 7.8 receives a documented Windows runtime/release-QA handoff.

## 10. Explicit exclusions

- ISBNdb or any additional provider
- Backend bulk enrichment or `--enrich`
- `enrichment.json` or another catalogue/sidecar contract
- Video, music, or comic provider enrichment
- Automatic/background enrichment and scan-time enrichment
- Search-ranking, matching-threshold, metadata-precedence, or artwork-precedence changes
- M7 version bump, tag, release build, final Windows matrix, or milestone closure

## 11. Decisions requiring approval before 7.7.2

1. Approve the minimal four-field `metadataProviders` settings contract.
2. Approve explicit Open Library opt-in with no request on enable.
3. Approve exact disclosure fields and the stricter prohibition on filenames/basenames.
4. Approve independent default-retain policies for enrichment and provider artwork.
5. Approve explicit operations only; no background refresh in Phase 7.7.
6. Accept credential storage as an ADR decision/deferment, not an Open Library prerequisite.
7. Approve the proposed operational defaults as implementation targets subject to 7.7.4 evidence.
