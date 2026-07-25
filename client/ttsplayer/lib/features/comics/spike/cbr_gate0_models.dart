/// Isolated Phase 6.3 Gate 0 spike models — not wired to browse/detail/search.
library;

/// Classified failure modes for CBR/RAR Gate 0 evidence.
enum CbrArchiveErrorKind {
  nativeLibraryMissing,
  nativeLibraryLoadFailed,
  notAnArchive,
  corruptArchive,
  encryptedArchive,
  passwordRequired,
  multiVolumeUnsupported,
  emptyArchive,
  noSupportedImages,
  entryNotFound,
  pathTraversalRejected,
  ioFailure,
  unsupported,
  unknown,
}

/// User-safe message suitable for a future Phase 6.3 reader banner.
class CbrArchiveException implements Exception {
  CbrArchiveException({
    required this.kind,
    required this.userMessage,
    this.diagnosticCode,
    this.diagnosticDetail,
  });

  final CbrArchiveErrorKind kind;
  final String userMessage;
  final int? diagnosticCode;

  /// Must not contain absolute filesystem paths of the media library.
  final String? diagnosticDetail;

  @override
  String toString() =>
      'CbrArchiveException($kind, code=$diagnosticCode): $userMessage';
}

/// One archive entry after listing (directories filtered by adapter).
class CbrArchiveEntry {
  const CbrArchiveEntry({
    required this.name,
    required this.index,
    required this.sizeBytes,
    required this.packedSizeBytes,
    required this.isDirectory,
    required this.isImage,
  });

  final String name;
  final int index;
  final int sizeBytes;
  final int packedSizeBytes;
  final bool isDirectory;
  final bool isImage;
}

/// Result of listing a CBR/RAR for Gate 0 evidence.
class CbrArchiveListing {
  const CbrArchiveListing({
    required this.entries,
    required this.imageEntries,
    required this.listDuration,
    required this.archiveLabel,
  });

  final List<CbrArchiveEntry> entries;
  final List<CbrArchiveEntry> imageEntries;
  final Duration listDuration;

  /// Basename-only label for diagnostics (never a full path).
  final String archiveLabel;
}

/// Bytes for a selectively extracted page/entry.
class CbrExtractedPage {
  const CbrExtractedPage({
    required this.entryName,
    required this.bytes,
    required this.duration,
    required this.usedTemporaryDirectory,
  });

  final String entryName;
  final List<int> bytes;
  final Duration duration;

  /// True when the underlying stack wrote temp files during extraction.
  final bool usedTemporaryDirectory;
}
