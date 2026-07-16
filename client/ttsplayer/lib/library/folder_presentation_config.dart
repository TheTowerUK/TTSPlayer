import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../theme/app_theme.dart';

/// Scroll and delegate tuning for large folder browse surfaces (M4 Phase 4.5).
///
/// Values are conservative: enough off-screen cache for smooth scroll without
/// retaining an excessive number of grid children in memory.
abstract final class FolderPresentationConfig {
  /// Off-screen area cached by [CustomScrollView] for folder grids.
  ///
  /// ~1 media-card row at desktop grid extents (280 logical × 0.72 aspect).
  /// Applied via [ScrollView.scrollCacheExtent].
  static final ScrollCacheExtent gridScrollCacheExtent =
      ScrollCacheExtent.pixels(400.0);

  /// [SliverChildBuilderDelegate] flags — explicit for auditability.
  static const bool addAutomaticKeepAlives = true;
  static const bool addRepaintBoundaries = true;
  static const bool addSemanticIndexes = true;

  /// Stable [PageStorageKey] value for a catalogue folder id.
  static String scrollStorageKey(String folderId) => 'folder-scroll:$folderId';

  /// Media grid delegate — shared between folder browse and tests.
  static const SliverGridDelegateWithMaxCrossAxisExtent mediaGridDelegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: AppSpacing.gridMedia,
    mainAxisSpacing: AppSpacing.gridGap,
    crossAxisSpacing: AppSpacing.gridGap,
    childAspectRatio: AppSpacing.gridAspectMedia,
  );

  /// Subfolder grid delegate.
  static const SliverGridDelegateWithMaxCrossAxisExtent subfolderGridDelegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: AppSpacing.gridSubfolder,
    mainAxisSpacing: AppSpacing.gridGap,
    crossAxisSpacing: AppSpacing.gridGap,
    childAspectRatio: AppSpacing.gridAspectLibrary,
  );
}
