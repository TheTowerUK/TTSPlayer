/// One ordered comic page discovered inside an archive.
class ComicPageRef {
  const ComicPageRef({
    required this.entryName,
    required this.index,
    this.sizeBytes,
  });

  /// Archive-relative path using `/` separators.
  final String entryName;

  /// Zero-based index in natural reading order.
  final int index;

  final int? sizeBytes;
}
