import 'package:flutter/material.dart';

/// Spacing scale, common EdgeInsets, and grid layout constants for TTSPlayer.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppSpacing {
  // ---------------------------------------------------------------------------
  // Base scale (multiples of 4)
  // ---------------------------------------------------------------------------

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;  // primary grid unit
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double page = 40;

  // ---------------------------------------------------------------------------
  // Semantic gap constants
  // ---------------------------------------------------------------------------

  /// Standard icon-to-text gap.
  static const double iconGap = 10;

  /// Compact label/value row gap.
  static const double labelGap = 6;

  /// Between dashboard sections (vertical rhythm).
  static const double section = 32;

  /// Continue Watching hero card width.
  static const double continueWatchingCardWidth = 320;

  /// Search result poster thumb width.
  static const double searchThumbWidth = 56;

  /// Inner padding for premium cards.
  static const double cardInner = 20;

  // ---------------------------------------------------------------------------
  // Grid layout constants
  // ---------------------------------------------------------------------------

  /// Max cross-axis extent for home Library folder cards.
  static const double gridLibrary = 220.0;

  /// Max cross-axis extent for subfolder cards inside a folder screen.
  static const double gridSubfolder = 200.0;

  /// Max cross-axis extent for media item cards.
  static const double gridMedia = 280.0;

  /// Child aspect ratio for folder/library cards with 16:9 artwork band + footer.
  static const double gridAspectLibrary = 0.82;

  /// Child aspect ratio for media cards (portrait, movie-poster style).
  static const double gridAspectMedia = 0.72;

  /// Standard grid gap (main + cross axis spacing).
  static const double gridGap = 14.0;

  // ---------------------------------------------------------------------------
  // Common EdgeInsets
  // ---------------------------------------------------------------------------

  /// Standard page / grid padding (16 all sides).
  static const EdgeInsets insetPage = EdgeInsets.all(base);

  /// Dashboard content padding (horizontal 20, vertical 16).
  static const EdgeInsets dashboard = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: base,
  );

  /// Card inner padding (8 all sides).
  static const EdgeInsets card = EdgeInsets.all(sm);

  /// Premium card inner padding (20 all sides).
  static const EdgeInsets cardPremium = EdgeInsets.all(cardInner);

  /// Dialog inner padding (24 all sides).
  static const EdgeInsets dialog = EdgeInsets.all(xl);

  /// Full-page error / empty-state padding (32 all sides).
  static const EdgeInsets errorView = EdgeInsets.all(xxl);

  /// Banner horizontal padding.
  static const EdgeInsets banner = EdgeInsets.symmetric(
    horizontal: base,
    vertical: 10,
  );

  /// Chip / badge internal padding.
  static const EdgeInsets chip = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: xs,
  );

  /// Section header inside a sliver (left/top/right = 16, bottom = 0).
  static const EdgeInsets sectionHeader = EdgeInsets.fromLTRB(base, base, base, 0);

  /// Small button / text-button padding (banner actions, etc.).
  static const EdgeInsets buttonSm = EdgeInsets.symmetric(horizontal: sm);

  /// Resume / secondary action button padding.
  static const EdgeInsets buttonAction = EdgeInsets.symmetric(
    horizontal: base,
    vertical: sm,
  );

  /// Warning-tile row vertical padding.
  static const EdgeInsets tileRow = EdgeInsets.symmetric(vertical: sm);

  /// Metadata panel section padding.
  static const EdgeInsets metadataSection = EdgeInsets.fromLTRB(lg, lg, lg, xs);

  /// Play-button section padding.
  static const EdgeInsets playSection = EdgeInsets.fromLTRB(lg, lg, lg, sm);

  /// File-info section padding.
  static const EdgeInsets fileInfo = EdgeInsets.fromLTRB(base, base, base, 40);

  /// Player bottom controls safe area.
  static const EdgeInsets playerControls = EdgeInsets.fromLTRB(base, 0, base, 28);

  /// Player seek bar vertical padding.
  static const EdgeInsets seekBar = EdgeInsets.symmetric(vertical: sm);
}
