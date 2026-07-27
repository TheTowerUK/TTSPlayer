# UnRAR64.dll redistribution enquiry (Gate 1 — awaiting response)

**Status:** Sent / awaiting publisher or qualified legal response  
**Related:** [unrar-dll-provenance.md](../architecture/unrar-dll-provenance.md) · [ADR-026](../architecture/decisions/ADR-026-reader-surface-architecture.md)  
**Do not treat as legal approval until a response is recorded below.**

---

## Enquiry text (2026-07-27)

**To:** RARLAB / win.rar GmbH (via official contact channel on https://www.rarlab.com/)

**Subject:** Redistribution confirmation — UnRAR64.dll in TTSPlayer Windows application

Dear RARLAB team,

We are developing **TTSPlayer**, a local-first media reader application for Windows (and future platforms). We request explicit confirmation that our intended use of the official UnRAR dynamic library is permitted.

### Intended use

| Item | Detail |
|---|---|
| Application | TTSPlayer — media reader (books, comics, video); not an archiver |
| Binary | Official unmodified **`UnRAR64.dll`** from developer package **`unrardll-723.exe`** |
| Source URL | https://www.rarlab.com/rar/unrardll-723.exe |
| Purpose | List and extract **RAR4/RAR5** comic archives (`.cbr`) for on-screen reading only |
| Compression | We do **not** implement RAR compression or recreate the RAR algorithm |
| Modification | We ship the DLL **unmodified** if redistribution is approved |
| Licence file | We include the original **`license.txt`** from the developer package |
| Packaging | DLL + licence inside TTSPlayer’s Windows installer and portable application folder (`unrar/` subdirectory) |
| Distribution channels | Direct download (installer and ZIP); potential future **Microsoft Store** submission |
| Commercial use | TTSPlayer may be distributed commercially |
| Code signing | The application installer may be Authenticode-signed; the DLL itself would remain the official binary (not re-signed or patched by us unless you require otherwise) |
| Attribution | We retain publisher attribution and version information in third-party notices |
| Maintenance | We commit to replacing the DLL when you publish security updates |

### Questions requiring explicit confirmation

1. **Redistribution:** May we redistribute the unmodified `UnRAR64.dll` and accompanying `license.txt` inside TTSPlayer’s application/installer package?
2. **Notice:** What attribution or licence files must be displayed to end users (in-app, installer, or documentation)?
3. **Commercial distribution:** Is commercial distribution of TTSPlayer including the DLL permitted?
4. **Microsoft Store:** Is inclusion in a Microsoft Store package permitted?
5. **Signing:** May the DLL remain unsigned by TTSPlayer while the outer installer is signed, or are there specific requirements?
6. **Renaming / path:** May the DLL be placed in an `unrar/` subdirectory (filename unchanged), or must it remain at a specific relative path?
7. **Separate agreement:** Is a separate licence agreement required beyond the package `license.txt`?

We will not ship the DLL in public releases until we receive your guidance or obtain qualified legal advice.

Thank you for your time.

TTSPlayer development team

---

## Response log

| Date | Channel | Summary | Recorded by |
|---|---|---|---|
| — | — | *No response received at Gate 1 checkpoint* | — |

---

## Governance status at checkpoint

| Gate | Status |
|---|---|
| Technical validation (FFI Gate 1) | **Pass** |
| Production packaging (Release layout) | **Conditional Pass** (engineering evidence; DLL omitted from public builds) |
| Bundled redistribution | **Awaiting publisher/legal confirmation** |
| ADR-026 | **Proposed** |
| Phase 6.3 | **In Progress** |
| M6 closure | **Blocked** |
