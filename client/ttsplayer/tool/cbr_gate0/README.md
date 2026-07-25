# CBR Gate 0 — optional fixture generator (Windows)

Produces **pending** local fixtures only (RAR4/RAR5 pages, encrypted, large, multi-volume).
These are **not** treated as completed Gate 0 evidence until a candidate passes
native packaging and the harness exercises them.

Requires WinRAR `rar.exe` on PATH or at the default install location.
Antivirus (e.g. Norton CyberCapture) may quarantine `rar.exe` / UnRAR binaries —
exclude the project and Pub cache directories before running. That is a packaging /
environment concern, separate from the Gate 0 MSVC compile failure for
`package:unrar`.

```powershell
cd client\ttsplayer
powershell -ExecutionPolicy Bypass -File tool\cbr_gate0\generate_fixtures.ps1
```

Outputs under `test\support\cbr_gate0_fixtures\` (optional packs are gitignored).
