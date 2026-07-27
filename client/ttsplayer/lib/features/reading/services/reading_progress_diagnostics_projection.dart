import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../../comics/archive/comic_archive_opener.dart';
import '../models/reading_location_payload.dart';
import '../models/reading_progress_record.dart';
import 'reading_progress_repository.dart';

/// Immutable aggregate reading-progress state for diagnostics (M6.5).
///
/// Exposes counts and classification only — no paths, hrefs, entry names, or
/// raw persisted payloads.
class ReadingProgressRepositoryDiagnosticsProjection {
  const ReadingProgressRepositoryDiagnosticsProjection({
    required this.schemaVersion,
    required this.initialized,
    required this.storedRecordCount,
    required this.continueReadingCount,
    required this.completedRecordCount,
    required this.staleOrUnmatchedRecordCount,
    required this.invalidSkippedRecordCount,
    required this.pdfRecordCount,
    required this.epubRecordCount,
    required this.cbzRecordCount,
    required this.legacyCbrRecordCount,
    required this.unsupportedComicFormatRecordCount,
    required this.recoveryWarningPresent,
    this.lastSuccessfulWriteAt,
    this.lastRepositoryErrorClassification,
    this.lastReconciliation,
  });

  final int schemaVersion;
  final bool initialized;
  final int storedRecordCount;
  final int continueReadingCount;
  final int completedRecordCount;
  final int staleOrUnmatchedRecordCount;
  final int invalidSkippedRecordCount;
  final int pdfRecordCount;
  final int epubRecordCount;
  final int cbzRecordCount;
  final int legacyCbrRecordCount;
  final int unsupportedComicFormatRecordCount;
  final bool recoveryWarningPresent;
  final DateTime? lastSuccessfulWriteAt;
  final String? lastRepositoryErrorClassification;
  final ReadingProgressReconciliationSummary? lastReconciliation;
}

/// Catalogue reconciliation outcome counts from the most recent validation.
class ReadingProgressReconciliationSummary {
  const ReadingProgressReconciliationSummary({
    required this.retainedCount,
    required this.refreshedCount,
    required this.removedMissingCount,
    required this.removedFormatMismatchCount,
    required this.unsupportedComicFormatRetainedCount,
    this.persistenceFailed = false,
  });

  final int retainedCount;
  final int refreshedCount;
  final int removedMissingCount;
  final int removedFormatMismatchCount;
  final int unsupportedComicFormatRetainedCount;
  final bool persistenceFailed;

  factory ReadingProgressReconciliationSummary.fromValidationResult(
    ReadingProgressValidationResult result, {
    required int unsupportedComicFormatRetainedCount,
  }) {
    return ReadingProgressReconciliationSummary(
      retainedCount: result.retainedCount,
      refreshedCount: result.metadataRefreshedCount,
      removedMissingCount: result.removedMissingCount,
      removedFormatMismatchCount: result.removedFormatMismatchCount,
      unsupportedComicFormatRetainedCount: unsupportedComicFormatRetainedCount,
      persistenceFailed: result.persistenceFailed,
    );
  }
}

/// Read-only diagnostics projection for [ReadingProgressRepository].
abstract final class ReadingProgressDiagnosticsProjection {
  static ReadingProgressRepositoryDiagnosticsProjection build({
    required ReadingProgressRepository repository,
    Catalog? catalog,
  }) {
    final records = repository.allRecords;
    final formatCounts = _formatCounts(records);
    final staleOrUnmatched = catalog == null
        ? 0
        : _countStaleOrUnmatched(records, catalog);

    final unsupportedComic = catalog == null
        ? 0
        : _countUnsupportedComicRecords(records, catalog);

    final validation = repository.lastValidationResult;
    ReadingProgressReconciliationSummary? reconciliation;
    if (validation != null) {
      reconciliation = ReadingProgressReconciliationSummary.fromValidationResult(
        validation,
        unsupportedComicFormatRetainedCount: unsupportedComic,
      );
    }

    return ReadingProgressRepositoryDiagnosticsProjection(
      schemaVersion: ReadingProgressRepository.currentStateVersion,
      initialized: repository.isLoaded,
      storedRecordCount: repository.storedRecordCount,
      continueReadingCount: repository.continueReadingCount,
      completedRecordCount: repository.completedRecordCount,
      staleOrUnmatchedRecordCount: staleOrUnmatched,
      invalidSkippedRecordCount: repository.lastLoadSkippedRecordCount,
      pdfRecordCount: formatCounts.pdf,
      epubRecordCount: formatCounts.epub,
      cbzRecordCount: formatCounts.cbz,
      legacyCbrRecordCount: formatCounts.cbr,
      unsupportedComicFormatRecordCount: unsupportedComic,
      recoveryWarningPresent: repository.recoveryWarningPresent,
      lastSuccessfulWriteAt: repository.lastSuccessfulWriteAt,
      lastRepositoryErrorClassification: repository.lastRepositoryError,
      lastReconciliation: reconciliation,
    );
  }

  static int _countUnsupportedComicRecords(
    List<ReadingProgressRecord> records,
    Catalog catalog,
  ) {
    final itemsById = {
      for (final item in catalog.allItems)
        if (item.isComic) item.id: item,
    };
    var count = 0;
    for (final record in records) {
      if (record.mediaKind != MediaKind.comic) continue;
      final item = itemsById[record.mediaId];
      if (item != null && !_isSupportedComicItem(item)) {
        count++;
      }
    }
    return count;
  }

  static bool _isSupportedComicItem(MediaItem item) {
    final dot = item.filePath.lastIndexOf('.');
    if (dot < 0 || dot == item.filePath.length - 1) return false;
    return isSupportedComicArchiveExtension(
      item.filePath.substring(dot + 1),
    );
  }

  static _FormatCounts _formatCounts(List<ReadingProgressRecord> records) {
    var pdf = 0;
    var epub = 0;
    var cbz = 0;
    var cbr = 0;
    for (final record in records) {
      switch (record.readerFormat) {
        case ReadingReaderFormat.pdf:
          pdf++;
        case ReadingReaderFormat.epub:
          epub++;
        case ReadingReaderFormat.cbz:
          cbz++;
        case ReadingReaderFormat.cbr:
          cbr++;
      }
    }
    return _FormatCounts(pdf: pdf, epub: epub, cbz: cbz, cbr: cbr);
  }

  static int _countStaleOrUnmatched(
    List<ReadingProgressRecord> records,
    Catalog catalog,
  ) {
    final itemsById = {
      for (final item in catalog.allItems)
        if (item.isBook || item.isComic) item.id: item,
    };

    var count = 0;
    for (final record in records) {
      final item = itemsById[record.mediaId];
      if (item == null || !_formatMatchesItem(record, item)) {
        count++;
      }
    }
    return count;
  }

  static bool _formatMatchesItem(
    ReadingProgressRecord record,
    MediaItem item,
  ) {
    if (item.isBook && record.mediaKind != MediaKind.book) return false;
    if (item.isComic && record.mediaKind != MediaKind.comic) return false;
    return _readerFormatForItem(item) == record.readerFormat;
  }

  static ReadingReaderFormat? _readerFormatForItem(MediaItem item) {
    final ext = item.filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => ReadingReaderFormat.pdf,
      'epub' => ReadingReaderFormat.epub,
      'cbz' || 'zip' => ReadingReaderFormat.cbz,
      _ => null,
    };
  }
}

class _FormatCounts {
  const _FormatCounts({
    required this.pdf,
    required this.epub,
    required this.cbz,
    required this.cbr,
  });

  final int pdf;
  final int epub;
  final int cbz;
  final int cbr;
}
