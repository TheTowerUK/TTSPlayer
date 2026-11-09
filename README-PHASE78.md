# TTSPlayer Phase 7.8 validation package

Prepared 3 November 2026. Contains a NEW opt-in Windows local-server test, a runner, an evidence ledger, and two documentation corrections. No production Dart code, dependencies, version or user data changes. M7 remains open.

## Apply

Inspect local changes first:

```powershell
git -C D:\AppDev\TTSPlayer status --short --branch
git -C D:\AppDev\TTSPlayer diff --stat
```

Extract this ZIP into D:\AppDev\TTSPlayer, merging folders. Copy the supplied files; do not move/delete existing project folders. The docs overlay is based on the documentation ZIP you supplied. Preserve/reconcile any newer changes to those two docs before replacing them. Existing .claude/, lib.zip and test.zip remain untouched and untracked.

## Run the new matrix

Close TTSPlayer normally if convenient; the tests use mock settings and no real media. From PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\AppDev\TTSPlayer\tools\validate-ttsplayer-phase78.ps1
```

ExecutionPolicy Bypass is scoped to that child PowerShell process; no machine/user policy is changed. The script formats only the new test, analyzes that test, then runs the nine scenarios. It restores the previous PHASE_78_RUNTIME value and PATH and records output under D:\TTSPlayer-validation\<timestamp>. It does not run pub get, change dependencies, build, commit or push. A local test server listens on 127.0.0.1 on a temporary port; do not open firewall ports externally.

This suite has not yet been compiled/executed here because Dart/Flutter is unavailable. Please share analysis output and the runtime summary (or failure log). Expected success: nine passed, zero failed and no skip when run with this script on Windows. A skipped-only run is NOT a pass.

Do not rerun the full 1,882-test baseline just for these documentation/test additions unless a failure or subsequent production change justifies it.

## Manual evidence

After automated results, follow Artwork and Copy diagnostics checks in docs/roadmap/m7-phase-7.8-validation.md. The ledger clearly separates completed, pending and potentially dispositionable UI/process checks. Do not mark M7 closed yet.

## Review / optional local checkpoint after checks pass

```powershell
git -C D:\AppDev\TTSPlayer diff --check
git -C D:\AppDev\TTSPlayer diff -- docs/roadmap/m7-plan.md docs/architecture/metadata-enrichment.md
git -C D:\AppDev\TTSPlayer add -- client/ttsplayer/test/phase_78_provider_windows_runtime_test.dart tools/validate-ttsplayer-phase78.ps1 docs/roadmap/m7-phase-7.8-validation.md docs/roadmap/m7-plan.md docs/architecture/metadata-enrichment.md README-PHASE78.md
git -C D:\AppDev\TTSPlayer diff --cached --check
git -C D:\AppDev\TTSPlayer diff --cached --stat
git -C D:\AppDev\TTSPlayer commit -m "test(m7.8): add local HTTP runtime validation and reconcile release evidence"
```

Review cached files for unrelated staged changes before committing. No remote Git operation is requested here. The source baseline and new-file checksums are in PACKAGE-SHA256.txt; it is packaging metadata, not required in the commit.
