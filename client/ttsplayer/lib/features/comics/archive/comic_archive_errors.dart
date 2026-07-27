/// Classified comic archive / reader failures (user-safe + redacted diagnostics).
enum ComicArchiveErrorKind {
  archiveMissing,
  unsupportedArchiveType,
  corruptArchive,
  emptyArchive,
  noReadableImages,
  unsafeEntryPath,
  encryptedArchive,
  multiVolumeUnsupported,
  pageExtractFailed,
  unsupportedImageEntry,
  timeout,
  ioFailure,
  unknown,
}

class ComicArchiveException implements Exception {
  ComicArchiveException({
    required this.kind,
    required this.userMessage,
    this.diagnosticDetail,
  });

  final ComicArchiveErrorKind kind;
  final String userMessage;

  /// Basename labels / codes only — never full media library paths.
  final String? diagnosticDetail;

  @override
  String toString() => 'ComicArchiveException($kind): $userMessage';
}
