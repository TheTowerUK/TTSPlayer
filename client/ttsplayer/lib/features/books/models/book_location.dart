import 'book_format.dart';

/// Non-persistent reader location (Phase 6.4). Serializable shape for Phase 6.5.
sealed class BookLocation {
  const BookLocation({
    required this.documentId,
    required this.format,
  });

  final String documentId;
  final BookFormat format;

  Map<String, Object?> toJson();
}

/// PDF location uses zero-based page index consistently.
class PdfBookLocation extends BookLocation {
  const PdfBookLocation({
    required super.documentId,
    required this.pageIndex,
    required this.pageCount,
  }) : super(format: BookFormat.pdf);

  final int pageIndex;
  final int pageCount;

  @override
  Map<String, Object?> toJson() => {
        'format': 'pdf',
        'document_id': documentId,
        'page_index': pageIndex,
        'page_count': pageCount,
      };
}

/// EPUB location uses spine index + href (stable within package).
class EpubBookLocation extends BookLocation {
  const EpubBookLocation({
    required super.documentId,
    required this.spineIndex,
    required this.spineHref,
    this.chapterTitle,
    this.scrollOffset = 0,
    this.progressPercent,
  }) : super(format: BookFormat.epub);

  final int spineIndex;
  final String spineHref;
  final String? chapterTitle;
  final double scrollOffset;
  final double? progressPercent;

  @override
  Map<String, Object?> toJson() => {
        'format': 'epub',
        'document_id': documentId,
        'spine_index': spineIndex,
        'spine_href': spineHref,
        if (chapterTitle != null) 'chapter_title': chapterTitle,
        'scroll_offset': scrollOffset,
        if (progressPercent != null) 'progress_percent': progressPercent,
      };
}
