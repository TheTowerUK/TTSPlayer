# CBR Gate 0 fixtures (Candidate E)

TTSPlayer-owned synthetic data only. **No copyrighted comics.**

## Committed / local synthetics

| File | How created | Purpose |
|---|---|---|
| `corrupt_synthetic.rar` | RAR5 magic + short payload | Corrupt / truncated |
| `empty.rar` | Zero-byte file | Empty archive |
| `not_rar.bin` | 32 arbitrary bytes | Not-an-archive |
| `page_001.png` | 1×1 PNG seed | Source image for packing |
| `rar4_pages.cbr` | WinRAR **6.24** `rar a -ep1 -m3 -ma4` over `page_001..005.png` | Valid **RAR4** (`Rar!\x1a\x07\x00`) |
| `rar5_pages.cbr` | WinRAR **7.23** `rar a -r -ep1 -m3 -ma5` from pages root | Valid **RAR5** with nested `nested/page_extra.png`, `page_006.jpg`, `notes.txt` |
| `encrypted.cbr` | `rar a -hpgate0` (password `gate0`) | Encrypted headers |
| `no_images.cbr` | Text-only archive | No supported images |
| `large_pages.cbr` | 40 tiny PNGs, `-m1 -ma5` | Timing / process observation |
| `safe_names_only.cbr` | Single `evil.png` | Safe-name extract baseline |
| `multivolume.cbr` | First volume of split set (`-v3k`) | Multi-volume detection |
| `multivolume_missing_part.cbr` | First volume alone | Missing continuation |
| `multivolume.part*.rar` | Remaining volumes (gitignored companions) | Optional complete set |

## Generator commands

Tooling only (not shipped). Requires extracted `Rar.exe`:

```powershell
cd client\ttsplayer
# RAR5 / encrypted / large / no-images (WinRAR 7.23+)
powershell -ExecutionPolicy Bypass -File tool\cbr_gate0\generate_fixtures.ps1 `
  -RarExe tool\cbr_gate0\staging\winrar_extract\Rar.exe

# RAR4 creation requires WinRAR 6.x (7.x removed -ma4):
# Extract https://www.rarlab.com/rar/winrar-x64-624.exe then:
& tool\cbr_gate0\staging\winrar624_extract\Rar.exe a -ep1 -m3 -ma4 -y `
  test\support\cbr_gate0_fixtures\rar4_pages.cbr page_*.png
```

Source images: generated PNGs/JPEGs only (see script). Never add licensed comic pages.

## Signature notes

- RAR5 magic: `52 61 72 21 1A 07 01`
- RAR4 magic: `52 61 72 21 1A 07 00`
