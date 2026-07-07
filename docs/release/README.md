# Release

Shipping history and milestone snapshots for TTSPlayer.

---

## Current stable milestone

**M3.5 — Configurable HTTPS Media Platform**

| | |
|---|---|
| **Status** | ✅ Complete |
| **Tag** | `m3.5-complete` |
| **Validated** | TerraMaster TNAS with HTTPS (Caddy) |

→ [M3.5 release snapshot](./m3.5-media-access-complete.md#deployment-validation--2026-07-07)

---

## Current development branch

`m4-development`

---

## Current work

**M4 — Rich Media Libraries** — [roadmap spec](../roadmap/m4-rich-media-libraries.md)

---

## Project state

Milestones and development branches are tracked separately: a completed milestone is tagged and documented here; active work happens on a named branch until the next milestone ships.

| State | Value |
|---|---|
| Latest validated release | M3.5 (`m3.5-complete`) |
| Development branch | `m4-development` |
| Current work | M4 |

---

## Release notes

| Document | Milestone | Tag |
|---|---|---|
| [M3.5 — Configurable HTTPS Media Platform](./m3.5-media-access-complete.md) | M3.5 | `m3.5-complete` |
| [v0.3.0 — Personal Media Experience](./v0.3.0.md) | M3 | `v0.3.0` / `m3-complete` |
| [v0.4.0-dev — M3.5 development cycle](./v0.4.0-dev.md) | M3.5 (archived) | — |
| [Release history](./release-history.md) | All versions | — |

The `v0.4.0-dev` document is a **historical record** of the M3.5 cycle — not an active version line. See [M3.5 release snapshot](./m3.5-media-access-complete.md) for the validated outcome.

---

## When tagging a release

1. Update `release-history.md` with Added / Changed / Fixed
2. Bump `client/ttsplayer/pubspec.yaml` version when appropriate
3. Annotate git tag: `git tag -a mX-complete -m "..."` (or `vX.Y.Z` for semver releases)
4. Update milestone status in [`../roadmap/roadmap.md`](../roadmap/roadmap.md) and [`../../MILESTONES.md`](../../MILESTONES.md)
