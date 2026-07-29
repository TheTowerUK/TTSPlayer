# Post-Milestone UX and Workflow Review

**Status:** Tracked — not blocking M6 release or core milestone closure  
**Recorded:** 2026-07-29  
**Review timing:** After core milestone phases are complete; before or during post-release polish  
**Classification:** UX and workflow refinements — **not** implementation blockers

→ [M6 closure audit](./m6-closure-report.md) · [M6 plan](./m6-plan.md) · [Roadmap principles](./principles.md)

---

## Purpose

Capture cross-cutting UX and workflow observations identified during M6 development and closure. These items do not block remaining core implementation, release finalisation, or milestone sign-off. They should be reviewed as a batch once core phases are complete and prioritised against other post-release work.

---

## Review checklist

| # | Area | Status | Priority |
|---|---|---|---|
| 1 | [Continue Watching image presentation](#1-continue-watching-image-presentation) | Open | Post-release |
| 2 | [Literature folder rescan option](#2-literature-folder-rescan-option) | Open | Post-release |
| 3 | [Item opening and playback workflow](#3-item-opening-and-playback-workflow) | Open | Post-release |

---

## 1. Continue Watching image presentation

### Observation

Images displayed within the **Continue Watching** section are stretched and do not retain their intended aspect ratio.

### Required review

Update the image presentation so that artwork is displayed consistently without distortion, cropping only where appropriate.

### Expected outcome

Continue Watching artwork maintains the correct aspect ratio and follows the same presentation rules as equivalent artwork elsewhere in the application.

### Likely touchpoints

- Continue Watching / dashboard card widgets
- Shared artwork/thumbnail layout helpers used on folder and detail surfaces

---

## 2. Literature folder rescan option

### Observation

There is currently **no folder-level rescan option** available for literature libraries, including book and comic folders.

### Required review

Provide an equivalent rescan action for literature folders, consistent with the rescan capability available for other supported media libraries.

### Expected outcome

Users can initiate a rescan directly against an individual book or comic folder without requiring a full catalogue or library rescan.

### Likely touchpoints

- `FolderScreen` rescan affordances
- `ScannerService` / indexer scope for subtree rescan
- Folder action parity with video/music library patterns

---

## 3. Item opening and playback workflow

### Observation

Opening or playing an item currently requires **one unnecessary navigation layer**.

Once the application has presented a specific item that can be opened or played, selecting that item navigates to a separate detail screen where the user must select **Open** or **Play** again.

### Required review

Review whether selecting an actionable item should open or play directly.

The intermediate detail screen should **only remain** where it provides meaningful additional choices or information, such as:

- Selecting an episode, chapter, track, edition, or version
- Choosing between multiple playback or opening actions
- Viewing information required before starting the item
- Accessing secondary actions that justify a dedicated detail screen

### Expected outcome

Single-action items open or play directly when selected, reducing unnecessary navigation. Detail screens remain only where they provide additional user value.

### Likely touchpoints

- Folder/search/dashboard card tap routing
- `ItemDetailScreen` entry conditions by `media_kind`
- Video Play vs book Open vs comic Open vs music track play paths

---

## Scope boundaries

| In scope for this review | Out of scope |
|---|---|
| Presentation and navigation UX | New reader features (bookmarks, annotations) |
| Folder-level rescan parity | Full catalogue schema changes |
| Direct-open vs detail-screen routing policy | Cloud sync or multi-device resume (M7) |

---

## Disposition policy

- Items remain **open** until a dedicated implementation task is approved.
- None of these items block M6 milestone closure, release tagging, or the Phase 6.2 runtime harness refresh.
- Implementation should follow existing stack conventions (`ChangeNotifier` + `provider`, folder-first catalogue, graceful degradation).
