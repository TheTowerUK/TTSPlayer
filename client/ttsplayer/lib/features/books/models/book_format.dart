enum BookFormat {
  pdf,
  epub,
}

extension BookFormatX on BookFormat {
  String get label => switch (this) {
        BookFormat.pdf => 'PDF',
        BookFormat.epub => 'EPUB',
      };
}

BookFormat? bookFormatFromExtension(String extension) {
  return switch (extension.toLowerCase()) {
    'pdf' => BookFormat.pdf,
    'epub' => BookFormat.epub,
    _ => null,
  };
}
