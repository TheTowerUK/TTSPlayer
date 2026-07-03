import 'package:flutter/material.dart';

/// Every colour used in TTSPlayer in one place.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces (dark-to-light depth)
  // ---------------------------------------------------------------------------

  /// Page / Scaffold background.
  static const Color background = Color(0xFF0E0E1A);

  /// AppBar, navigation surface.
  static const Color surface = Color(0xFF161626);

  /// Card and dialog background.
  static const Color card = Color(0xFF1C1C2E);

  /// Card background on desktop hover.
  static const Color cardHover = Color(0xFF222238);

  /// Card background on desktop press.
  static const Color cardPressed = Color(0xFF181828);

  /// Chips, metadata rows, thumbnail placeholder.
  static const Color chip = Color(0xFF282840);

  /// LinearProgressIndicator track.
  static const Color progressTrack = Color(0xFF2A2A42);

  /// Subtle card border (7 % white).
  static const Color border = Color(0x12FFFFFF);

  /// Section divider (5 % white).
  static const Color divider = Color(0x0DFFFFFF);

  // ---------------------------------------------------------------------------
  // Accent
  // ---------------------------------------------------------------------------

  /// Primary accent — buttons, active icons, progress bars.
  static const Color primary = Color(0xFF7B8CDE);

  /// Lighter primary — info text on dark backgrounds.
  static const Color primaryLight = Color(0xFF9BAAEE);

  // ---------------------------------------------------------------------------
  // Semantic / status
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF4CAF50);
  static const Color error   = Colors.red;
  static const Color warning = Colors.amber;
  static const Color caution = Colors.orange;

  // ---------------------------------------------------------------------------
  // Banner backgrounds
  // ---------------------------------------------------------------------------

  static const Color infoBannerBg    = Color(0xFF0E1E3A);
  static const Color errorBannerBg   = Color(0xFF3D1A1A);
  static const Color warningBannerBg = Color(0xFF2D2200);

  // ---------------------------------------------------------------------------
  // Item-status badge colours
  // ---------------------------------------------------------------------------

  static final Color statusMissing     = Colors.red.shade700;
  static final Color statusUnavailable = Colors.orange.shade700;
  static final Color statusRestricted  = Colors.purple.shade700;
  static final Color statusDefault     = Colors.grey.shade700;

  // ---------------------------------------------------------------------------
  // Text on dark backgrounds (opacity ladder)
  // ---------------------------------------------------------------------------

  static const Color textPrimary  = Colors.white;
  static const Color textHigh     = Colors.white70;   // 70 %
  static const Color textMedium   = Colors.white54;   // 54 %
  static const Color textLow      = Colors.white38;   // 38 %
  static const Color textDisabled = Colors.white24;   // 24 %
  static const Color textFaint    = Colors.white12;   // 12 %

  // ---------------------------------------------------------------------------
  // Player
  // ---------------------------------------------------------------------------

  static const Color playerBg      = Colors.black;
  static const Color playerOverlay = Color(0xCC000000);
}
