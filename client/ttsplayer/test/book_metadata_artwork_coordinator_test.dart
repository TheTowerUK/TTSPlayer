import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/fake_metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_generation_guard.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_artwork_download_url_resolver.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_artwork_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_artwork_workflow_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/models/media_kind.dart';

import 'support/metadata_artwork_test_fixtures.dart';
import 'support/metadata_enrichment_test_support.dart';

class CountingMetadataEnrichmentRepository extends MetadataEnrichmentRepository {
  int upsertInvocationCount = 0;
  bool failNextUpsert = false;

  @override
  Future<MetadataEnrichmentSaveResult> upsert(
    MetadataEnrichmentRecord record,
  ) async {
    upsertInvocationCount++;
    if (failNextUpsert) {
      return const MetadataEnrichmentSaveResult(
        success: false,
        errorMessage: 'Simulated persistence failure.',
      );
    }
    return super.upsert(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late CountingMetadataEnrichmentRepository repository;
  late MetadataArtworkCacheRepository cacheRepository;
  late FakeMetadataArtworkHttpClient httpClient;
  late MetadataArtworkDownloadGenerationGuard generationGuard;
  late MetadataArtworkDownloadService downloadService;
  late BookMetadataArtworkCoordinator coordinator;

  MediaItem bookItem({String id = 'book-1'}) {
    return MediaItem(
      id: id,
      title: 'Sample Book',
      filePath: '/media/Books/sample.epub',
      status: MediaItemStatus.available,
      mediaKindRaw: MediaKind.book.catalogueValue,
    );
  }

  MetadataEnrichmentRecord linkedRecord({
    String itemId = 'book-1',
    MetadataArtworkReference? artworkReference,
    Map<String, EnrichmentFieldValue>? fields,
  }) {
    return MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: 'open_library',
      providerRecordId: '/books/OL123M',
      providerMediaType: 'book',
      matchMethod: EnrichmentMatchMethod.manual,
      fields: fields ??
          {
            'title': EnrichmentFieldValue(
              value: 'Provider Title',
              source: EnrichmentFieldSource.provider,
              providerId: 'open_library',
              updatedAt: DateTime.utc(2026, 8, 3, 12),
            ),
          },
      artworkReference: artworkReference ??
          MetadataArtworkTestFixtures.sampleReference(),
    ).normalized();
  }

  Future<void> seedDownloadedReference({
    MetadataArtworkReference? reference,
  }) async {
    final ref = reference ?? MetadataArtworkTestFixtures.sampleReference();
    httpClient.registerResponse(
      'https://covers.openlibrary.org/b/id/${ref.artworkId}-L.jpg',
      MetadataArtworkTestFixtures.pngResponse(
        MetadataArtworkTestFixtures.onePixelPng,
      ),
    );
    final result = await downloadService.download(reference: ref);
    expect(result, isA<MetadataArtworkDownloadSuccess>());
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_artwork_coordinator_test_');
    SharedPreferences.setMockInitialValues({});
    repository = CountingMetadataEnrichmentRepository();
    await repository.initialize();
    cacheRepository = MetadataArtworkCacheRepository(
      filesystem: MetadataArtworkFilesystem(cacheRoot: tempRoot),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await cacheRepository.initialize();
    httpClient = FakeMetadataArtworkHttpClient();
    generationGuard = MetadataArtworkDownloadGenerationGuard();
    downloadService = MetadataArtworkDownloadService(
      cacheRepository: cacheRepository,
      httpClient: httpClient,
      urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
      generationGuard: generationGuard,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    coordinator = BookMetadataArtworkCoordinator(
      repository: repository,
      downloadService: downloadService,
      generationGuard: generationGuard,
      cacheRepository: cacheRepository,
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('Download eligibility', () {
    test('linked book with available reference downloads and persists', () async {
      await repository.upsert(linkedRecord());
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final result = await coordinator.downloadCover(item: bookItem());

      expect(result, isA<BookMetadataArtworkDownloaded>());
      expect(httpClient.requestCount, 1);
      final saved = repository.getByItemId('book-1');
      expect(saved?.artworkReference?.cacheState,
          MetadataArtworkCacheState.downloaded);
      expect(saved?.artworkReference?.localRelativePath, isNotNull);
      expect(saved?.fields['title']?.value, 'Provider Title');
      expect(repository.upsertInvocationCount, 2);
    });

    test('unlinked book is rejected', () async {
      final result = await coordinator.downloadCover(item: bookItem());
      expect(result, isA<BookMetadataArtworkNotLinked>());
      expect(httpClient.requestCount, 0);
    });

    test('missing reference is rejected', () async {
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'open_library',
          providerRecordId: '/books/OL123M',
          providerMediaType: 'book',
          matchMethod: EnrichmentMatchMethod.manual,
        ).normalized(),
      );
      final result = await coordinator.downloadCover(item: bookItem());
      expect(result, isA<BookMetadataArtworkNoArtworkAvailable>());
      expect(httpClient.requestCount, 0);
    });
  });

  group('Already cached', () {
    test('valid cache returns already cached without HTTP', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedDownloadedReference(reference: reference);
      await repository.upsert(
        linkedRecord(
          artworkReference: reference.copyWith(
            cacheState: MetadataArtworkCacheState.downloaded,
            localRelativePath: '${reference.cacheKey}.png',
            validatedAt: DateTime.utc(2026, 8, 3, 12),
          ),
        ),
      );
      final beforeUpserts = repository.upsertInvocationCount;

      final beforeHttp = httpClient.requestCount;
      final result = await coordinator.downloadCover(item: bookItem());

      expect(result, isA<BookMetadataArtworkAlreadyCached>());
      expect(httpClient.requestCount, beforeHttp);
      expect(repository.upsertInvocationCount, beforeUpserts);
    });
  });

  group('Refresh', () {
    test('refresh updates enrichment after successful HTTP', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedDownloadedReference(reference: reference);
      await repository.upsert(
        linkedRecord(
          artworkReference: reference.copyWith(
            cacheState: MetadataArtworkCacheState.downloaded,
            localRelativePath: '${reference.cacheKey}.png',
            validatedAt: DateTime.utc(2026, 8, 3, 11),
          ),
        ),
      );
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final result = await coordinator.refreshCover(item: bookItem());

      expect(result, isA<BookMetadataArtworkRefreshed>());
      expect(httpClient.requestCount, 2);
      expect(
        repository.getByItemId('book-1')?.artworkReference?.validatedAt,
        DateTime.utc(2026, 8, 3, 12),
      );
    });

    test('refresh failure retains prior cache metadata', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedDownloadedReference(reference: reference);
      final persistedReference = reference.copyWith(
        cacheState: MetadataArtworkCacheState.downloaded,
        localRelativePath: '${reference.cacheKey}.png',
        validatedAt: DateTime.utc(2026, 8, 3, 11),
      );
      await repository.upsert(linkedRecord(artworkReference: persistedReference));
      httpClient = FakeMetadataArtworkHttpClient(
        throwOnRequest: Exception('network'),
      );
      downloadService = MetadataArtworkDownloadService(
        cacheRepository: cacheRepository,
        httpClient: httpClient,
        urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
        generationGuard: generationGuard,
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      coordinator = BookMetadataArtworkCoordinator(
        repository: repository,
        downloadService: downloadService,
        generationGuard: generationGuard,
        cacheRepository: cacheRepository,
      );

      final result = await coordinator.refreshCover(item: bookItem());

      expect(result, isA<BookMetadataArtworkPriorCacheRetained>());
      expect(repository.getByItemId('book-1')?.artworkReference,
          persistedReference);
    });
  });

  group('Lifecycle protection', () {
    test('identity change during download prevents persistence', () async {
      await repository.upsert(linkedRecord());
      httpClient = FakeMetadataArtworkHttpClient(
        delay: const Duration(milliseconds: 30),
      );
      downloadService = MetadataArtworkDownloadService(
        cacheRepository: cacheRepository,
        httpClient: httpClient,
        urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
        generationGuard: generationGuard,
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      coordinator = BookMetadataArtworkCoordinator(
        repository: repository,
        downloadService: downloadService,
        generationGuard: generationGuard,
        cacheRepository: cacheRepository,
      );
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final pending = coordinator.downloadCover(item: bookItem());
      coordinator.invalidateItemOperations('book-1');
      final result = await pending;

      expect(result, isA<BookMetadataArtworkIdentityChanged>());
      expect(
        repository.getByItemId('book-1')?.artworkReference?.cacheState,
        MetadataArtworkCacheState.available,
      );
    });

    test('different items resolve independently', () async {
      final refA = MetadataArtworkTestFixtures.sampleReference(artworkId: '111');
      final refB = MetadataArtworkTestFixtures.sampleReference(artworkId: '222');
      await repository.upsert(linkedRecord(itemId: 'book-a', artworkReference: refA));
      await repository.upsert(linkedRecord(itemId: 'book-b', artworkReference: refB));
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/222-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final results = await Future.wait([
        coordinator.downloadCover(item: bookItem(id: 'book-a')),
        coordinator.downloadCover(item: bookItem(id: 'book-b')),
      ]);

      expect(results[0], isA<BookMetadataArtworkDownloaded>());
      expect(results[1], isA<BookMetadataArtworkDownloaded>());
      expect(
        repository.getByItemId('book-a')?.artworkReference?.artworkId,
        '111',
      );
      expect(
        repository.getByItemId('book-b')?.artworkReference?.artworkId,
        '222',
      );
    });
  });

  group('Duplicate operations', () {
    test('concurrent download coalesces to one HTTP request', () async {
      await repository.upsert(linkedRecord());
      httpClient = FakeMetadataArtworkHttpClient(
        delay: const Duration(milliseconds: 20),
      );
      downloadService = MetadataArtworkDownloadService(
        cacheRepository: cacheRepository,
        httpClient: httpClient,
        urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
        generationGuard: generationGuard,
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      coordinator = BookMetadataArtworkCoordinator(
        repository: repository,
        downloadService: downloadService,
        generationGuard: generationGuard,
        cacheRepository: cacheRepository,
      );
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final results = await Future.wait([
        coordinator.downloadCover(item: bookItem()),
        coordinator.downloadCover(item: bookItem()),
      ]);

      expect(results.every((r) => r is BookMetadataArtworkDownloaded), isTrue);
      expect(httpClient.requestCount, 1);
    });
  });

  group('Persistence failure', () {
    test('cache write succeeds but enrichment save fails', () async {
      await repository.upsert(linkedRecord());
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );
      repository.failNextUpsert = true;

      final first = await coordinator.downloadCover(item: bookItem());
      expect(first, isA<BookMetadataArtworkPersistenceFailure>());
      expect(cacheRepository.entryForKey(
            MetadataArtworkTestFixtures.sampleReference().cacheKey,
          ),
          isNotNull);

      repository.failNextUpsert = false;
      final retry = await coordinator.downloadCover(item: bookItem());
      expect(retry, isA<BookMetadataArtworkDownloaded>());
      expect(httpClient.requestCount, 1);
    });
  });
}
