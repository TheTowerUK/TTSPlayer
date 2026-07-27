# Official UnRAR.dll / UnRAR64.dll — Provenance, Security & Maintenance

**Status:** Gate 1 engineering evidence (2026-07-27) — **not legal approval**  
**Related:** [cbr-rar-evaluation.md](./cbr-rar-evaluation.md) · [unrar-redistribution-enquiry.md](../governance/unrar-redistribution-enquiry.md) · [ADR-026](./decisions/ADR-026-reader-surface-architecture.md)

---

## TTSPlayer use policy

TTSPlayer:

- Uses **decompression only** (list + extract for comic reading).
- Does **not** provide RAR creation or modification.
- Does **not** derive or recreate the RAR compression algorithm.
- Ships the official DLL **unmodified** if redistribution is approved.
- Does **not** rename or patch the DLL without a separate engineering and governance review.
- Includes the exact accompanying **`license.txt`** from the developer package whenever the DLL is packaged.
- Verifies the **approved SHA-256** before loading (runtime) and before install (CMake).
- Does **not** download DLL updates automatically over the network.

---

## Official source inventory

| Field | Value |
|---|---|
| Publisher | RARLab / Alexander L. Roshal (win.rar GmbH distribution) |
| Product page | https://www.rarlab.com/rar_add.htm |
| Developer package URL | https://www.rarlab.com/rar/unrardll-723.exe |
| Package filename | `unrardll-723.exe` |
| Package SHA-256 | `68B064B34691988158C4126D3CF422F4E74A7D1D618C26BAFC93B4E502B88B55` |
| DLL filename (x64) | `UnRAR64.dll` |
| DLL SHA-256 (approved Gate 1) | `894B7D2DB8D6363EB12F30C7B89F48EAB9E71963B8B438675BDD64C12DD59BCC` |
| Licence filename | `license.txt` |
| Licence SHA-256 | `2933572C0589934D80BC868CD37A15AE44791F2BA53927108791DA6105B0BFAD` |
| Header filename | `unrar.h` |
| Header SHA-256 | `74A1C1CFD72A6569CC55496DFDC5B88773FE384AFAF1A10ACBDD0ADAB65266A1` |
| Version | **7.23** (package); `RARGetDllVersion` returns API version **10** |
| Retrieval date | **2026-07-27** |
| Supported architecture | Windows **x64** (`UnRAR64.dll`) — TTSPlayer Windows Release target |
| Minimum API version | `RAR_DLL_VERSION` **10** (from `unrar.h`) |
| Current approved version | **7.23 / API 10** — hash above |

Local evaluation path (gitignored): `client/ttsplayer/third_party/_gate1_eval/unrardll-723/x64/UnRAR64.dll`  
Approved staging path (optional CMake): `client/ttsplayer/third_party/unrar_dll/`  
Production install subdir: `{app}/unrar/UnRAR64.dll` + `{app}/unrar/license.txt`

Harness override: `PHASE_63_UNRAR_DLL` (evaluation only — not production)

---

## Required exports (verified at load)

From `unrar.h` / `UnrarDllLoader.unrarRequiredExports`:

- `RAROpenArchiveEx`
- `RARCloseArchive`
- `RARReadHeaderEx`
- `RARProcessFile`
- `RARGetDllVersion`

Missing any export → controlled load failure (`missingExports`).

---

## Security baseline

| Topic | Policy |
|---|---|
| Approved hash trust | The approved SHA-256 is **not** a permanent trust guarantee |
| Security advisories | Track https://www.rarlab.com/vuln_rev3_names.html and RARLab release notes |
| Minimum version | Reject DLLs below `RAR_DLL_VERSION` (10) |
| Newer DLL acceptance | TTSPlayer must **not** silently accept any newer DLL merely because version is higher — hash + provenance + regression review required |
| Hash revocation | An outdated approved hash may be **revoked** when RARLab publishes a security fix |
| Update owner | TTSPlayer maintainers (post-shipping approval) |
| Review cadence | On every RARLab security advisory; at minimum quarterly while CBR DLL is bundled |
| Archive inputs | Remain **untrusted** even when processed by an approved DLL |

Gate 1 confirms evaluated **7.23** is current relative to published RARLab security minimums at retrieval date (2026-07-27).

---

## Upgrade procedure

1. Download new official `unrardll-<version>.exe` from https://www.rarlab.com/rar_add.htm
2. Verify package SHA-256; record in this document
3. Extract `x64/UnRAR64.dll`, `license.txt`, `unrar.h`
4. Verify DLL and licence SHA-256
5. Update `UnrarDllLoader.gate1ExpectedSha256UnRAR64` and CMake `UNRAR_DLL_EXPECTED_SHA256`
6. Stage to `third_party/unrar_dll/` (never commit binary to Git)
7. Rerun Gate 1 matrix + Release-layout smoke + full Flutter regression
8. Update ADR-026 evidence and governance records

---

## Hash-update approval procedure

1. Maintainer proposes new hash with provenance record (URL, date, SHA-256 table)
2. Gate 1 harness + Release-layout proof pass on staging binary
3. If redistribution already approved: update packaging; else engineering-only staging
4. Document in this file and ADR-026 changelog — **no ADR Accept solely from hash update**

---

## Rollback procedure

1. Remove DLL from `third_party/unrar_dll/` staging
2. Revert hash constants to last approved values
3. Rebuild — CMake omits DLL; CBR falls back to unavailable or dev CLI override
4. Rerun tests without DLL env to confirm non-CBR paths green

---

## Security-advisory response process

1. Monitor RARLab advisories within 48 hours of publication
2. If advisory affects UnRAR DLL ≤ approved version → mark hash **revoked** in this doc
3. Block any public packaging that includes revoked hash
4. Execute upgrade procedure; do not ship until Gate 1 matrix passes
5. Record advisory ID, dates, and actions in governance evidence

---

## Redistribution conclusion (engineering — not legal advice)

| Question | Gate 1 reading | Confidence |
|---|---|---|
| Official component? | Yes — listed on rar_add.htm | High |
| Use in software? | Explicit in DLL `license.txt` clause 2 | High |
| Redistribute in installer? | **Awaiting publisher confirmation** — see [enquiry](../governance/unrar-redistribution-enquiry.md) | Low until response |
| Microsoft Store | **Unresolved** | Unknown |
| Code signing DLL | **Unresolved** | Unknown |

**Do not ship publicly until written confirmation or qualified legal advice is recorded.**

---

## Packaging safety (CMake)

- DLL **never committed** to Git
- Install only from `third_party/unrar_dll/` (explicitly **not** `_gate1_eval`)
- Missing DLL → build succeeds; CBR DLL support omitted
- DLL + `license.txt` installed together to `unrar/`
- SHA-256 mismatch → **FATAL_ERROR** at configure/install when DLL staged
- Build log states whether CBR DLL support was included

---

## Open governance items

- [ ] Publisher redistribution confirmation
- [ ] Commercial / Store distribution confirmation
- [ ] ADR-026 Accept (blocked on redistribution gate)
- [ ] Phase 6.3 Complete (blocked on redistribution gate)
