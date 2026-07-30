import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/isbn_lookup_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/normalized_book_metadata.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_attribution.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';

void main() {
  group('IsbnLookupRequest', () {
    test('normalizes ISBN-13 with spaces and hyphens', () {
      final request = IsbnLookupRequest.parse('978-0-14-044913-6');
      expect(request.isValid, isTrue);
      expect(request.isIsbn13, isTrue);
      expect(request.normalizedIsbn, '9780140449136');
    });

    test('normalizes ISBN-10 with hyphens and lowercase x', () {
      final request = IsbnLookupRequest.parse('0-14-044913-2');
      expect(request.isValid, isTrue);
      expect(request.isIsbn13, isFalse);
      expect(request.normalizedIsbn, '0140449132');
    });

    test('rejects invalid characters', () {
      final request = IsbnLookupRequest.parse('978014044913A');
      expect(request.isValid, isFalse);
    });

    test('rejects invalid length', () {
      expect(IsbnLookupRequest.parse('123').isValid, isFalse);
      expect(IsbnLookupRequest.parse('').isValid, isFalse);
    });

    test('rejects invalid checksum without HTTP call path', () {
      final request = IsbnLookupRequest.parse('9780140449137');
      expect(request.isValid, isFalse);
      expect(request.validationMessage, contains('checksum'));
    });
  });

  group('BookSearchRequest', () {
    test('requires title or author', () {
      final request = BookSearchRequest.create();
      expect(request.isValid, isFalse);
    });

    test('trims and bounds limit', () {
      final request = BookSearchRequest.create(
        title: '  Sample   Title  ',
        author: ' Author ',
        limit: 100,
      );
      expect(request.isValid, isTrue);
      expect(request.normalizedTitle, 'Sample Title');
      expect(request.normalizedAuthor, 'Author');
      expect(request.limit, 25);
    });
  });

  group('Provider-neutral models', () {
    test('NormalizedBookMetadata equality uses immutable lists', () {
      final fetchedAt = DateTime.utc(2026, 7, 30);
      final a = NormalizedBookMetadata(
        providerId: 'open_library',
        providerRecordId: '/books/OL1M',
        canonicalTitle: 'Title',
        authors: const ['Author'],
        fetchedAt: fetchedAt,
        attribution: const ProviderAttribution(
          providerId: 'open_library',
          displayName: 'Open Library',
        ),
      );
      final b = NormalizedBookMetadata(
        providerId: 'open_library',
        providerRecordId: '/books/OL1M',
        canonicalTitle: 'Title',
        authors: const ['Author'],
        fetchedAt: fetchedAt,
        attribution: const ProviderAttribution(
          providerId: 'open_library',
          displayName: 'Open Library',
        ),
      );
      expect(a, equals(b));
    });

    test('ProviderBookCandidate exposes display fields', () {
      final candidate = FakeBookMetadataProvider.sampleCandidate(
        title: 'Display Title',
      );
      expect(candidate.displayTitle, 'Display Title');
      expect(candidate.displayAuthors, 'Candidate Author');
    });
  });
}
