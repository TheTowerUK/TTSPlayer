# Official UnRAR CLI (Gate 0 Candidate E)

See [unrar-cli-provenance.md](../../../../docs/architecture/unrar-cli-provenance.md).

**Do not commit `UnRAR.exe` here** until redistribution of the exact binary is formally approved.
Normal repository builds omit the optional CBR tool when the file is absent.

## Local Gate 0 / harness only

Working binary used for Gate 0 technical evidence (not redistribution approval):

1. Obtain WinRAR x64 **7.23** installer from RARLab (`winrar-x64-723.exe`)
2. Extract with 7-Zip; copy package `UnRAR.exe` to this directory
3. Keep `License.txt` from the same package (committed as licence text reference)

| Field | Value |
|---|---|
| Version banner | `UNRAR 7.23 x64 freeware` |
| SHA-256 | `0D3715001790F0FD18D3E850F947B540530B2D2DEB9A2E6A9E84F2ED7B234235` |
| Size | 560848 bytes |

Rejected: standalone addon `unrarw64.exe` — no usable console I/O on the Gate 0 machine.

## Resolution order (app)

1. `PHASE_63_UNRAR_EXE` (local/harness override)
2. `UnRAR.exe` beside `ttsplayer.exe`
3. `unrar/UnRAR.exe` beside `ttsplayer.exe`

Never PATH / WinRAR install discovery. Missing exe → controlled “CBR support unavailable”.
