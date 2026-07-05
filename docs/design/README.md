# Design

UI framework, design tokens, and interaction patterns for TTSPlayer.

## Design system

→ **[design-system.md](./design-system.md)** — single source of truth for colour, typography, cards, spacing, motion, empty states, and component behaviour (Sprint 3+).

## Implementation

The Flutter client implements tokens via:

```
client/ttsplayer/lib/theme/app_theme.dart
```

Re-exports: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIcons`, `AppAnimations`, and `AppTheme.dark`.

Sprint 3 (Artwork) and Sprint 4 (UI Polish) align these constants to [design-system.md](./design-system.md).

## Principles (summary)

- **Content first** — media and libraries are the focus; minimal chrome
- **Calm interface** — dark, neutral, no flashy or gaming UI
- **Local-first** — your libraries, not recommendations
- Material 3 built-ins only — no heavy component libraries
- TV-friendly layouts — large tap targets, grid-first browsing
- Graceful degradation — missing posters and metadata never block playback
