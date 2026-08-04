import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../artwork/metadata_artwork_cache_repository.dart';
import '../artwork/metadata_artwork_cache_state.dart';
import '../artwork/metadata_artwork_download_generation_guard.dart';
import '../artwork/metadata_artwork_download_result.dart';
import '../artwork/metadata_artwork_download_service.dart';
import '../artwork/metadata_artwork_reference.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';
import 'book_metadata_artwork_workflow_result.dart';
import 'book_metadata_match_transition.dart';
import 'metadata_enrichment_repository.dart';

/// Item-scoped artwork identity captured at workflow start (M7.4.5).
class BookMetadataArtworkOperationIdentity {
  const BookMetadataArtworkOperationIdentity({
    required this.itemId,
    required this.providerId,
    required this.providerRecordId,
    required this.artworkId,
    required this.cacheKey,
    required this.generation,
  });

  final String itemId;
  final String providerId;
  final String providerRecordId;
  final String artworkId;
  final String cacheKey;
  final int generation;
}

/// Book cover download and refresh workflow orchestration (M7.4.5).
///
/// Owns provider URI resolution timing, cache writes via
/// [MetadataArtworkDownloadService], and enrichment record artwork merges.
/// Never performs metadata search or artwork precedence resolution.
class BookMetadataArtworkCoordinator {
  BookMetadataArtworkCoordinator({
    required MetadataEnrichmentRepository repository,
    required MetadataArtworkDownloadService downloadService,
    MetadataArtworkDownloadGenerationGuard? generationGuard,
    MetadataArtworkCacheRepository? cacheRepository,
  })  : _repository = repository,
        _downloadService = downloadService,
        _generationGuard =
            generationGuard ?? MetadataArtworkDownloadGenerationGuard(),
        _cacheRepository = cacheRepository;

  final MetadataEnrichmentRepository _repository;
  final MetadataArtworkDownloadService _downloadService;
  final MetadataArtworkDownloadGenerationGuard _generationGuard;
  final MetadataArtworkCacheRepository? _cacheRepository;

  final Map<String, Future<BookMetadataArtworkWorkflowResult>> _pendingByCacheKey =
      {};

  /// Bumps the item-scoped artwork generation (call on relink/unlink/item change).
  int invalidateItemOperations(String itemId) => _generationGuard.bump(itemId);

  int generationFor(String itemId) => _generationGuard.generationFor(itemId);

  Future<BookMetadataArtworkWorkflowResult> downloadCover({
    required MediaItem item,
    int? expectedGeneration,
  }) {
    return _runWorkflow(
      item: item,
      refresh: false,
      expectedGeneration: expectedGeneration,
    );
  }

  Future<BookMetadataArtworkWorkflowResult> refreshCover({
    required MediaItem item,
    int? expectedGeneration,
  }) {
    return _runWorkflow(
      item: item,
      refresh: true,
      expectedGeneration: expectedGeneration,
    );
  }

  Future<BookMetadataArtworkWorkflowResult> _runWorkflow({
    required MediaItem item,
    required bool refresh,
    int? expectedGeneration,
  }) async {
    final eligibility = _evaluateEligibility(item);
    if (eligibility.error != null) {
      return eligibility.error!;
    }
    final record = eligibility.record!;
    final reference = eligibility.reference!;

    final generation =
        expectedGeneration ?? _generationGuard.generationFor(item.id);
    final identity = BookMetadataArtworkOperationIdentity(
      itemId: item.id,
      providerId: reference.providerId,
      providerRecordId: reference.providerRecordId,
      artworkId: reference.artworkId,
      cacheKey: reference.cacheKey,
      generation: generation,
    );

    if (!refresh && await _hasValidMatchingCache(reference) &&
        _referenceMatchesCacheMetadata(record, reference)) {
      return const BookMetadataArtworkAlreadyCached();
    }

    final pendingKey = '${identity.cacheKey}:${refresh ? 'refresh' : 'download'}';
    final existingPending = _pendingByCacheKey[pendingKey];
    if (existingPending != null) {
      return existingPending;
    }

    final operation = _executeWorkflow(
      identity: identity,
      reference: reference,
      refresh: refresh,
    );
    _pendingByCacheKey[pendingKey] = operation;
    try {
      return await operation;
    } finally {
      _pendingByCacheKey.remove(pendingKey);
    }
  }

