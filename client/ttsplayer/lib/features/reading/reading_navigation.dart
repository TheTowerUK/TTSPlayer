import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../books/reader/book_navigation.dart' as book_nav;
import '../comics/reader/comic_navigation.dart' as comic_nav;
import 'models/reading_location_payload.dart';
import 'models/reading_progress_record.dart';
import 'services/reading_location_reconciliation.dart';
import 'services/reading_progress_repository.dart';

/// Opens a book or comic reader with optional progress restoration (M6.5).
Future<void> openReadingItem(
  BuildContext context, {
  required MediaItem item,
  bool startFromBeginning = false,
}) async {
  if (item.isBook) {
    await book_nav.openBookReaderScreen(
      context,
      item: item,
      startFromBeginning: startFromBeginning,
    );
    return;
  }
  if (item.isComic) {
    await comic_nav.openComicReaderScreen(
      context,
      item: item,
      startFromBeginning: startFromBeginning,
    );
  }
}

/// Resolves saved progress for detail/reader entry points.
ReadingProgressRestorePlan? resolveReadingRestore({
  required MediaItem item,
  required ReadingProgressRepository repository,
  bool startFromBeginning = false,
}) {
  if (startFromBeginning) return null;
  final record = repository.getByMediaId(item.id);
  if (record == null || record.completed) return null;
  if (!ReadingProgressRecord.hasMeaningfulProgress(record)) return null;
  return ReadingProgressRestorePlan(record: record);
}

class ReadingProgressRestorePlan {
  const ReadingProgressRestorePlan({required this.record});

  final ReadingProgressRecord record;

  PdfReadingLocationPayload? pdfLocation({
    required int currentPageCount,
  }) {
    final saved = record.location;
    if (saved is! PdfReadingLocationPayload) return null;
    final result = ReadingLocationReconciliation.reconcilePdf(
      saved: saved,
      currentPageCount: currentPageCount,
      sameDocumentHint: saved.pageCountAtSave == currentPageCount,
    );
    return result.location as PdfReadingLocationPayload;
  }

  EpubReadingLocationPayload? epubLocation({
    required List<String> spineHrefs,
    required int currentSpineCount,
  }) {
    final saved = record.location;
    if (saved is! EpubReadingLocationPayload) return null;
    final result = ReadingLocationReconciliation.reconcileEpub(
      saved: saved,
      spineHrefs: spineHrefs,
      currentSpineCount: currentSpineCount,
      sameDocumentHint: saved.spineCountAtSave == currentSpineCount,
    );
    return result.location as EpubReadingLocationPayload;
  }

  ComicReadingLocationPayload? comicLocation({
    required List<String> entryNames,
    required int currentPageCount,
  }) {
    final saved = record.location;
    if (saved is! ComicReadingLocationPayload) return null;
    final result = ReadingLocationReconciliation.reconcileComic(
      saved: saved,
      entryNames: entryNames,
      currentPageCount: currentPageCount,
      sameDocumentHint: saved.pageCountAtSave == currentPageCount,
    );
    return result.location as ComicReadingLocationPayload;
  }
}

ReadingProgressSummary? readingProgressSummaryForItem(
  BuildContext context, {
  required MediaItem item,
}) {
  final repository = context.read<ReadingProgressRepository>();
  final record = repository.getByMediaId(item.id);
  if (record == null) return null;
  return ReadingProgressSummary.fromRecord(record);
}

class ReadingProgressSummary {
  const ReadingProgressSummary({
    required this.progressPercent,
    required this.locationLabel,
    required this.completed,
    required this.hasMeaningfulProgress,
  });

  final int progressPercent;
  final String locationLabel;
  final bool completed;
  final bool hasMeaningfulProgress;

  factory ReadingProgressSummary.fromRecord(ReadingProgressRecord record) {
    return ReadingProgressSummary(
      progressPercent: (record.progressFraction * 100).round().clamp(0, 100),
      locationLabel: ContinueReadingProjectionLabel.forRecord(record),
      completed: record.completed,
      hasMeaningfulProgress:
          ReadingProgressRecord.hasMeaningfulProgress(record),
    );
  }
}

/// Presentation-only location labels shared by detail and Continue Reading.
abstract final class ContinueReadingProjectionLabel {
  static String forRecord(ReadingProgressRecord record) {
    return switch (record.location) {
      PdfReadingLocationPayload(:final pageIndex, :final pageCountAtSave) =>
        'Page ${pageIndex + 1} of $pageCountAtSave',
      EpubReadingLocationPayload(
        :final spineIndex,
        :final spineCountAtSave,
        :final chapterTitle,
      ) =>
        chapterTitle != null && chapterTitle.isNotEmpty
            ? chapterTitle
            : 'Chapter ${spineIndex + 1} of $spineCountAtSave',
      ComicReadingLocationPayload(:final pageIndex, :final pageCountAtSave) =>
        'Page ${pageIndex + 1} of $pageCountAtSave',
    };
  }
}
