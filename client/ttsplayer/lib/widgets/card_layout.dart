import 'dart:math' as math;

/// Shared layout math for artwork-forward cards in fixed-height grids.
abstract final class CardLayout {
  /// Landscape artwork ratio used on library, folder, and Continue Watching cards.
  static const double artworkAspect = 16 / 9;

  /// Maximum share of card height given to the artwork band in tight grids.
  static const double artworkMaxHeightFraction = 0.52;

  /// Fixed height for Continue Watching hero cards (artwork + footer).
  static const double continueWatchingCardHeight = 300;

  /// Room for a horizontal scrollbar beneath the card row on desktop.
  static const double continueWatchingScrollbarGutter = 12;

  /// Height of the Continue Watching horizontal list row (cards + scrollbar).
  static double get continueWatchingListHeight =>
      continueWatchingCardHeight + continueWatchingScrollbarGutter;

  /// Portrait media cards in the Recently Added carousel.
  static const double recentlyAddedCardWidth = 160;
  static const double recentlyAddedCardHeight = 240;
  static const double recentlyAddedScrollbarGutter = 12;

  static double get recentlyAddedListHeight =>
      recentlyAddedCardHeight + recentlyAddedScrollbarGutter;

  /// Landscape folder cards in the Featured Folders carousel.
  static const double featuredFolderCardWidth = 280;
  static const double featuredFolderCardHeight = 200;
  static const double featuredFolderScrollbarGutter = 12;

  static double get featuredFolderListHeight =>
      featuredFolderCardHeight + featuredFolderScrollbarGutter;

  /// Artwork band height that never exceeds the card bounds.
  static double artworkBandHeight({
    required double width,
    required double maxHeight,
  }) {
    final ideal = width / artworkAspect;
    if (!maxHeight.isFinite || maxHeight <= 0) return ideal;
    return math.min(ideal, maxHeight * artworkMaxHeightFraction);
  }
}