  Future<BookMetadataArtworkWorkflowResult> _executeWorkflow({
    required BookMetadataArtworkOperationIdentity identity,
    required MetadataArtworkReference reference,
    required bool refresh,
  }) async {
    if (!_generationGuard.isCurrent(identity.itemId, identity.generation)) {
      return const BookMetadataArtworkIdentityChanged();
    }

    final downloadResult = refresh
        ? await _downloadService.refresh(
            reference: reference,
            itemId: identity.itemId,
            expectedGeneration: identity.generation,
          )
        : await _downloadService.download(
            reference: reference,
            itemId: identity.itemId,
            expectedGeneration: identity.generation,
          );

    if (!_identityStillCurrent(identity)) {
      return const BookMetadataArtworkIdentityChanged();
    }

    return switch (downloadResult) {
      MetadataArtworkDownloadSuccess(:final updatedReference) =>
        await _handleDownloadSuccess(
          identity: identity,
          reference: reference,
          updatedReference: updatedReference,
          refresh: refresh,
          hadExistingCache: refresh ||
              reference.cacheState == MetadataArtworkCacheState.downloaded ||
              reference.cacheState == MetadataArtworkCacheState.stale,
        ),
      MetadataArtworkDownloadFailure(
        :final category,
        :final updatedReference,
      ) =>
        _handleDownloadFailure(
          identity: identity,
          reference: reference,
          category: category,
          updatedReference: updatedReference,
          refresh: refresh,
        ),
    };
  }

  Future<BookMetadataArtworkWorkflowResult> _handleDownloadSuccess({
    required BookMetadataArtworkOperationIdentity identity,
    required MetadataArtworkReference reference,
    required MetadataArtworkReference updatedReference,
    required bool refresh,
    required bool hadExistingCache,
  }) async {
    final recordBefore = _repository.getByItemId(identity.itemId);
    final unchangedBeforePersist = recordBefore != null &&
        _recordsEqualArtwork(
          recordBefore,
          recordBefore.copyWith(artworkReference: updatedReference.normalized()),
        );

    final persistResult = await _persistArtworkReference(
      identity: identity,
      updatedReference: updatedReference,
    );
    if (persistResult != null) {
      return persistResult;
    }

    if (refresh) {
      return const BookMetadataArtworkRefreshed();
    }
    if (hadExistingCache && unchangedBeforePersist) {
      return const BookMetadataArtworkAlreadyCached();
    }
    return const BookMetadataArtworkDownloaded();
  }

  BookMetadataArtworkWorkflowResult _handleDownloadFailure({
    required BookMetadataArtworkOperationIdentity identity,
    required MetadataArtworkReference reference,
    required MetadataArtworkDownloadFailureCategory category,
    MetadataArtworkReference? updatedReference,
    required bool refresh,
  }) {
    if (category == MetadataArtworkDownloadFailureCategory.staleGeneration ||
        category == MetadataArtworkDownloadFailureCategory.cancelled) {
      return category == MetadataArtworkDownloadFailureCategory.cancelled
          ? const BookMetadataArtworkCancelled()
          : const BookMetadataArtworkIdentityChanged();
    }

    if (refresh &&
        updatedReference != null &&
        _isDisplayableReference(updatedReference)) {
      return BookMetadataArtworkPriorCacheRetained(category);
    }

    return switch (category) {
      MetadataArtworkDownloadFailureCategory.validation =>
        const BookMetadataArtworkValidationFailure(),
      MetadataArtworkDownloadFailureCategory.filesystem =>
        const BookMetadataArtworkDiskFailure(),
      MetadataArtworkDownloadFailureCategory.insecureUri ||
      MetadataArtworkDownloadFailureCategory.httpError ||
      MetadataArtworkDownloadFailureCategory.network ||
      MetadataArtworkDownloadFailureCategory.timeout ||
      MetadataArtworkDownloadFailureCategory.urlUnavailable =>
        BookMetadataArtworkProviderFailure(category),
      MetadataArtworkDownloadFailureCategory.staleGeneration =>
        const BookMetadataArtworkIdentityChanged(),
      MetadataArtworkDownloadFailureCategory.cancelled =>
        const BookMetadataArtworkCancelled(),
    };
  }

