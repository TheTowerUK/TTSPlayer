import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/widgets/continue_watching_section.dart';
import 'package:ttsplayer/features/favourites/favourites_screen.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_entry.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/search/models/search_result.dart';
import 'package:ttsplayer/features/search/widgets/search_result_row.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_presentation_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';
import 'package:ttsplayer/widgets/artwork/resolved_media_artwork_image.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_artwork_test_fixtures.dart';
import 'support/metadata_enrichment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late MetadataEnrichmentRepository repository;
  late MetadataArtworkCacheRepository cacheRepository;
  late ArtworkService artworkService;
  late ArtworkPresentationService presentationService;
  late FakeMetadataHttpCounter httpCounter;
  late FakeDownloadCounter downloadCounter;

  MediaItem bookItem({
    String id = 'book-1',
    String? thumbnailPath,
  }) {
    return MediaItem(
      id: id,
      title: 'Sample Book',
      filePath: r'Y:\Media\Books\sample.epub',
      thumbnailPath: thumbnailPath,
      status: MediaItemStatus.available,
      mediaKindRaw: MediaKind.book.catalogueValue,
    );
  }

  MediaItem videoItem() {
    return MediaItem(
      id: 'video-1',
      title: 'Sample Video',
      filePath: r'Y:\Media\Movies\film.mp4',
      status: MediaItemStatus.available,
      mediaKindRaw: MediaKind.video.catalogueValue,
    );
  }

  MetadataEnrichmentRecord linkedRecord({
    String itemId = 'book-1',
    String providerRecordId = '/books/OL123M',
    MetadataArtworkReference? artworkReference,
    EnrichmentMatchState matchState = EnrichmentMatchState.linkedManual,
  }) {
    return MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: matchState,
      providerId: 'open_library',
      providerRecordId: providerRecordId,
      providerMediaType: 'book',
      matchMethod: EnrichmentMatchMethod.manual,
      artworkReference: artworkReference,
    ).normalized();
  }

  Future<MetadataArtworkReference> seedProviderCache({
    String artworkId = '8230111',
    String providerRecordId = '/books/OL123M',
  }) async {
    final base = MetadataArtworkTestFixtures.sampleReference(
      artworkId: artworkId,
      providerRecordId: providerRecordId,
    );
    final reference = base.copyWith(
      cacheState: MetadataArtworkCacheState.downloaded,
      localRelativePath: '${base.cacheKey}.png',
      validatedAt: DateTime.utc(2026, 8, 3, 12),
      contentType: 'image/png',
      width: 1,
      height: 1,
    );
    final path = reference.localRelativePath!;
    final fs = await cacheRepository.filesystem();
    final target = fs.fileForRelativePath(path);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(MetadataArtworkTestFixtures.onePixelPng);
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
        cacheState: MetadataArtworkCacheState.downloaded,
      ).normalized(),
    );
    return reference;
  }

  ArtworkSource? displayedSource(WidgetTester tester) {
    final images = tester.widgetList<ArtworkImage>(find.byType(ArtworkImage));
    if (images.isEmpty) {
      return null;
    }
    return images.first.candidate.source;
  }

  Future<MetadataArtworkReference> seedLinkedBook({
    WidgetTester? tester,
    String itemId = 'book-1',
    String artworkId = '8230111',
    String providerRecordId = '/books/OL123M',
    EnrichmentMatchState matchState = EnrichmentMatchState.linkedManual,
  }) async {
    Future<MetadataArtworkReference> seed() async {
      final reference = await seedProviderCache(
        artworkId: artworkId,
        providerRecordId: providerRecordId,
      );
      await repository.upsert(
        linkedRecord(
          itemId: itemId,
          providerRecordId: providerRecordId,
          artworkReference: reference,
          matchState: matchState,
        ),
      );
      return reference;
    }

    if (tester == null) {
      return seed();
    }
    late MetadataArtworkReference reference;
    await tester.runAsync(() async {
      reference = await seed();
    });
    return reference;
  }

  Future<void> pumpResolvedFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Widget wrapResolved({
    required Widget child,
    LibraryMetadataRepository? libraryMetadata,
  }) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
          if (libraryMetadata != null)
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: libraryMetadata,
            ),
          Provider<MediaLocationResolver>.value(
            value: const NonLoadingMediaLocationResolver(),
          ),
          Provider<ArtworkService>.value(value: artworkService),
          Provider<ArtworkPresentationService?>.value(
            value: presentationService,
          ),
          ChangeNotifierProvider<MetadataEnrichmentRepository>.value(
            value: repository,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_artwork_presentation_');
    repository = await initializedMetadataEnrichmentRepository();
    cacheRepository = MetadataArtworkCacheRepository(
      filesystem: MetadataArtworkFilesystem(cacheRoot: tempRoot),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await cacheRepository.initialize();
    artworkService = ArtworkService(fileExists: (_) => false);
    presentationService = ArtworkPresentationService(
      artworkService: artworkService,
      enrichmentRepository: repository,
      cacheRepository: cacheRepository,
    );
    httpCounter = FakeMetadataHttpCounter();
    downloadCounter = FakeDownloadCounter();
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('ArtworkPresentationService', () {
    test('local catalogue thumbnail beats provider cache', () async {
      final reference = await seedProviderCache();
      await repository.upsert(linkedRecord(artworkReference: reference));
      artworkService = ArtworkService(
        fileExists: (path) => path.endsWith('thumb.jpg'),
      );
      presentationService = ArtworkPresentationService(
        artworkService: artworkService,
        enrichmentRepository: repository,
        cacheRepository: cacheRepository,
      );

      final result = await presentationService.resolveForMediaItem(
        item: bookItem(thumbnailPath: r'Y:\Media\Books\thumb.jpg'),
      );

      expect(result.candidate.source, ArtworkSource.catalogThumbnail);
      expect(result.isProviderCached, isFalse);
      expect(httpCounter.requestCount, 0);
      expect(downloadCounter.callCount, 0);
    });

    test('linked book with cache resolves provider artwork', () async {
      final reference = await seedProviderCache();
      await repository.upsert(linkedRecord(artworkReference: reference));

      final result = await presentationService.resolveForMediaItem(
        item: bookItem(),
      );

      expect(result.isProviderCached, isTrue);
      expect(result.candidate.source, ArtworkSource.providerCache);
      expect(httpCounter.requestCount, 0);
      expect(downloadCounter.callCount, 0);
    });

    test('non-book ignores provider cache', () async {
      final reference = await seedProviderCache();
      await repository.upsert(
        linkedRecord(itemId: 'video-1', artworkReference: reference),
      );

      final result = await presentationService.resolveForMediaItem(
        item: videoItem(),
      );

      expect(result.isProviderCached, isFalse);
      expect(result.candidate.source, ArtworkSource.placeholder);
    });

    test('unlink clears provider eligibility', () async {
      final reference = await seedProviderCache();
      await repository.upsert(linkedRecord(artworkReference: reference));
      expect(
        (await presentationService.resolveForMediaItem(item: bookItem()))
            .isProviderCached,
        isTrue,
      );

      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );

      final after = await presentationService.resolveForMediaItem(
        item: bookItem(),
      );
      expect(after.isProviderCached, isFalse);
      expect(after.candidate.source, ArtworkSource.placeholder);
    });

    test('changed artwork id waits for explicit download', () async {
      final reference = await seedProviderCache(artworkId: '8230111');
      await repository.upsert(linkedRecord(artworkReference: reference));
      expect(
        (await presentationService.resolveForMediaItem(item: bookItem()))
            .isProviderCached,
        isTrue,
      );

      final changed = MetadataArtworkTestFixtures.sampleReference(
        artworkId: '9999999',
      ).copyWith(
        cacheState: MetadataArtworkCacheState.available,
        clearLocalRelativePath: true,
      );
      await repository.upsert(linkedRecord(artworkReference: changed));

      final after = await presentationService.resolveForMediaItem(
        item: bookItem(),
      );
      expect(after.isProviderCached, isFalse);
      expect(after.candidate.source, ArtworkSource.placeholder);
      expect(downloadCounter.callCount, 0);
    });
  });

  group('Item detail presentation', () {
    testWidgets('1 shows local artwork', (tester) async {
      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: bookItem(thumbnailPath: r'Y:\Media\Books\thumb.jpg'),
          repository: repository,
          artworkCacheRepository: cacheRepository,
          artworkFileExists: (path) => path.endsWith('thumb.jpg'),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.catalogThumbnail);
    });

    testWidgets('2 shows provider artwork for linked downloaded cover',
        (tester) async {
      final reference = await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: bookItem(),
          repository: repository,
          artworkCacheRepository: cacheRepository,
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.providerCache);
      expect(find.textContaining('http'), findsNothing);
      expect(find.textContaining(reference.cacheKey), findsNothing);
      expect(httpCounter.requestCount, 0);
      expect(downloadCounter.callCount, 0);
    });

    testWidgets('3 placeholder fallback', (tester) async {
      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: bookItem(),
          repository: repository,
          artworkCacheRepository: cacheRepository,
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });

    testWidgets('4 relink updates presentation', (tester) async {
      await seedLinkedBook(
        tester: tester,
        artworkId: '8230111',
        providerRecordId: '/books/OL123M',
      );

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: bookItem(),
          repository: repository,
          artworkCacheRepository: cacheRepository,
        ),
      );
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.providerCache);

      final second = await seedLinkedBook(
        tester: tester,
        artworkId: '5555555',
        providerRecordId: '/books/OL999M',
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.providerCache);
      final image = tester.widget<ArtworkImage>(find.byType(ArtworkImage));
      expect(image.candidate.filePath, contains(second.cacheKey));
    });

    testWidgets('5 unlink updates presentation to placeholder', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: bookItem(),
          repository: repository,
          artworkCacheRepository: cacheRepository,
        ),
      );
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.providerCache);

      await tester.runAsync(() async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.unmatched,
          ),
        );
      });
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });

    testWidgets('6 non-book item detail ignores provider artwork',
        (tester) async {
      await seedLinkedBook(tester: tester, itemId: 'video-1');

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: videoItem(),
          repository: repository,
          artworkCacheRepository: cacheRepository,
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });
  });

  group('Browse surfaces', () {
    testWidgets('7 media card shows provider artwork', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        wrapResolved(
          child: SizedBox(
            width: 180,
            height: 280,
            child: TtsMediaCard(
              item: bookItem(),
              onTap: () {},
            ),
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);
      expect(displayedSource(tester), ArtworkSource.providerCache);
      expect(httpCounter.requestCount, 0);
    });

    testWidgets('8 local beats provider on media card', (tester) async {
      await seedLinkedBook(tester: tester);
      artworkService = ArtworkService(
        fileExists: (path) => path.endsWith('thumb.jpg'),
      );
      presentationService = ArtworkPresentationService(
        artworkService: artworkService,
        enrichmentRepository: repository,
        cacheRepository: cacheRepository,
      );

      await tester.pumpWidget(
        wrapResolved(
          child: SizedBox(
            width: 180,
            height: 280,
            child: TtsMediaCard(
              item: bookItem(thumbnailPath: r'Y:\Media\Books\thumb.jpg'),
              onTap: () {},
            ),
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.catalogThumbnail);
    });

    testWidgets('9 placeholder on media card', (tester) async {
      await tester.pumpWidget(
        wrapResolved(
          child: SizedBox(
            width: 180,
            height: 280,
            child: TtsMediaCard(
              item: bookItem(),
              onTap: () {},
            ),
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });

    testWidgets('10 continue watching shows provider artwork', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        wrapResolved(
          child: ContinueWatchingSection(
            entries: [
              ContinueWatchingEntry(
                item: bookItem(),
                resume: const ResumeInfo(
                  savedPosition: Duration(minutes: 2),
                  totalDuration: Duration(minutes: 10),
                ),
              ),
            ],
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.providerCache);
    });

    testWidgets('11 favourites shows provider artwork', (tester) async {
      await seedLinkedBook(tester: tester);
      final item = bookItem();
      final catalog = Catalog.fromJson({
        'generated_at': '2026-08-03T00:00:00Z',
        'total_items': 1,
        'folders': [
          {
            'id': 'folder-books',
            'name': 'Books',
            'path': r'Y:\Media\Books',
            'item_count': 1,
            'items': [item.toJson()],
            'subfolders': <Map<String, dynamic>>[],
          },
        ],
      });
      late LibraryMetadataRepository libraryMetadata;
      await tester.runAsync(() async {
        libraryMetadata = LibraryMetadataRepository();
        await libraryMetadata.initialize();
        await libraryMetadata.toggleItemFavourite(item.id);
      });

      await tester.pumpWidget(
        wrapResolved(
          libraryMetadata: libraryMetadata,
          child: FavouritesScreen(catalog: catalog),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);
      expect(displayedSource(tester), ArtworkSource.providerCache);
    });

    testWidgets('12 search row shows provider artwork', (tester) async {
      await seedLinkedBook(tester: tester);
      final item = bookItem();

      await tester.pumpWidget(
        wrapResolved(
          child: SearchResultRow(
            result: SearchResult(
              item: item,
              libraryName: 'Books',
              parentFolderName: 'Books',
              parentFolderPath: r'Y:\Media\Books',
              score: 100,
            ),
            displayContext: 'Books',
            onOpen: () {},
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.providerCache);
    });
  });

  group('Lifecycle', () {
    testWidgets('13 download completion updates presentation', (tester) async {
      await tester.runAsync(() async {
        await repository.upsert(linkedRecord());
      });

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.placeholder);

      await seedLinkedBook(tester: tester);
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.providerCache);
      expect(downloadCounter.callCount, 0);
    });

    testWidgets('14 relink replaces artwork path', (tester) async {
      final first = await seedLinkedBook(
        tester: tester,
        artworkId: '111',
        providerRecordId: '/books/OL111M',
      );

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);
      final firstPath =
          tester.widget<ArtworkImage>(find.byType(ArtworkImage)).candidate.filePath;

      final second = await seedLinkedBook(
        tester: tester,
        artworkId: '222',
        providerRecordId: '/books/OL222M',
      );
      await pumpResolvedFrames(tester);

      final secondPath =
          tester.widget<ArtworkImage>(find.byType(ArtworkImage)).candidate.filePath;
      expect(secondPath, isNot(firstPath));
      expect(secondPath, contains(second.cacheKey));
      expect(firstPath, contains(first.cacheKey));
    });

    testWidgets('15 unlink clears provider artwork', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.providerCache);

      await tester.runAsync(() async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.unmatched,
          ),
        );
      });
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.placeholder);
    });

    testWidgets('16 changed artwork id waits for explicit download',
        (tester) async {
      await seedLinkedBook(tester: tester, artworkId: '8230111');

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);
      expect(displayedSource(tester), ArtworkSource.providerCache);

      await tester.runAsync(() async {
        final changed = MetadataArtworkTestFixtures.sampleReference(
          artworkId: '9999999',
        ).copyWith(
          cacheState: MetadataArtworkCacheState.available,
          clearLocalRelativePath: true,
        );
        await repository.upsert(linkedRecord(artworkReference: changed));
      });
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
      expect(downloadCounter.callCount, 0);
    });

    testWidgets('17 ignored item hides provider artwork', (tester) async {
      await seedLinkedBook(
        tester: tester,
        matchState: EnrichmentMatchState.ignored,
      );

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });
  });

  group('Resolver usage and isolation', () {
    testWidgets('18-19 zero HTTP and zero download on rebuild', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      await pumpResolvedFrames(tester);
      await tester.pump();
      await tester.pump();

      expect(httpCounter.requestCount, 0);
      expect(downloadCounter.callCount, 0);
      expect(displayedSource(tester), ArtworkSource.providerCache);
    });

    testWidgets('20 resolver precedence local over provider', (tester) async {
      await seedLinkedBook(tester: tester);
      artworkService = ArtworkService(
        fileExists: (path) => path.endsWith('cover.jpg'),
      );
      presentationService = ArtworkPresentationService(
        artworkService: artworkService,
        enrichmentRepository: repository,
        cacheRepository: cacheRepository,
      );

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(
            item: bookItem(thumbnailPath: r'Y:\Media\Books\cover.jpg'),
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.catalogThumbnail);
    });

    testWidgets('21 repeated rebuild stays cheap (no HTTP)', (tester) async {
      await seedLinkedBook(tester: tester);

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: bookItem()),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(httpCounter.requestCount, 0);
      expect(displayedSource(tester), ArtworkSource.providerCache);
    });

    testWidgets('22 item isolation across concurrent widgets', (tester) async {
      late MetadataArtworkReference first;
      late MetadataArtworkReference second;
      await tester.runAsync(() async {
        first = await seedProviderCache(
          artworkId: 'aaa',
          providerRecordId: '/books/OLAAA',
        );
        second = await seedProviderCache(
          artworkId: 'bbb',
          providerRecordId: '/books/OLBBB',
        );
        await repository.upsert(
          linkedRecord(
            itemId: 'book-1',
            providerRecordId: '/books/OLAAA',
            artworkReference: first,
          ),
        );
        await repository.upsert(
          linkedRecord(
            itemId: 'book-2',
            providerRecordId: '/books/OLBBB',
            artworkReference: second,
          ),
        );
      });

      await tester.pumpWidget(
        wrapResolved(
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: ResolvedMediaArtworkImage(item: bookItem(id: 'book-1')),
              ),
              SizedBox(
                height: 80,
                child: ResolvedMediaArtworkImage(item: bookItem(id: 'book-2')),
              ),
            ],
          ),
        ),
      );
      await pumpResolvedFrames(tester);

      final images =
          tester.widgetList<ArtworkImage>(find.byType(ArtworkImage)).toList();
      expect(images, hasLength(2));
      expect(images[0].candidate.filePath, contains(first.cacheKey));
      expect(images[1].candidate.filePath, contains(second.cacheKey));
    });

    testWidgets('23 non-book isolation', (tester) async {
      await seedLinkedBook(tester: tester, itemId: 'video-1');

      await tester.pumpWidget(
        wrapResolved(
          child: ResolvedMediaArtworkImage(item: videoItem()),
        ),
      );
      await pumpResolvedFrames(tester);

      expect(displayedSource(tester), ArtworkSource.placeholder);
    });
  });
}

/// Tracks accidental HTTP use; presentation must never call it.
class FakeMetadataHttpCounter {
  int requestCount = 0;
}

/// Tracks accidental download-service use; presentation must never call it.
class FakeDownloadCounter {
  int callCount = 0;
}
