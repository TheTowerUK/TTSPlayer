# M7 Phase 7.7 — Production Hardening Closure Report

**Status:** Complete with explicit deferrals
**Date:** 2026-09-09
**Branch:** `m7-development`
**Planning baseline:** `7ed95c1 docs(m7.7): define production hardening plan`
**Implementation commits:** `739748a`, `e250f24`, `1fc1d97`

→ [Phase 7.7 plan](./m7-phase-7.7-production-hardening-plan.md) · [M7 plan](./m7-plan.md) · [ADR-030](../architecture/decisions/ADR-030-windows-provider-credential-storage.md) · [v0.8.0-dev](../release/v0.8.0-dev.md)

---

## Objective

Make the existing Open Library books enrichment slice private, explicitly enabled, safely diagnosable, resilient, and operationally bounded without changing local authority, matching, ranking, metadata/artwork precedence, catalogue schema, or ordinary local-media operation.

## Implementation summary

- Added additive, backward-compatible `metadataProviders` settings with default-off master/provider gates and independent retain-on-disable defaults.
- Replaced the development gate with a production lifecycle boundary. Enabling performs no request or background work; disabling prevents new work and invalidates stale completion.
- Added aggregate-only enrichment diagnostics through the existing snapshot, screen, and export architecture.
- Added a bounded in-memory coordinator around production Open Library metadata API operations: 32 pending, one active per provider, two globally, one-second spacing, typed transient retries, 2s/4s backoff, and capped `Retry-After`.
- Recorded successful-refresh telemetry only after accepted enrichment persistence.
- Selected Windows Credential Manager as the Proposed future credential-storage target; no secure-store implementation or credentialed provider was added.

## Sub-phase completion

| Sub-phase | Outcome | Evidence | Status |
|---|---|---|---|
| 7.7.1 | Production-readiness audit and locked plan | `7ed95c1` | Complete |
| 7.7.2 | Privacy, explicit opt-in, lifecycle and retention boundary | `739748a` | Complete |
| 7.7.3 | Aggregate-only diagnostics | `e250f24` | Complete |
| 7.7.4 | Metadata API resilience and operational coordination | `1fc1d97` | Complete |
| 7.7.5 | Credential decision and reconciliation | ADR-030 and this report | Complete with deferrals below |

## Requirement reconciliation

### 7.7.2 — Privacy, opt-in and lifecycle

| Requirement | Implementation evidence | Test evidence | Status | Disposition |
|---|---|---|---|---|
| External metadata default-off | `MetadataProvidersSettings.externalMetadataEnabled = false` | `metadata_provider_settings_test`, `metadata_provider_lifecycle_test` | SATISFIED | Closed |
| Explicit provider enablement | Master gate plus `enabledProviderIds`; Open Library needs both | Lifecycle truth-table tests | SATISFIED | Closed |
| Privacy disclosure | Settings disclosure lists transmitted and prohibited fields | Disclosure widget test | SATISFIED | Closed |
| No path/filename transmission | Typed ISBN/search requests; filename stem remains local evaluator input | Open Library request-isolation tests | SATISFIED | Closed |
| Retain on disable | Metadata and artwork policies default to `retain`; cached presentation stays readable | Lifecycle and artwork retention tests | SATISFIED | Closed |
| No request on enable | Settings mutation has no provider side effect | Zero-call enable test | SATISFIED | Closed |
| No background enrichment | Calls remain behind explicit matching/download actions | Ordinary-path provider-spy and isolation tests | SATISFIED | Closed |
| In-flight invalidation | Lifecycle generation guards matching, refresh and artwork persistence | Delayed metadata/artwork disable tests | SATISFIED | Closed |
| Backward-compatible recovery | Missing/invalid group recovers disabled retain defaults | Migration, invalid-group and round-trip tests | SATISFIED | Closed |
| Explicit deletion | Disable never deletes; no combined disable/delete action exists | Retention tests | DEFERRED | A future delete UI remains a separate confirmed feature; not required for retain-default release |

### 7.7.3 — Diagnostics

