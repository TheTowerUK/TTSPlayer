# M7 Phase 7.8 — Windows validation and release ledger

Prepared 3 November 2026. Updated 8–9 November 2026 to record P78 matrix execution and P78-A/B/C dispositions. Status: IN PROGRESS. This is evidence reconciliation, not a release or milestone closure. M7 release closure remains pending.

Baseline: m7-development, ec403c17d2ef2c0fbbcc8a60fbf21a36fb740acd; last reported 16 commits ahead of locally recorded origin/m7-development. Tracked source clean on 2 November. No remote refresh/alignment has been verified in this package. Application remains 0.7.0+1 until release preparation.

## Evidence already obtained — do not repeat without a reason

| Gate | Evidence | Status |
|---|---|---|
| Windows tools | Flutter 3.44.8, Dart 3.12.2; Visual Studio/Windows SDK doctor checks passed | PASS, user output |
| Baseline suite | 1,882 passed / 21 skipped / zero failed, 27 October | PASS, user output |
| Release compilation | build/windows/x64/runner/Release/ttsplayer.exe produced | PASS, user output |
| Metadata matching harness | Phase 7.3.6: 30 passed / 1 skipped | PASS; duplicate-submission tap warning retained |
| Search/detail harness | Phase 7.5: 12 passed | PASS |
| Core browse/search/play/read | User reports video, music and book/comic workflows work | MANUAL PASS; exact per-format evidence not separately recorded |
| Live Open Library explicit confirmation | Details changed to Manually linked; diagnostics linked_manual=1 and accepted refresh timestamp | MANUAL PASS, 30 October |
| Retention after disable/restart | Provider text visible; master off; linked_manual=1 retained | MANUAL PASS, 30 October |
| Master/provider preference | Open Library selected but inactive when master disabled | MANUAL PASS |
| Missing-file notification | No longer reproduced after fresh launch; previously two processes existed | NOT REPRODUCED; cause unconfirmed, no code fix claimed |

Historical test evidence is not a guarantee of every final Windows UI scenario. The 21 baseline skips and one matching-harness skip are retained, not marked passed. Unit coverage for coordinator retry, spacing, bounds, cancellation, lifecycle, parser and diagnostics is already green; the Phase 7.8 HTTP integration suite is additional evidence, not a substitute for that baseline.

## Automated local-server matrix — executed

File: client/ttsplayer/test/phase_78_provider_windows_runtime_test.dart. Windows-only and PHASE_78_RUNTIME=1; ordinary test runs skip it. Binds a temporary IPv4 loopback port. Uses production HTTP transport, Open Library response adapter, coordinated provider and lifecycle with mocked SharedPreferences and synthetic data. No public API, real catalogue, media or production settings are read or changed.

Executed on Windows 8 November 2026: **9 passed, 0 failed**.

| ID | New integration check | Status |
|---|---|---|
| P78-01 | Disabled request blocked; enabling sends no request; explicit search uses local HTTP | PASS, 8 November 2026 |
| P78-02 | HTTP 500 maps to bounded failure with three attempts and 2s/4s delay policy | PASS, 8 November 2026 |
| P78-03 | HTTP 429 Retry-After policy followed before success | PASS, 8 November 2026 |
| P78-04 | Malformed JSON and HTTP 403 are not retried | PASS, 8 November 2026 |
| P78-05 | Queue cancellation while an actual HTTP request is held; no second request | PASS, 8 November 2026 |
| P78-06 | Disable during held ISBN HTTP request blocks late persistence and queued work | PASS, 8 November 2026 |
| P78-07 | Cancellation interrupts a deliberately held retry backoff | PASS, 8 November 2026 |
| P78-08 | Accepted ISBN persistence survives disable/repository reload; fresh coordinator has no queue/telemetry | PASS, 8 November 2026 |
| P78-09 | Live pending/in-flight diagnostic counters and export redaction; export sends no HTTP | PASS, 8 November 2026 |

