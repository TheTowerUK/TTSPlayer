import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/fake_metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_entry.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_resolution.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_resolver.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/artwork/library_visual_kind.dart';

import 'support/metadata_artwork_test_fixtures.dart';

/// Cache repository that delays [peekLookup] per key for concurrency tests.
class _DelayedPeekCacheRepository extends MetadataArtworkCacheRepository {
  _DelayedPeekCacheRepository({
    required super.filesystem,
    required this.peekDelaysByKey,
    super.clock,
  });

  final Map<String, Duration> peekDelaysByKey;
  int peekLookupCallCount = 0;
  int lookupCallCount = 0;

  @override
  Future<MetadataArtworkCacheLookup?> peekLookup(String cacheKey) async {
    peekLookupCallCount++;
    final delay = peekDelaysByKey[cacheKey];
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return super.peekLookup(cacheKey);
  }

  @override
  Future<MetadataArtworkCacheLookup?> lookup(String cacheKey) async {
    lookupCallCount++;
    return super.lookup(cacheKey);
  }
}

/// Counts download-service entry points if accidentally invoked during resolution.
class _CountingDownloadService extends MetadataArtworkDownloadService {
  _CountingDownloadService({
    required super.cacheRepository,
    required super.httpClient,
  });

  int invocationCount = 0;

  @override
  Future<MetadataArtworkDownloadResult> download({
    required MetadataArtworkReference reference,
    String? itemId,
    int? expectedGeneration,
    Uri? overrideDownloadUrl,
  }) {
    invocationCount++;
    return super.download(
      reference: reference,
      itemId: itemId,
      expectedGeneration: expectedGeneration,
      overrideDownloadUrl: overrideDownloadUrl,
    );
  }

