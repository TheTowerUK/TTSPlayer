# Official UnRAR64.dll (Gate 1 Candidate A)

See [unrar-dll-provenance.md](../../../../docs/architecture/unrar-dll-provenance.md).

**Do not commit `UnRAR64.dll` here** until redistribution is approved in the Gate 1 review package.

Place the official x64 DLL from RARLab `unrardll-723.exe` developer package:

- `UnRAR64.dll` — from package `x64/UnRAR64.dll`
- `license.txt` — from package root `license.txt`

Resolution order at runtime:

1. `PHASE_63_UNRAR_DLL` (local/harness override)
2. `UnRAR64.dll` beside `ttsplayer.exe`
3. `unrar/UnRAR64.dll` beside `ttsplayer.exe`

Never PATH or system-directory search.
