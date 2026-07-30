import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../models/book_search_request.dart';
import '../models/enrichment_match_method.dart';
import '../models/enrichment_match_state.dart';
import '../models/isbn_lookup_request.dart';
import '../models/metadata_enrichment_record.dart';
import '../models/normalized_book_metadata.dart';
import '../models/provider_book_candidate.dart';
import '../providers/book_metadata_provider.dart';
import '../providers/book_metadata_provider_failure.dart';
import '../providers/book_metadata_provider_result.dart';
import 'book_metadata_enrichment_mapper.dart';
import 'metadata_enrichment_repository.dart';

/// Result of an explicit ISBN refresh request (M7.2).
sealed class BookMetadataRefreshResult {
  const BookMetadataRefreshResult();
}

class BookMetadataRefreshSuccess extends BookMetadataRefreshResult {
  const BookMetadataRefreshSuccess(this.record);

  final MetadataEnrichmentRecord record;
}

class BookMetadataRefreshEmpty extends BookMetadataRefreshResult {
  const BookMetadataRefreshEmpty();
}

class BookMetadataRefreshFailure extends BookMetadataRefreshResult {
  const BookMetadataRefreshFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

class BookMetadataRefreshRejected extends BookMetadataRefreshResult {
  const BookMetadataRefreshRejected(this.reason);

  final String reason;
}

/// Result of an explicit search request (M7.2).
sealed class BookMetadataSearchRefreshResult {
  const BookMetadataSearchRefreshResult();
}

class BookMetadataSearchRefreshSuccess extends BookMetadataSearchRefreshResult {
  const BookMetadataSearchRefreshSuccess(this.candidates);

  final List<ProviderBookCandidate> candidates;
}

class BookMetadataSearchRefreshFailure extends BookMetadataSearchRefreshResult {
  const BookMetadataSearchRefreshFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

class BookMetadataSearchRefreshRejected extends BookMetadataSearchRefreshResult {
  const BookMetadataSearchRefreshRejected(this.reason);

  final String reason;
}

/// Connects explicit book lookup requests to enrichment persistence (M7.2).
class BookMetadataRefreshService {
  BookMetadataRefreshService({
    required BookMetadataProvider provider,
    required MetadataEnrichmentRepository repository,
    BookMetadataEnrichmentMapper? mapper,
  })  : _provider = provider,
        _repository = repository,
        _mapper = mapper ?? const BookMetadataEnrichmentMapper();

  final BookMetadataProvider _provider;
  final MetadataEnrichmentRepository _repository;
  final BookMetadataEnrichmentMapper _mapper;

  Future<BookMetadataRefreshResult> refreshByIsbn({
    required MediaItem item,
    required String isbnInput,
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    final rejection = _validateBookItem(item);
    if (rejection != null) {
      return BookMetadataRefreshRejected(rejection);
    }

    final request = IsbnLookupRequest.parse(isbnInput);
    if (!request.isValid) {
      return BookMetadataRefreshRejected(
        request.validationMessage ?? 'ISBN is invalid.',
      );
    }

    final result = await _provider.lookupByIsbn(request, options: options);
    switch (result) {
      case BookMetadataLookupSuccess(:final metadata):
        if (metadata == null) {
          return _handleEmptyIsbnLookup(item);
        }
        return _persistIsbnSuccess(item, metadata, request);
      case BookMetadataLookupFailure(:final failure):
        return _handleLookupFailure(item, failure);
    }
  }

  Future<BookMetadataSearchRefreshResult> searchCandidates({
    required MediaItem item,
    required BookSearchRequest searchRequest,
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    final rejection = _validateBookItem(item);
    if (rejection != null) {
      return BookMetadataSearchRefreshRejected(rejection);
    }

    if (!searchRequest.isValid) {
      return BookMetadataSearchRefreshRejected(
        searchRequest.validationMessage ?? 'Search request is invalid.',
      );
    }

    final result = await _provider.search(searchRequest, options: options);
    switch (result) {
      case BookMetadataSearchSuccess(:final candidates):
        return BookMetadataSearchRefreshSuccess(candidates);
      case BookMetadataSearchFailure(:final failure):
        return BookMetadataSearchRefreshFailure(
          category: failure.category,
          retryAfter: failure.retryAfter,
        );
    }
  }

  Future<BookMetadataRefreshResult> _persistIsbnSuccess(
    MediaItem item,
    NormalizedBookMetadata metadata,
    IsbnLookupRequest request,
  ) async {
    final fetchedAt = metadata.fetchedAt;
    final confidence = _mapper.confidenceForExactIsbn(
      metadata,
      request.normalizedIsbn,
      lookupKeyConfirmed: true,
    );

    final existing = _repository.getByItemId(item.id);
    final record = existing == null
        ? _mapper.createLinkedRecord(
            itemId: item.id,
            metadata: metadata,
            matchMethod: EnrichmentMatchMethod.identifier,
            confidence: confidence,
            fetchedAt: fetchedAt,
          )
        : _mapper.mergeProviderFields(
            existing: existing,
            metadata: metadata,
            matchState: EnrichmentMatchState.linkedByIdentifier,
            matchMethod: EnrichmentMatchMethod.identifier,
            confidence: confidence,
            fetchedAt: fetchedAt,
          );

    final saveResult = await _repository.upsert(record);
    if (!saveResult.success) {
      return const BookMetadataRefreshFailure(
        category: BookMetadataProviderFailureCategory.unknown,
      );
    }
    return BookMetadataRefreshSuccess(record);
  }

  Future<BookMetadataRefreshResult> _handleEmptyIsbnLookup(MediaItem item) async {
    // Empty lookup is not an error. Do not create a record when none exists.
    final existing = _repository.getByItemId(item.id);
    if (existing == null) {
      return const BookMetadataRefreshEmpty();
    }

    final updated = existing.copyWith(
      matchState: EnrichmentMatchState.unmatched,
      clearProviderId: true,
      clearProviderRecordId: true,
      clearProviderMediaType: true,
      clearMatchMethod: true,
      clearConfidence: true,
      clearLastErrorCategory: true,
    ).normalized();

    final saveResult = await _repository.upsert(updated);
    if (!saveResult.success) {
      return const BookMetadataRefreshFailure(
        category: BookMetadataProviderFailureCategory.unknown,
      );
    }
    return const BookMetadataRefreshEmpty();
  }

  Future<BookMetadataRefreshResult> _handleLookupFailure(
    MediaItem item,
    BookMetadataProviderFailure failure,
  ) async {
    final existing = _repository.getByItemId(item.id);
    if (existing == null) {
      return BookMetadataRefreshFailure(
        category: failure.category,
        retryAfter: failure.retryAfter,
      );
    }

    final updated = existing.copyWith(
      lastErrorCategory: failure.toEnrichmentErrorCategory(),
    ).normalized();

    await _repository.upsert(updated);
    return BookMetadataRefreshFailure(
      category: failure.category,
      retryAfter: failure.retryAfter,
    );
  }

  String? _validateBookItem(MediaItem item) {
    if (item.mediaKind != MediaKind.book) {
      return 'Metadata refresh is supported for books only.';
    }
    return null;
  }
}
