# Official UnRAR CLI — Binary Provenance & Licensing (Gate 0 Candidate E)

**Status:** Documented + Gate 0 Candidate 2 evidence (2026-07-25)  
**Related:** [cbr-rar-evaluation.md](./cbr-rar-evaluation.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md)  
**Legal certainty:** **None claimed.** Engineering due diligence only. Items marked **legal review** need counsel before shipping.

---

## Official source

| Field | Value |
|---|---|
| Vendor | RARLab / Alexander L. Roshal |
| Product page | https://www.rarlab.com/rar_add.htm |
| Listed item | **UnRAR for Windows** — command line freeware |
| Standalone addon URL | https://www.rarlab.com/rar/unrarw64.exe |
| WinRAR package URL (working binary source) | https://www.rarlab.com/rar/winrar-x64-723.exe |
| Architecture | Windows **x64** |
| RARLab note | Official UnRAR binaries for Windows are distributed as part of RAR/WinRAR packages |

### Fetched artefacts (Gate 0 machine, 2026-07-25)

| Artefact | SHA-256 | Size | Result |
|---|---|---|---|
| `unrarw64.exe` (standalone addon) | `CA630E4D4EFF213076DEF6690CC82EAD81ABB739158DA7EAD3FD263FF9D104E5` | 741976 | **Rejected for packaging** — process spawn returned exit 0 with **empty stdout/stderr** (unusable CLI I/O on this machine) |
| `winrar-x64-723.exe` | `8FF0DAF3ED564CC743C0E23FF2E253997FFC74460F9673F0B6DD037B2DB4CE7B` | 3775056 | Used only to extract official `UnRAR.exe` + `License.txt` via 7-Zip |
| Extracted `UnRAR.exe` (bundled candidate) | `0D3715001790F0FD18D3E850F947B540530B2D2DEB9A2E6A9E84F2ED7B234235` | 560848 | **Used** — banner `UNRAR 7.23 x64 freeware` |
| Tooling-only `winrar-x64-624.exe` (RAR4 fixture creator) | `794481DBBC9009A2565726FB5B4A4AB2FE216FF9EDBB08951548EE765DE9B4A6` | 3589048 | Not shipped — WinRAR 7 removed RAR4 creation (`-ma4`) |

Local Gate 0 path (gitignored executable): `client/ttsplayer/third_party/unrar_cli/UnRAR.exe`

---

## Licence terms (UnRAR freeware utility)

Full text ships with the binary / WinRAR package as `License.txt` (also copied beside Release `UnRAR.exe` when present). SPDX identifier commonly used: **UnRAR**.

Paraphrase (always ship full text):

1. Copyrights owned by Alexander Roshal.
2. UnRAR **source** may handle RAR archives free of charge; must **not** recreate proprietary RAR compression / archiver.
3. The UnRAR **utility may be freely distributed**, including **inside other software packages**.
4. **AS IS**, no warranty.
5. Use signifies acceptance.

**Engineering reading:** Licence text discusses free distribution of the UnRAR utility, including inside other packages. That is **not** a determination that extracting `UnRAR.exe` from a WinRAR installer and redistributing that exact binary with TTSPlayer is permitted.

**Not legal advice.** Production packaging and release distribution of any build that includes `UnRAR.exe` remain **blocked** until formal confirmation of the **exact binary’s** redistribution terms.

---

## Redistribution / commercial / Store

| Topic | Gate 0 position |
|---|---|
| Extract + redistribute WinRAR-supplied `UnRAR.exe` | **Unresolved — blocking** (no definitive permission claimed) |
| Microsoft Store | **Unresolved — legal/policy review** |
| Installer vs portable | Same layout *if* redistribution is later approved; notices required in both |
| Required notices | Full UnRAR/`License.txt` text; do not imply WinRAR endorsement |
| Update / security patches | TTSPlayer maintainers (only after shipping is approved) |

---

## Packaging policy

1. Do **not** commit `UnRAR.exe` until redistribution of the exact binary is formally confirmed.
2. Working Gate 0 binary: `UnRAR.exe` from WinRAR 7.23; reject `unrarw64.exe` (no usable console I/O).
3. CMake **optionally** copies `third_party/unrar_cli/UnRAR.exe` when present; **omits** it when absent (normal repo builds do not require a developer-local exe).
4. Local/harness tests may use `PHASE_63_UNRAR_EXE`; production resolution never uses PATH.
5. Optional SHA-256 check against `UnrarCliResolver.gate0ExpectedSha256`.
6. Missing packaged exe → adapter controlled CBR-unavailable (no crash).

---

## Open legal-review checklist

- [ ] Commercial bundling confirmation
- [ ] Microsoft Store binary + notice requirements
- [ ] Notice placement for portable and installer
- [ ] Code-signing / SmartScreen expectations for bundled `UnRAR.exe`
