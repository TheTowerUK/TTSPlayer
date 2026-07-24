# Windows CBR / RAR Extraction Evaluation (M6 Phase 6.1)

**Status:** Provisional preferred implementation recorded — **not** Gate-0 validated  
**Date:** 2026-07-24 (corrected)  
**Related:** [ADR-024](./decisions/ADR-024-book-comic-catalogue-schema-and-media-kind.md) · [m6-plan.md](../roadmap/m6-plan.md) · [books-comics.md](./books-comics.md)

> **Product scope:** `.cbz` and `.cbr` are **both required** for M6. This document records a **provisional preferred** Windows CBR/RAR approach for Phase 6.3. No reader dependency is in `pubspec.yaml` yet. No Windows Release spike has been run. A failed Gate 0 must evaluate a documented fallback — **not** silently drop CBR.

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

## Security posture (reader phase)

When implementing after Gate 0:

- Extract only to a **session-scoped or LRU temp directory**; never into the media library tree.
- Bound extraction size / page count where practical.
- Reject path traversal in archive entry names.
- Treat encrypted and multi-volume archives as non-openable with recovery actions.
- Never let a bad archive crash the isolate without recovery or poison catalogue state.

---

## Phase 6.1 outcome (corrected)

| Item | Result |
|---|---|
| Provisional preferred stack | **`package:unrar`** (official UnRAR via Dart FFI) — Windows claimed by package docs |
| `package:rar` for Windows | **Not preferred** — Windows not in published platform support |
| Fully selected / validated | **No** — awaiting Phase 6.3 Gate 0 |
| Added to app now | **No** |
| Scanner indexes `.cbr` | **Yes** (`media_kind: comic`) |
| CBR metadata in 6.1 | Filename title only |
| CBZ metadata in 6.1 | Optional ComicInfo.xml when present |
| Failed Gate 0 policy | Evaluate documented fallback; **no silent CBR removal** |
