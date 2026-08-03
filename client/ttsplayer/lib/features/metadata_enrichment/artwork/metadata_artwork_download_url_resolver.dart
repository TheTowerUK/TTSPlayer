import 'metadata_artwork_reference.dart';

/// Resolves a download URL for a provider artwork reference (M7.4.3).
///
/// Provider-specific implementations construct Covers API URLs at download time
/// only — URLs are never persisted on the reference.
abstract class MetadataArtworkDownloadUrlResolver {
  const MetadataArtworkDownloadUrlResolver();

  Uri? resolveDownloadUrl(MetadataArtworkReference reference);
}
