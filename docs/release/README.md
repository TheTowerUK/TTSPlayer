# Release

Shipping history and milestone snapshots for TTSPlayer.

---

## Current stable milestone

**M5 — Music**

| | |
|---|---|
| **Status** | ✅ Complete |
| **Tag** | `v0.6.0` / `m5-complete` |
| **Snapshot** | [M5 complete](./m5-complete.md) |

---

## Current development focus

**M6 — Books & Comics** — Closure audit complete (2026-07-28); release finalisation pending.

→ [M6 closure audit](../roadmap/m6-closure-report.md) · [M6 plan](../roadmap/m6-plan.md) · [v0.7.0-dev tracker](./v0.7.0-dev.md) · [Books & comics architecture](../architecture/books-comics.md)

Deferred M5 music features (playlists, shuffle/repeat, favourites redesign, etc.) remain a **separate backlog** — not silent M6 scope ([m5-complete.md §4](./m5-complete.md)).

**Branch:** `m6-development`

---

## Project state

Milestones and development branches are tracked separately: a completed milestone is tagged and documented here; active work happens on a named branch until the next milestone ships.

| State | Value |
|---|---|
| Latest release | M5 — `v0.6.0` — [m5-complete.md](./m5-complete.md) |
| Previous release | M4 — `v0.5.0` — [m4-release-summary.md](./m4-release-summary.md) |
| Current work | M6 Phase 6.0 — Planning and Architecture |
| Development branch | `m6-development` |
| Previous validated tag | `v0.6.0` / `m5-complete` |

---

## Release notes

| Document | Milestone | Tag |
|---|---|---|
| [v0.7.0-dev — M6 development tracker](./v0.7.0-dev.md) | M6 (active) | — |
| [M5 — Music](./m5-complete.md) | M5 | `v0.6.0` / `m5-complete` |
| [M4 — User Experience and Platform Integration](./m4-release-summary.md) | M4 | `v0.5.0` / `m4-complete` |
| [v0.5.0-dev — M4/M5 development cycle notes](./v0.5.0-dev.md) | M4–M5 (archive) | — |
| [M4 foundation snapshot — Phases 4.1–4.3](./m4-foundation-complete.md) | M4 (development archive) | — |
| [M3.5 — Configurable HTTPS Media Platform](./m3.5-media-access-complete.md) | M3.5 | `m3.5-complete` |
| [v0.3.0 — Personal Media Experience](./v0.3.0.md) | M3 | `v0.3.0` / `m3-complete` |
| [v0.4.0-dev — M3.5 development cycle](./v0.4.0-dev.md) | M3.5 (archived) | — |
| [Release history](./release-history.md) | All versions | — |

The `v0.4.0-dev` and `v0.5.0-dev` documents are **historical records** of development cycles — not active version lines.

---

## When tagging a release

1. Update `release-history.md` with Added / Changed / Fixed
2. Bump `client/ttsplayer/pubspec.yaml` version when appropriate
3. Annotate git tag: `git tag -a mX-complete -m "..."` (or `vX.Y.Z` for semver releases)
4. Update milestone status in [`../roadmap/roadmap.md`](../roadmap/roadmap.md) and [`../../MILESTONES.md`](../../MILESTONES.md)
