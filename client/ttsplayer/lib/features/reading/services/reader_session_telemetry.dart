import '../models/reading_location_payload.dart';
import '../../../models/media_kind.dart';

/// Aggregate reader-session telemetry for diagnostics (M6.6).
///
/// Read-only snapshots only — no paths, titles, or document identifiers.
class ReaderSessionTelemetry {
  ReaderSessionTelemetry._();

  static final ReaderSessionTelemetry instance = ReaderSessionTelemetry._();

  ReadingReaderFormat? _lastReaderFormat;
  Duration? _lastReaderOpenDuration;
  Duration? _lastFirstContentDuration;
  String? _lastCleanupResult;

  int _comicCacheMaxEntries = 5;
  int _comicCacheMaxBytes = 24 * 1024 * 1024;
  int _comicCacheEntryCount = 0;
  int _comicCacheEstimatedBytes = 0;

  int _epubCacheMaxEntries = 32;
  int _epubCacheMaxBytes = 16 * 1024 * 1024;
  int _epubCacheEntryCount = 0;
  int _epubCacheEstimatedBytes = 0;

  bool _comicReaderActive = false;
  String? _comicItemIdentity;
  String _comicArchiveType = 'cbz';
  int? _comicPageIndex;
  int? _comicPageCount;
  String? _comicFitMode;
  bool? _comicChromeVisible;
  bool? _comicZoomedBeyondBase;
  int _comicFailedPagesTracked = 0;
  String? _comicCurrentPageFailureCategory;
  bool? _comicRetryAvailable;
  String? _comicLastSafeErrorCategory;
  bool? _comicProgressSessionActive;
  bool? _comicSessionCompleted;
  int _nextComicSessionId = 0;
  int? _activeComicSessionId;

  /// Registers a new comic reader diagnostics owner (Phase 6.4C).
  ///
  /// Returns an opaque session id; updates and clears must pass the same id.
  int beginComicReaderSession() {
    final id = ++_nextComicSessionId;
    _activeComicSessionId = id;
    _comicReaderActive = false;
    _clearComicReaderSessionFields();
    return id;
  }

  void recordReaderOpen({
    required ReadingReaderFormat format,
    required Duration openDuration,
    Duration? firstContentDuration,
  }) {
    _lastReaderFormat = format;
    _lastReaderOpenDuration = openDuration;
    _lastFirstContentDuration = firstContentDuration;
  }

  void recordCleanupResult(String result) {
    _lastCleanupResult = result;
  }

  void updateComicPageCache({
    required int maxEntries,
    required int maxBytes,
    required int entryCount,
    required int estimatedBytes,
  }) {
    _comicCacheMaxEntries = maxEntries;
    _comicCacheMaxBytes = maxBytes;
    _comicCacheEntryCount = entryCount;
    _comicCacheEstimatedBytes = estimatedBytes;
  }

  void updateEpubResourceCache({
    required int maxEntries,
    required int maxBytes,
    required int entryCount,
    required int estimatedBytes,
  }) {
    _epubCacheMaxEntries = maxEntries;
    _epubCacheMaxBytes = maxBytes;
    _epubCacheEntryCount = entryCount;
    _epubCacheEstimatedBytes = estimatedBytes;
  }

  /// Updates the active CBZ comic reader snapshot for diagnostics (Phase 6.4C).
  ///
  /// Pass [active: false] or call [clearComicReaderSession] when the reader closes.
  void updateComicReaderSession({
    required int sessionId,
    required bool active,
    String? itemIdentity,
    String archiveType = 'cbz',
    int? pageIndex,
    int? pageCount,
    String? fitMode,
    bool? chromeVisible,
    bool? zoomedBeyondBase,
    int? failedPagesTracked,
    String? currentPageFailureCategory,
    bool? retryAvailable,
    bool? progressSessionActive,
    bool? sessionCompleted,
  }) {
    if (sessionId != _activeComicSessionId) return;
    _comicReaderActive = active;
    if (!active) {
      _clearComicReaderSessionFields();
      return;
    }
    _comicItemIdentity = itemIdentity;
    _comicArchiveType = archiveType;
    _comicPageIndex = pageIndex;
    _comicPageCount = pageCount;
    _comicFitMode = fitMode;
    _comicChromeVisible = chromeVisible;
    _comicZoomedBeyondBase = zoomedBeyondBase;
    _comicFailedPagesTracked = failedPagesTracked ?? 0;
    _comicCurrentPageFailureCategory = currentPageFailureCategory;
    _comicRetryAvailable = retryAvailable;
    _comicProgressSessionActive = progressSessionActive;
    _comicSessionCompleted = sessionCompleted;
  }

  void recordComicReaderSafeError(String categoryLabel) {
    if (categoryLabel.isEmpty) return;
    _comicLastSafeErrorCategory = categoryLabel;
  }

  void clearComicReaderSession(int sessionId) {
    if (sessionId != _activeComicSessionId) return;
    _activeComicSessionId = null;
    _comicReaderActive = false;
    _clearComicReaderSessionFields();
  }

  ComicReaderTelemetrySnapshot? comicReaderSnapshot() {
    if (!_comicReaderActive) return null;
    return ComicReaderTelemetrySnapshot(
      archiveType: _comicArchiveType,
      itemIdentity: _comicItemIdentity,
      pageIndex: _comicPageIndex,
      pageCount: _comicPageCount,
      fitMode: _comicFitMode,
      chromeVisible: _comicChromeVisible,
      zoomedBeyondBase: _comicZoomedBeyondBase,
      cacheMaxEntries: _comicCacheMaxEntries,
      cacheMaxBytes: _comicCacheMaxBytes,
      cacheEntryCount: _comicCacheEntryCount,
      cacheEstimatedBytes: _comicCacheEstimatedBytes,
      failedPagesTracked: _comicFailedPagesTracked,
      currentPageFailureCategory: _comicCurrentPageFailureCategory,
      retryAvailable: _comicRetryAvailable,
      lastSafeErrorCategory: _comicLastSafeErrorCategory,
      progressSessionActive: _comicProgressSessionActive,
      sessionCompleted: _comicSessionCompleted,
    );
  }

