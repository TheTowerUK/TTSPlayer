import '../../../../services/artwork/artwork_candidate.dart';
import '../../../../services/artwork/artwork_kind.dart';

/// Bounded reason provider artwork was not selected (M7.4.4).
enum MetadataArtworkIneligibilityReason {
  unsupportedMediaKind('unsupported_media_kind'),
  itemIdentityMismatch('item_identity_mismatch'),
  noEnrichmentRecord('no_enrichment_record'),
  notProviderLinked('not_provider_linked'),
  noArtworkReference('no_artwork_reference'),
  identityMismatch('identity_mismatch'),
  cacheKeyMismatch('cache_key_mismatch'),
  cacheEntryMissing('cache_entry_missing'),
  cacheFileMissing('cache_file_missing'),
  cacheStateIneligible('cache_state_ineligible'),
  cachePathUnsafe('cache_path_unsafe'),
  cacheRepositoryUnavailable('cache_repository_unavailable');

  const MetadataArtworkIneligibilityReason(this.code);

  final String code;
}

/// Provider-neutral artwork resolution for one media item (M7.4.4).
class MetadataArtworkResolution {
  const MetadataArtworkResolution({
    required this.candidate,
    required this.isLocal,
    required this.isProviderCached,
    required this.isPlaceholder,
    required this.isStale,
    required this.usedFallback,
    this.ineligibilityReason,
    this.provenanceLabel,
    this.cacheKey,
  });

  final ArtworkCandidate candidate;
  final bool isLocal;
  final bool isProviderCached;
  final bool isPlaceholder;
  final bool isStale;
  final bool usedFallback;
  final MetadataArtworkIneligibilityReason? ineligibilityReason;
  final String? provenanceLabel;

  /// Stable cache key when [isProviderCached] — for diagnostics only.
  final String? cacheKey;

  factory MetadataArtworkResolution.fromLocal(ArtworkCandidate candidate) {
    return MetadataArtworkResolution(
      candidate: candidate,
      isLocal: candidate.source != ArtworkSource.placeholder &&
          candidate.source != ArtworkSource.providerCache,
      isProviderCached: false,
      isPlaceholder: candidate.source == ArtworkSource.placeholder,
      isStale: false,
      usedFallback: false,
    );
  }

  factory MetadataArtworkResolution.fromProviderCache({
    required ArtworkCandidate candidate,
    required bool isStale,
    required String cacheKey,
    String? provenanceLabel,
  }) {
    return MetadataArtworkResolution(
      candidate: candidate,
      isLocal: false,
      isProviderCached: true,
      isPlaceholder: false,
      isStale: isStale,
      usedFallback: false,
      provenanceLabel: provenanceLabel ?? 'Cached provider artwork',
      cacheKey: cacheKey,
    );
  }

  factory MetadataArtworkResolution.fallback({
    required ArtworkCandidate candidate,
    MetadataArtworkIneligibilityReason? reason,
  }) {
    return MetadataArtworkResolution(
      candidate: candidate,
      isLocal: candidate.source != ArtworkSource.placeholder,
      isProviderCached: false,
      isPlaceholder: candidate.source == ArtworkSource.placeholder,
      isStale: false,
      usedFallback: reason != null,
      ineligibilityReason: reason,
    );
  }
}