Retry delays use injected clock/wait controls; this validates policy values without waiting through wall-clock delays. Minimum provider spacing is zero only in this isolated HTTP suite; its actual one-second policy is covered in the existing coordinator tests. Fresh-coordinator reconstruction is not an OS process-kill test (see P78-C). The synthetic diagnostics harness does not prove the app's clipboard/plugin or production composition-root UI wiring; P78-B covers Copy Diagnostics in the running application separately. No benchmark/large-index timing gate is added.

A passing service or snapshot test does not prove a user-visible Windows UI state. Those distinctions are recorded under P78-C.

## Manual checks

### A. Artwork download and retained cache — PASS

One successful explicit Download cover produced **one artwork cache entry, 18.2 KB**. After disabling External Metadata, closing TTSPlayer, and restarting, that downloaded artwork remained. This proves provider-disabled retained presentation, not physical network disconnection. NAS and remote session were not disconnected.

### B. Application Copy diagnostics — PASS

Copy Diagnostics from the running application pasted successfully into Notepad. The Metadata Enrichment information in that paste was confirmed correct against the Diagnostics screen. This does **not** claim a full sensitive-field audit of the entire report beyond the Metadata Enrichment confirmation actually performed. Automated export redaction remains covered by P78-09 and existing formatter tests, not by this manual paste check.

### C. Controlled status and restart coverage — ACCEPTED WITH LIMITATION

Reconciled against the Phase 7.7 handoff. No additional Windows runtime test is required for this gate. Distinct user-visible retry, queue and cancellation statuses are **not implemented** on Details; they are not silently marked passed.

| Claim | Disposition |
|---|---|
| Retry, cancellation and provider disabling | Validated by service integration (P78-02/03/05/06/07/09) plus existing coordinator tests. Implementation correctness: PASS. |
| Details loading and disabled/hidden controls | Existing widget tests cover the implemented busy indicator, disabled actions while loading, and section hidden when the provider gate is off. |
| Distinct Details retry / queue / cancellation status | Not a product surface. Not claimed as Windows UI acceptance. |
| Diagnostics pending/in-flight values | Snapshot-based (open or Refresh). P78-09 proves snapshot/export counters. Live Windows Diagnostics values during a held request were not tested. |
| P78-08 | Repository reload and fresh-coordinator reconstruction. Not termination of a Windows process with work pending. |
| Real Windows restart | Confirms retained metadata/artwork (including P78-A). Does not prove recovery of an in-memory operation queue; queues are process memory only and start empty. |

## Release gates after validation

1. P78-01–09, P78-A, P78-B and P78-C are recorded above. Remaining UI/process gaps for P78-C are explicitly dispositioned as accepted with limitation. Optional timings remain informational. Historical skips are unchanged.
2. ADR-028 is **Accepted** (9 November 2026) with the limitations recorded in that ADR and under P78-C. Do not treat tests as auto-acceptance of remaining release gates. ADR-029 remains Accepted. ADR-030 stays Proposed; credential storage remains deferred.
3. Prepare final v0.8.0 release notes, M7 closure report and version/build update. Keep pubspec unchanged until that release-preparation step. This documentation update does not bump the version.
4. Build versioned Windows release; smoke-check its visible version and retained user state. Package the complete Release directory (exe, DLLs and data), never the exe alone. Verify a launch from the packaged/extracted directory. A prior unversioned Release compilation remains recorded in the baseline table; it is not this versioned packaging gate.
5. Review all local commits; preserve the 16 existing M7 commits. Refresh/reconcile remote state and select the established release branch/tag workflow before publication. This package runs no remote Git operations. No new remote evidence is recorded here.
6. Update Development Dashboard: current remains verified v0.7.0, next v0.8.0, phase Validation. Close the dated M7 release milestone only after acceptance/publication and build evidence exist. No live dashboard has been edited by this package.

## Explicit deferrals retained

No new providers, credential vault, NAS secrets, background/bulk enrichment, provider-data deletion UI, artwork retry policy, mobile release or multi-device enrichment sync. Filename/basename/stem transmission remains prohibited. The roadmap corrections align old proposals with the implemented Phase 7.7 boundary; they do not change application code.
