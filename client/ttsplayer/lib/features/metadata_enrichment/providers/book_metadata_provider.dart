import '../../../models/media_kind.dart';
import '../models/book_search_request.dart';
import '../models/isbn_lookup_request.dart';
import '../models/provider_attribution.dart';
import '../transport/metadata_http_transport.dart';
import 'book_metadata_provider_result.dart';

/// Optional controls for a single provider request (M7.2).
class BookMetadataRequestOptions {
  const BookMetadataRequestOptions({
    this.timeout,
    this.cancellationToken,
  });

  final Duration? timeout;
  final MetadataCancellationToken? cancellationToken;
}

/// Provider-neutral book metadata contract (M7.2).
abstract class BookMetadataProvider {
  String get providerId;

  Set<MediaKind> get supportedKinds;

  ProviderAttribution get attribution;

  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  });

  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  });
}