  @override
  Future<MetadataArtworkDownloadResult> refresh({
    required MetadataArtworkReference reference,
    String? itemId,
    int? expectedGeneration,
    Uri? overrideDownloadUrl,
  }) {
    invocationCount++;
    return super.refresh(
      reference: reference,
      itemId: itemId,
      expectedGeneration: expectedGeneration,
      overrideDownloadUrl: overrideDownloadUrl,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late MetadataArtworkFilesystem filesystem;
  late MetadataArtworkCacheRepository cacheRepository;
  late ArtworkService artworkService;
  late MetadataArtworkResolver resolver;

  MediaItem bookItem({
    String id = 'book-1',
    String filePath = r'Y:\Media\Books\sample.epub',
    String? thumbnailPath,
  }) {
    return MediaItem(
      id: id,
      title: 'Sample Book',
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      mediaKindRaw: MediaKind.book.catalogueValue,
    );
  }

  MetadataEnrichmentRecord linkedRecord({
    String itemId = 'book-1',
    String providerRecordId = '/books/OL123M',
    MetadataArtworkReference? artworkReference,
  }) {
    return MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: 'open_library',
      providerRecordId: providerRecordId,
      providerMediaType: 'book',
      matchMethod: EnrichmentMatchMethod.manual,
      artworkReference: artworkReference,
    ).normalized();
  }

  Future<void> seedCache({
    required MetadataArtworkReference reference,
    MetadataArtworkCacheState cacheState = MetadataArtworkCacheState.downloaded,
    String? relativePath,
  }) async {
    final path = relativePath ?? '${reference.cacheKey}.png';
    final file = filesystem.fileForRelativePath(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(MetadataArtworkTestFixtures.onePixelPng);
    final now = DateTime.utc(2026, 8, 3, 12);
    await cacheRepository.upsertEntry(
      MetadataArtworkCacheEntry(
        cacheKey: reference.cacheKey,
        providerId: reference.providerId,
        providerRecordId: reference.providerRecordId,
        artworkId: reference.artworkId,
        relativePath: path,
        contentType: 'image/png',
        width: 1,
        height: 1,
        byteSize: MetadataArtworkTestFixtures.onePixelPng.length,
        createdAt: now,
        lastValidatedAt: now,
        lastAccessedAt: now,
        cacheState: cacheState,
      ).normalized(),
    );
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_artwork_resolver_test_');
    filesystem = MetadataArtworkFilesystem(cacheRoot: tempRoot);
    cacheRepository = MetadataArtworkCacheRepository(
      filesystem: filesystem,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await cacheRepository.initialize();
    artworkService = ArtworkService(fileExists: (_) => false);
    resolver = MetadataArtworkResolver(
      artworkService: artworkService,
      cacheRepository: cacheRepository,
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('Local precedence', () {
    test('catalogue thumbnail beats provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      artworkService = ArtworkService(
        fileExists: (path) => path.endsWith('thumb.jpg'),
      );
      resolver = MetadataArtworkResolver(
        artworkService: artworkService,
        cacheRepository: cacheRepository,
      );

      final item = bookItem(
        thumbnailPath: r'Y:\Media\Books\thumb.jpg',
      );
      final result = await resolver.resolveForMediaItem(
        item: item,
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.candidate.source, ArtworkSource.catalogThumbnail);
      expect(result.isProviderCached, isFalse);
    });

    test('sidecar beats provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      artworkService = ArtworkService(
        fileExists: (path) => path.endsWith('sample.jpg'),
      );
      resolver = MetadataArtworkResolver(
        artworkService: artworkService,
        cacheRepository: cacheRepository,
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(filePath: r'Y:\Media\Books\sample.epub'),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.candidate.source, ArtworkSource.sidecar);
      expect(result.isProviderCached, isFalse);
    });

    test('folder art beats provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      artworkService = ArtworkService(
        fileExists: (path) => path == r'Y:\Media\Books\cover.jpg',
      );
      resolver = MetadataArtworkResolver(
        artworkService: artworkService,
        cacheRepository: cacheRepository,
      );

      final parent = MediaFolder(
        id: 'books',
        name: 'Books',
        path: r'Y:\Media\Books',
        itemCount: 1,
        items: const [],
        subfolders: const [],
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(filePath: r'Y:\Media\Books\nested\sample.epub'),
        parentFolder: parent,
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.candidate.source, ArtworkSource.folderArt);
      expect(result.isProviderCached, isFalse);
    });

    test('placeholder used when no source exists', () async {
      final result = await resolver.resolveForMediaItem(item: bookItem());
      expect(result.candidate.source, ArtworkSource.placeholder);
      expect(result.isPlaceholder, isTrue);
    });
  });

  group('Provider eligibility', () {
    test('linked book with matching cache resolves provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.isProviderCached, isTrue);
      expect(result.candidate.source, ArtworkSource.providerCache);
      expect(result.candidate.hasFile, isTrue);
      expect(result.provenanceLabel, isNotNull);
      expect(result.cacheKey, reference.cacheKey);
    });

    test('reference without cache falls back to placeholder', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.usedFallback, isTrue);
      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.cacheEntryMissing);
      expect(result.candidate.source, ArtworkSource.placeholder);
    });

    test('cache without linked record is ineligible', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);

      final result = await resolver.resolveForMediaItem(item: bookItem());
      expect(result.isProviderCached, isFalse);
      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.noEnrichmentRecord);
    });

    test('unmatched item cannot use provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      final record = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.unmatched,
        artworkReference: reference,
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: record,
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.notProviderLinked);
    });

    test('ignored unlinked item cannot use provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      final record = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.ignored,
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: record,
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.notProviderLinked);
    });

    test('non-book item cannot use provider cache', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      final video = MediaItem(
        id: 'video-1',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
        mediaKindRaw: MediaKind.video.catalogueValue,
      );

      final result = await resolver.resolveForMediaItem(
        item: video,
        enrichmentRecord: linkedRecord(itemId: 'video-1', artworkReference: reference),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.unsupportedMediaKind);
    });

    test('provider record mismatch is ineligible', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/OLD',
      );
      await seedCache(reference: reference);

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(
          providerRecordId: '/books/NEW',
          artworkReference: reference,
        ),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.identityMismatch);
    });

    test('missing cache file falls back', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      final now = DateTime.utc(2026, 8, 3, 12);
      await cacheRepository.upsertEntry(
        MetadataArtworkCacheEntry(
          cacheKey: reference.cacheKey,
          providerId: reference.providerId,
          providerRecordId: reference.providerRecordId,
          artworkId: reference.artworkId,
          relativePath: '${reference.cacheKey}.png',
          contentType: 'image/png',
          byteSize: 100,
          createdAt: now,
          lastValidatedAt: now,
          lastAccessedAt: now,
          cacheState: MetadataArtworkCacheState.downloaded,
        ).normalized(),
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.cacheEntryMissing);
    });

    test('failed cache state is ineligible', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(
        reference: reference,
        cacheState: MetadataArtworkCacheState.failed,
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.cacheStateIneligible);
    });

    test('stale valid state is eligible and marked stale', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference().copyWith(
        cacheState: MetadataArtworkCacheState.stale,
      );
      await seedCache(
        reference: reference,
        cacheState: MetadataArtworkCacheState.stale,
      );

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.isProviderCached, isTrue);
      expect(result.isStale, isTrue);
    });

    test('unsafe relative path falls back', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      final now = DateTime.utc(2026, 8, 3, 12).toIso8601String();
      await filesystem.writeIndexAtomically(
        '{"indexVersion":1,"entries":[{"cacheKey":"${reference.cacheKey}",'
        '"providerId":"open_library","providerRecordId":"/books/OL123M",'
        '"artworkId":"8230111","relativePath":"../escape.png",'
        '"contentType":"image/png","byteSize":100,'
        '"createdAt":"$now","lastValidatedAt":"$now","lastAccessedAt":"$now",'
        '"cacheState":"downloaded"}]}',
      );
      await cacheRepository.initialize();

      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.cacheEntryMissing);
    });
  });

  group('Lifecycle', () {
    test('relink invalidates old cached artwork identity', () async {
      final oldReference = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/OLD',
        artworkId: '111',
      );
      final newReference = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/NEW',
        artworkId: '222',
      );
      await seedCache(reference: oldReference);
      await seedCache(reference: newReference);

      final relinked = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(
          providerRecordId: '/books/NEW',
          artworkReference: newReference,
        ),
      );
      expect(relinked.cacheKey, newReference.cacheKey);

      final staleOld = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(
          providerRecordId: '/books/NEW',
          artworkReference: oldReference,
        ),
      );
      expect(staleOld.ineligibilityReason,
          MetadataArtworkIneligibilityReason.identityMismatch);
    });

    test('same-record relink retains cache eligibility', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);

      final first = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );
      final second = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(first.isProviderCached, isTrue);
      expect(second.isProviderCached, isTrue);
      expect(first.cacheKey, second.cacheKey);
    });

    test('unlink removes provider eligibility but cache file remains', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);

      final unlinked = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );
      expect(unlinked.isProviderCached, isFalse);

      final file = filesystem.fileForRelativePath('${reference.cacheKey}.png');
      expect(await file.exists(), isTrue);
    });
  });

  group('Resolver output and performance', () {
    test('provider result contains no raw remote URL', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.candidate.filePath, isNot(contains('http')));
      expect(result.candidate.filePath, startsWith(tempRoot.path));
    });

    test('peekLookup does not update lastAccessedAt', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);
      final before = cacheRepository.entryForKey(reference.cacheKey)!.lastAccessedAt;

      await cacheRepository.peekLookup(reference.cacheKey);
      await cacheRepository.peekLookup(reference.cacheKey);

      final after = cacheRepository.entryForKey(reference.cacheKey)!.lastAccessedAt;
      expect(after, before);
    });

    test('repeated resolution reuses ArtworkService LRU', () async {
      var calls = 0;
      artworkService = ArtworkService(
        fileExists: (path) {
          calls++;
          return path.endsWith('cover.jpg');
        },
      );
      resolver = MetadataArtworkResolver(
        artworkService: artworkService,
        cacheRepository: cacheRepository,
      );

      final item = bookItem();
      await resolver.resolveForMediaItem(item: item);
      final afterFirst = calls;
      await resolver.resolveForMediaItem(item: item);
      expect(calls, afterFirst);
    });

    test('different books resolve independently', () async {
      final refA = MetadataArtworkTestFixtures.sampleReference(artworkId: '111');
      final refB = MetadataArtworkTestFixtures.sampleReference(artworkId: '222');
      await seedCache(reference: refA);
      await seedCache(reference: refB);

      final resultA = await resolver.resolveForMediaItem(
        item: bookItem(id: 'book-a'),
        enrichmentRecord: linkedRecord(
          itemId: 'book-a',
          artworkReference: refA,
        ),
      );
      final resultB = await resolver.resolveForMediaItem(
        item: bookItem(id: 'book-b'),
        enrichmentRecord: linkedRecord(
          itemId: 'book-b',
          artworkReference: refB,
        ),
      );

      expect(resultA.cacheKey, isNot(resultB.cacheKey));
    });

    test('concurrent resolutions do not cross-link cache entries', () async {
      final refA = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/OL111M',
        artworkId: '111',
      );
      final refB = MetadataArtworkTestFixtures.sampleReference(
        providerRecordId: '/books/OL222M',
        artworkId: '222',
      );
      await seedCache(reference: refA);
      await seedCache(reference: refB);

      final delayedRepository = _DelayedPeekCacheRepository(
        filesystem: filesystem,
        peekDelaysByKey: {
          refA.cacheKey: const Duration(milliseconds: 40),
          refB.cacheKey: const Duration(milliseconds: 5),
        },
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      await delayedRepository.initialize();

      final httpClient = FakeMetadataArtworkHttpClient();
      final downloadService = _CountingDownloadService(
        cacheRepository: delayedRepository,
        httpClient: httpClient,
      );

      final concurrentResolver = MetadataArtworkResolver(
        artworkService: artworkService,
        cacheRepository: delayedRepository,
      );

      final itemA = bookItem(
        id: 'book-a',
        filePath: r'Y:\Media\Books\alpha.epub',
      );
      final itemB = bookItem(
        id: 'book-b',
        filePath: r'Y:\Media\Books\beta.epub',
      );
      final recordA = linkedRecord(
        itemId: 'book-a',
        providerRecordId: refA.providerRecordId,
        artworkReference: refA,
      );
      final recordB = linkedRecord(
        itemId: 'book-b',
        providerRecordId: refB.providerRecordId,
        artworkReference: refB,
      );

      for (var iteration = 0; iteration < 3; iteration++) {
        delayedRepository.peekDelaysByKey
          ..[refA.cacheKey] = iteration.isEven
              ? const Duration(milliseconds: 50)
              : Duration.zero
          ..[refB.cacheKey] = iteration.isEven
              ? Duration.zero
              : const Duration(milliseconds: 50);

        final results = await Future.wait([
          concurrentResolver.resolveForMediaItem(
            item: itemA,
            enrichmentRecord: recordA,
          ),
          concurrentResolver.resolveForMediaItem(
            item: itemB,
            enrichmentRecord: recordB,
          ),
        ]);

        final resultA = results[0];
        final resultB = results[1];

        expect(resultA.isProviderCached, isTrue);
        expect(resultB.isProviderCached, isTrue);
        expect(resultA.cacheKey, refA.cacheKey);
        expect(resultB.cacheKey, refB.cacheKey);
        expect(resultA.candidate.filePath, contains(refA.cacheKey));
        expect(resultB.candidate.filePath, contains(refB.cacheKey));
        expect(resultA.candidate.filePath, isNot(contains(refB.cacheKey)));
        expect(resultB.candidate.filePath, isNot(contains(refA.cacheKey)));
        expect(resultA.candidate.filePath, isNot(resultB.candidate.filePath));
      }

      expect(delayedRepository.peekLookupCallCount, greaterThanOrEqualTo(6));
      expect(delayedRepository.lookupCallCount, 0);
      expect(httpClient.requestCount, 0);
      expect(downloadService.invocationCount, 0);
    });

    test('null cache repository falls back safely', () async {
      resolver = MetadataArtworkResolver(artworkService: artworkService);
      final reference = MetadataArtworkTestFixtures.sampleReference();
      final result = await resolver.resolveForMediaItem(
        item: bookItem(),
        enrichmentRecord: linkedRecord(artworkReference: reference),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.cacheRepositoryUnavailable);
      expect(result.candidate.source, ArtworkSource.placeholder);
    });

    test('item identity mismatch is isolated', () async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await seedCache(reference: reference);

      final result = await resolver.resolveForMediaItem(
        item: bookItem(id: 'other-item'),
        enrichmentRecord: linkedRecord(
          itemId: 'book-1',
          artworkReference: reference,
        ),
      );

      expect(result.ineligibilityReason,
          MetadataArtworkIneligibilityReason.itemIdentityMismatch);
    });

    test('placeholder identifies visual kind for books', () async {
      final result = await resolver.resolveForMediaItem(item: bookItem());
      expect(result.candidate.visualKind, LibraryVisualKind.literature);
    });
  });
}
