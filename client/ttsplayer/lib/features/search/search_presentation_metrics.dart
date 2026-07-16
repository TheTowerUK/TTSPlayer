import 'package:flutter/foundation.dart';

/// Test-only counters for search result presentation (M4 Phase 4.5 Step 6).
abstract final class SearchPresentationMetrics {
  static int flattenInvocationCount = 0;

  @visibleForTesting
  static void reset() {
    flattenInvocationCount = 0;
  }

  static void recordFlatten() {
    flattenInvocationCount++;
  }
}