  void _clearComicReaderSessionFields() {
    _comicItemIdentity = null;
    _comicArchiveType = 'cbz';
    _comicPageIndex = null;
    _comicPageCount = null;
    _comicFitMode = null;
    _comicChromeVisible = null;
    _comicZoomedBeyondBase = null;
    _comicFailedPagesTracked = 0;
    _comicCurrentPageFailureCategory = null;
    _comicRetryAvailable = null;
    _comicProgressSessionActive = null;
    _comicSessionCompleted = null;
  }

  ReaderSessionTelemetrySnapshot snapshot() {
    return ReaderSessionTelemetrySnapshot(
      lastReaderFormat: _lastReaderFormat?.name,
      lastReaderOpenDurationMs: _lastReaderOpenDuration?.inMilliseconds,
      lastFirstContentDurationMs: _lastFirstContentDuration?.inMilliseconds,
      lastCleanupResult: _lastCleanupResult,
      comicCacheMaxEntries: _comicCacheMaxEntries,
      comicCacheMaxBytes: _comicCacheMaxBytes,
      comicCacheEntryCount: _comicCacheEntryCount,
      comicCacheEstimatedBytes: _comicCacheEstimatedBytes,
      epubCacheMaxEntries: _epubCacheMaxEntries,
      epubCacheMaxBytes: _epubCacheMaxBytes,
      epubCacheEntryCount: _epubCacheEntryCount,
      epubCacheEstimatedBytes: _epubCacheEstimatedBytes,
    );
  }

  /// Test-only reset.
  void resetForTest() {
    _lastReaderFormat = null;
    _lastReaderOpenDuration = null;
    _lastFirstContentDuration = null;
    _lastCleanupResult = null;
    _comicCacheEntryCount = 0;
    _comicCacheEstimatedBytes = 0;
    _epubCacheEntryCount = 0;
    _epubCacheEstimatedBytes = 0;
    _comicReaderActive = false;
    _activeComicSessionId = null;
    _nextComicSessionId = 0;
    _clearComicReaderSessionFields();
    _comicLastSafeErrorCategory = null;
  }
}

class ComicReaderTelemetrySnapshot {
  const ComicReaderTelemetrySnapshot({
    required this.archiveType,
    this.itemIdentity,
    this.pageIndex,
    this.pageCount,
    this.fitMode,
    this.chromeVisible,
    this.zoomedBeyondBase,
    required this.cacheMaxEntries,
    required this.cacheMaxBytes,
    required this.cacheEntryCount,
    required this.cacheEstimatedBytes,
    required this.failedPagesTracked,
    this.currentPageFailureCategory,
    this.retryAvailable,
    this.lastSafeErrorCategory,
    this.progressSessionActive,
    this.sessionCompleted,
  });

  final String archiveType;
  final String? itemIdentity;
  final int? pageIndex;
  final int? pageCount;
  final String? fitMode;
  final bool? chromeVisible;
  final bool? zoomedBeyondBase;
  final int cacheMaxEntries;
  final int cacheMaxBytes;
  final int cacheEntryCount;
  final int cacheEstimatedBytes;
  final int failedPagesTracked;
  final String? currentPageFailureCategory;
  final bool? retryAvailable;
  final String? lastSafeErrorCategory;
  final bool? progressSessionActive;
  final bool? sessionCompleted;
}

class ReaderSessionTelemetrySnapshot {
  const ReaderSessionTelemetrySnapshot({
    this.lastReaderFormat,
    this.lastReaderOpenDurationMs,
    this.lastFirstContentDurationMs,
    this.lastCleanupResult,
    required this.comicCacheMaxEntries,
    required this.comicCacheMaxBytes,
    required this.comicCacheEntryCount,
    required this.comicCacheEstimatedBytes,
    required this.epubCacheMaxEntries,
    required this.epubCacheMaxBytes,
    required this.epubCacheEntryCount,
    required this.epubCacheEstimatedBytes,
  });

  final String? lastReaderFormat;
  final int? lastReaderOpenDurationMs;
  final int? lastFirstContentDurationMs;
  final String? lastCleanupResult;
  final int comicCacheMaxEntries;
  final int comicCacheMaxBytes;
  final int comicCacheEntryCount;
  final int comicCacheEstimatedBytes;
  final int epubCacheMaxEntries;
  final int epubCacheMaxBytes;
  final int epubCacheEntryCount;
  final int epubCacheEstimatedBytes;
}

/// Maps [MediaKind] + extension to [ReadingReaderFormat] label for telemetry.
ReadingReaderFormat? readerFormatForTelemetry({
  required MediaKind kind,
  required String extension,
}) {
  final ext = extension.toLowerCase();
  if (kind == MediaKind.book) {
    return switch (ext) {
      'pdf' => ReadingReaderFormat.pdf,
      'epub' => ReadingReaderFormat.epub,
      _ => null,
    };
  }
  if (kind == MediaKind.comic) {
    return switch (ext) {
      'cbz' || 'zip' => ReadingReaderFormat.cbz,
      _ => null,
    };
  }
  return null;
}
