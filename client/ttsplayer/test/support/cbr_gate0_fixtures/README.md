# CBR Gate 0 fixtures

TTSPlayer-owned test data for M6 Phase 6.3 Gate 0. **No copyrighted comics. No third-party sample archives.**

## Committed files (licence-safe, reproducible)

| File | How created | Purpose |
|---|---|---|
| `corrupt_synthetic.rar` | TTSPlayer-generated: RAR5 magic (`Rar!\x1a\x07\x01`) + short pseudo-random payload, truncated | Corrupt / incomplete archive shape (no third-party content) |
| `empty.rar` | Zero-byte file created by TTSPlayer | Empty archive failure |
| `not_rar.bin` | 32 arbitrary TTSPlayer-chosen bytes | Not-an-archive failure |
| `page_001.png` | TTSPlayer-generated 1×1 PNG | Neutral seed image for optional local packing |

Regenerate committed synthetics (PowerShell):

```powershell
$dir = "client\ttsplayer\test\support\cbr_gate0_fixtures"
$magic = [byte[]](0x52,0x61,0x72,0x21,0x1A,0x07,0x01)
$payload = [byte[]](0x00,0x33,0x92,0xB5,0xE5,0x0A,0x01,0x05,0x06,0xDE,0xAD,0xBE,0xEF)
[IO.File]::WriteAllBytes("$dir\corrupt_synthetic.rar", ($magic + $payload))
[IO.File]::WriteAllBytes("$dir\empty.rar", [byte[]]@())
[IO.File]::WriteAllBytes("$dir\not_rar.bin", [byte[]](1..32 | ForEach-Object { $_ }))
# page_001.png: minimal 1x1 PNG already committed; re-export from any PNG tool if needed
```

## Pending fixtures (not committed — not Gate 0 complete)

Create locally with `tool/cbr_gate0/generate_fixtures.ps1` when WinRAR `rar.exe` is available. These remain **pending**, not completed evidence:

| File | Purpose |
|---|---|
| `rar4_pages.cbr` | Valid RAR4 with ordered PNG pages |
| `rar5_pages.cbr` | Valid RAR5 with ordered PNG pages + nested folder + non-image |
| `encrypted.cbr` | Password-protected (`gate0`) |
| `large_pages.cbr` | Larger page set for memory observation |
| `multivolume.cbr` / `.r00` | Multi-volume unsupported path |

Do **not** commit copyrighted comic content. Prefer generated PNGs from `page_001.png` only. Do **not** commit third-party package sample RAR files unless redistribution rights and purpose are documented in this README and approved.

## Signature notes

- RAR5 magic: `52 61 72 21 1A 07 01` (`Rar!\x1a\x07\x01`)
- RAR4 magic: `52 61 72 21 1A 07 00` (`Rar!\x1a\x07\x00`)
