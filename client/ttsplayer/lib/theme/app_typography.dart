import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles for TTSPlayer.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // Font-size scale
  // ---------------------------------------------------------------------------

  static const double size11 = 11; // captions, technical detail, timestamps
  static const double size12 = 12; // banner text, chip labels, player time
  static const double size13 = 13; // dialog label rows, secondary actions
  static const double size14 = 14; // dashboard subtitle, section context
  static const double size16 = 16; // play/action buttons, card titles
  static const double size17 = 17; // player overlay title
  static const double size18 = 18; // completed-view item title
  static const double size22 = 22; // dashboard header

  // ---------------------------------------------------------------------------
  // Named styles — regular body
  // ---------------------------------------------------------------------------

  /// Standard body text on dark background.
  static const TextStyle body = TextStyle(color: AppColors.textHigh);

  /// De-emphasised secondary text.
  static const TextStyle bodyMuted = TextStyle(color: AppColors.textMedium);

  /// Very faint helper / placeholder text.
  static const TextStyle bodyFaint = TextStyle(color: AppColors.textLow);

  // ---------------------------------------------------------------------------
  // Caption / label styles
  // ---------------------------------------------------------------------------

  /// Caption — small supplementary info (11 px).
  static const TextStyle caption = TextStyle(
    color: AppColors.textLow,
    fontSize: size11,
  );

  /// Label used in banner messages and chip text (12 px).
  static const TextStyle label = TextStyle(
    color: AppColors.textHigh,
    fontSize: size12,
  );

  /// Label for muted / disabled UI text (12 px).
  static const TextStyle labelMuted = TextStyle(
    color: AppColors.textLow,
    fontSize: size12,
  );

  /// Value column in label-row dialogs (13 px).
  static const TextStyle labelRowValue = TextStyle(
    color: AppColors.textHigh,
    fontSize: size13,
  );

  /// Label column in label-row dialogs (13 px, de-emphasised).
  static const TextStyle labelRowLabel = TextStyle(
    color: AppColors.textLow,
    fontSize: size13,
  );

  // ---------------------------------------------------------------------------
  // Component-specific styles
  // ---------------------------------------------------------------------------

  /// Uppercase section header label (11 px, tracked).
  static const TextStyle sectionLabel = TextStyle(
    color: AppColors.textLow,
    fontSize: size11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Card title — folder name, media title (16 px semi-bold).
  static const TextStyle cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: size16,
    fontWeight: FontWeight.w600,
  );

  /// Card subtitle — item count, year, duration (12 px muted).
  static const TextStyle cardSubtitle = TextStyle(
    color: AppColors.textLow,
    fontSize: size12,
  );

  /// Dashboard page header (22 px bold).
  static const TextStyle dashboardHeader = TextStyle(
    color: AppColors.textPrimary,
    fontSize: size22,
    fontWeight: FontWeight.w700,
  );

  /// Dashboard sub-header / context text (14 px muted).
  static const TextStyle dashboardSub = TextStyle(
    color: AppColors.textMedium,
    fontSize: size14,
  );

  /// Section header (e.g. "Subfolders") — used inside folder screen.
  static const TextStyle sectionHeader = TextStyle(
    color: AppColors.textMedium,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  // ---------------------------------------------------------------------------
  // Player styles
  // ---------------------------------------------------------------------------

  /// Player time counter (12 px).
  static const TextStyle playerTime = TextStyle(
    color: AppColors.textHigh,
    fontSize: size12,
  );

  /// Player title overlay (17 px).
  static const TextStyle playerTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: size17,
    fontWeight: FontWeight.w600,
  );

  // ---------------------------------------------------------------------------
  // Monospace styles (paths, technical output)
  // ---------------------------------------------------------------------------

  /// Monospace path / file text (12 px, high contrast).
  static const TextStyle mono = TextStyle(
    color: AppColors.textHigh,
    fontSize: size12,
    fontFamily: 'monospace',
  );

  /// Monospace technical detail (11 px, low contrast).
  static const TextStyle monoFaint = TextStyle(
    color: AppColors.textLow,
    fontSize: size11,
    fontFamily: 'monospace',
  );
}
