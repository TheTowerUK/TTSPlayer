import 'package:flutter/foundation.dart';

/// Test-only counters for folder browse presentation (M4 Phase 4.5 Step 5).
///
/// Not used for production control flow. Reset in tests via [reset].
abstract final class FolderPresentationMetrics {
  static int viewPreparationCount = 0;
  static int mediaCardBuildCount = 0;
  static int folderCardBuildCount = 0;

  @visibleForTesting
  static void reset() {
    viewPreparationCount = 0;
    mediaCardBuildCount = 0;
    folderCardBuildCount = 0;
  }
}
