# Windows CBR / RAR Extraction Evaluation (M6 Phase 6.1)

**Status:** Candidate B **FAIL**; Candidate E (UnRAR CLI) **Conditional pass** (2026-07-25) — CBR remains required; Phase 6.3 reader **not** complete  
**Date:** 2026-07-25 (Gate 0 spikes)  
**Related:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md) · [unrar-cli-provenance.md](./unrar-cli-provenance.md) · [m6-plan.md](../roadmap/m6-plan.md) · [books-comics.md](./books-comics.md)

> **Product scope:** `.cbz` and `.cbr` are **both required** for M6. Candidate B (`package:unrar`) failed MSVC native hooks. Candidate E (official `UnRAR.exe` CLI) earned a **Conditional pass** — see conditions below. **Do not silently drop CBR.** ADR-026 remains Proposed; reader UI not started.

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

### Fallback recommendation (after Candidate B Fail)

1. **Candidate E — bundled `UnRAR.exe` CLI** — evaluated next (below).
2. **Candidate D — TTSPlayer-owned FFI** to official UnRAR DLL — remains alternate if CLI conditions prove unacceptable.
3. **Fork of `package:unrar`** with MSVC-conditional flags — only if upstream/DLL path preferred later.

**Not preferred:** Candidate A (`package:rar`) — Windows still not a published platform.

### Gate decision (Candidate B)

| Field | Value |
|---|---|
| Decision | **Fail** (Candidate B as published) |
| Blocking criteria failed | Windows native packaging / Release-capable DLL build via package hooks |
| CBR scope | **Still required** |
| ADR-026 | Remains **Proposed** — do not Accept |
| Phase 6.3 | **Not complete** |

---

## Gate 0 Candidate 2 — Official UnRAR CLI (Candidate E) — 2026-07-25

**Decision: Conditional pass**

This Conditional pass means **technical viability only**. It does **not** approve redistribution of any UnRAR/WinRAR-supplied executable, and it does **not** authorize production packaging or release distribution of a build that includes `UnRAR.exe`.

| Axis | Status |
|---|---|
| Technical viability (list/extract/failure matrix/Release copy-when-present) | **Conditional pass** |
| Redistribution / shipping approval for the exact binary | **Unresolved — blocking** for production packaging and release distribution |
| ADR-026 / Phase 6.3 complete | **No** — remain Proposed / incomplete |

Provenance: [unrar-cli-provenance.md](./unrar-cli-provenance.md) · Notices: [third-party-unrar-cli.md](../legal/third-party-unrar-cli.md)

### What was proven (technical)

| Check | Result |
|---|---|
| Baseline | `m6-development` @ `c7c0755`; no `package:unrar`; ADR-026 Proposed |
| Working binary | `UnRAR.exe` obtained from **WinRAR 7.23** x64 package (`winrar-x64-723.exe`); banner `UNRAR 7.23 x64 freeware`; SHA-256 `0D3715001790F0FD18D3E850F947B540530B2D2DEB9A2E6A9E84F2ED7B234235` |
| Rejected addon | `unrarw64.exe` from rarlab addon page — **unsuitable**: spawned with exit 0 but **no usable console stdout/stderr** (required CLI I/O absent) |
| Local Release copy test | When `third_party/unrar_cli/UnRAR.exe` is present locally, CMake **optionally** copies it beside `ttsplayer.exe`; normal repo builds **omit** it when absent (no hard fail) |
| Dev/Gate override | `PHASE_63_UNRAR_EXE` for local/harness tests only — **not** required for normal builds |
| Missing executable | Adapter returns controlled unavailable error (`nativeLibraryMissing`) — no crash |
| List RAR4 / RAR5 | `UnRAR lt -p-` — one process; no full extract; nested paths OK |
| Selective extract | `UnRAR x` of named entry into owned temp dir; **one process per page**; temp cleaned |
| Failure matrix | Corrupt, encrypted (exit 11), empty, not-rar, no-images, multi-volume (`Details: volume`), missing exe, hash mismatch — classified; no crash |
| Path traversal | Rejected in Dart before spawn |
| Security | `Process.start` + arg list, `runInShell: false`, output bounded, passwords not logged (`-p-`) |

