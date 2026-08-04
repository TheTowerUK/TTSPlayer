import '../../features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import '../../features/metadata_enrichment/artwork/metadata_artwork_resolution.dart';
import '../../features/metadata_enrichment/artwork/metadata_artwork_resolver.dart';
import '../../features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import '../../models/media_folder.dart';
import '../../models/media_item.dart';
import 'artwork_candidate.dart';
import 'artwork_service.dart';

/// Presentation entry point for media-item artwork (M7.4.6).
///
/// Composes [MetadataArtworkResolver] so widgets request one resolved result
/// without querying enrichment or cache repositories directly.
/// Never downloads, constructs provider URLs, or rewrites cache metadata.
class ArtworkPresentationService {
  ArtworkPresentationService({
    required ArtworkService artworkService,
    required MetadataEnrichmentRepository enrichmentRepository,
    MetadataArtworkCacheRepository? cacheRepository,
    MetadataArtworkResolver? resolver,
  })  : _artworkService = artworkService,
        _enrichmentRepository = enrichmentRepository,
        _resolver = resolver ??
            MetadataArtworkResolver(
              artworkService: artworkService,
              cacheRepository: cacheRepository,
            );

  final ArtworkService _artworkService;
  final MetadataEnrichmentRepository _enrichmentRepository;
  final MetadataArtworkResolver _resolver;

  /// Immediate local-only candidate for first paint (sync).
  ArtworkCandidate localCandidateForMediaItem(
    MediaItem item, {
    MediaFolder? parentFolder,
  }) {
    return _artworkService.forMediaItem(item, parentFolder: parentFolder);
  }

  /// Full local-first resolution including eligible provider cache.
  Future<MetadataArtworkResolution> resolveForMediaItem({
    required MediaItem item,
    MediaFolder? parentFolder,
  }) {
    final record = _enrichmentRepository.getByItemId(item.id);
    return _resolver.resolveForMediaItem(
      item: item,
      parentFolder: parentFolder,
      enrichmentRecord: record,
    );
  }
}
