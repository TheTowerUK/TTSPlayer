# M7 Phase 7.8 — Windows validation and release ledger

Prepared 3 November 2026. Status: IN PROGRESS. This is evidence reconciliation, not a release or milestone closure.

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

Historical test evidence is not a guarantee of every final Windows UI scenario. The 21 baseline skips and one matching-harness skip are retained, not marked passed. Unit coverage for coordinator retry, spacing, bounds, cancellation, lifecycle, parser and diagnostics is already green; this package adds HTTP integration rather than rerunning all those tests.

## New automated local-server matrix — pending execution

File: client/ttsplayer/test/phase_78_provider_windows_runtime_test.dart. Windows-only and PHASE_78_RUNTIME=1; ordinary test runs skip it. Binds a temporary IPv4 loopback port. Uses production HTTP transport, Open Library response adapter, coordinated provider and lifecycle with mocked SharedPreferences and synthetic data. No public API, real catalogue, media or production settings are read or changed.

| ID | New integration check | Status |
|---|---|---|
| P78-01 | Disabled request blocked; enabling sends no request; explicit search uses local HTTP | PENDING |
| P78-02 | HTTP 500 maps to bounded failure with three attempts and 2s/4s delay policy | PENDING |
| P78-03 | HTTP 429 Retry-After policy followed before success | PENDING |
| P78-04 | Malformed JSON and HTTP 403 are not retried | PENDING |
| P78-05 | Queue cancellation while an actual HTTP request is held; no second request | PENDING |
| P78-06 | Disable during held ISBN HTTP request blocks late persistence and queued work | PENDING |
| P78-07 | Cancellation interrupts a deliberately held retry backoff | PENDING |
| P78-08 | Accepted ISBN persistence survives disable/repository reload; fresh coordinator has no queue/telemetry | PENDING |
| P78-09 | Live pending/in-flight diagnostic counters and export redaction; export sends no HTTP | PENDING |

Retry delays use injected clock/wait controls; this validates policy values without waiting through wall-clock delays. Minimum provider spacing is zero only in this isolated HTTP suite; its actual one-second policy is covered in the existing coordinator tests. Fresh-coordinator reconstruction is not an OS process-kill test. The synthetic diagnostics harness does not prove the app's clipboard/plugin or production composition-root UI wiring. Existing manual and widget checks provide separate evidence. No benchmark/large-index timing gate is added.

This newly written suite has NOT been compiled or executed in the preparation environment (Dart/Flutter unavailable). Run focused analysis and all nine scenarios on Windows; any failure is a validation issue to investigate, never permission to weaken assertions or change production policy.

## Remaining manual checks

### A. Artwork download and retained cache

Use one disposable/test book linked to a correct candidate that actually advertises a cover. Paddy's Cover unavailable and zero cache entries demonstrated safe fallback, not successful download. Enable master/provider, use the existing explicit Download cover action, and verify success. Local sidecar artwork may take precedence, so inspect the enrichment section as well as the card.

Check Diagnostics: artwork cache entries and indexed bytes should increase above zero if the downloaded cover is newly cached. Disable External metadata, close all instances, reopen one instance, and confirm the cached cover and indexed cache totals remain. This proves provider-disabled retained presentation, not physical network disconnection. Do not disconnect the NAS or remote session. Record PASS/FAIL/NOT AVAILABLE with the actual outcome. A provider item without a cover cannot satisfy the successful-download gate.

### B. Application Copy diagnostics

Use the built application's existing Copy diagnostics control. Paste into a local text editor. Confirm the Metadata Enrichment section agrees with the screen (master off, retained record count) and excludes book titles, authors, ISBNs, filenames, paths, provider record IDs, request URLs, headers and raw responses. Other diagnostic sections have their own contracts; do not assume all counts apply to the entire report. Record clipboard success or exact error; no need to publish the whole export.

### C. Controlled status and restart coverage

P78-02/03/05/06/07/09 test service integration under controlled failure. They do not verify user-visible retry/cancellation status in the running application. Before closure, reconcile this with the Phase 7.7 handoff: provide an app/harness UI run if controls expose these states, or explicitly record the scope adjustment and acceptance of deterministic service integration plus existing widget evidence. Do not silently mark these UI scenarios passed.

Restart queue abandonment requires controlled work pending at process exit if claimed as a full runtime result; P78-08 only checks fresh object state. Metadata persistence across a real app restart is separately manually passed. Any remaining process/UI gap must be resolved or explicitly dispositioned before closure.

## Release gates after validation

1. Attach Windows analysis/matrix results and manual artwork/export outcomes to this ledger. Resolve or explicitly disposition remaining UI/process gaps, warnings and skipped coverage. Leave optional timings informational.
2. Reconcile ADR-028's actual acceptance gate and decision; do not auto-accept on the basis of tests. ADR-029 remains Accepted. ADR-030 stays Proposed; credential storage remains deferred.
3. Prepare final v0.8.0 release notes, M7 closure report and version/build update. Keep pubspec unchanged in this validation package.
4. Build versioned Windows release; smoke-check its visible version and retained user state. Package the complete Release directory (exe, DLLs and data), never the exe alone. Verify a launch from the packaged/extracted directory.
5. Review all local commits; preserve the 16 existing M7 commits. Refresh/reconcile remote state and select the established release branch/tag workflow before publication. This package runs no remote Git operations.
6. Update Development Dashboard: current remains verified v0.7.0, next v0.8.0, phase Validation. Close the dated M7 release milestone only after acceptance/publication and build evidence exist. No live dashboard has been edited by this package.

## Explicit deferrals retained

No new providers, credential vault, NAS secrets, background/bulk enrichment, provider-data deletion UI, artwork retry policy, mobile release or multi-device enrichment sync. Filename/basename/stem transmission remains prohibited. The roadmap corrections align old proposals with the implemented Phase 7.7 boundary; they do not change application code.
