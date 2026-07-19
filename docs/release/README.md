# Release

Shipping history and milestone snapshots for TTSPlayer.

---

## Current stable milestone

**M4 — User Experience and Platform Integration**

| | |
|---|---|
| **Status** | ✅ Complete |
| **Tag** | `v0.5.0` / `m4-complete` |
| **Snapshot** | [M4 release summary](./m4-release-summary.md) |

---

## Current development focus

**M5 — Music** — Phase **5.2** next (5.1 complete 2026-07-19) · catalogue v3 and scanner `0.4.0` implemented

→ [M5 plan](../roadmap/m5-plan.md) · [Phase 5.1 spec](../roadmap/m5-phase-5.1-music-catalogue-metadata.md) · [Music architecture](../architecture/music.md)

**Branch:** `m4-development`

---

## Project state

Milestones and development branches are tracked separately: a completed milestone is tagged and documented here; active work happens on a named branch until the next milestone ships.

| State | Value |
|---|---|
| Latest release | M4 — `v0.5.0` — [release summary](./m4-release-summary.md) |
| Current work | M5 Phase 5.2 — [M5 plan](../roadmap/m5-plan.md) |
| Development branch | `m4-development` |
| Previous validated tag | `m3.5-complete` |

---

## Release notes

| Document | Milestone | Tag |
|---|---|---|
| [M4 — User Experience and Platform Integration](./m4-release-summary.md) | M4 | `v0.5.0` / `m4-complete` |
| [v0.5.0-dev — M4 development cycle](./v0.5.0-dev.md) | M4 (archived cycle) | — |
| [M4 foundation snapshot — Phases 4.1–4.3](./m4-foundation-complete.md) | M4 (development archive) | — |
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

For active M4 sub-phases, add a **Phase retrospective** (what went well / lessons) to [v0.5.0-dev.md](./v0.5.0-dev.md) at closure — before starting the next phase.
