# Windows CBR / RAR Extraction Evaluation (M6 Phase 6.1)

**Status:** Gate 0 **FAIL** for published `package:unrar` 0.1.2 on Windows MSVC (2026-07-25) — CBR remains required; evaluate fallback next  
**Date:** 2026-07-25 (Gate 0 spike)  
**Related:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md) · [m6-plan.md](../roadmap/m6-plan.md) · [books-comics.md](./books-comics.md)

> **Product scope:** `.cbz` and `.cbr` are **both required** for M6. Gate 0 rejected the provisional preferred package **as published** for Windows Release builds. **Do not silently drop CBR.** Next work evaluates a documented fallback.

---

## Correction note (2026-07-24)

An earlier draft incorrectly described **`package:rar` + libarchive FFI** as the selected Windows implementation.

**Evidence against that claim:** the published [`rar`](https://pub.dev/packages/rar) package metadata and docs list platform support for **Android, iOS, macOS, and Web only**. Windows is **not** listed in the official platform support table. Changelog mentions of desktop/FFI must not be treated as confirmed Windows product support without repository proof and a successful Release spike.

Therefore `package:rar` is **not** the provisional Windows choice.

---

## Requirement

Phase 6.3 must open CBR (RAR-based comic archives) on Windows with:

- Archive listing without mandatory full extraction
- Selective page / entry extraction (or equivalent streaming to memory)
- Graceful failure for corrupt, encrypted, unsupported, and multi-volume archives
- Acceptable licensing for redistribution with TTSPlayer
- Maintainable packaging for Windows **Release** builds

CBZ remains ZIP (`package:archive` / Dart zip APIs) and is out of scope for this RAR decision.

---

## Candidate comparison

| Criterion | A. `package:rar` (pub.dev) | B. `package:unrar` (pub.dev) — **provisional preferred** | C. Custom Dart FFI → libarchive | D. Custom FFI → official UnRAR (own bindings) | E. Bundled `UnRAR.exe` / CLI subprocess |
|---|---|---|---|---|---|
| **What it is** | Flutter plugin (MIT) using libarchive (Android FFI) / UnrarKit (Apple) / WASM (Web) | Dart FFI wrapper around **official UnRAR library** (RARLab) | First-party FFI to libarchive.dll | First-party FFI to UnRAR sources/DLL | Ship vendor CLI beside `ttsplayer.exe` |
| **Confirmed Windows support (published)** | **No** — pub.dev platforms: Android, iOS, macOS, Web | **Yes** — docs claim Windows, macOS, Linux | Possible, but no TTSPlayer spike yet | Possible, but high ownership cost | **Yes** (process spawn) |
| **RAR4 / RAR5** | Claims RAR5 on Android via libarchive; Windows unproven | Claims RAR4 and RAR5 | Depends on libarchive build + codecs | Official UnRAR typically supports both | Official UnRAR CLI supports both |
| **Solid archives** | Unknown / unvalidated on Windows | Expected via UnRAR; must prove in Gate 0 | Depends on libarchive RAR codec quality | Expected via UnRAR; Gate 0 | Expected via UnRAR CLI |
| **Encrypted archives** | Password API on supported platforms | Must map to clear failure (no M6 password UI unless approved) | Same policy | Same policy | Same policy |
| **Multi-volume archives** | Treat as **unsupported** in M6 | Treat as **unsupported** in M6 | Same | Same | Same |
| **List without full extract** | `listRarContents` on supported platforms | `listFiles` API documented | Need custom API | Need custom API | CLI list mode |
| **Selective page extraction** | Full extract API primary; selective TBD | `extractFile` / in-memory extract documented | Must implement | Must implement | Harder / temp-dir heavy |
| **Native DLL packaging** | N/A for Windows (not a supported platform) | Build hooks claim auto compile; **unverified** on our Release pipeline | Manual `libarchive.dll` (+ deps) next to exe | Manual UnRAR DLL / static link | Bundle `UnRAR.exe` |
| **Release-build deployment** | Cannot rely on this package for Windows | Gate 0 must prove Release bundle | Gate 0 must prove | Gate 0 must prove | Proven pattern but ops-heavy |
| **Licensing / redistribution** | Plugin MIT; libarchive BSD; UnRAR terms for decompress where used | Package MIT; **UnRAR license** (decompress-only; no RAR creation) | libarchive BSD + any RAR codec terms | UnRAR license | UnRAR license + binary redistribution rules |
| **Maintenance health** | Active; **wrong platform set for us** | Early (`0.1.x`), unverified publisher — higher risk | Full ownership | Full ownership | Vendor CLI updates manual |
| **Corrupt-archive behaviour** | Documented error strings on supported platforms | `UnrarException` / test API claimed — Gate 0 | Must define | Must define | Parse CLI exit codes |
| **Path traversal / extraction safety** | Must enforce in app layer | Must enforce in app layer (reject `..`, absolute paths) | Same | Same | Same + sandbox temp dir |

---

## Provisional preferred implementation

**Candidate B — `package:unrar` (Dart FFI to the official UnRAR library).**

### Why provisional preferred (not “selected / validated”)

1. **Confirmed Windows in published package docs** — unlike `package:rar`.
2. **Uses official UnRAR** — appropriate for RAR4/RAR5 comic archives rather than assuming libarchive’s RAR codec on Windows.
3. **API shape fits comics** — list entries + extract a single file (page) without always unpacking the whole archive.
4. **Licensing model is understood at a high level** — decompression-only UnRAR terms; attribution required; Gate 0 must confirm redistribution acceptability for our shipping layout.

### What this is *not*

| Misstatement | Correction |
|---|---|
| “`package:rar` + libarchive FFI (Windows)” | **Rejected** for Windows — platform not listed on pub.dev |
| “Fully selected and validated” | **Incorrect** — no dependency added; no Release spike; no fixture runtime |
| “Custom libarchive FFI” | That is Candidate C — **fallback / alternate**, not current provisional preferred |
| “Bundled UnRAR.exe” | Candidate E — **documented fallback** if B fails Gate 0 |

### Explicit non-goals for Phase 6.1

- Do **not** add `unrar`, `rar`, or any RAR native binary to the app yet.
- Scanner continues to index `.cbr` with filename metadata only.
- No production-code assumption that a RAR reader package is already available.

---

## Phase 6.3 — Gate 0 (blocking)

Gate 0 is a **hard blocker** before comic-reader CBR work is Accepted. It must:

1. Build a **minimal Windows Release** spike that links the provisional stack (or the chosen fallback).
2. **Bundle the required native library** correctly beside / inside the Release output (document exact files and licenses).
3. **List** a representative CBR/RAR archive without full extraction.
4. **Extract or stream selected image entries** (enough for one page turn).
5. Validate **RAR4 and RAR5** fixtures.
6. Test **corrupt**, **encrypted**, and **multi-volume** fixtures:
   - corrupt → catchable failure, no crash
   - encrypted → clear non-openable message (no password UI unless separately approved)
   - multi-volume → unsupported message; catalogue remainder unaffected
7. Confirm **licensing and redistribution** acceptability in writing (UnRAR terms + package MIT + any DLLs shipped).
8. Confirm **acceptable memory behaviour for large archives** (lazy/selective page access; no unbounded full-archive load into RAM for representative large fixtures).

### Gate 0 outcomes

| Outcome | Action |
|---|---|
| Pass | Adopt B as **Accepted** for 6.3; update ADR-024; implement reader |
| Fail on packaging / API gaps | Spike **Candidate E** (bundled UnRAR CLI) or **C/D** as needed; document switch |
| All technical candidates fail | **Do not silently remove CBR.** Produce an explicit deferral proposal (rationale + known limitation + approval) before M6 closure |

---

## Gate 0 spike result (2026-07-25) — **FAIL** for Candidate B as published

### Baseline

| Check | Result |
|---|---|
| Branch | `m6-development` @ `eab1751` (Phase 6.2 complete) |
| Working tree at start | Clean |
| ADR-024 / ADR-026 | Remain **Proposed** (not Accepted) |
| RAR dependency in app before spike | None |
| Norton CyberCapture | Separate development-environment / packaging observation only (session interruption). **Not** the cause of this Gate 0 technical failure |

### Dependency audit — `package:unrar` 0.1.2

| Item | Finding |
|---|---|
| Version evaluated | **0.1.2** (pub.dev; published ~6 months before spike; changelog still “experimental”) |
| Publisher | **Unverified** uploader; GitHub [Maistho/dart_unrar](https://github.com/maistho/dart_unrar) |
| SDK | `>=3.10.0 <4.0.0` (Dart build hooks) |
| Platforms claimed | Windows, macOS, Linux |
| Native sources | Bundles official UnRAR **7.2.0 beta 3** sources under `third_party/unrar/` (`version.hpp` 2025-12-18) |
| Build integration | `hook/build.dart` + `native_toolchain_c` compiles a shared library named `unrar` / `unrar.dll` |
| Runtime lookup | `DynamicLibrary.open` over `.dart_tool/lib`, CWD, exe dir, `UNRAR_LIBRARY_PATH` |
| Package licence | **MIT** (`LICENSE`) |
| UnRAR licence | RARLab freeware UnRAR terms (`third_party/unrar/license.txt`): decompress-only; may redistribute UnRAR; modified source OK if licence paragraph preserved; **not** legal advice |
| Bundles prebuilt DLL? | **No** — expects host compile via hooks |
| Architectures | Spike exercised **Windows x64** MSVC Build Tools 18 / cl 19.50 |

### Blocking failure — Windows MSVC native hook

**Failure class:** Reproducible **native compilation** failure on Windows x64 MSVC **before** any `unrar.dll` is created. It is independent of Norton CyberCapture / runtime antivirus behaviour. Antivirus may still matter later for packaging UnRAR binaries; it did not cause this Fail.

Adding `unrar: ^0.1.2` and running `flutter test` (native asset / hooks build) invokes MSVC `cl.exe` 19.50.35728 via `package:unrar` `hook/build.dart` + `native_toolchain_c`. Captured command shape (sources abbreviated; full log in local `.dart_tool/hooks_runner/unrar/*/stdout.txt` during the spike):

```text
"C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\cl.exe" /O2 -Wno-dangling-else -Wno-switch -DRARDLL -std=c++11 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -DRAR_SMP -pthread /DRELEASE /DNDEBUG /LD /Fe:...\.dart_tool\hooks_runner\shared\unrar\build\<hash>\unrar.dll <unrar-0.1.2\third_party\unrar\*.cpp> /link /MACHINE:X64 /LIBPATH:...\.dart_tool\hooks_runner\shared\unrar\build\<hash>\
```

MSVC rejects the GCC/Clang-style flags (first failure):

```text
Microsoft (R) C/C++ Optimizing Compiler Version 19.50.35728 for x64
cl : Command line error D8021 : invalid numeric argument '/Wno-dangling-else'
```

(The same line also carries `-Wno-switch`, `-std=c++11`, and `-pthread`, which MSVC would likewise reject.)

**Process exit code: 2.** Output path `unrar.dll` was **never produced**. Therefore:

- Failure is at **compile/link invocation**, not DLL load, not extract, and not AV quarantine of a finished binary
- Windows Release packaging via the published hook is **not proven**
- Listing / selective extraction / RAR4·RAR5 runtime evidence against this package **could not be completed** on this toolchain
- Keeping the dependency in `pubspec.yaml` breaks the Flutter suite’s native-asset build on this machine

**Action taken:** dependency **removed** after evidence capture so the app remains green. Local `.dart_tool/hooks_runner/unrar` residue cleaned. Spike isolation code remains under `lib/features/comics/spike/` (`CbrArchiveAdapter` + path safety + failed-candidate stub) and TTSPlayer-owned fixtures under `test/support/cbr_gate0_fixtures/`.

### API / design observations (from source review — not runtime-proven)

| Topic | Observation |
|---|---|
| List without full extract | `listFiles` uses `RAR_OM_LIST` + `RAR_SKIP` — appropriate API shape |
| Selective extract | `extractFile` extracts **one** matching entry via `RAR_EXTRACT` into a **system temp directory**, reads bytes, deletes temp (`usedTemporaryDirectory=true`). Not pure memory streaming; solid archives may still decompress prior members internally |
| Unicode paths | Uses ANSI `RAROpenArchive` / `RARHeaderData` (not Ex/W variants) — risk for non-ASCII paths on Windows |
| Path traversal | Package does not sanitize `..` in entry names; TTSPlayer spike helpers reject unsafe names before extract |

### Fixtures prepared

See `client/ttsplayer/test/support/cbr_gate0_fixtures/README.md`.

**Committed (TTSPlayer-owned only):** synthetic corrupt RAR-like bytes, empty file, not-rar bytes, 1×1 PNG seed.

**Pending (not completed — require local `rar.exe` / generator; do not treat as Gate 0 evidence):** valid RAR4 pages, valid RAR5 pages, encrypted, large page set, multi-volume. Generator: `tool/cbr_gate0/generate_fixtures.ps1` (not run — no `rar.exe` on PATH). No third-party package sample archives are committed.

### Failure-mode matrix (partial)

| Case | Status |
|---|---|
| Native DLL missing / hook fail | **Observed** — compile-time D8021; stub adapter classifies as `nativeLibraryLoadFailed` |
| Corrupt / empty / not-rar fixtures | TTSPlayer-owned files on disk; full UnRAR classification **pending** (no DLL) |
| Valid RAR4 / RAR5 page archives | **Pending** |
| Encrypted / large / multi-volume | **Pending** |
| Path traversal | **Unit-tested** pure Dart helpers (pass) |

### Licensing (informational — not formal legal review)

- Package MIT + UnRAR freeware decompress licence appear **compatible in principle** with bundling a decompress DLL, with required UnRAR licence text in docs/notices.
- Unresolved for formal review: Microsoft Store binary policy; whether shipping a forked hook + compiled UnRAR needs extra attribution packaging; commercial distribution acknowledgements.

### Maintainability

| Factor | Assessment |
|---|---|
| Recency | Early `0.1.x`, low download volume, unverified publisher |
| Windows readiness | **Hook not MSVC-safe** — high risk |
| Replaceability | TTSPlayer-owned `CbrArchiveAdapter` port is the right boundary |
| Security/upgrade | Would require tracking UnRAR upstream + hook maintenance |

### Fallback recommendation (next)

**Preferred next spike order:**

1. **Candidate D — TTSPlayer-owned FFI** binding to official UnRAR, building `UnRARDll.vcxproj` (or makefile) with MSVC and shipping `unrar.dll` beside the Release exe (plus `UNRAR_LIBRARY_PATH` / exe-dir load). Reuse UnRAR 7.x sources; keep `CbrArchiveAdapter`.
2. **Candidate E — bundled `UnRAR.exe` CLI** if DLL packaging remains painful; higher process overhead; clearer redistribution story for the official binary.
3. **Fork of `package:unrar`** with MSVC-conditional flags in `hook/build.dart` — only if upstream is unresponsive and we want to keep their Dart bindings.

**Not preferred next:** Candidate A (`package:rar`) — Windows still not a published platform.

### Gate decision

| Field | Value |
|---|---|
| Decision | **Fail** (Candidate B as published) |
| Blocking criteria failed | Windows native packaging / Release-capable DLL build via package hooks |
| CBR scope | **Still required** |
| ADR-026 | Remains **Proposed** — do not Accept |
| Phase 6.3 | **Not complete** — Gate 0 must pass on a fallback before reader Accept |

---

## Security posture (reader phase)

When implementing after Gate 0:

- Extract only to a **session-scoped or LRU temp directory**; never into the media library tree.
- Bound extraction size / page count where practical.
- Reject path traversal in archive entry names.
- Treat encrypted and multi-volume archives as non-openable with recovery actions.
- Never let a bad archive crash the isolate without recovery or poison catalogue state.

---

## Phase 6.1 outcome (corrected) + Gate 0

| Item | Result |
|---|---|
| Provisional preferred stack (6.1) | **`package:unrar`** (official UnRAR via Dart FFI) |
| Gate 0 (6.3 spike, 2026-07-25) | **FAIL** — Windows MSVC native hook incompatible |
| `package:rar` for Windows | Still **not preferred** |
| In `pubspec.yaml` now | **No** (removed after evidence) |
| Scanner indexes `.cbr` | **Yes** |
| ADR-026 | Remains **Proposed** |
| Failed Gate 0 policy | Evaluate documented fallback; **no silent CBR removal** |
