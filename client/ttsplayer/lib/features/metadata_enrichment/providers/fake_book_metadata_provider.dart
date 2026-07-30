import '../../../models/media_kind.dart';
import '../models/book_search_request.dart';
import '../models/isbn_lookup_request.dart';
import '../models/normalized_book_metadata.dart';
import '../models/provider_attribution.dart';
import '../models/provider_book_candidate.dart';
import 'book_metadata_provider.dart';
import 'book_metadata_provider_result.dart';

/// Deterministic book metadata provider for tests (M7.2).
class FakeBookMetadataProvider implements BookMetadataProvider {
  FakeBookMetadataProvider({
    this.providerId = 'fake_books',
    this.attribution = const ProviderAttribution(
      providerId: 'fake_books',
      displayName: 'Fake Books',
    ),
    this.lookupResult,
    this.searchResult,
  });

  @override
  final String providerId;

  @override
  final ProviderAttribution attribution;

  BookMetadataLookupResult? lookupResult;
  BookMetadataSearchResult? searchResult;

  IsbnLookupRequest? lastLookupRequest;
  BookSearchRequest? lastSearchRequest;
  int lookupInvocationCount = 0;
  int searchInvocationCount = 0;

  @override
  Set<MediaKind> get supportedKinds => const {MediaKind.book};

  @override
  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    lookupInvocationCount++;
    lastLookupRequest = request;
    if (lookupResult != null) return lookupResult!;
    return const BookMetadataLookupSuccess(null);
  }

  @override
  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    searchInvocationCount++;
    lastSearchRequest = request;
    if (searchResult != null) return searchResult!;
    return const BookMetadataSearchSuccess([]);
  }

  static NormalizedBookMetadata sampleMetadata({
    String providerRecordId = '/books/OL123M',
    String title = 'Sample Book',
    List<String> authors = const ['Sample Author'],
    List<String> isbn13 = const ['9780140449136'],
  }) {
    return NormalizedBookMetadata(
      providerId: 'fake_books',
      providerRecordId: providerRecordId,
      editionId: providerRecordId,
      workId: '/works/OL45804W',
      canonicalTitle: title,
      authors: authors,
      isbn13Values: isbn13,
      fetchedAt: DateTime.utc(2026, 7, 30),
    );
  }

  static ProviderBookCandidate sampleCandidate({
    String title = 'Candidate Book',
    String editionId = '/books/OL999M',
  }) {
    return ProviderBookCandidate(
      metadata: NormalizedBookMetadata(
        providerId: 'fake_books',
        providerRecordId: editionId,
        editionId: editionId,
        canonicalTitle: title,
        authors: const ['Candidate Author'],
        fetchedAt: DateTime.utc(2026, 7, 30),
      ),
    );
  }
}
