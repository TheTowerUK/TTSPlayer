import '../../../models/media_kind.dart';
import 'reading_location_payload.dart';
import 'reading_progress_policy.dart';

/// One persisted reading-progress entry (M6.5).
///
/// [mediaId] is the sole identity key. [title] and [sourceBasename] are display
/// snapshots only — never used to rematch catalogue items.
class ReadingProgressRecord {
  const ReadingProgressRecord({
    required this.mediaId,
    required this.mediaKind,
    required this.readerFormat,
    required this.title,
    required this.location,
    required this.progressFraction,
    required this.completed,
    required this.lastReadAt,
    this.firstReadAt,
    this.completedAt,
    this.sourceBasename,
  });

  final String mediaId;
  final MediaKind mediaKind;
  final ReadingReaderFormat readerFormat;
  final String title;
  final ReadingLocationPayload location;
  final double progressFraction;
  final bool completed;
  final DateTime lastReadAt;
  final DateTime? firstReadAt;
  final DateTime? completedAt;

  /// Basename of the source file at last save (redacted-safe hint only).
  final String? sourceBasename;

  bool get isBook => mediaKind == MediaKind.book;
  bool get isComic => mediaKind == MediaKind.comic;

  ReadingProgressRecord copyWith({
    String? mediaId,
    MediaKind? mediaKind,
    ReadingReaderFormat? readerFormat,
    String? title,
    ReadingLocationPayload? location,
    double? progressFraction,
    bool? completed,
    DateTime? lastReadAt,
    DateTime? firstReadAt,
    DateTime? completedAt,
    String? sourceBasename,
    bool clearCompletedAt = false,
    bool clearFirstReadAt = false,
    bool clearSourceBasename = false,
  }) {
    return ReadingProgressRecord(
      mediaId: mediaId ?? this.mediaId,
      mediaKind: mediaKind ?? this.mediaKind,
      readerFormat: readerFormat ?? this.readerFormat,
      title: title ?? this.title,
      location: location ?? this.location,
      progressFraction: progressFraction ?? this.progressFraction,
      completed: completed ?? this.completed,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      firstReadAt: clearFirstReadAt ? null : (firstReadAt ?? this.firstReadAt),
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sourceBasename: clearSourceBasename
          ? null
          : (sourceBasename ?? this.sourceBasename),
    );
  }

  ReadingProgressRecord normalized() {
    final playedAt = lastReadAt.toUtc();
    final fraction = progressFraction.isFinite
        ? progressFraction.clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = completed ||
        fraction >= ReadingProgressPolicy.completionThreshold;

    if (isCompleted) {
      return ReadingProgressRecord(
        mediaId: mediaId.trim(),
        mediaKind: mediaKind,
        readerFormat: readerFormat,
        title: title,
        location: location,
        progressFraction: 1.0,
        completed: true,
        lastReadAt: playedAt,
        firstReadAt: firstReadAt?.toUtc(),
        completedAt: (completedAt ?? playedAt).toUtc(),
        sourceBasename: sourceBasename,
      );
    }

    return ReadingProgressRecord(
      mediaId: mediaId.trim(),
      mediaKind: mediaKind,
      readerFormat: readerFormat,
      title: title,
      location: location,
      progressFraction: fraction,
      completed: false,
      lastReadAt: playedAt,
      firstReadAt: firstReadAt?.toUtc(),
      completedAt: null,
      sourceBasename: sourceBasename,
    );
  }

  static ReadingProgressRecord? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final mediaId = json['mediaId'];
    if (mediaId is! String || mediaId.trim().isEmpty) {
      warnings?.add('Skipped reading record with missing mediaId.');
      return null;
    }

    final kind = MediaKind.fromString(json['mediaKind'] as String?);
    if (kind != MediaKind.book && kind != MediaKind.comic) {
      warnings?.add('Skipped reading record with unsupported mediaKind.');
      return null;
    }

    final readerFormat =
        ReadingReaderFormat.fromString(json['readerFormat'] as String?);
    if (readerFormat == null) {
      warnings?.add('Skipped reading record with invalid readerFormat.');
      return null;
    }

    final lastReadRaw = json['lastReadAt'];
    if (lastReadRaw is! String) {
      warnings?.add('Skipped reading record with invalid lastReadAt.');
      return null;
    }
    final lastReadAt = DateTime.tryParse(lastReadRaw)?.toUtc();
    if (lastReadAt == null) {
      warnings?.add('Skipped reading record with invalid lastReadAt.');
      return null;
    }