**Redistribution wording:** Nothing in this evaluation claims that extracting `UnRAR.exe` from a WinRAR installer and redistributing it with TTSPlayer is definitively permitted. Production packaging and release distribution remain **blocked** until formal confirmation of the **exact binary’s** redistribution terms.

### Informational performance (large_pages.cbr, 40 tiny PNGs)

| Metric | Observation |
|---|---|
| List | ~60–65 ms |
| First-page extract | ~60–65 ms |
| Sequential 3 pages | 3 process invocations |
| Temp disk | Per-extract unique dir under system temp; deleted after read |
| Peak memory | Not instrumented beyond process spawn; CLI child is short-lived |

### Maintainability comparison (updated)

| Factor | B `package:unrar` | E UnRAR CLI | D Owned UnRAR DLL FFI | C libarchive |
|---|---|---|---|---|
| Packaging | Fail (MSVC hooks) | CMake copy exe — works | MSVC project ownership | DLL + codecs |
| Runtime | N/A | Process-per-op overhead | In-process | In-process |
| Parsing | Dart API | CLI text (`lt`) fragile | FFI structs | FFI |
| Security surface | Native hook compile | Child process + temp files | DLL load | DLL load |
| Licensing | UnRAR + MIT pkg | UnRAR terms exist; **redistribution of exact binary unresolved** | UnRAR source/DLL | libarchive + RAR codec |
| Upgrade | Pub + hooks | Manual re-hash/bundle | Manual rebuild | Manual |
| Testability | Blocked | Opt-in harness green | Not spiked | Not spiked |

### Conditions (Phase 6.3 Definition of Done items)

1. **Redistribution approval (blocking):** Obtain formal confirmation that the **exact** shipping `UnRAR.exe` (identity + SHA-256) may be redistributed with TTSPlayer; until then, **do not** commit the exe or ship production/release builds that embed it.
2. Ship only a **validated** UnRAR binary with `License.txt` and runtime SHA-256 gate once redistribution is approved.
3. Accept **process-per-page** + **temp-dir selective extract** for M6 comics (document; bound timeouts).
4. Keep multi-volume and encrypted archives as **non-openable** with taxonomy mapping.
5. Complete **legal/policy review** (including Microsoft Store if applicable) before any channel that distributes `UnRAR.exe`.
6. Revalidate **Unicode entry names** (console/code-page) before claiming full Unicode comic support.
7. Builds without a local/approved binary must **omit** the optional CBR tool predictably; adapter must report controlled CBR-unavailable (not crash).
8. Do **not** Accept ADR-026 or mark Phase 6.3 complete until comic reader UI + CBZ/CBR runtime validation land **and** redistribution condition (1) is cleared.

### Gate decision (Candidate E)

| Field | Value |
|---|---|
| Decision | **Conditional pass** (technical viability ≠ redistribution approval) |
| Redistribution | **Unresolved — blocking** for production packaging / release distribution |
| CBR scope | **Still required** |
| ADR-026 | Remains **Proposed** |
| Phase 6.3 | **Not complete** |
| Recommended next after docs commit | Clear redistribution condition, then comic reader UI under remaining conditions; Candidate D remains escape hatch |

Norton CyberCapture / AV: treat as a **separate packaging observation**. Candidate E technical evidence used a working UnRAR console binary; standalone `unrarw64.exe` empty I/O may involve environment/AV and was not used.

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
| Gate 0 Candidate B | **FAIL** — Windows MSVC native hook incompatible |
| Gate 0 Candidate E | **Conditional pass** — official UnRAR CLI (see conditions) |
| `package:rar` for Windows | Still **not preferred** |
| RAR dependency in app | CLI binary optional beside Release exe (not committed until approved) |
| Scanner indexes `.cbr` | **Yes** |
| ADR-026 | Remains **Proposed** |
| Failed Gate 0 policy | Evaluate documented fallback; **no silent CBR removal** |
