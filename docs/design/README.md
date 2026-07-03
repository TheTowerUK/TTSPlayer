# Design

UI framework, design tokens, and interaction patterns for TTSPlayer.

## Current system

The Flutter client uses a single design-system barrel:

```
client/ttsplayer/lib/theme/app_theme.dart
```

Re-exports: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIcons`, `AppAnimations`, and `AppTheme.dark`.

## Principles

- Material 3 built-ins only — no heavy component libraries
- TV-friendly layouts — large tap targets, grid-first browsing
- Graceful degradation — missing posters and metadata never block playback
- Premium dark theme — consistent cards, banners, and player chrome

Design specs and component notes will be added here as M3 (Library Experience) work begins.
