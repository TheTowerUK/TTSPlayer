# TTSPlayer Design System

Single source of truth for visual identity, component behaviour, and interaction patterns.

**Implementation:** Flutter tokens live in `client/ttsplayer/lib/theme/` (barrel: `app_theme.dart`). Sprint 3 (Artwork) and Sprint 4 (UI Polish) align code to this document — the doc leads; tokens follow.

→ [Design folder overview](./README.md)  
→ [M3 Personal Media Experience](../roadmap/m3-personal-media-experience.md)

---

## Design philosophy

TTSPlayer sits deliberately **between a file explorer and a commercial streaming platform**:

| | File explorer | **TTSPlayer** | Streaming platform |
|---|---|---|---|
| Tone | Technical | Personal | Commercial |
| Focus | File-centric | Library-centric | Recommendation-centric |
| Navigation | Folder tree | Media experience | Marketing experience |
| Motivation | Utility | Ownership | Subscription |

The middle column is TTSPlayer's identity: **your libraries, your folders, your media** — framed as a calm personal platform, not Windows Explorer and not Netflix.

---

## Core principles

### 1. Content first

The media is always the focus. The UI frames content; it does not compete with it.

- Large artwork where available
- Minimal chrome
- Generous spacing
- Clear hierarchy

**Never feel like Windows Explorer.** No dense column trees, no technical clutter on primary surfaces, no path-first layouts on the dashboard.

### 2. Calm interface

A media platform should feel relaxing.

- No flashing or pulsing accents
- No heavy gradients
- No glassmorphism everywhere
- No "gaming" UI (neon, aggressive glow, busy borders)

Status and errors are visible but restrained — informative, not alarming.

### 3. Local-first

Unlike Plex or Netflix, TTSPlayer does not advertise or recommend content.

The dashboard says:

> **These are your libraries.**

Not:

> Here's what we recommend.

Copy, layout, and empty states reflect **ownership** and **filesystem truth** — folder names from the catalogue, paths when helpful, rescan/refresh as recovery — never invented categories or promotional rows.

---

## Colour palette

Neutral dark base. Accent and semantic colours used **sparingly**.

### Surfaces

| Role | Hex | Usage |
|---|---|---|
| **Background** | `#111315` | Primary application background (Scaffold) |
| **Secondary panel** | `#1B1F23` | Cards, list rows |
| **Raised / hover** | `#252A31` | Card hover, elevated panels |
| **Border** | `#323943` | Subtle dividers and card outlines |

Elevation is expressed primarily through **colour steps**, not drop shadows.

### Accent and semantic

| Role | Hex | Usage |
|---|---|---|
| **Primary accent** | `#4C8DFF` | Links, focus rings, progress, primary actions — use sparingly |
| **Success** | `#39C16C` | Resume, healthy state, Live NAS connected |
| **Warning** | `#F4B942` | Fallback NAS, scan notices, caution |
| **Error** | `#D9534F` | Unavailable media, blocking errors |

### Text (on dark surfaces)

Use an opacity ladder for hierarchy — avoid pure white everywhere:

| Level | Approx. | Usage |
|---|---|---|
| Primary | 100% white | Titles, active labels |
| High | ~70% | Body text |
| Medium | ~54% | Secondary metadata |
| Low | ~38% | Captions, placeholders |
| Disabled | ~24% | Inactive controls |

### Implementation map

| Design token | Dart constant (target) | Notes |
|---|---|---|
| Background | `AppColors.background` | Migrate to `#111315` in Sprint 3/4 |
| Card | `AppColors.card` | Target `#1B1F23` |
| Card hover | `AppColors.cardHover` | Target `#252A31` |
| Border | `AppColors.border` | Target `#323943` |
| Primary | `AppColors.primary` | Target `#4C8DFF` |
| Success | `AppColors.success` | Target `#39C16C` |

Current shipped tokens may differ slightly; **this table is canonical** for forward work.

---

## Typography

Clean, readable, few sizes. No decorative fonts.