    final locationRaw = json['location'];
    if (locationRaw is! Map) {
      warnings?.add('Skipped reading record with invalid location.');
      return null;
    }
    final location = ReadingLocationPayload.fromJson(
      Map<String, dynamic>.from(locationRaw),
    );
    if (location == null) {
      warnings?.add('Skipped reading record with invalid location payload.');
      return null;
    }
    if (location.format != readerFormat) {
      warnings?.add('Skipped reading record with format/location mismatch.');
      return null;
    }

    final fractionRaw = json['progressFraction'];
    if (fractionRaw is! num || !fractionRaw.isFinite) {
      warnings?.add('Skipped reading record with invalid progressFraction.');
      return null;
    }
    final progressFraction = fractionRaw.toDouble();
    if (progressFraction < 0 || progressFraction > 1) {
      warnings?.add('Skipped reading record with out-of-range progress.');
      return null;
    }

    final title = json['title'];
    final completedRaw = json['completed'];
    final completed = completedRaw == true;

    DateTime? firstReadAt;
    final firstReadRaw = json['firstReadAt'];
    if (firstReadRaw is String) {
      firstReadAt = DateTime.tryParse(firstReadRaw)?.toUtc();
    }

    DateTime? completedAt;
    final completedAtRaw = json['completedAt'];
    if (completedAtRaw is String) {
      completedAt = DateTime.tryParse(completedAtRaw)?.toUtc();
    }

    final basename = json['sourceBasename'];

    return ReadingProgressRecord(
      mediaId: mediaId.trim(),
      mediaKind: kind,
      readerFormat: readerFormat,
      title: title is String && title.trim().isNotEmpty ? title.trim() : 'Untitled',
      location: location,
      progressFraction: progressFraction,
      completed: completed,
      lastReadAt: lastReadAt,
      firstReadAt: firstReadAt,
      completedAt: completedAt,
      sourceBasename: basename is String && basename.trim().isNotEmpty
          ? basename.trim()
          : null,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'mediaKind': mediaKind.name,
        'readerFormat': readerFormat.storageName,
        'title': title,
        'location': location.toJson(),
        'progressFraction': progressFraction,
        'completed': completed,
        'lastReadAt': lastReadAt.toUtc().toIso8601String(),
        if (firstReadAt != null)
          'firstReadAt': firstReadAt!.toUtc().toIso8601String(),
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
        if (sourceBasename != null) 'sourceBasename': sourceBasename,
      };

  static bool hasMeaningfulProgress(ReadingProgressRecord record) {
    if (record.completed) return false;
    if (record.progressFraction >=
        ReadingProgressPolicy.minContinueReadingProgress) {
      return true;
    }
    return switch (record.location) {
      PdfReadingLocationPayload(:final pageIndex) =>
        pageIndex >= ReadingProgressPolicy.minMeaningfulPageIndex,
      ComicReadingLocationPayload(:final pageIndex) =>
        pageIndex >= ReadingProgressPolicy.minMeaningfulPageIndex,
      EpubReadingLocationPayload(
        :final spineIndex,
        :final sectionRelativeOffset,
      ) =>
        spineIndex >= ReadingProgressPolicy.minMeaningfulSpineIndex ||
            sectionRelativeOffset >=
                ReadingProgressPolicy.epubMeaningfulScrollOffset,
    };
  }

  static double fractionForPdf(int pageIndex, int pageCount) {
    if (pageCount <= 0) return 0;
    return ((pageIndex + 1) / pageCount).clamp(0.0, 1.0);
  }

  static double fractionForComic(int pageIndex, int pageCount) {
    if (pageCount <= 0) return 0;
    if (pageCount == 1) {
      return ReadingProgressPolicy.singlePageComicInProgressFraction;
    }
    return ((pageIndex + 1) / pageCount).clamp(0.0, 1.0);
  }

  static double fractionForEpub({
    required int spineIndex,
    required int spineCount,
    required double sectionRelativeOffset,
    required double sectionExtent,
  }) {
    if (spineCount <= 0) return 0;
    final chapterBase = spineIndex / spineCount;
    if (sectionExtent <= 0) {
      return ((spineIndex + 1) / spineCount).clamp(0.0, 1.0);
    }
    final within = (sectionRelativeOffset / sectionExtent).clamp(0.0, 1.0);
    final perChapter = 1.0 / spineCount;
    return (chapterBase + within * perChapter).clamp(0.0, 1.0);
  }
}
