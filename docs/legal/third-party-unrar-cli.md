# Third-party notice — UnRAR CLI (Candidate E)

TTSPlayer’s Gate 0 spike evaluates the official RARLab **UnRAR** command-line utility for Windows to open `.cbr` (RAR) comic archives.

- Vendor: Alexander L. Roshal / RARLab — https://www.rarlab.com/
- Working Gate 0 binary identity: `UnRAR.exe` from WinRAR 7.23 (`UNRAR 7.23 x64 freeware`)
- SHA-256 (Gate 0 record): `0D3715001790F0FD18D3E850F947B540530B2D2DEB9A2E6A9E84F2ED7B234235`
- Licence text: UnRAR freeware licence (`License.txt`)
- Use if shipped: decompression / listing only — TTSPlayer must not create RAR archives with UnRAR
- Provenance: [unrar-cli-provenance.md](../architecture/unrar-cli-provenance.md)

**This notice does not authorize redistribution.** Extracting `UnRAR.exe` from a WinRAR package and shipping it with TTSPlayer is **not** claimed to be permitted. Production packaging and release distribution remain **blocked** until formal confirmation of the exact binary’s redistribution terms.

The executable is **not** committed to the repository at the Conditional-pass stage.
