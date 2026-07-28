import '../archive/comic_archive_errors.dart';

/// Stable category for a single comic page load/decode failure (Phase 6.4C).
enum ComicPageFailureCategory {
  sourceMissing,
  archiveReadFailure,
  unsupportedImage,
  corruptImageData,
  decodeFailure,
  archiveChanged,
  unknownPageError,
}

/// User-safe failure state for one archive page entry.
class ComicPageFailure {
  const ComicPageFailure({
    required this.entryName,
    required this.category,
    required this.userMessage,
    this.canRetry = true,
  });

  final String entryName;
  final ComicPageFailureCategory category;
  final String userMessage;
  final bool canRetry;

  static ComicPageFailure fromArchiveException(
    String entryName,
    ComicArchiveException exception,
  ) {
    final category = switch (exception.kind) {
      ComicArchiveErrorKind.archiveMissing =>
        ComicPageFailureCategory.sourceMissing,
      ComicArchiveErrorKind.unsupportedImageEntry =>
        ComicPageFailureCategory.unsupportedImage,
      ComicArchiveErrorKind.pageExtractFailed ||
      ComicArchiveErrorKind.corruptArchive =>
        ComicPageFailureCategory.corruptImageData,
      ComicArchiveErrorKind.ioFailure ||
      ComicArchiveErrorKind.timeout =>
        ComicPageFailureCategory.archiveReadFailure,
      _ => ComicPageFailureCategory.unknownPageError,
    };

    final canRetry = category != ComicPageFailureCategory.unsupportedImage;

    return ComicPageFailure(
      entryName: entryName,
      category: category,
      userMessage: exception.userMessage,
      canRetry: canRetry,
    );
  }

  static ComicPageFailure decodeFailure(String entryName) {
    return ComicPageFailure(
      entryName: entryName,
      category: ComicPageFailureCategory.decodeFailure,
      userMessage: 'This page could not be displayed.',
      canRetry: true,
    );
  }

  static ComicPageFailure unknown(String entryName) {
    return ComicPageFailure(
      entryName: entryName,
      category: ComicPageFailureCategory.unknownPageError,
      userMessage: 'This page could not be displayed.',
      canRetry: true,
    );
  }
}

/// Per-page load outcome tracked by [ComicReaderController].
enum ComicPageLoadStatus {
  notRequested,
  loading,
  loaded,
  failed,
}

extension ComicPageLoadStatusX on ComicPageLoadStatus {
  bool get isTerminal =>
      this == ComicPageLoadStatus.loaded || this == ComicPageLoadStatus.failed;
}
