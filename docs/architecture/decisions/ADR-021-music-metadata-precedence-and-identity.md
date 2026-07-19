# ADR-021: Music Metadata Precedence and Identity



**Status:** Proposed

**Date:** 2026-07-19

**Milestone:** M5 Phase 5.0 / 5.1

**Authors:** M5 planning pass



---



## Context



Music files carry embedded tags of varying quality. Folder layouts differ (`Artist/Album/tracks`, flat dumps, compilations). TTSPlayer must group tracks into **artists** and **albums** for browsing without renaming filesystem paths or inventing catalogue folders.



Track **`id`** remains path-derived (stable across rescans). Album and artist identities are **derived views** for UI and search — not persisted filesystem nodes.



---



## Decision



1. **Track identity:** unchanged — md5(path) `id` from indexer.



2. **Metadata precedence** (highest wins):



   | Field | Order |

   |---|---|

   | Track title | embedded tag title → `track_title` field → filename stem |

   | Artist | embedded artist → folder heuristic → `"Unknown Artist"` |

   | Album | embedded album → folder heuristic → `"Unknown Album"` |

   | Album artist | embedded album artist → artist → folder heuristic |



3. **Grouping keys** (normalized: trim + case-fold for comparison; original casing for display):



   - **Artist browse key:** normalized `artist`, falling back to `album_artist`

   - **Album browse key:** `(normalized album_artist or artist, normalized album name, disc_number default 1)`



4. **Compilations:** when tag `compilation` is true or album artist matches various-artists sentinel list (defined in 5.1 spec), artist browse uses **Various Artists**; album browse still keyed by album name + album artist.



5. **Filename vs tag conflict:** tags determine grouping and display title; filename is not shown as alternate album name.



6. **Missing tags never exclude** an item from the catalogue — emit with fallbacks; status `available` when file readable.



---



## Rationale



- Tags reflect user intent for music libraries more often than folder names.

- Folder heuristics rescue untagged rips without manual intervention.

- Derived keys avoid duplicate album nodes for the same folder path split.

- Stable track `id` keeps favourites and resume keys valid across metadata-only rescans.



---



## Consequences



### Positive



- Predictable browse trees for common layouts

- Honest handling of unknown metadata

- Search can index both tags and filenames



### Negative



- Normalization rules may merge distinct artists (`The Beatles` vs `Beatles`) — document limitation

- Same album in two folders appears twice (filesystem truth)



### Neutral



- Heuristic tuning may iterate in 5.1 without schema bump if fields already present



---



## Alternatives considered



### Alternative A — Filesystem folder names always win



**Rejected because:** Flat or inconsistently named folders are common; tags are often correct.



### Alternative B — Persist album/artist entities in catalogue JSON as folders



**Rejected because:** Violates catalogue principle — would invent structure not on disk.



---



## Related documents



- [music.md](../music.md) · §5–§7

- [ADR-020](./ADR-020-music-catalogue-schema-and-media-kind.md)

- [Catalogue principle](../../../.cursor/rules/catalogue-principle.mdc)
