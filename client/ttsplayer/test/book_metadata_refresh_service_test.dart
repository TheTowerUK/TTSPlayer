import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_last_error_category.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/models/media_kind.dart';

import 'support/metadata_enrichment_test_support.dart';

MediaItem bookItem({String id = 'book-1'}) {
  return MediaItem(
    id: id,
    title: 'Local Title',
    filePath: '/media/Books/sample.epub',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.book.catalogueValue,
  );
}

MediaItem videoItem() {
  return MediaItem(
    id: 'video-1',
    title: 'Video',
    filePath: '/media/Movies/sample.mp4',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.video.catalogueValue,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookMetadataRefreshService', () {
    late MetadataEnrichmentRepository repository;
    late FakeBookMetadataProvider provider;
    late BookMetadataRefreshService service;

    setUp(() async {
      repository = await initializedMetadataEnrichmentRepository();
      provider = FakeBookMetadataProvider();
      service = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
    });

    test('ISBN success persists linkedByIdentifier with provenance', () async {
      final metadata = FakeBookMetadataProvider.sampleMetadata();
      provider.lookupResult = BookMetadataLookupSuccess(metadata);

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshSuccess>());
      final record = (result as BookMetadataRefreshSuccess).record;
      expect(record.matchState, EnrichmentMatchState.linkedByIdentifier);
      expect(record.matchMethod, EnrichmentMatchMethod.identifier);
      expect(record.confidence, 1.0);
      expect(record.providerId, 'fake_books');
      expect(record.fields[EnrichmentBookFieldKeys.title]?.source,
          EnrichmentFieldSource.provider);
      expect(repository.getByItemId('book-1'), isNotNull);
    });

    test('preserves locked fields on refresh', () async {
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
          fields: {
            EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
              value: 'User Title',
              source: EnrichmentFieldSource.userOverride,
            ),
          },
          lockedFields: const [EnrichmentBookFieldKeys.title],
        ),
      );

      provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(title: 'Provider Title'),
      );

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshSuccess>());
      final record = repository.getByItemId('book-1')!;
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'User Title');
      expect(record.fields[EnrichmentBookFieldKeys.authors], isNotNull);
    });

    test('empty lookup persists unmatched on new item', () async {
      provider.lookupResult = const BookMetadataLookupSuccess(null);

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshEmpty>());
      final record = repository.getByItemId('book-1');
      expect(record, isNotNull);
      expect(record!.matchState, EnrichmentMatchState.unmatched);
    });

    test('ISBN conflict returns conflict without persisting', () async {
      provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(
          isbn13: const ['9780000000000'],
        ),
      );

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshConflict>());
      expect(repository.storedRecordCount, 0);
    });

    test('empty lookup preserves linkage on existing linked record', () async {
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedByIdentifier,
          providerId: 'fake_books',
          providerRecordId: '/books/OL123M',
          matchMethod: EnrichmentMatchMethod.identifier,
          confidence: 1.0,
        ),
      );
      provider.lookupResult = const BookMetadataLookupSuccess(null);

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshEmpty>());
      final record = repository.getByItemId('book-1')!;
      expect(record.matchState, EnrichmentMatchState.linkedByIdentifier);
      expect(record.providerId, 'fake_books');
    });

    test('failure updates last error without overwriting fields', () async {
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedByIdentifier,
          fields: {
            EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
              value: 'Existing Title',
              source: EnrichmentFieldSource.provider,
              providerId: 'fake_books',
            ),
          },
        ),
      );
      provider.lookupResult = const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.rateLimited,
        ),
      );

      final result = await service.refreshByIsbn(
        item: bookItem(),
        isbnInput: '9780140449136',
      );

      expect(result, isA<BookMetadataRefreshFailure>());
      final record = repository.getByItemId('book-1')!;
      expect(record.lastErrorCategory, EnrichmentLastErrorCategory.rateLimited);
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value,
          'Existing Title');
    });

    test('search returns candidates without persisting', () async {
      provider.searchResult = BookMetadataSearchSuccess([
        FakeBookMetadataProvider.sampleCandidate(),
      ]);

      final result = await service.searchCandidates(
        item: bookItem(),
        searchRequest: BookSearchRequest.create(title: 'Sample'),
      );

      expect(result, isA<BookMetadataSearchRefreshSuccess>());
      expect((result as BookMetadataSearchRefreshSuccess).candidates.length, 1);
      expect(repository.storedRecordCount, 0);
      expect(provider.searchInvocationCount, 1);
    });

    test('rejects non-book items locally', () async {
      final result = await service.refreshByIsbn(
        item: videoItem(),
        isbnInput: '9780140449136',
      );
      expect(result, isA<BookMetadataRefreshRejected>());
      expect(provider.lookupInvocationCount, 0);
    });

    test('repository initialization does not invoke provider', () async {
      expect(provider.lookupInvocationCount, 0);
      expect(provider.searchInvocationCount, 0);
    });
  });
}
