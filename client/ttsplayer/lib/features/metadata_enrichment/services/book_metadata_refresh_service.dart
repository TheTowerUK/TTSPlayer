import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../models/book_search_request.dart';
import '../models/isbn_lookup_request.dart';
import '../models/metadata_enrichment_record.dart';
import '../models/normalized_book_metadata.dart';
import '../models/provider_book_candidate.dart';
import '../providers/book_metadata_provider.dart';
import '../providers/book_metadata_provider_failure.dart';
import '../providers/book_metadata_provider_result.dart';
import 'book_metadata_match_transition.dart';
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
  const BookMetadataRefreshEmpty({this.record});

  final MetadataEnrichmentRecord? record;
}

class BookMetadataRefreshConflict extends BookMetadataRefreshResult {
  const BookMetadataRefreshConflict({this.existingRecord});

  final MetadataEnrichmentRecord? existingRecord;
}

class BookMetadataRefreshFailure extends BookMetadataRefreshResult {
  const BookMetadataRefreshFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

class BookMetadataRefreshRepositoryFailure extends BookMetadataRefreshResult {
  const BookMetadataRefreshRepositoryFailure([this.message]);

  final String? message;
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

/// Lower-level explicit ISBN refresh service (M7.2).
///
/// Application workflows must use [BookMetadataMatchingCoordinator] instead.
/// This service exists for compatibility, focused tests, and shared ISBN
/// persistence policy — not as an alternative UI orchestration path.
class BookMetadataRefreshService {
  BookMetadataRefreshService({
    required BookMetadataProvider provider,
    required MetadataEnrichmentRepository repository,
    BookMetadataMatchTransition? transition,
  })  : _provider = provider,
        _repository = repository,
        _transition = transition ?? const BookMetadataMatchTransition();

  final BookMetadataProvider _provider;
  final MetadataEnrichmentRepository _repository;
  final BookMetadataMatchTransition _transition;

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
        if (!_transition.isbnResponseConfirmed(
          metadata,
          request,
          lookupKeyConfirmed: false,
        )) {
          return BookMetadataRefreshConflict(
            existingRecord: _repository.getByItemId(item.id),
          );
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
    final existing = _repository.getByItemId(item.id);
    final record = _transition.applyIsbnLink(
      existing: existing,
      itemId: item.id,
      metadata: metadata,
      request: request,
      fetchedAt: metadata.fetchedAt,
      lookupKeyConfirmed: _transition.isbnResponseConfirmed(
        metadata,
        request,
        lookupKeyConfirmed: false,
      ),
    );

    final saveResult = await _repository.upsert(record);
    if (!saveResult.success) {
      return BookMetadataRefreshRepositoryFailure(saveResult.errorMessage);
    }
    return BookMetadataRefreshSuccess(record);
  }

  Future<BookMetadataRefreshResult> _handleEmptyIsbnLookup(MediaItem item) async {
    final existing = _repository.getByItemId(item.id);
    if (BookMetadataMatchTransition.isProviderLinked(existing)) {
      return BookMetadataRefreshEmpty(record: existing);
    }

    if (existing == null) {
      final record = _transition.applyNoMatch(
        existing: null,
        itemId: item.id,
        updatedAt: DateTime.now().toUtc(),
      );
      final saveResult = await _repository.upsert(record);
      if (!saveResult.success) {
        return BookMetadataRefreshRepositoryFailure(saveResult.errorMessage);
      }
      return BookMetadataRefreshEmpty(record: record);
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
