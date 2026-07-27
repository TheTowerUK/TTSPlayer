import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../models/reading_location_payload.dart';
import '../models/reading_progress_record.dart';
import '../models/reading_progress_policy.dart';
import 'reading_progress_repository.dart';

enum ContinueReadingAvailability {
  available,
  missing,
  unavailable,
  restricted,
  cbrToolingUnavailable,
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
  const ContinueReadingProjection({
    this.cbrToolingAvailable = true,
  });

  final bool cbrToolingAvailable;

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
    if (item.isComic &&
        item.filePath.toLowerCase().endsWith('.cbr') &&
        !cbrToolingAvailable) {
      return ContinueReadingAvailability.cbrToolingUnavailable;
    }
    return ContinueReadingAvailability.available;
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
      ContinueReadingAvailability.cbrToolingUnavailable =>
        'CBR reading requires local UnRAR tooling.',
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
        chapterTitle != null && chapterTitle.isNotEmpty
            ? chapterTitle
            : 'Chapter ${spineIndex + 1} of $spineCountAtSave',
      ComicReadingLocationPayload(:final pageIndex, :final pageCountAtSave) =>
        'Page ${pageIndex + 1} of $pageCountAtSave',
    };
  }
}
