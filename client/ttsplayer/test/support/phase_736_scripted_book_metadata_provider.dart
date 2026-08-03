import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/isbn_lookup_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_attribution.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'phase_736_metadata_fixtures.dart';

/// Deterministic scripted provider for Phase 7.3.6 runtime validation.
///
/// Maps [BookSearchRequest.title] to fixture scenarios — never performs HTTP.
class Phase736ScriptedBookMetadataProvider implements BookMetadataProvider {
  Phase736ScriptedBookMetadataProvider();

  @override
  String get providerId => Phase736Fixtures.providerId;

  @override
  final ProviderAttribution attribution = Phase736Fixtures.attribution;

  @override
  Set<MediaKind> get supportedKinds => const {MediaKind.book};

  int lookupInvocationCount = 0;
  int searchInvocationCount = 0;
  BookSearchRequest? lastSearchRequest;
  IsbnLookupRequest? lastLookupRequest;

  final Map<String, int> searchInvocationsByTitle = {};

  @override
  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    lookupInvocationCount++;
    lastLookupRequest = request;
    return const BookMetadataLookupSuccess(null);
  }

  @override
  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    searchInvocationCount++;
    lastSearchRequest = request;
    final title = request.title?.trim() ?? '';
    searchInvocationsByTitle[title] =
        (searchInvocationsByTitle[title] ?? 0) + 1;

    if (title == Phase736Fixtures.bookATitle) {
      return BookMetadataSearchSuccess(Phase736Fixtures.bookASearchResults());
    }
    if (title == Phase736Fixtures.bookBTitle) {
      return BookMetadataSearchSuccess(Phase736Fixtures.bookBSearchResults());
    }
    if (title == Phase736Fixtures.bookETitle) {
      return BookMetadataSearchSuccess(Phase736Fixtures.bookERematchResults());
    }
    if (title == Phase736Fixtures.bookFTitle) {
      return const BookMetadataSearchSuccess([]);
    }
    if (title == Phase736Fixtures.bookGTitle) {
      return BookMetadataSearchFailure(
        const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.networkUnavailable,
        ),
      );
    }

    return const BookMetadataSearchSuccess([]);
  }

  void resetCounts() {
    lookupInvocationCount = 0;
    searchInvocationCount = 0;
    searchInvocationsByTitle.clear();
    lastSearchRequest = null;
    lastLookupRequest = null;
  }
}
