# Roadmap Principles

How TTSPlayer evolves — not what features ship, but the rules that govern milestone decisions.

Use these principles when evaluating new ideas (human or AI): **Does this align with the principles below, or does it belong in a later milestone?**

→ [Milestone plan](./roadmap.md)  
→ [Mobile delivery](./mobile-delivery.md)

---

## Principles

### One codebase

All supported platforms use the **same Flutter application**. Mobile is not a separate app or a rewrite — it is a different access mode within the shared client.

### Local-first by default

Desktop continues to support **direct filesystem access** (local paths and UNC) without requiring a server. The NAS serving layer extends reach; it does not replace offline-capable local browsing on Windows.

### Network is additive

HTTP/HTTPS access **extends** the platform for devices that cannot mount drive letters. It does **not** replace local/UNC access on desktop. Both modes coexist in one codebase.

### Platform parity where practical

Features should be available across Windows, Android, and iOS unless a **platform limitation** genuinely prevents it (e.g. no Python subprocess scanner on mobile). Document the exception; do not silently drop parity.

### Content and platform evolve independently

**Media library types** (Images, Music, Books, etc.) are a separate axis from **networking** and **multi-device** capabilities. A milestone may advance one axis without blocking the other.

### Incremental delivery

Each milestone should leave the application in a **stable, releasable state** without depending on future milestones. Partial work is acceptable only when it is hidden, inert, or gracefully degraded — never when it breaks the current release.

---

## Milestone progression

High-level arc the project is designed to follow:

| Phase | Milestone | Focus |
|---|---|---|
| Foundation | M1–M2 | Build a solid, playable platform |
| Personal UX | M3 | Polished personal media experience (Windows-first) |
| Network access | M3.5 | Network-aware media access (same app, HTTPS mode) |
| Content expansion | M4–M6 | Supported content domains (images, music, books) |
| Multi-device | M7 | Seamless multi-device media ecosystem |

M1 is implicit pre-history (project bootstrap and catalogue model). M2 is the first tagged release (v0.2.0).

This structure is intended to stay coherent as the project grows. New milestones should slot into an existing phase or justify a new phase — not bypass the sequence (e.g. M7 before M3.5).

---

## Evaluation checklist

When a suggestion arrives, ask:

1. **One codebase?** — Would this fork the client or duplicate logic per platform?
2. **Local-first preserved?** — Does desktop still work without NAS HTTP?
3. **Additive network?** — Is HTTP optional on desktop, required only where filesystem access is unavailable?
4. **Parity?** — If we build it for one platform, should others get it too?
5. **Right axis?** — Is this content (M4–M6), network (M3.5), or multi-device (M7)?
6. **Releasable?** — Can we ship M3 (or current milestone) cleanly if this lands half-done?

If any answer is wrong for the **current** milestone, defer or split the work.
