import 'package:flutter/material.dart';

/// Border-radius constants for TTSPlayer.
///
/// All values use `BorderRadius.all(Radius.circular(...))` so they can be
/// declared `const`.  `BorderRadius.circular()` is a factory constructor and
/// cannot be used in `const` expressions.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppRadius {
  // ---------------------------------------------------------------------------
  // Raw radii (double)
  // ---------------------------------------------------------------------------

  static const double chip   = 6;
  static const double button = 10;
  static const double card   = 12;
  static const double dialog = 16;
  static const double section = 12;

  // ---------------------------------------------------------------------------
  // BorderRadius
  // ---------------------------------------------------------------------------

  static const BorderRadius chipRadius =
      BorderRadius.all(Radius.circular(chip));

  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));

  static const BorderRadius dialogRadius =
      BorderRadius.all(Radius.circular(dialog));

  static const BorderRadius sectionRadius =
      BorderRadius.all(Radius.circular(section));

  // ---------------------------------------------------------------------------
  // OutlinedBorder (for Card, Button, Dialog shapes)
  //
  // Typed as RoundedRectangleBorder (an OutlinedBorder) rather than the
  // abstract ShapeBorder, so they can be passed directly to APIs that require
  // OutlinedBorder (e.g. FilledButton.styleFrom, CardThemeData.shape).
  // ---------------------------------------------------------------------------

  static const RoundedRectangleBorder chipShape = RoundedRectangleBorder(
    borderRadius: chipRadius,
  );

  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: buttonRadius,
  );

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: cardRadius,
  );

  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: dialogRadius,
  );
}
