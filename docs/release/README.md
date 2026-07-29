# Release

Shipping history and milestone snapshots for TTSPlayer.

---

## Current stable milestone

**M6 — Books & Comics**

| | |
|---|---|
| **Status** | ✅ Complete |
| **Tag** | `v0.7.0` / `m6-complete` |
| **Snapshot** | [M6 complete](./m6-complete.md) |

---

## Previous stable milestone

**M5 — Music**

| | |
|---|---|
| **Status** | ✅ Complete |
| **Tag** | `v0.6.0` / `m5-complete` |
| **Snapshot** | [M5 complete](./m5-complete.md) |

---

## Project state

| State | Value |
|---|---|
| Latest release | M6 — `v0.7.0` — [m6-complete.md](./m6-complete.md) |
| Previous release | M5 — `v0.6.0` — [m5-complete.md](./m5-complete.md) |
| Development branch | `m7-development` (planning) |
| Next milestone | M7 — [m7-plan.md](../roadmap/m7-plan.md) · [v0.8.0-dev.md](./v0.8.0-dev.md) |

Deferred M5 music features (playlists, shuffle/repeat, favourites redesign, etc.) remain a **separate backlog** — not silent M6 scope ([m5-complete.md §4](./m5-complete.md)).

Post-milestone UX refinements: [post-milestone-ux-workflow-review.md](../roadmap/post-milestone-ux-workflow-review.md).

---

## Release notes

| Document | Milestone | Tag |
|---|---|---|
| [v0.8.0-dev — M7 development tracker](./v0.8.0-dev.md) | M7 (planning) | — |
| [M6 — Books & Comics](./m6-complete.md) | M6 | `v0.7.0` / `m6-complete` |
| [v0.7.0-dev — M6 development tracker (archive)](./v0.7.0-dev.md) | M6 (development cycle) | — |
| [M5 — Music](./m5-complete.md) | M5 | `v0.6.0` / `m5-complete` |
| [M4 — User Experience and Platform Integration](./m4-release-summary.md) | M4 | `v0.5.0` / `m4-complete` |
| [v0.5.0-dev — M4/M5 development cycle notes](./v0.5.0-dev.md) | M4–M5 (archive) | — |
| [M4 foundation snapshot — Phases 4.1–4.3](./m4-foundation-complete.md) | M4 (development archive) | — |
| [M3.5 — Configurable HTTPS Media Platform](./m3.5-media-access-complete.md) | M3.5 | `m3.5-complete` |
| [v0.3.0 — Personal Media Experience](./v0.3.0.md) | M3 | `v0.3.0` / `m3-complete` |
| [v0.4.0-dev — M3.5 development cycle](./v0.4.0-dev.md) | M3.5 (archived) | — |
| [Release history](./release-history.md) | All versions | — |

The `v0.4.0-dev`, `v0.5.0-dev`, `v0.7.0-dev`, and active `v0.8.0-dev` documents are **development cycle trackers** — historical archives once the milestone ships.

---

## When tagging a release

1. Update `release-history.md` with Added / Changed / Fixed
2. Bump `client/ttsplayer/pubspec.yaml` version when appropriate
3. Annotate git tag: `git tag -a mX-complete -m "..."` (or `vX.Y.Z` for semver releases)
4. Update milestone status in [`../roadmap/roadmap.md`](../roadmap/roadmap.md) and [`../../MILESTONES.md`](../../MILESTONES.md)