| Role | Size | Weight | Usage |
|---|---|---|---|
| **Page title** | 32–36 px | Bold (700) | Dashboard welcome, major screen titles |
| **Section** | 22–24 px | SemiBold (600) | Section headers (human-readable, not only uppercase labels) |
| **Card title** | 18 px | Medium (500–600) | Library name, media title on cards |
| **Metadata** | 14 px | Regular (400) | Counts, duration, folder context |
| **Caption** | 12 px | Regular, muted | Timestamps, extensions, helper text |

### Section labels

Dashboard section labels may use **uppercase tracked captions** (11 px) for scanability — e.g. `LIBRARIES`, `CONTINUE WATCHING`. Pair with the section size above for hierarchy, not as the only heading style.

### Implementation map

| Role | Dart style |
|---|---|
| Page title | `AppTypography.dashboardHeader` (extend to 32 px in polish sprint) |
| Card title | `AppTypography.cardTitle` (target 18 px) |
| Metadata | `AppTypography.dashboardSub`, `AppTypography.cardSubtitle` |
| Caption | `AppTypography.caption`, `AppTypography.sectionLabel` |

---

## Spacing

Single rhythm — **multiples of 4**. No arbitrary one-off values in new UI.

| Name | px | Token |
|---|---|---|
| Tiny | 4 | `AppSpacing.xs` |
| Small | 8 | `AppSpacing.sm` |
| Normal | 16 | `AppSpacing.base` |
| Large | 24 | `AppSpacing.xl` |
| Section | 32 | `AppSpacing.xxl` / `AppSpacing.section` |
| Page | 40 | Add `AppSpacing.page` in token migration |

**Grid gaps:** use `AppSpacing.gridGap` (14 px) or round to 16 px when touching new layouts.

**Card inner padding:** 20 px (`AppSpacing.cardPremium`) — close to Normal + Small; acceptable.

---

## Corners

Two radii only — do not introduce ad-hoc rounding.

| Element | Radius |
|---|---|
| **Cards, panels, inputs** | **12 px** (`AppRadius.card`) |
| **Hero / large continue-watching** | **16 px** (`AppRadius.dialog`) |
| **Chips, badges** | 6 px (`AppRadius.chip`) — exception for small controls |

---

## Shadows

**Very subtle.** Prefer elevation through surface colour (`#111315` → `#1B1F23` → `#252A31`).

- No large drop shadows on cards
- Player overlay may use scrim (`AppColors.playerOverlay`) — not decorative shadow stacks

---

## Cards

Cards are the **primary design language**. Three tiers:

### Library card

Top-level folder from the catalogue — not scan history, not recommendations.

```
┌────────────────────┐
│  ██████████████████│  ← artwork / icon area (16:9 or folder art, Sprint 3+)
│  Videos            │
│  1,542 items       │
│  Browse →          │
└────────────────────┘
```

- **Component:** `LibraryCard` / `TtsFolderCard`
- Item count from catalogue data
- Explicit **Browse** action
- Sprint 3+: top half accepts folder/library artwork; placeholder icon until then

### Media card

Grid item in folder views and search results (when poster layout applies).

```
┌─────────────┐
│ ██████████  │  ← poster (2:3 video default)
│ Movie Title │
│ 2h 11m      │
│ ██████░░░░  │  ← resume bar when in progress
│ Resume      │
└─────────────┘
```

- **Component:** `TtsMediaCard`
- Title, optional year/duration metadata
- Resume progress when `PlaybackService` has saved position
- Non-playable status badge — item remains visible per status model

### Hero card

**One per dashboard context** — Continue Watching.

- Large, wide, **16:9** artwork area
- Title + progress + Resume
- **Component:** `ContinueWatchingSection` row cards; upgrade to full hero in Sprint 3

---

## Artwork aspect ratios

Standardise now; implement in Sprint 3 (Artwork).

| Content | Layout | Ratio | Notes |
|---|---|---|---|
| Movie | Poster | **2:3** | Default video grid |
| TV | Poster | **2:3** | Same as movie unless user folder implies otherwise |
| Music | Square | **1:1** | Future M5 |
| Books | Poster | **2:3** | Future M6 |
| Games | Landscape | **16:9** | Box art / hero |
| Folders / libraries | Landscape | **16:9** | Library card header |
| Continue Watching | Landscape | **16:9** | Hero row |

