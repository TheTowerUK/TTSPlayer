import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/fake_metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_generation_guard.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_artwork_download_url_resolver.dart';

import 'support/metadata_artwork_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late MetadataArtworkCacheRepository repository;
  late FakeMetadataArtworkHttpClient httpClient;
  late MetadataArtworkDownloadService service;
  late MetadataArtworkDownloadGenerationGuard generationGuard;

  setUp(() async {
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_artwork_download_test_');
    repository = MetadataArtworkCacheRepository(
      filesystem: MetadataArtworkFilesystem(cacheRoot: tempRoot),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await repository.initialize();
    httpClient = FakeMetadataArtworkHttpClient();
    generationGuard = MetadataArtworkDownloadGenerationGuard();
    service = MetadataArtworkDownloadService(
      cacheRepository: repository,
      httpClient: httpClient,
      urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
      generationGuard: generationGuard,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('MetadataArtworkDownloadService', () {
    test('download stores validated cache entry and reference patch', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final result = await service.download(reference: reference);

      expect(result, isA<MetadataArtworkDownloadSuccess>());
      final success = result as MetadataArtworkDownloadSuccess;
      expect(success.cacheEntry.cacheState, MetadataArtworkCacheState.downloaded);
      expect(success.updatedReference.localRelativePath, isNotNull);
      expect(success.updatedReference.cacheState,
          MetadataArtworkCacheState.downloaded);
      expect(await service.lookup(reference), isNotNull);
    });

    test('download reuses existing cache without HTTP', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      await service.download(reference: reference);
      final beforeCount = httpClient.requestCount;
      final result = await service.download(reference: reference);

      expect(httpClient.requestCount, beforeCount);
      expect(result, isA<MetadataArtworkDownloadSuccess>());
    });

    test('refresh failure preserves previous valid cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );
      await service.download(reference: reference);

      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.htmlBytes,
        ),
      );

      final result = await service.refresh(reference: reference);
      expect(result, isA<MetadataArtworkDownloadFailure>());
      final failure = result as MetadataArtworkDownloadFailure;
      expect(failure.updatedReference?.cacheState,
          MetadataArtworkCacheState.downloaded);
      expect(await service.lookup(reference), isNotNull);
    });

    test('validation failure deletes temp file and leaves cache empty', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.htmlBytes,
        ),
      );

      final result = await service.download(reference: reference);
      expect(result, isA<MetadataArtworkDownloadFailure>());
      expect(await service.lookup(reference), isNull);

      final fs = await repository.filesystem();
      final files = await fs.listCachedFiles();
      expect(files.where((file) => file.path.endsWith('.part')), isEmpty);
    });

    test('stale generation prevents commit', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      final generation = generationGuard.bump('book-1');
      generationGuard.bump('book-1');

      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );

      final result = await service.download(
        reference: reference,
        itemId: 'book-1',
        expectedGeneration: generation,
      );

      expect(result, isA<MetadataArtworkDownloadFailure>());
      expect(
        (result as MetadataArtworkDownloadFailure).category,
        MetadataArtworkDownloadFailureCategory.staleGeneration,
      );
      expect(await service.lookup(reference), isNull);
    });

    test('relink uses different cache key for different provider record', () async {
      final first = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/OLD',
        artworkId: '111',
      );
      final second = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/NEW',
        artworkId: '222',
      );

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

      await service.download(reference: first);
      await service.download(reference: second);

      expect(first.cacheKey, isNot(second.cacheKey));
      expect(await service.lookup(first), isNotNull);
      expect(await service.lookup(second), isNotNull);
    });

    test('unlink simulation retains cache file until explicit remove', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      httpClient.registerResponse(
        'https://covers.openlibrary.org/b/id/8230111-L.jpg',
        MetadataArtworkTestFixtures.pngResponse(
          MetadataArtworkTestFixtures.onePixelPng,
        ),
      );
      await service.download(reference: reference);

      expect(await service.lookup(reference), isNotNull);

      await service.remove(reference);
      expect(await service.lookup(reference), isNull);
    });
  });
}