| Requirement | Implementation evidence | Test evidence | Status | Disposition |
|---|---|---|---|---|
| Aggregate-only diagnostics | Immutable `MetadataEnrichmentDiagnostics` projection | Service/screen/export tests | SATISFIED | Closed |
| Provider IDs | Sorted stable enabled IDs | Aggregation/export tests | SATISFIED | Closed |
| Credential boolean | Open Library reports false; no secret-shaped value | Snapshot/export tests | SATISFIED | Closed |
| Persisted state counts | One pass over in-memory records by match state | Populated aggregation test | SATISFIED | Closed |
| Pending/in-flight counts | Live coordinator counters | Live telemetry test | SATISFIED | Closed in 7.7.4 |
| Last successful refresh | Coordinator timestamp from accepted persistence boundary | Persistence-boundary test | SATISFIED | Closed in 7.7.4 |
| Last safe error | Bounded provider or persisted enrichment category | Coordinator/diagnostics tests | SATISFIED | Closed |
| Artwork metrics | Indexed entry count and bytes; no content traversal | Artwork repository/diagnostics tests | SATISFIED | Closed |
| Export safety | Existing central formatter renders allow-listed aggregates | Export canary test | SATISFIED | Closed |
| Sensitive fields absent | No titles, authors, ISBNs, paths, IDs, URLs, headers, payloads or raw errors | UI/export prohibited-canary tests | SATISFIED | Closed |
| Synthetic timing observations | Architecture is one in-memory record pass plus indexed cache totals | Full regression; no flaky wall-clock gate | DEFERRED | Informational benchmark moves to Phase 7.8 runtime evidence if useful; algorithmic no-walk rule is enforced |

### 7.7.4 — Resilience and operations

| Requirement | Implementation evidence | Test evidence | Status | Disposition |
|---|---|---|---|---|
| Bounded queue | `maxPendingOperations = 32` | 32/33 boundary test | SATISFIED | Closed |
| Safe queue-full outcome | Typed `providerUnavailable`; no silent drop | Overflow test | SATISFIED | Closed |
| Concurrency limits | Active-provider set plus global counter | One/provider and two/global tests | SATISFIED | Closed |
| Same-provider spacing | Last-start clock with one-second minimum | Fake-clock spacing test | SATISFIED | Closed |
| Retry eligibility | Timeout/network/provider-unavailable/rate-limit only | Category matrix tests | SATISFIED | Closed |
| 2s/4s backoff | Maximum three attempts | Fake-delay sequence tests | SATISFIED | Closed |
| Bounded `Retry-After` | Positive values through five minutes honoured; larger values fail | Three/six-minute tests | SATISFIED | Closed |
| Cancellation | Queued removal and cancellable throttle/backoff signal | Queued/backoff cancellation tests | SATISFIED | Closed |
| Provider disablement | Lifecycle wakes waits, rejects pending, invalidates results | Disable race tests | SATISFIED | Closed |
| No queue persistence | Queue and telemetry are process memory only | Fresh-coordinator restart test | SATISFIED | Closed |
| Safe malformed/error handling | Typed bounded categories; raw exceptions collapse to unknown | Provider parsing and diagnostics redaction tests | SATISFIED | Closed |
| Artwork failure isolation | Existing text/cache preservation and late-write guards retained | Artwork download/cache tests | SATISFIED | Closed |
| Automatic artwork retry | Artwork retains a single bounded attempt rather than using the metadata API coordinator | Artwork failure tests | DEFERRED | The approved production seam wrapped Open Library metadata calls only; artwork retry requires a separate explicit policy review |
| Ambiguity safety | Candidate evaluation still requires confirmation | Matching/candidate-selection tests | SATISFIED | Closed |
| Genuine diagnostics state | Coordinator supplies counts/timestamp/error category | Live diagnostics tests | SATISFIED | Closed |
| Core local-media isolation | No provider call is attached to catalogue, scanner, search, reader or playback | Focused and full regression suites | SATISFIED | Closed |

No required release row is `NOT SATISFIED`. The deferred items do not weaken default-off, explicit-operation, retention, local-authority, or failure-isolation guarantees and require separate authorization before implementation.

## Final privacy and opt-in contract

Open Library is unavailable unless the master switch and its provider switch are enabled. Enabling initiates no operation. Explicit requests may transmit normalized ISBN, normalized title, author and optional year, plus ordinary HTTPS connection metadata; local paths, directory names, filenames, basenames, file stems and catalogue structure are prohibited. Disablement stops new work and defaults to retaining accepted metadata and validated artwork for offline presentation.

## Final diagnostics contract