  Future<BookMetadataArtworkWorkflowResult?> _persistArtworkReference({
    required BookMetadataArtworkOperationIdentity identity,
    required MetadataArtworkReference updatedReference,
  }) async {
    if (!_identityStillCurrent(identity)) {
      return const BookMetadataArtworkIdentityChanged();
    }

    final current = _repository.getByItemId(identity.itemId);
    if (current == null) {
      return const BookMetadataArtworkNotLinked();
    }

    final merged = current.copyWith(
      artworkReference: updatedReference.normalized(),
    ).normalized();

    if (_recordsEqualArtwork(current, merged)) {
      return null;
    }

    final saveResult = await _repository.upsert(merged);
    if (!saveResult.success) {
      return const BookMetadataArtworkPersistenceFailure();
    }

    if (!_identityStillCurrent(identity)) {
      return const BookMetadataArtworkIdentityChanged();
    }

    return null;
  }

  _ArtworkEligibility _evaluateEligibility(MediaItem item) {
    if (item.mediaKind != MediaKind.book) {
      return const _ArtworkEligibility.ineligible(
        BookMetadataArtworkNotLinked(),
      );
    }

    final record = _repository.getByItemId(item.id);
    if (record == null || !BookMetadataMatchTransition.isProviderLinked(record)) {
      return const _ArtworkEligibility.ineligible(
        BookMetadataArtworkNotLinked(),
      );
    }

    if (record.matchState == EnrichmentMatchState.ignored) {
      return const _ArtworkEligibility.ineligible(
        BookMetadataArtworkNotLinked(),
      );
    }

    final reference = record.artworkReference;
    if (reference == null) {
      return const _ArtworkEligibility.ineligible(
        BookMetadataArtworkNoArtworkAvailable(),
      );
    }

    if (!_referenceLinkedToRecord(record, reference)) {
      return const _ArtworkEligibility.ineligible(
        BookMetadataArtworkIdentityChanged(),
      );
    }

    return _ArtworkEligibility.eligible(record, reference);
  }

  bool _identityStillCurrent(BookMetadataArtworkOperationIdentity identity) {
    if (!_generationGuard.isCurrent(identity.itemId, identity.generation)) {
      return false;
    }

    final record = _repository.getByItemId(identity.itemId);
    if (record == null) {
      return false;
    }

    final reference = record.artworkReference;
    if (reference == null) {
      return false;
    }

    return record.itemId == identity.itemId &&
        record.providerId == identity.providerId &&
        record.providerRecordId == identity.providerRecordId &&
        reference.artworkId == identity.artworkId &&
        reference.cacheKey == identity.cacheKey;
  }

  static bool _referenceLinkedToRecord(
    MetadataEnrichmentRecord record,
    MetadataArtworkReference reference,
  ) {
    return record.providerId == reference.providerId &&
        record.providerRecordId == reference.providerRecordId;
  }

  Future<bool> _hasValidMatchingCache(MetadataArtworkReference reference) async {
    final repository = _cacheRepository;
    if (repository == null) {
      return reference.cacheState == MetadataArtworkCacheState.downloaded ||
          reference.cacheState == MetadataArtworkCacheState.stale;
    }

    final peek = await repository.peekLookup(reference.cacheKey);
    if (peek == null) {
      return false;
    }

    final entry = peek.entry;
    return entry.providerId == reference.providerId &&
        entry.providerRecordId == reference.providerRecordId &&
        entry.artworkId == reference.artworkId &&
        (entry.cacheState == MetadataArtworkCacheState.downloaded ||
            entry.cacheState == MetadataArtworkCacheState.stale);
  }

  static bool _isDisplayableReference(MetadataArtworkReference reference) {
    return reference.cacheState == MetadataArtworkCacheState.downloaded ||
        reference.cacheState == MetadataArtworkCacheState.stale;
  }

  static bool _referenceMatchesCacheMetadata(
    MetadataEnrichmentRecord record,
    MetadataArtworkReference reference,
  ) {
    return _isDisplayableReference(reference) &&
        reference.localRelativePath != null &&
        reference.localRelativePath!.isNotEmpty;
  }

  static bool _recordsEqualArtwork(
    MetadataEnrichmentRecord before,
    MetadataEnrichmentRecord after,
  ) {
    return before.artworkReference == after.artworkReference;
  }
}

class _ArtworkEligibility {
  const _ArtworkEligibility.eligible(this.record, this.reference) : error = null;

  const _ArtworkEligibility.ineligible(this.error)
      : record = null,
        reference = null;

  final MetadataEnrichmentRecord? record;
  final MetadataArtworkReference? reference;
  final BookMetadataArtworkWorkflowResult? error;
}
