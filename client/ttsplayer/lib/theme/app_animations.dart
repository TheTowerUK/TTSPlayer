import 'package:flutter/material.dart';

/// Animation durations, curves, and scale constants for TTSPlayer.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppAnimations {
  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// Micro-interaction — card press scale, icon swap (120 ms).
  static const Duration fast = Duration(milliseconds: 120);

  /// Standard transition — hover colour, fade, slide (220 ms).
  static const Duration standard = Duration(milliseconds: 220);

  /// Slower transition — page fade, dialog entrance (380 ms).
  static const Duration slow = Duration(milliseconds: 380);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Used for enter/appear transitions.
  static const Curve enter = Curves.easeOut;

  /// Used for exit/disappear transitions.
  static const Curve exit = Curves.easeIn;

  /// Used for hover and colour-shift transitions.
  static const Curve smooth = Curves.easeInOut;

  // ---------------------------------------------------------------------------
  // Scale
  // ---------------------------------------------------------------------------

  /// Card press-down scale factor (96 % of normal size).
  static const double pressScale = 0.96;

  /// Hover lift scale factor (102 % of normal size — subtle).
  static const double hoverScale = 1.02;
}