Diagnostics expose provider enablement, a safe configured boolean, persisted match-state counts, pending/in-flight counts, accepted-refresh timestamp, bounded last error, and indexed artwork totals. Capture does not perform provider work, persistence, cache content reads, or filesystem walks. UI and export contain no request content, local identifiers, raw provider data, secrets, URLs, stack traces, or raw exceptions.

## Final resilience and operational contract

| Control | Final value |
|---|---|
| Metadata API concurrency | Maximum 1/provider and 2 globally |
| Pending metadata API queue | Maximum 32; excess rejected safely |
| Same-provider start spacing | At least 1 second |
| Attempts | Initial plus at most 2 eligible retries |
| Ordinary retry delays | 2 seconds, then 4 seconds; below the 30-second planning ceiling |
| `Retry-After` | Honour positive values through 5 minutes; larger/invalid values do not auto-wait |
| Request timeout | Existing 15 seconds |
| Cancellation | Queue removal and cancellable waits; lifecycle generation prevents stale acceptance |
| Persistence | No operation queue or operational telemetry persistence |
| Trigger | Explicit user operations only; no automatic/background work |

Transport taxonomy groups network/DNS/TLS client failures as `networkUnavailable`; it cannot selectively suppress TLS retries without a new failure category. All such retries remain bounded to two and the 15-second request timeout remains unchanged.

## Credential-security decision

[ADR-030](../architecture/decisions/ADR-030-windows-provider-credential-storage.md) is **Proposed** and names Windows Credential Manager as the preferred future target behind a provider-neutral interface. Acceptance is gated on package/native review, Windows packaging, rotation/deletion behavior, integration tests and leak audit. Credentialed persistent configuration remains unsupported. Open Library requires no credential and is unaffected.

## Validation evidence

- Phase 7.7.4 deterministic coordinator tests: 14 passed.
- Phase 7.7.4 focused privacy/diagnostics/provider/persistence/artwork/catalogue/scanner/search-detail regression: 280 passed, 1 skipped, 0 failed.
- Final production-code baseline after Phase 7.7.4: 1,882 passed, 21 skipped, 0 failed.
- Changed-file analysis for Phase 7.7.4: no issues.
- Phase 7.7.5 is documentation-only; source/history reconciliation and `git diff --check` are the validation gate.

## Known limitations and explicit deferrals

- No credential store exists; persistent credentialed providers remain unsupported.
- ADR-030 remains Proposed until implementation and packaging evidence exists.
- Artwork retrieval retains existing single-attempt timeout and cache-preserving failure behavior; automatic artwork retry needs separate approval.
- Diagnostics performance timing and large-index projection timing remain informational Phase 7.8 runtime observations, not flaky CI gates.
- Explicit provider-data deletion UI is not implemented; disablement is retain-only by default and never silently deletes.
- Current HTTP client cancellation guarantees state/persistence cancellation immediately, while the underlying request resource remains bounded by its timeout.
- No desktop-to-NAS credential transfer or NAS secret-store design exists.

## Scope audit

Phase 7.7 introduced no ISBNdb, additional metadata/video/comic provider, backend bulk enrichment, `enrichment.json`, NAS credential storage, background enrichment, catalogue-load/rescan enrichment, provider fields in `catalog.json`, search-ranking changes, metadata/artwork precedence changes, new media kinds, or generic task scheduler.

## Phase 7.8 handoff

1. Run the approved Windows provider-disabled and fake-provider runtime matrix.
2. Validate explicit enable/disable, queued cancellation, retry/backoff status, offline retained presentation, malformed/429/5xx behavior, and restart abandonment without live provider dependencies.
3. Confirm diagnostics screen/export counters and redaction during controlled fake-provider operations.
4. Observe diagnostics and local projection cost on representative large synthetic state if the harness supports reliable measurements.
5. Exercise Windows release build/packaging and ordinary browse/search/play/read workflows.
6. Reconcile v0.8.0 release notes, application version/build metadata, M7 roadmap closure, tag/readiness, and remaining ADR status.
7. Do not implement credential storage, another provider, artwork retry, backend enrichment, or NAS secrets without separate scope approval.

## Closure recommendation

Close Phase 7.7 with the explicit deferrals above. Its production requirement is an explicit, default-off, credential-free Open Library workflow with safe diagnostics and bounded metadata operations; that boundary is implemented and regression-clean. Phase 7.8 owns final Windows runtime and release readiness, not further provider expansion.
