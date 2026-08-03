import '../../../../models/media_folder.dart';
import '../../../../models/media_item.dart';
import '../../../../models/media_kind.dart';
import '../../../../services/artwork/artwork_candidate.dart';
import '../../../../services/artwork/artwork_kind.dart';
import '../../../../services/artwork/artwork_service.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';
import '../services/book_metadata_match_transition.dart';
import 'metadata_artwork_cache_entry.dart';
import 'metadata_artwork_cache_repository.dart';
import 'metadata_artwork_cache_state.dart';
import 'metadata_artwork_reference.dart';
import 'metadata_artwork_resolution.dart';

/// Central artwork precedence resolver (M7.4.4).
///
/// Composes [ArtworkService] for trusted local artwork and consults
/// [MetadataArtworkCacheRepository] for eligible provider-cache files only.
/// Never downloads, decodes images, or constructs provider URLs.
class MetadataArtworkResolver {
  const MetadataArtworkResolver({
    required ArtworkService artworkService,
    MetadataArtworkCacheRepository? cacheRepository,
  })  : _artworkService = artworkService,
        _cacheRepository = cacheRepository;

  final ArtworkService _artworkService;
  final MetadataArtworkCacheRepository? _cacheRepository;

  /// Resolves artwork for [item] using local probes first, then provider cache.
  Future<MetadataArtworkResolution> resolveForMediaItem({
    required MediaItem item,
    MediaFolder? parentFolder,
    MetadataEnrichmentRecord? enrichmentRecord,
  }) async {
    final localCandidate = _artworkService.forMediaItem(
      item,
      parentFolder: parentFolder,
    );

    if (_isTrustedLocalSource(localCandidate.source)) {
      return MetadataArtworkResolution.fromLocal(localCandidate);
    }

    final ineligibility = _evaluateProviderEligibility(
      item: item,
      record: enrichmentRecord,
    );
    if (ineligibility != null) {
      return MetadataArtworkResolution.fallback(
        candidate: localCandidate,
        reason: ineligibility,
      );
    }

    final repository = _cacheRepository;
    if (repository == null) {
      return MetadataArtworkResolution.fallback(
        candidate: localCandidate,
        reason: MetadataArtworkIneligibilityReason.cacheRepositoryUnavailable,
      );
    }

    try {
      final reference = enrichmentRecord!.artworkReference!;
      final peek = await repository.peekLookup(reference.cacheKey);
      if (peek == null) {
        return MetadataArtworkResolution.fallback(
          candidate: localCandidate,
          reason: MetadataArtworkIneligibilityReason.cacheEntryMissing,
        );
      }

      final identityReason = _validateIdentity(
        item: item,
        record: enrichmentRecord,
        reference: reference,
        entry: peek.entry,
      );
      if (identityReason != null) {
        return MetadataArtworkResolution.fallback(
          candidate: localCandidate,
          reason: identityReason,
        );
      }

      if (!_isDisplayableCacheState(peek.entry.cacheState)) {
        return MetadataArtworkResolution.fallback(
          candidate: localCandidate,
          reason: MetadataArtworkIneligibilityReason.cacheStateIneligible,
        );
      }

      final isStale = peek.entry.cacheState == MetadataArtworkCacheState.stale ||
          reference.cacheState == MetadataArtworkCacheState.stale;

      final candidate = ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.providerCache,
        filePath: peek.absoluteFilePath,
        visualKind: _artworkService.visualKindForMediaItem(item),
      );

      return MetadataArtworkResolution.fromProviderCache(
        candidate: candidate,
        isStale: isStale,
        cacheKey: reference.cacheKey,
      );
    } catch (_) {
      return MetadataArtworkResolution.fallback(
        candidate: localCandidate,
        reason: MetadataArtworkIneligibilityReason.cacheRepositoryUnavailable,
      );
    }
  }

  static bool _isTrustedLocalSource(ArtworkSource source) {
    return source == ArtworkSource.catalogThumbnail ||
        source == ArtworkSource.sidecar ||
        source == ArtworkSource.folderArt;
  }

  static MetadataArtworkIneligibilityReason? _evaluateProviderEligibility({
    required MediaItem item,
    required MetadataEnrichmentRecord? record,
  }) {
    if (item.mediaKind != MediaKind.book) {
      return MetadataArtworkIneligibilityReason.unsupportedMediaKind;
    }
    if (record == null) {
      return MetadataArtworkIneligibilityReason.noEnrichmentRecord;
    }
    if (record.itemId != item.id) {
      return MetadataArtworkIneligibilityReason.itemIdentityMismatch;
    }
    if (!BookMetadataMatchTransition.isProviderLinked(record)) {
      return MetadataArtworkIneligibilityReason.notProviderLinked;
    }
    if (record.matchState == EnrichmentMatchState.ignored) {
      return MetadataArtworkIneligibilityReason.notProviderLinked;
    }
    final reference = record.artworkReference;
    if (reference == null) {
      return MetadataArtworkIneligibilityReason.noArtworkReference;
    }
    if (!_referenceLinkedToRecord(record, reference)) {
      return MetadataArtworkIneligibilityReason.identityMismatch;
    }
    return null;
  }

  static MetadataArtworkIneligibilityReason? _validateIdentity({
    required MediaItem item,
    required MetadataEnrichmentRecord record,
    required MetadataArtworkReference reference,
    required MetadataArtworkCacheEntry entry,
  }) {
    if (record.itemId != item.id) {
      return MetadataArtworkIneligibilityReason.itemIdentityMismatch;
    }
    if (reference.cacheKey != entry.cacheKey) {
      return MetadataArtworkIneligibilityReason.cacheKeyMismatch;
    }
    if (reference.providerId != entry.providerId ||
        reference.providerRecordId != entry.providerRecordId ||
        reference.artworkId != entry.artworkId) {
      return MetadataArtworkIneligibilityReason.identityMismatch;
    }
    if (record.providerId != reference.providerId ||
        record.providerRecordId != reference.providerRecordId) {
      return MetadataArtworkIneligibilityReason.identityMismatch;
    }
    return null;
  }

  static bool _referenceLinkedToRecord(
    MetadataEnrichmentRecord record,
    MetadataArtworkReference reference,
  ) {
    return record.providerId == reference.providerId &&
        record.providerRecordId == reference.providerRecordId;
  }

  static bool _isDisplayableCacheState(MetadataArtworkCacheState state) {
    return state == MetadataArtworkCacheState.downloaded ||
        state == MetadataArtworkCacheState.stale;
  }
}
