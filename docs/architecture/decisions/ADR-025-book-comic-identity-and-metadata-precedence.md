# ADR-025: Book/Comic Identity and Metadata Precedence

**Status:** **Accepted** (2026-07-28) — identity and metadata precedence implemented in Phases 6.1–6.2
**Date:** 2026-07-24 (proposed) / 2026-07-28 (accepted)
**Milestone:** M6 — Phase 6.1–6.2  
**Related:** [books-comics.md](../books-comics.md) · [ADR-021](./ADR-021-music-metadata-precedence-and-identity.md) · [ADR-024](./ADR-024-book-comic-catalogue-schema-and-media-kind.md)

---

## Context

Books and comics often carry embedded metadata (EPUB OPF, PDF info, ComicInfo.xml inside CBZ). Users also name files and folders deliberately. TTSPlayer must not let enrichment override filesystem identity or invent library structure.

Music already established path-based identity with enrichment precedence (ADR-021). Books/comics follow the same philosophy.

---

## Decision

1. **Stable item identity** remains path-derived (existing MD5-of-file-path pattern). Renames create new identities (same as music/video).
2. **Display title precedence:**
   1. Trusted embedded title when extraction is cheap, reliable, and non-empty
   2. Else filename stem
3. **Optional fields** (author, series, volume, page count): nullable enrichment only.
4. **Covers:** optional; placeholder on miss or load failure.
5. **No remote metadata APIs** in M6 (Goodreads, Comic Vine, etc.).
6. **No virtual series folders** constructed from metadata.

---

## Consequences

### Positive

- Predictable identity for reading progress keys
- Aligns with music/video mental model
- Graceful degradation when tags are absent

### Negative / risks

- Rename loses progress (documented limitation; multi-device/path-stable ids are future work)
- Embedded metadata quality varies — keep extraction best-effort

---

## Alternatives considered

| Alternative | Why not preferred |
|---|---|
| Content-hash identity | Expensive for large PDFs/EPUBs; breaks path-provider model |
| Always prefer ComicInfo/EPUB over filename | Can disagree with user’s naming; harder to debug |
| Cloud metadata enrichment | Out of M6 scope |

---

## Acceptance criteria

- [x] Progress keys by stable item id (ADR-027)
- [x] Title fallback never blanks the UI
- [x] Tests cover missing metadata; rename-as-new-id documented limitation
- [x] ADR-025 formal **Accepted** (2026-07-28)
