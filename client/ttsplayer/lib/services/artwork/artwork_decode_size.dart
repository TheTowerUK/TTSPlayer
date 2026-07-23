import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/card_layout.dart';

/// Physical pixel decode dimensions for Flutter [Image] cache hints.
class ArtworkDecodeSize {
  final int? cacheWidth;
  final int? cacheHeight;

  const ArtworkDecodeSize({this.cacheWidth, this.cacheHeight});

  /// Converts a logical layout [size] to rounded physical decode pixels.
  static ArtworkDecodeSize fromLogicalSize({
    required Size size,
    required double devicePixelRatio,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return const ArtworkDecodeSize();
    }
    final dpr = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final width = _toPhysicalPixels(size.width * dpr);
    final height = _toPhysicalPixels(size.height * dpr);
    return ArtworkDecodeSize(cacheWidth: width, cacheHeight: height);
  }

  static int _toPhysicalPixels(double value) {
    final rounded = value.round();
    return math.max(1, rounded);
  }
}

/// Stable logical artwork surface sizes derived from design tokens.
abstract final class ArtworkSurfaceSizes {
  static const double mediaCardMetadataMaxHeight = 72;

  static Size gridMediaCard() {
    const width = AppSpacing.gridMedia;
    const cardHeight = width / AppSpacing.gridAspectMedia;
    const artworkHeight = cardHeight - mediaCardMetadataMaxHeight;
    return Size(width, artworkHeight);
  }

  static Size gridFolderCard() {
    const width = AppSpacing.gridSubfolder;
    const cardHeight = width / AppSpacing.gridAspectLibrary;
    final artworkHeight = CardLayout.artworkBandHeight(
      width: width,
      maxHeight: cardHeight,
    );
    return Size(width, artworkHeight);
  }

  static Size continueWatchingCard() {
    const width = AppSpacing.continueWatchingCardWidth;
    const footerAllowance = 96.0;
    final artworkHeight =
        CardLayout.continueWatchingCardHeight - footerAllowance;
    return Size(width, artworkHeight);
  }

  static Size searchResultThumbnail() {
    const width = AppSpacing.searchThumbWidth;
    const height = width * 1.5;
    return Size(width, height);
  }

  /// Square music browse / detail / history thumbnails (Phase 5.6 Step 5).
  static Size musicSquareThumbnail([double size = 56]) => Size(size, size);

  static Size favouritesRowThumbnail() => const Size(72, 48);

  static Size itemDetailPoster(double screenWidth) {
    final width = screenWidth;
    final height = width * 9 / 16;
    return Size(width, height);
  }
}