**Grid:** `AppSpacing.gridAspectMedia` (0.72 ≈ 2:3 portrait) — keep aligned to poster ratio.

Missing artwork: **neutral placeholder** (`errorBuilder` / placeholder widget) — never hide the item.

### Known visual debt (M4.5 artwork pipeline — deferred UX polish)

**Not a functional defect.** Documented for a post-M4 dashboard UX pass; not in Phase 4.7 implementation scope.

| Area | Observation |
|---|---|
| **Continue Watching** | Fixed hero card height (`CardLayout.continueWatchingCardHeight`) can stretch artwork when M4.5 decode/cached candidates do not match the 16:9 band — reduce stretching via aspect-preserving `BoxFit` and/or card dimension review |
| **Dashboard sections overall** | Libraries, Continue Watching, Recently Added, and Featured Folders use different card widths/heights/ratios — future pass should unify spacing and artwork presentation |

See [M4 Phase 4.7 observations](../roadmap/m4-plan.md#phase-47--release-and-documentation) in the roadmap.

---

## Icons

- **Style:** Material outlined icons only — do not mix filled and outlined in the same view
- **Size scale:** `AppIcons` (sm / md / lg / hero)
- **Colour:** `AppColors.textLow` default; `AppColors.primary` on hover/active

### Library icon hints (cosmetic only)

Icons suggest content type; **labels always come from folder names** (filesystem is truth). Never branch business logic on these names.

| Folder flavour (examples) | Icon hint |
|---|---|
| Videos | `movie_outlined` |
| Music | `music_note_outlined` |
| Images | `photo_outlined` |
| Documents | `description_outlined` |
| Literature | `menu_book_outlined` |
| Games | `sports_esports_outlined` |
| Archives | `archive_outlined` |
| Default | `folder_outlined` |

---

## Navigation

Linear, shallow hierarchy — user always knows where they are.

```
Dashboard → Search
         → Libraries (top-level folders)
              → Library (folder tree)
                   → Item (detail)
                        → Player
```

- **No deep nesting** beyond the real folder tree
- **Home** control returns to Dashboard
- **Search** is global (AppBar + dashboard quick-search)
- **Back** follows Navigator stack — no hidden state

| Screen | AppBar title | Home button |
|---|---|---|
| Dashboard | TTSPlayer | Hidden |
| Search | Search | Shown |
| Folder | Folder name | Shown |
| Item detail | Item title | Shown |
| Player | (minimal chrome) | Back / exit |

---

## Animations

Restrained — functional, not decorative.

| Interaction | Duration | Curve |
|---|---|---|
| Fade in/out | 150–200 ms | `easeOut` / `easeIn` |
| Card hover colour | 100 ms | `easeInOut` |
| Progress bar / seek | 200 ms | linear |
| Card press scale | 120 ms | `AppAnimations.fast` |

**Avoid:** bounce, elastic, long parallax, autoplay motion.

**Implementation:** `AppAnimations.fast` (120 ms), `AppAnimations.standard` (220 ms) — tighten standard to 200 ms in polish if needed.

---

## Loading states

Prefer **skeleton cards** and **artwork placeholders** over spinners.

| Context | Pattern |
|---|---|
| Dashboard sections | Skeleton rectangles matching card aspect ratios |
| Artwork | Neutral block + icon (`Icons.movie_outlined`) |
| Full-page catalogue load | Single `LoadingCard` with message — acceptable |
| Player buffer | Inline progress on seek bar — not fullscreen spinner |

**Avoid:** multiple simultaneous `CircularProgressIndicator`s on one screen.

---

## Empty states

Helpful, local-first copy — not generic developer messages.

| Avoid | Prefer |
|---|---|
| "No results" | "No matches for «query»" + suggest clearing filters |
| "Error" | What failed + concrete recovery (Refresh catalogue, Check NAS path) |
| "Empty" | "No videos yet" + "Add media to `Y:\Media\Videos` and run a scan" |

**Component:** `EmptyState` — icon, title, optional subtitle with **actionable** next step.

**Search:** distinguish before typing / no results / catalogue unavailable (see `SearchEmptyState`).

**Recently Added (Sprint 1):** honest empty state until indexer provides `added_at` metadata.

---

## Dashboard layout

Content-forward; minimal chrome.

```
┌──────────────────────────────────────┐
│ TTSPlayer              [Search …]  │
├──────────────────────────────────────┤
│ Welcome back          [Live NAS]     │
│ [ Search your library…            ]  │  ← opens Search (no inline search)
│                                      │
│ CONTINUE WATCHING                    │
│ ████████████████████████████         │  ← hero / wide cards
│                                      │
│ LIBRARIES                            │
│ ┌──────┐ ┌──────┐ ┌──────┐          │
│ │      │ │      │ │      │          │
│ └──────┘ └──────┘ └──────┘          │
│                                      │
│ RECENTLY ADDED                       │
│                                      │
│ RECENT ACTIVITY              [▼]     │  ← collapsed by default
│                                      │
│ STORAGE STATUS                       │
└──────────────────────────────────────┘
```

Rules:

- Libraries = **top-level catalogue folders only** (not scan history)
- Recent Activity = **collapsible** scan history panel
- Storage Status = Live NAS / Fallback NAS / Demo — consistent with Library Manager

---

## Component checklist (M3)

| Component | Status | Sprint |
|---|---|---|
| Library card | Shipped (`LibraryCard`) | Sprint 1 |
| Media card | Shipped (`TtsMediaCard`) | M2 |
| Hero / Continue Watching | Basic row cards | Sprint 1; artwork Sprint 3 |
| Search result row | Shipped (`SearchResultRow`) | Sprint 2 |
| Catalogue source chip | Shipped (`CatalogueSourceChip`) | Sprint 1 |
| Poster / thumbnail loading | Placeholder only | Sprint 3 |
| Skeleton loaders | Not yet | Sprint 3–4 |
| Token colour migration | Partial | Sprint 4 |

---

## Do not

- Hardcode media categories ("Movies", "TV Shows") in UI copy or layout
- Hide items because metadata or artwork is missing
- Use recommendation-style rows ("Because you watched…")
- Introduce glass/blur-heavy panels or gradient backgrounds
- Add persistence-driven UI patterns that contradict local-first (user-curated collections deferred to a future milestone; Sprint 4 uses catalogue-driven Featured Folders only)
- Mix icon families or arbitrary spacing values in new screens

---

## Related documents

| Document | Purpose |
|---|---|
| [Roadmap principles](../roadmap/principles.md) | How the product evolves |
| [M3 Personal Media Experience](../roadmap/m3-personal-media-experience.md) | Milestone scope and sprints |
| [Graceful degradation](../../.cursor/rules/graceful-degradation.mdc) | Failure-mode UI rules (workspace) |
| [Catalogue principle](../../.cursor/rules/catalogue-principle.mdc) | Folder names from data only |

When implementing UI, **read this document first**, then apply tokens in `lib/theme/`. If code and doc disagree, update code in a focused token PR or note the exception here.

---

## Design evolution rules

The design system defines the **canonical visual language** for TTSPlayer — the visual equivalent of [roadmap principles](../roadmap/principles.md).

### Extend before inventing

New UI should **reuse existing design tokens** wherever possible:

- Colours from `AppColors` (and this palette)
- Spacing from `AppSpacing`
- Typography from `AppTypography`
- Radii from `AppRadius`
- Card patterns already defined here (library, media, hero)

Do not introduce one-off colours, spacing values, type scales, or card styles inline in widgets.

### Update the system first

When a new visual pattern is **genuinely required** — a new card tier, a new semantic colour, a new aspect ratio — **update this document first**, then implement in `lib/theme/` and shared widgets.

The doc leads; code follows.

### Decision checklist

Before adding a new style, ask:

1. **Does an existing token or component already cover this?**
2. **Can I compose existing cards/spacing instead of a new pattern?**
3. **If not, what single addition to the design system would make this reusable?**

This keeps the UI consistent as the platform grows through M3 sprints and beyond.
