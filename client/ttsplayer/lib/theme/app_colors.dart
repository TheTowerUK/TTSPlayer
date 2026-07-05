import 'package:flutter/material.dart';

/// Every colour used in TTSPlayer in one place.
///
/// Palette aligned to [docs/design/design-system.md].
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces (dark-to-light depth)
  // ---------------------------------------------------------------------------

  /// Page / Scaffold background — `#111315`.
  static const Color background = Color(0xFF111315);

  /// AppBar, navigation surface — one step above background.
  static const Color surface = Color(0xFF161A1E);

  /// Card and dialog background — `#1B1F23`.
  static const Color card = Color(0xFF1B1F23);

  /// Card background on desktop hover — `#252A31`.
  static const Color cardHover = Color(0xFF252A31);

  /// Card background on desktop press.
  static const Color cardPressed = Color(0xFF1A1E23);

  /// Chips, metadata rows, thumbnail placeholder fill.
  static const Color chip = Color(0xFF2A3038);

  /// LinearProgressIndicator track.
  static const Color progressTrack = Color(0xFF323943);

  /// Subtle card border — `#323943`.
  static const Color border = Color(0xFF323943);

  /// Section divider.
  static const Color divider = Color(0xFF2A3038);

  // ---------------------------------------------------------------------------
  // Accent
  // ---------------------------------------------------------------------------

  /// Primary accent — `#4C8DFF`.
  static const Color primary = Color(0xFF4C8DFF);

  /// Lighter primary — info text on dark backgrounds.
  static const Color primaryLight = Color(0xFF7AABFF);

  // ---------------------------------------------------------------------------
  // Semantic / status
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF39C16C);
  static const Color error = Color(0xFFD9534F);
  static const Color warning = Color(0xFFF4B942);
  static const Color caution = Color(0xFFF4B942);

  // ---------------------------------------------------------------------------
  // Banner backgrounds
  // ---------------------------------------------------------------------------

  static const Color infoBannerBg = Color(0xFF152238);
  static const Color errorBannerBg = Color(0xFF3D1A1A);
  static const Color warningBannerBg = Color(0xFF2D2200);

  // ---------------------------------------------------------------------------
  // Item-status badge colours
  // ---------------------------------------------------------------------------

  static const Color statusMissing = Color(0xFFD9534F);
  static const Color statusUnavailable = Color(0xFFF4B942);
  static const Color statusRestricted = Color(0xFF9B7EDE);
  static const Color statusDefault = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Text on dark backgrounds (opacity ladder)
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Colors.white;
  static const Color textHigh = Colors.white70;
  static const Color textMedium = Colors.white54;
  static const Color textLow = Colors.white38;
  static const Color textDisabled = Colors.white24;
  static const Color textFaint = Colors.white12;

  // ---------------------------------------------------------------------------
  // Player
  // ---------------------------------------------------------------------------

  static const Color playerBg = Colors.black;
  static const Color playerOverlay = Color(0xCC000000);
}
