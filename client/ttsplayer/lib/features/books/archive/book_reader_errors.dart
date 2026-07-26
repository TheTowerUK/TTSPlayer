/// Classified book reader failures (user-safe + redacted diagnostics).
enum BookReaderErrorKind {
  fileMissing,
  unsupportedFormat,
  pdfInvalid,
  pdfCorrupt,
  pdfEncrypted,
  pdfRendererUnavailable,
  pdfPageRenderFailed,
  epubInvalidZip,
  epubMissingContainer,
  epubMalformedManifest,
  epubInvalidSpine,
  epubMissingResource,
  epubUnsafePath,
  epubUnsupportedActiveContent,
  epubResourceTooLarge,
  readerTimeout,
  ioFailure,
  unknown,
}

class BookReaderException implements Exception {
  BookReaderException({
    required this.kind,
    required this.userMessage,
    this.diagnosticDetail,
  });

  final BookReaderErrorKind kind;
  final String userMessage;
  final String? diagnosticDetail;

  @override
  String toString() => 'BookReaderException($kind): $userMessage';
}
