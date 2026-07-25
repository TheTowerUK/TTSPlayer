# CBR Gate 0 — fixture generator + staging (Windows)

Produces TTSPlayer-owned synthetic CBR/RAR fixtures for Candidate E evidence.
See `test/support/cbr_gate0_fixtures/README.md`.

Requires WinRAR `Rar.exe` (tooling only — not shipped). Extract WinRAR with 7-Zip
into `staging/winrar_extract/` or pass `-RarExe`. RAR4 creation needs WinRAR 6.x
(`-ma4` removed in WinRAR 7).

Antivirus may quarantine RAR tooling — environment concern, separate from
Candidate B's MSVC compile failure and from Candidate E's technical CLI evidence.

```powershell
cd client\ttsplayer
powershell -ExecutionPolicy Bypass -File tool\cbr_gate0\generate_fixtures.ps1 `
  -RarExe tool\cbr_gate0\staging\winrar_extract\Rar.exe
```

`staging/` is gitignored. Do not commit WinRAR installers.
