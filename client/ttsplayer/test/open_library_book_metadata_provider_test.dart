import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/isbn_lookup_request.dart';
import 'package:http/http.dart' as http;
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_response_parser.dart';
import 'package:ttsplayer/features/metadata_enrichment/transport/fake_metadata_http_transport.dart';
import 'package:ttsplayer/features/metadata_enrichment/transport/http_metadata_http_transport.dart';
import 'package:ttsplayer/features/metadata_enrichment/transport/metadata_http_transport.dart';

import 'support/open_library_test_fixtures.dart';

void main() {
  group('OpenLibraryResponseParser', () {
    const parser = OpenLibraryResponseParser();
    final fetchedAt = DateTime.utc(2026, 7, 30);

    test('parses Books API success', () {
      final json = parser.parseBooksApiResponse(
        {
          'ISBN:${OpenLibraryTestFixtures.validIsbn13}': {
            'key': '/books/OL45804M',
            'title': 'The Republic',
            'authors': [
              {'name': 'Plato'},
            ],
            'identifiers': {
              'isbn_13': [OpenLibraryTestFixtures.validIsbn13],
            },
            'works': [
              {'key': '/works/OL45804W'},
            ],
          },
        },
        OpenLibraryTestFixtures.validIsbn13,
        fetchedAt: fetchedAt,
      );

      expect(json, isNotNull);
      expect(json!.canonicalTitle, 'The Republic');
      expect(json.editionId, '/books/OL45804M');
      expect(json.workId, '/works/OL45804W');
    });

    test('returns null for missing Books API result', () {
      final json = parser.parseBooksApiResponse(
        const {},
        OpenLibraryTestFixtures.validIsbn13,
        fetchedAt: fetchedAt,
      );
      expect(json, isNull);
    });

    test('parses description object variant', () {
      final json = parser.parseBooksApiResponse(
        {
          'ISBN:${OpenLibraryTestFixtures.validIsbn13}': {
            'title': 'Object Description',
            'key': '/books/OL999M',
            'description': {'value': 'Nested description.'},
          },
        },
        OpenLibraryTestFixtures.validIsbn13,
        fetchedAt: fetchedAt,
      );
      expect(json?.description, 'Nested description.');
    });

    test('deduplicates search candidates by edition key', () {
      final candidates = parser.parseSearchResponse(
        {
          'docs': [
            {
              'title': 'Duplicate Book',
              'edition_key': ['OL555M'],
              'author_name': ['Same Author'],
              'first_publish_year': 1999,
              'score': 5.0,
            },
            {
              'title': 'Duplicate Book',
              'edition_key': ['OL555M'],
              'author_name': ['Same Author'],
              'first_publish_year': 1999,
              'score': 3.0,
            },
          ],
        },
        fetchedAt: fetchedAt,
      );
      expect(candidates.length, 1);
      expect(candidates.first.relevanceScore, 5.0);
    });

    test('parses search cover_i as coverArtworkId', () {
      final candidates = parser.parseSearchResponse(
        {
          'docs': [
            {
              'title': 'Cover Book',
              'edition_key': ['OL777M'],
              'cover_i': 8230111,
            },
          ],
        },
        fetchedAt: fetchedAt,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.metadata.coverArtworkId, '8230111');
    });

    test('parses Books API covers array as coverArtworkId', () {
      final metadata = parser.parseBooksApiResponse(
        {
          'ISBN:${OpenLibraryTestFixtures.validIsbn13}': {
            'title': 'Edition Cover',
            'key': '/books/OL45804M',
            'covers': [111, 8230111],
          },
        },
        OpenLibraryTestFixtures.validIsbn13,
        fetchedAt: fetchedAt,
      );

      expect(metadata?.coverArtworkId, '111');
    });
  });

  group('OpenLibraryBookMetadataProvider', () {
    late FakeMetadataHttpTransport transport;
    late OpenLibraryBookMetadataProvider provider;

    setUp(() {
      transport = FakeMetadataHttpTransport();
      provider = OpenLibraryBookMetadataProvider(
        transport: transport,
        config: const OpenLibraryConfig(userAgent: 'TTSPlayer-Test/1.0'),
      );
    });

    test('constructs Books API request with encoded ISBN and User-Agent', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        MetadataHttpResponse(
          statusCode: 200,
          body: OpenLibraryTestFixtures.booksApiSuccess,
          contentType: 'application/json',
        ),
      );

      final request = IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13);
      await provider.lookupByIsbn(request);

      expect(transport.requestCount, 1);
      final uri = transport.requestedUris.single;
      expect(uri.path, '/api/books');
      expect(uri.queryParameters['bibkeys'], 'ISBN:${OpenLibraryTestFixtures.validIsbn13}');
      expect(
        transport.requestedHeaders.single['User-Agent'],
        'TTSPlayer-Test/1.0',
      );
      expect(uri.queryParameters.containsKey('api_key'), isFalse);
    });

    test('invalid ISBN fails locally without HTTP', () async {
      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse('bad-isbn'),
      );
      expect(transport.requestCount, 0);
      expect(result, isA<BookMetadataLookupFailure>());
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(failure.category, BookMetadataProviderFailureCategory.invalidRequest);
    });

    test('empty Books API response is success with null metadata', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(statusCode: 200, body: '{}'),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );

      expect(result, isA<BookMetadataLookupSuccess>());
      expect((result as BookMetadataLookupSuccess).metadata, isNull);
    });

    test('search uses title author and year parameters', () async {
      transport.registerResponse(
        'https://openlibrary.org/search.json',
        MetadataHttpResponse(
          statusCode: 200,
          body: OpenLibraryTestFixtures.searchMultiple,
          contentType: 'application/json',
        ),
      );

      final searchRequest = BookSearchRequest.create(
        title: 'Alpha Book',
        author: 'Author One',
        publicationYear: 2001,
        limit: 5,
      );
      final result = await provider.search(searchRequest);

      expect(result, isA<BookMetadataSearchSuccess>());
      final success = result as BookMetadataSearchSuccess;
      expect(success.candidates.length, 2);
      final uri = transport.requestedUris.single;
      expect(uri.queryParameters['title'], 'Alpha Book');
      expect(uri.queryParameters['author'], 'Author One');
      expect(uri.queryParameters['first_publish_year'], '2001');
      expect(uri.queryParameters['limit'], '5');
    });

    test('maps HTTP 429 to rateLimited with retry-after', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(
          statusCode: 429,
          body: 'Too Many Requests',
          headers: {'retry-after': '30'},
        ),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );

      expect(result, isA<BookMetadataLookupFailure>());
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(failure.category, BookMetadataProviderFailureCategory.rateLimited);
      expect(failure.retryAfter, const Duration(seconds: 30));
    });

    test('maps HTTP 403 to authorization', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(statusCode: 403, body: 'Forbidden'),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(
        failure.category,
        BookMetadataProviderFailureCategory.authorization,
      );
    });

    test('maps HTTP 401 to authentication', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(statusCode: 401, body: 'Unauthorized'),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(
        failure.category,
        BookMetadataProviderFailureCategory.authentication,
      );
    });

    test('maps HTTP 500 to providerUnavailable', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(statusCode: 500, body: 'Error'),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(
        failure.category,
        BookMetadataProviderFailureCategory.providerUnavailable,
      );
    });

    test('maps malformed JSON to malformedResponse', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(
          statusCode: 200,
          body: OpenLibraryTestFixtures.malformedJson,
          contentType: 'application/json',
        ),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(
        failure.category,
        BookMetadataProviderFailureCategory.malformedResponse,
      );
    });

    test('maps unexpected content type to unsupportedResponse', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        const MetadataHttpResponse(
          statusCode: 200,
          body: '<html></html>',
          contentType: 'text/html',
        ),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(
        failure.category,
        BookMetadataProviderFailureCategory.unsupportedResponse,
      );
    });

    test('maps transport timeout to timeout', () async {
      transport = FakeMetadataHttpTransport(
        throwOnRequest: const MetadataTransportTimeoutException(),
      );
      provider = OpenLibraryBookMetadataProvider(
        transport: transport,
        config: const OpenLibraryConfig(userAgent: 'TTSPlayer-Test/1.0'),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(failure.category, BookMetadataProviderFailureCategory.timeout);
    });

    test('accepts JSON content type with charset parameter', () async {
      transport.registerResponse(
        'https://openlibrary.org/api/books',
        MetadataHttpResponse(
          statusCode: 200,
          body: OpenLibraryTestFixtures.booksApiSuccess,
          contentType: 'application/json; charset=utf-8',
        ),
      );

      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
      );

      expect(result, isA<BookMetadataLookupSuccess>());
      expect((result as BookMetadataLookupSuccess).metadata, isNotNull);
    });

    test('HttpMetadataHttpTransport closes only owned clients', () {
      final owned = HttpMetadataHttpTransport();
      expect(owned.ownsClient, isTrue);
      owned.close();

      final injected = HttpMetadataHttpTransport(client: http.Client());
      expect(injected.ownsClient, isFalse);
      injected.close();
    });

    test('maps cancellation to cancelled', () async {
      final token = MetadataCancellationToken()..cancel();
      final result = await provider.lookupByIsbn(
        IsbnLookupRequest.parse(OpenLibraryTestFixtures.validIsbn13),
        options: BookMetadataRequestOptions(cancellationToken: token),
      );
      expect(transport.requestCount, 0);
      final failure = (result as BookMetadataLookupFailure).failure;
      expect(failure.category, BookMetadataProviderFailureCategory.cancelled);
    });
  });
}
