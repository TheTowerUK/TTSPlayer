import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../comics/archive/comic_archive_opener.dart';
import '../models/reading_location_payload.dart';
import '../models/reading_progress_record.dart';
import '../models/reading_progress_policy.dart';
import 'reading_progress_repository.dart';

enum ContinueReadingAvailability {
  available,
  missing,
  unavailable,
  restricted,
  unsupportedComicFormat,
}

/// Catalogue-backed Continue Reading row (M6.5).
class ContinueReadingEntry {
  const ContinueReadingEntry({
    required this.item,
    required this.record,
    required this.progressPercent,
    required this.locationLabel,
    required this.availability,
    this.unavailabilityReason,
  });

  final MediaItem item;
  final ReadingProgressRecord record;
  final int progressPercent;
  final String locationLabel;
  final ContinueReadingAvailability availability;
  final String? unavailabilityReason;

  bool get isPlayable => availability == ContinueReadingAvailability.available;
}

/// Joins persisted reading progress with the current catalogue (M6.5).
class ContinueReadingProjection {
  const ContinueReadingProjection();

  List<ContinueReadingEntry> build({
    required Catalog catalog,
    required ReadingProgressRepository repository,
    int? limit,
  }) {
    final itemsById = {
      for (final item in catalog.allItems)
        if (item.isBook || item.isComic) item.id: item,
    };

    final cap = limit ?? ReadingProgressPolicy.defaultContinueReadingQueryCap;
    final records = repository.continueReading(limit: cap * 2);
    final entries = <ContinueReadingEntry>[];

    for (final record in records) {
      if (entries.length >= cap) break;
      final item = itemsById[record.mediaId];
      if (item == null) continue;

      final availability = _availabilityFor(item);
      entries.add(
        ContinueReadingEntry(
          item: item,
          record: record,
          progressPercent: (record.progressFraction * 100).round().clamp(0, 99),
          locationLabel: _locationLabel(record),
          availability: availability,
          unavailabilityReason: _unavailabilityReason(item, availability),
        ),
      );
    }

    return entries;
  }

  ContinueReadingAvailability _availabilityFor(MediaItem item) {
    if (!item.status.isPlayable) {
      return switch (item.status) {
        MediaItemStatus.missing => ContinueReadingAvailability.missing,
        MediaItemStatus.unavailable => ContinueReadingAvailability.unavailable,
        MediaItemStatus.restricted => ContinueReadingAvailability.restricted,
        _ => ContinueReadingAvailability.unavailable,
      };
    }
    if (item.isComic && !_isSupportedComic(item)) {
      return ContinueReadingAvailability.unsupportedComicFormat;
    }
    return ContinueReadingAvailability.available;
  }

  bool _isSupportedComic(MediaItem item) {
    final dot = item.filePath.lastIndexOf('.');
    if (dot < 0 || dot == item.filePath.length - 1) return false;
    final ext = item.filePath.substring(dot + 1);
    return isSupportedComicArchiveExtension(ext);
  }

  String? _unavailabilityReason(
    MediaItem item,
    ContinueReadingAvailability availability,
  ) {
    return switch (availability) {
      ContinueReadingAvailability.missing => 'File is missing from the library.',
      ContinueReadingAvailability.unavailable =>
        'This item is currently unavailable.',
      ContinueReadingAvailability.restricted => 'Access to this item is restricted.',
      ContinueReadingAvailability.unsupportedComicFormat => kCbrConversionGuidance,
      ContinueReadingAvailability.available => null,
    };
  }

  static String _locationLabel(ReadingProgressRecord record) {
    return switch (record.location) {
      PdfReadingLocationPayload(:final pageIndex, :final pageCountAtSave) =>
        'Page ${pageIndex + 1} of $pageCountAtSave',
      EpubReadingLocationPayload(
        :final spineIndex,
        :final spineCountAtSave,
        :final chapterTitle,
      ) =>
        chapterTitle?.isNotEmpty == true
            ? chapterTitle!
            : 'Section ${spineIndex + 1} of $spineCountAtSave',
      ComicReadingLocationPayload(:final pageIndex, :final pageCountAtSave) =>
        'Page ${pageIndex + 1} of $pageCountAtSave',
    };
  }
}
