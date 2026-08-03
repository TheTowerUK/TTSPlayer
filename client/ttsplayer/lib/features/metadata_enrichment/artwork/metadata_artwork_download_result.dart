import 'metadata_artwork_cache_entry.dart';
import 'metadata_artwork_reference.dart';

/// Outcome of an explicit artwork download or refresh (M7.4.3).
sealed class MetadataArtworkDownloadResult {
  const MetadataArtworkDownloadResult();
}

class MetadataArtworkDownloadSuccess extends MetadataArtworkDownloadResult {
  const MetadataArtworkDownloadSuccess({
    required this.cacheEntry,
    required this.updatedReference,
  });

  final MetadataArtworkCacheEntry cacheEntry;
  final MetadataArtworkReference updatedReference;
}

class MetadataArtworkDownloadFailure extends MetadataArtworkDownloadResult {
  const MetadataArtworkDownloadFailure({
    required this.category,
    this.message,
    this.updatedReference,
  });

  final MetadataArtworkDownloadFailureCategory category;
  final String? message;

  /// Reference patch for callers to persist failure state when appropriate.
  final MetadataArtworkReference? updatedReference;
}

enum MetadataArtworkDownloadFailureCategory {
  insecureUri,
  httpError,
  network,
  timeout,
  cancelled,
  validation,
  filesystem,
  staleGeneration,
  urlUnavailable,
}
