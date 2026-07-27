import '../../books/models/book_format.dart';

/// Supported persisted reader formats for reading progress (M6.5).
enum ReadingReaderFormat {
  pdf,
  epub,
  cbz,
  cbr;

  String get storageName => name;

  static ReadingReaderFormat? fromString(String? raw) {
    if (raw == null) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Format-specific location payload stored inside [ReadingProgressRecord].
sealed class ReadingLocationPayload {
  const ReadingLocationPayload({required this.format});

  final ReadingReaderFormat format;

  Map<String, Object?> toJson();

  static ReadingLocationPayload? fromJson(Map<String, dynamic> json) {
    final format = ReadingReaderFormat.fromString(json['format'] as String?);
    return switch (format) {
      ReadingReaderFormat.pdf => PdfReadingLocationPayload.fromJson(json),
      ReadingReaderFormat.epub => EpubReadingLocationPayload.fromJson(json),
      ReadingReaderFormat.cbz ||
      ReadingReaderFormat.cbr =>
        ComicReadingLocationPayload.fromJson(json),
      null => null,
    };
  }
}

class PdfReadingLocationPayload extends ReadingLocationPayload {
  const PdfReadingLocationPayload({
    required this.pageIndex,
    required this.pageCountAtSave,
    this.pageRelativeOffset,
  }) : super(format: ReadingReaderFormat.pdf);

  final int pageIndex;
  final int pageCountAtSave;
  final double? pageRelativeOffset;

  @override
  Map<String, Object?> toJson() => {
        'format': format.storageName,
        'page_index': pageIndex,
        'page_count_at_save': pageCountAtSave,
        if (pageRelativeOffset != null)
          'page_relative_offset': pageRelativeOffset,
      };

  static PdfReadingLocationPayload? fromJson(Map<String, dynamic> json) {
    final pageIndex = _parseNonNegativeInt(json['page_index']);
    final pageCount = _parsePositiveInt(json['page_count_at_save']);
    if (pageIndex == null || pageCount == null) return null;
    if (pageIndex >= pageCount) return null;
    final offset = _parseFiniteDouble(json['page_relative_offset']);
    if (json.containsKey('page_relative_offset') && offset == null) {
      return null;
    }
    return PdfReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCount,
      pageRelativeOffset: offset,
    );
  }
}

class EpubReadingLocationPayload extends ReadingLocationPayload {
  const EpubReadingLocationPayload({
    required this.spineIndex,
    required this.spineHref,
    required this.spineCountAtSave,
    this.chapterTitle,
    this.sectionRelativeOffset = 0,
  }) : super(format: ReadingReaderFormat.epub);

  final int spineIndex;
  final String spineHref;
  final int spineCountAtSave;
  final String? chapterTitle;
  final double sectionRelativeOffset;

  @override
  Map<String, Object?> toJson() => {
        'format': format.storageName,
        'spine_index': spineIndex,
        'spine_href': spineHref,
        'spine_count_at_save': spineCountAtSave,
        if (chapterTitle != null) 'chapter_title': chapterTitle,
        'section_relative_offset': sectionRelativeOffset,
      };

  static EpubReadingLocationPayload? fromJson(Map<String, dynamic> json) {
    final spineIndex = _parseNonNegativeInt(json['spine_index']);
    final spineCount = _parsePositiveInt(json['spine_count_at_save']);
    final href = json['spine_href'];
    if (spineIndex == null ||
        spineCount == null ||
        href is! String ||
        href.trim().isEmpty) {
      return null;
    }
    if (spineIndex >= spineCount) return null;
    final offset =
        _parseFiniteDouble(json['section_relative_offset']) ?? 0.0;
    if (offset.isNegative) return null;
    final title = json['chapter_title'];
    return EpubReadingLocationPayload(
      spineIndex: spineIndex,
      spineHref: href.trim(),
      spineCountAtSave: spineCount,
      chapterTitle: title is String && title.trim().isNotEmpty
          ? title.trim()
          : null,
      sectionRelativeOffset: offset,
    );
  }
}

class ComicReadingLocationPayload extends ReadingLocationPayload {
  const ComicReadingLocationPayload({
    required this.pageIndex,
    required this.pageCountAtSave,
    this.entryName,
    required this.archiveFormat,
  }) : super(format: archiveFormat);

  final int pageIndex;
  final int pageCountAtSave;
  final String? entryName;
  final ReadingReaderFormat archiveFormat;

  @override
  Map<String, Object?> toJson() => {
        'format': format.storageName,
        'page_index': pageIndex,
        'page_count_at_save': pageCountAtSave,
        if (entryName != null) 'entry_name': entryName,
      };

  static ComicReadingLocationPayload? fromJson(Map<String, dynamic> json) {
    final format = ReadingReaderFormat.fromString(json['format'] as String?);
    if (format != ReadingReaderFormat.cbz && format != ReadingReaderFormat.cbr) {
      return null;
    }
    final pageIndex = _parseNonNegativeInt(json['page_index']);
    final pageCount = _parsePositiveInt(json['page_count_at_save']);
    if (pageIndex == null || pageCount == null) return null;
    if (pageIndex >= pageCount) return null;
    final entry = json['entry_name'];
    return ComicReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCount,
      entryName: entry is String && entry.trim().isNotEmpty
          ? entry.trim()
          : null,
      archiveFormat: format!,
    );
  }
}

int? _parseNonNegativeInt(Object? raw) {
  if (raw is! num || !raw.isFinite) return null;
  final value = raw.toInt();
  if (value < 0) return null;
  return value;
}

int? _parsePositiveInt(Object? raw) {
  if (raw is! num || !raw.isFinite) return null;
  final value = raw.toInt();
  if (value <= 0) return null;
  return value;
}

double? _parseFiniteDouble(Object? raw) {
  if (raw is! num || !raw.isFinite) return null;
  return raw.toDouble();
}

ReadingReaderFormat? readerFormatForBook(BookFormat format) =>
    switch (format) {
      BookFormat.pdf => ReadingReaderFormat.pdf,
      BookFormat.epub => ReadingReaderFormat.epub,
    };

ReadingReaderFormat? readerFormatForComicExtension(String extension) {
  final lower = extension.toLowerCase();
  return switch (lower) {
    'cbz' || 'zip' => ReadingReaderFormat.cbz,
    _ => null,
  };
}
