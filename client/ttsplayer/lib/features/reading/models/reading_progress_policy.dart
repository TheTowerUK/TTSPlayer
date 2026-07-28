/// Query, retention, debounce, and completion constants for reading progress (M6.5).
abstract final class ReadingProgressPolicy {
  /// Minimum interval between debounced persistence writes during reading.
  static const persistDebounce = Duration(seconds: 2);

  /// Maximum records persisted in [ReadingProgressRepository].
  static const maxStoredRecords = 100;

  /// Default cap for Continue Reading queries.
  static const defaultContinueReadingQueryCap = 20;

  /// Progress fraction at or above which an item is treated as completed.
  static const completionThreshold = 0.95;

  /// Minimum scroll offset (logical pixels) before EPUB intra-chapter progress
  /// counts as meaningful.
  static const epubMeaningfulScrollOffset = 48.0;

  /// Minimum page index (zero-based) before comic/PDF progress is meaningful.
  static const minMeaningfulPageIndex = 1;

  /// Minimum spine index before EPUB chapter-only progress is meaningful.
  static const minMeaningfulSpineIndex = 1;

  /// Minimum progress fraction before Continue Reading eligibility (non-start).
  static const minContinueReadingProgress = 0.02;

  /// In-progress fraction for a single-page comic while the reader is open.
  ///
  /// Stays below [completionThreshold] until the reader closes after layout is
  /// ready ([ReadingProgressCoordinator.onReaderClosed]).
  static const singlePageComicInProgressFraction = 0.5;
}
