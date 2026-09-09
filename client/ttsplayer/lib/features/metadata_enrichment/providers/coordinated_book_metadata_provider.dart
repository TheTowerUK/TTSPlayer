import '../../../models/media_kind.dart';
import '../models/book_search_request.dart';
import '../models/isbn_lookup_request.dart';
import '../models/provider_attribution.dart';
import '../services/metadata_provider_operation_coordinator.dart';
import 'book_metadata_provider.dart';
import 'book_metadata_provider_failure.dart';
import 'book_metadata_provider_result.dart';

class CoordinatedBookMetadataProvider implements BookMetadataProvider {
  CoordinatedBookMetadataProvider({
    required BookMetadataProvider delegate,
    required MetadataProviderOperationCoordinator coordinator,
  })  : _delegate = delegate,
        _coordinator = coordinator;

  final BookMetadataProvider _delegate;
  final MetadataProviderOperationCoordinator _coordinator;

  @override
  String get providerId => _delegate.providerId;
  @override
  Set<MediaKind> get supportedKinds => _delegate.supportedKinds;
  @override
  ProviderAttribution get attribution => _delegate.attribution;

  @override
  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    try {
      return await _coordinator.execute(
        providerId: providerId,
        operation: () => _delegate.lookupByIsbn(request, options: options),
        failureOf: (result) =>
            result is BookMetadataLookupFailure ? result.failure : null,
        isCancelled: () => options.cancellationToken?.isCancelled ?? false,
        cancellationSignal: options.cancellationToken?.whenCancelled,
      );
    } on MetadataProviderOperationRejected catch (failure) {
      return BookMetadataLookupFailure(
        BookMetadataProviderFailure(category: failure.category),
      );
    }
  }

  @override
  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    try {
      return await _coordinator.execute(
        providerId: providerId,
        operation: () => _delegate.search(request, options: options),
        failureOf: (result) =>
            result is BookMetadataSearchFailure ? result.failure : null,
        isCancelled: () => options.cancellationToken?.isCancelled ?? false,
        cancellationSignal: options.cancellationToken?.whenCancelled,
      );
    } on MetadataProviderOperationRejected catch (failure) {
      return BookMetadataSearchFailure(
        BookMetadataProviderFailure(category: failure.category),
      );
    }
  }
}
