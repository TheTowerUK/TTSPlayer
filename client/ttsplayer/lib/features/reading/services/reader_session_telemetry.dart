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

  int _cbrProcessInvocations = 0;
  int _cbrTempDirectoryCount = 0;

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

  void updateCbrSession({
    required int processInvocations,
    required int tempDirectoryCount,
  }) {
    _cbrProcessInvocations = processInvocations;
    _cbrTempDirectoryCount = tempDirectoryCount;
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
      cbrProcessInvocations: _cbrProcessInvocations,
      cbrTempDirectoryCount: _cbrTempDirectoryCount,
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
    _cbrProcessInvocations = 0;
    _cbrTempDirectoryCount = 0;
  }
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
    required this.cbrProcessInvocations,
    required this.cbrTempDirectoryCount,
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
  final int cbrProcessInvocations;
  final int cbrTempDirectoryCount;
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
      'cbz' => ReadingReaderFormat.cbz,
      'cbr' => ReadingReaderFormat.cbr,
      _ => null,
    };
  }
  return null;
}
