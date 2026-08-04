import '../artwork/metadata_artwork_cache_state.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';
import '../services/book_metadata_match_transition.dart';

/// Explicit artwork actions exposed by the enrichment section (M7.4.5).
enum MetadataArtworkAction {
  downloadCover,
  refreshCover,
}

/// Bounded cover status and permitted artwork actions (M7.4.5).
class MetadataArtworkPresentation {
  const MetadataArtworkPresentation({
    required this.statusLabel,
    required this.permittedActions,
  });

  final String statusLabel;
  final Set<MetadataArtworkAction> permittedActions;

  bool permits(MetadataArtworkAction action) =>
      permittedActions.contains(action);

  static MetadataArtworkPresentation forRecord(MetadataEnrichmentRecord? record) {
    if (record == null ||
        !BookMetadataMatchTransition.isProviderLinked(record)) {
      return const MetadataArtworkPresentation(
        statusLabel: 'Cover unavailable',
        permittedActions: {},
      );
    }

    if (record.matchState == EnrichmentMatchState.ignored) {
      return const MetadataArtworkPresentation(
        statusLabel: 'Cover unavailable',
        permittedActions: {},
      );
    }

    final reference = record.artworkReference;
    if (reference == null) {
      return const MetadataArtworkPresentation(
        statusLabel: 'Cover unavailable',
        permittedActions: {},
      );
    }

    return switch (reference.cacheState) {
      MetadataArtworkCacheState.available => MetadataArtworkPresentation(
          statusLabel: 'Cover available',
          permittedActions: {MetadataArtworkAction.downloadCover},
        ),
      MetadataArtworkCacheState.downloaded => MetadataArtworkPresentation(
          statusLabel: 'Cover downloaded',
          permittedActions: {MetadataArtworkAction.refreshCover},
        ),
      MetadataArtworkCacheState.stale => MetadataArtworkPresentation(
          statusLabel: 'Cover stale',
          permittedActions: {MetadataArtworkAction.refreshCover},
        ),
      MetadataArtworkCacheState.failed => MetadataArtworkPresentation(
          statusLabel: 'Cover download failed',
          permittedActions: {MetadataArtworkAction.downloadCover},
        ),
      MetadataArtworkCacheState.unavailable => const MetadataArtworkPresentation(
          statusLabel: 'Cover unavailable',
          permittedActions: {},
        ),
    };
  }
}
