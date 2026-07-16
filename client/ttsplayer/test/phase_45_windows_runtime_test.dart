@Tags(['phase45-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_presentation_metrics.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_results_list.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/library/folder_presentation_metrics.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/large_catalog_factory.dart';
import 'support/phase_45_runtime_baseline.dart';

class _CountingArtworkService extends ArtworkService {
  _CountingArtworkService({super.fileExists});

  int clearInvocations = 0;

  @override
  void clearCache() {
    clearInvocations++;
    super.clearCache();
  }
}

class _FailingMetadataRepository extends LibraryMetadataRepository {
  @override
  Future<CatalogueMetadataValidationResult> validateAgainstCatalog(
    Catalog catalog,
  ) async {
    throw StateError('Simulated favourites reconciliation failure');
  }
}

class _InlineCatalogService extends CatalogService {
  _InlineCatalogService(this._catalog);

  final Catalog _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}
}

/// Windows runtime validation harness for M4 Phase 4.5 performance and caching.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_45_RUNTIME='1'
/// flutter test test/phase_45_windows_runtime_test.dart --tags phase45-runtime
/// ```
///
/// Optional environment variables (no committed paths):
/// - `PHASE_45_LOCAL_CATALOG` — path to a local `catalog.json` for optional live validation
///
/// ### R1–R32 runtime matrix (Step 7)
///
/// | ID | Scenario | Automation |
/// |----|----------|------------|
/// | R1 | Large folder (~2000 items) opens interactively | Widget |
/// | R2 | Initial card builds ≪ total item count | Metrics |
/// | R3 | Folder view preparation count = 1 on first open | Metrics |
/// | R4 | Folder browse does not build search index | `indexBuildCount` |
/// | R5 | No layout overflow or exception on open | Exception |
/// | R6 | Extended directional scrolling | Widget drag |
/// | R7 | Additional cards built incrementally | Metrics |
/// | R8 | Total builds remain below collection size | Metrics |
/// | R9 | Scroll does not freeze or throw | Exception |
/// | R10 | Scroll smoothness / visual stability | **Manual** |
/// | R11 | Artwork candidate cache ≤ 500 during browse | `cacheEntryCount` |
/// | R12 | LRU evictions after >500 distinct identities | `cacheEvictionCount` |
/// | R13 | Sort change causes one new view preparation | Metrics |
/// | R14 | Filter change causes one new view preparation | Metrics |
/// | R15 | Unrelated settings notify does not re-prepare | Metrics |
/// | R16 | Filter clear restores complete view | Widget |
/// | R17 | Item detail return preserves folder scroll | Scroll offset |
/// | R18 | Child folder opens at scroll offset 0 | Widget |
/// | R19 | Parent folder offset preserved after child pop | Widget |
/// | R20 | Unrelated folders do not share scroll offsets | Widget |
/// | R21 | Catalogue replacement invalidates memoized folder view | Metrics + identity |
/// | R22 | Resize viewport near top without exception | Widget |
/// | R23 | Resize viewport while deeply scrolled | Widget |
/// | R24 | Grid layout survives resize (no overflow) | Exception |
/// | R25 | Search open without query — zero index builds | `indexBuildCount` |
/// | R26 | First qualifying search — one index build | `indexBuildCount` |
/// | R27 | Repeated searches reuse built index | `indexBuildCount` |
/// | R28 | Stale async search results not shown | Widget |
/// | R29 | Successful catalogue replacement lifecycle | Coordinator + identity |
/// | R30 | Failed refresh preserves last-good state | Coordinator + caches |
/// | R31 | Flutter ImageCache 100 MB budget configured | Unit |
/// | R32 | ArtworkService clear does not reset Flutter ImageCache budget | Unit |
/// | R33 | Search index build failure retried successfully | Service |
/// | R34 | Favourites reconciliation failure is failure-safe | Coordinator |
/// | R35 | Replacement during in-flight index build | Service |
/// | R36 | Search flatten once per result-list build | Metrics |
/// | R37 | Optional local catalogue load | Skip if env unset |
/// | R38 | Optional local catalogue folder browse | Skip if env unset |
///
/// Manual checkpoints (not automated substitutes):
/// - R10 subjective scroll smoothness on Windows desktop (`flutter run -d windows`)
/// - Brief artwork flicker during fast scroll
/// - Image sharpness after viewport resize
/// - Process-level memory from external profiler
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_45_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_45_RUNTIME=1 to run Phase 4.5 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 4.5 runtime validation is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  const fixtureItemCount = mediumCatalogItemCount;
  final baseline = Phase45RuntimeBaseline();
  final optionalLocalCatalog = Platform.environment['PHASE_45_LOCAL_CATALOG'];

  group('Phase 4.5 Windows runtime validation', () {
    late Directory tempDir;
    late _CountingArtworkService artwork;
    late SearchService search;
    late LibraryMetadataRepository metadata;
    late CatalogCacheCoordinator coordinator;
    late CatalogService catalogService;
    late SettingsRepository settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FolderPresentationMetrics.reset();
      SearchPresentationMetrics.reset();
      configureArtworkFlutterImageCache();

      tempDir = await Directory.systemTemp.createTemp('ttsplayer_phase45_');
      artwork = _CountingArtworkService(fileExists: (_) => false);
      search = SearchService();
      metadata = LibraryMetadataRepository();
      await metadata.initialize();
      coordinator = CatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
      );
      catalogService = CatalogService(
        onCatalogReplaced: coordinator.onCatalogReplaced,
      )..includeLegacyCataloguePaths = false;

      settings = SettingsRepository();
      await settings.initialize();

      final catalog = buildLargeCatalog(itemCount: fixtureItemCount);
      final path = await _writeCatalogFile(
        tempDir,
        catalog,
        'initial.json',
      );
      await catalogService.loadFromFile(path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    tearDownAll(() {
      baseline.printReport();
    });

    Future<void> pumpHarness(
      WidgetTester tester, {
      required Widget home,
      Size viewport = const Size(1280, 800),
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
            ChangeNotifierProvider<SettingsRepository>.value(value: settings),
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: metadata,
            ),
            Provider(
              create: (context) => MediaLocationResolver(
                config:
                    context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: true,
              ),
            ),
            Provider<ArtworkService>.value(value: artwork),
            Provider<SearchService>.value(value: search),
            ChangeNotifierProvider<CatalogService>.value(
              value: catalogService,
            ),
            ChangeNotifierProvider(
              create: (context) => PlaybackService(
                mediaLocationResolver: context.read<MediaLocationResolver>(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => ScannerService()),
            ChangeNotifierProvider(create: (_) => ScanHistoryService()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQueryData(size: viewport),
                child: home,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    MediaFolder activeFolder() {
      final catalog = catalogService.catalog!;
      return largeCatalogFolder(catalog);
    }

    Finder folderScrollable() {
      return find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
    }

    Future<void> scrollFolder(
      WidgetTester tester, {
      required double delta,
      int passes = 1,
    }) async {
      for (var i = 0; i < passes; i++) {
        await tester.drag(folderScrollable(), Offset(0, -delta));
        await tester.pumpAndSettle();
      }
    }

    double folderScrollOffset(WidgetTester tester) {
      return tester
          .state<ScrollableState>(folderScrollable())
          .position
          .pixels;
    }

    group('R1–R5 large-folder loading', () {
      testWidgets('R1–R5 opens lazy without eager search index', (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
        );

        expect(tester.takeException(), isNull);
        expect(FolderPresentationMetrics.viewPreparationCount, 1);
        expect(FolderPresentationMetrics.mediaCardBuildCount, greaterThan(0));
        expect(
          FolderPresentationMetrics.mediaCardBuildCount,
          lessThan(80),
        );
        expect(
          FolderPresentationMetrics.mediaCardBuildCount,
          lessThan(fixtureItemCount),
        );
        expect(search.indexBuildCount, 0);
        expect(search.hasIndex, isFalse);

        baseline
          ..observe('catalogue_source', 'generated')
          ..observe('fixture_item_count', fixtureItemCount)
          ..observe(
            'initial_media_card_builds',
            FolderPresentationMetrics.mediaCardBuildCount,
          )
          ..observe(
            'initial_view_preparations',
            FolderPresentationMetrics.viewPreparationCount,
          )
          ..observe('search_index_builds_after_folder_open', search.indexBuildCount);
      });
    });

    group('R6–R12 extended scrolling and artwork bounds', () {
      testWidgets('R6–R9 scroll builds incrementally without freeze',
          (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
        );
        final initialBuilds = FolderPresentationMetrics.mediaCardBuildCount;

        await scrollFolder(tester, delta: 900, passes: 12);

        expect(tester.takeException(), isNull);
        expect(
          FolderPresentationMetrics.mediaCardBuildCount,
          greaterThan(initialBuilds),
        );
        expect(
          FolderPresentationMetrics.mediaCardBuildCount,
          lessThan(fixtureItemCount),
        );
        expect(artwork.cacheEntryCount, lessThanOrEqualTo(500));

        baseline
          ..observe(
            'post_scroll_media_card_builds',
            FolderPresentationMetrics.mediaCardBuildCount,
          )
          ..observe('artwork_cache_peak_scroll', artwork.cacheEntryCount);
      });

      test('R11–R12 artwork LRU bounded beyond 500 identities', () {
        final catalog = buildLargeCatalog(itemCount: 600);
        for (final item in catalog.allItems) {
          artwork.forMediaItem(item);
        }

        expect(artwork.cacheEntryCount, lessThanOrEqualTo(500));
        expect(artwork.cacheEvictionCount, greaterThan(0));

        baseline
          ..observe('artwork_cache_peak_programmatic', artwork.cacheEntryCount)
          ..observe('artwork_eviction_count', artwork.cacheEvictionCount);
      });
    });

    group('R13–R16 sort and filter', () {
      testWidgets('R13–R16 sort and filter prepare once; clear restores view',
          (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
        );
        expect(FolderPresentationMetrics.viewPreparationCount, 1);

        await tester.tap(find.byKey(const Key('folder_sort_menu')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(CheckedPopupMenuItem<LibrarySortMode>),
            matching: find.text('Name A–Z'),
          ),
        );
        await tester.pumpAndSettle();
        expect(FolderPresentationMetrics.viewPreparationCount, 2);

        await tester.tap(find.byKey(const Key('folder_filter_images')));
        await tester.pumpAndSettle();
        expect(FolderPresentationMetrics.viewPreparationCount, 3);

        settings.notifyListeners();
        await tester.pump();
        expect(FolderPresentationMetrics.viewPreparationCount, 3);

        await tester.tap(find.byKey(const Key('folder_filter_all')));
        await tester.pumpAndSettle();
        expect(FolderPresentationMetrics.viewPreparationCount, 4);
        expect(find.text('No items match this filter'), findsNothing);

        baseline.observe(
          'folder_view_preparations_after_sort_filter',
          FolderPresentationMetrics.viewPreparationCount,
        );
      });
    });

    group('R17–R21 navigation and scroll restoration', () {
      testWidgets('R17 detail return preserves folder scroll', (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
        );

        await scrollFolder(tester, delta: 1600, passes: 1);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('media-card-item-15')),
          400,
          scrollable: folderScrollable(),
        );
        await tester.pumpAndSettle();

        final offsetBefore = folderScrollOffset(tester);
        expect(offsetBefore, greaterThan(100));

        await tester.tap(find.byKey(const ValueKey('media-card-item-15')));
        await tester.pumpAndSettle();
        expect(find.byType(ItemDetailScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(folderScrollOffset(tester), closeTo(offsetBefore, 4));
      });

      testWidgets('R18–R19 child folder at top; parent offset on return',
          (tester) async {
        final catalog = buildLargeCatalog(
          itemCount: 20,
          subfolderCount: 1,
          subfolderItemCount: 5,
          folderId: 'parent-folder',
        );
        final path = await _writeCatalogFile(tempDir, catalog, 'nested.json');
        await catalogService.loadFromFile(path);

        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(
            largeCatalogFolder(catalog, folderId: 'parent-folder'),
          ),
        );

        await tester.tap(find.byType(TtsFolderCard));
        await tester.pumpAndSettle();
        expect(folderScrollOffset(tester), 0);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(folderScrollOffset(tester), 0);
      });

      testWidgets('R20 unrelated folders start at independent offsets',
          (tester) async {
        final catalog = buildLargeCatalog(
          itemCount: 30,
          subfolderCount: 1,
          subfolderItemCount: 10,
          folderId: 'folder-a',
        );
        final folderB = catalog.findFolderById('subfolder-0')!;
        final path = await _writeCatalogFile(tempDir, catalog, 'two-folders.json');
        await catalogService.loadFromFile(path);

        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(largeCatalogFolder(catalog, folderId: 'folder-a')),
        );
        await scrollFolder(tester, delta: 1200, passes: 2);
        final offsetA = folderScrollOffset(tester);
        expect(offsetA, greaterThan(0));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(folderB),
        );
        expect(folderScrollOffset(tester), 0);
      });

      testWidgets('R21 catalogue replacement invalidates folder memo',
          (tester) async {
        final catalogA = buildLargeCatalog(
          itemCount: 50,
          catalogueIdentity: 'RUNTIME-A',
        );
        final catalogB = buildLargeCatalog(
          itemCount: 40,
          catalogueIdentity: 'RUNTIME-B',
        );
        final pathA = await _writeCatalogFile(tempDir, catalogA, 'a.json');
        final pathB = await _writeCatalogFile(tempDir, catalogB, 'b.json');

        final clearsAtStart = artwork.clearInvocations;
        await catalogService.loadFromFile(pathA);
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(largeCatalogFolder(catalogA)),
        );
        expect(FolderPresentationMetrics.viewPreparationCount, 1);
        final identityA = catalogService.catalog?.catalogueIdentity;

        await catalogService.loadFromFile(pathB);
        expect(catalogService.catalog?.catalogueIdentity, isNot(identityA));
        expect(artwork.clearInvocations, clearsAtStart + 2);
        expect(search.hasIndex, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        FolderPresentationMetrics.reset();

        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(largeCatalogFolder(catalogB)),
        );
        expect(FolderPresentationMetrics.viewPreparationCount, 1);
        expect(catalogService.catalog?.catalogueIdentity, 'RUNTIME-B');

        baseline
          ..observe('catalogue_identity_before_replace', identityA)
          ..observe('catalogue_identity_after_replace', 'RUNTIME-B');
      });
    });

    group('R22–R24 window resizing', () {
      testWidgets('R22 resize near top remains stable', (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
        );

        await tester.binding.setSurfaceSize(const Size(1024, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TtsMediaCard), findsWidgets);
      });

      testWidgets('R23–R24 resize while scrolled keeps valid offset',
          (tester) async {
        await pumpHarness(
          tester,
          home: FolderScreen.fromFolder(activeFolder()),
          viewport: const Size(900, 420),
        );
        await scrollFolder(tester, delta: 2000, passes: 1);
        final offsetBefore = folderScrollOffset(tester);

        await tester.binding.setSurfaceSize(const Size(1200, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(folderScrollOffset(tester), greaterThan(0));
        expect(folderScrollOffset(tester), closeTo(offsetBefore, 50));
      });
    });

    group('R25–R28 search lifecycle', () {
      testWidgets('R25 open search without query does not build index',
          (tester) async {
        await pumpHarness(
          tester,
          home: const SearchScreen(autofocus: true),
        );

        expect(search.indexBuildCount, 0);
        expect(search.hasIndex, isFalse);
        expect(find.text('Search your library'), findsOneWidget);
      });

      testWidgets('R26–R27 first search builds once; repeat reuses index',
          (tester) async {
        await pumpHarness(
          tester,
          home: const SearchScreen(autofocus: true),
        );

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'Title',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 250));
        expect(search.indexBuildCount, 1);
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          '00010',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 250));
        expect(search.indexBuildCount, 1);

        baseline.observe('search_index_builds_after_queries', search.indexBuildCount);
      });

      testWidgets('R28 stale async results are not shown for newer query',
          (tester) async {
        await pumpHarness(
          tester,
          home: const SearchScreen(autofocus: true),
        );

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'Title',
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'zzzzmissing',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 250));

        expect(find.text('No results found'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('R36 search flatten once per result-list build', (tester) async {
        final catalog = catalogService.catalog!;
        search.buildIndex(catalog);
        final results = search.search('Title', const SearchFilters.empty());
        expect(results.length, greaterThan(1));

        await pumpHarness(
          tester,
          home: SearchResultsList(
            catalog: catalog,
            results: results,
            onOpenResult: (_) {},
            onBrowseFolder: (_) {},
          ),
        );
        expect(SearchPresentationMetrics.flattenInvocationCount, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        SearchPresentationMetrics.reset();

        await pumpHarness(
          tester,
          home: SearchResultsList(
            catalog: catalog,
            results: results,
            onOpenResult: (_) {},
            onBrowseFolder: (_) {},
          ),
        );
        expect(SearchPresentationMetrics.flattenInvocationCount, 1);
        expect(
          SearchPresentationMetrics.flattenInvocationCount,
          lessThan(results.length),
        );
      });
    });

    group('R29–R30 catalogue replacement lifecycle', () {
      test('R29 successful replacement clears artwork and invalidates search',
          () async {
        final catalogA = buildLargeCatalog(
          itemCount: 100,
          catalogueIdentity: 'REPLACE-A',
        );
        final catalogB = buildLargeCatalog(
          itemCount: 80,
          catalogueIdentity: 'REPLACE-B',
        );
        final pathA = await _writeCatalogFile(tempDir, catalogA, 'rep-a.json');
        final pathB = await _writeCatalogFile(tempDir, catalogB, 'rep-b.json');

        final clearsAtStart = artwork.clearInvocations;
        await catalogService.loadFromFile(pathA);
        for (final item in catalogA.allItems.take(20)) {
          artwork.forMediaItem(item);
        }
        await search.searchCatalog(
          catalogA,
          'Title',
          const SearchFilters.empty(),
        );
        expect(search.indexBuildCount, 1);
        expect(artwork.cacheEntryCount, greaterThan(0));

        await catalogService.loadFromFile(pathB);
        expect(artwork.clearInvocations, clearsAtStart + 2);
        expect(artwork.cacheEntryCount, 0);
        expect(search.hasIndex, isFalse);
        expect(search.indexBuildCount, 1);
        expect(catalogService.catalog?.catalogueIdentity, 'REPLACE-B');

        await search.searchCatalog(
          catalogB,
          'Title',
          const SearchFilters.empty(),
        );
        expect(search.indexBuildCount, 2);
        expect(search.catalogueIdentity, 'REPLACE-B');
      });

      test('R30 failed refresh preserves last-good catalogue and caches',
          () async {
        final catalogB = buildLargeCatalog(
          itemCount: 80,
          catalogueIdentity: 'LAST-GOOD-B',
        );
        final pathB = await _writeCatalogFile(tempDir, catalogB, 'last-b.json');
        await catalogService.loadFromFile(pathB);
        await search.searchCatalog(
          catalogB,
          'Title',
          const SearchFilters.empty(),
        );
        for (final item in catalogB.allItems.take(10)) {
          artwork.forMediaItem(item);
        }

        final indexBefore = search.indexBuildCount;
        final cacheBefore = artwork.cacheEntryCount;
        final clearsBefore = artwork.clearInvocations;

        await catalogService.loadFromFile('${tempDir.path}/missing.json');

        expect(catalogService.catalog?.catalogueIdentity, 'LAST-GOOD-B');
        expect(artwork.clearInvocations, clearsBefore);
        expect(search.indexBuildCount, indexBefore);
        expect(artwork.cacheEntryCount, cacheBefore);
      });
    });

    group('R31–R35 stability and recovery', () {
      test('R31–R32 Flutter ImageCache budget configured and preserved', () {
        configureArtworkFlutterImageCache();
        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          kArtworkFlutterImageCacheMaxBytes,
        );

        artwork.forMediaItem(
          buildLargeCatalog(itemCount: 1).allItems.single,
        );
        coordinator.onCatalogReplaced(buildLargeCatalog(itemCount: 2));

        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          kArtworkFlutterImageCacheMaxBytes,
        );
        expect(artwork.cacheEntryCount, 0);
      });

      test('R33 search build failure can be retried', () async {
        final catalog = buildLargeCatalog(itemCount: 50);
        search.simulateBuildFailure = true;

        await expectLater(
          search.searchCatalog(catalog, 'Title', const SearchFilters.empty()),
          throwsA(isA<SearchIndexBuildException>()),
        );
        expect(search.hasIndex, isFalse);

        search.simulateBuildFailure = false;
        final results = await search.searchCatalog(
          catalog,
          'Title',
          const SearchFilters.empty(),
        );
        expect(results, isNotEmpty);
        expect(search.indexBuildCount, 1);
      });

      test('R34 favourites reconciliation failure is failure-safe', () async {
        final failingMetadata = _FailingMetadataRepository();
        await failingMetadata.initialize();
        final localArtwork = _CountingArtworkService(fileExists: (_) => false);
        final localSearch = SearchService();
        final localCoordinator = CatalogCacheCoordinator(
          artworkService: localArtwork,
          searchService: localSearch,
          libraryMetadataRepository: failingMetadata,
        );
        final localCatalogService = CatalogService(
          onCatalogReplaced: localCoordinator.onCatalogReplaced,
        )..includeLegacyCataloguePaths = false;

        final catalog = buildLargeCatalog(itemCount: 10);
        final path = await _writeCatalogFile(tempDir, catalog, 'fav-fail.json');
        await localCatalogService.loadFromFile(path);

        expect(localArtwork.clearInvocations, 1);
        expect(localCatalogService.catalog?.catalogueIdentity, isNotNull);
      });

      test('R35 replacement during in-flight build does not publish stale index',
          () async {
        final catalogA = buildLargeCatalog(
          itemCount: 200,
          catalogueIdentity: 'INFLIGHT-A',
        );
        final catalogB = buildLargeCatalog(
          itemCount: 50,
          catalogueIdentity: 'INFLIGHT-B',
        );

        final buildFuture = search.ensureIndex(catalogA);
        search.onCatalogReplaced(catalogB);
        await buildFuture;

        expect(search.hasIndex, isFalse);
        expect(search.catalogueIdentity, isNull);

        await search.searchCatalog(
          catalogB,
          'Title',
          const SearchFilters.empty(),
        );
        expect(search.catalogueIdentity, 'INFLIGHT-B');
        expect(search.indexBuildCount, 1);
      });
    });

    group('R37–R38 optional local catalogue', () {
      late bool localCatalogAvailable;
      late String? localCatalogSkipReason;
      Catalog? localCatalog;

      setUpAll(() async {
        if (optionalLocalCatalog == null || optionalLocalCatalog.isEmpty) {
          localCatalogAvailable = false;
          localCatalogSkipReason =
              'Optional local catalogue not configured — set PHASE_45_LOCAL_CATALOG';
          return;
        }

        final file = File(optionalLocalCatalog);
        if (!await file.exists()) {
          localCatalogAvailable = false;
          localCatalogSkipReason = 'PHASE_45_LOCAL_CATALOG file not found';
          return;
        }

        try {
          final raw = await file.readAsString();
          localCatalog = Catalog.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          localCatalogAvailable = localCatalog!.totalItems > 0;
          localCatalogSkipReason = localCatalogAvailable
              ? null
              : 'Local catalogue contained no items';
        } catch (e) {
          localCatalogAvailable = false;
          localCatalogSkipReason = 'Failed to parse PHASE_45_LOCAL_CATALOG: $e';
        }
      });

      testWidgets('R37 optional local catalogue loads without exception',
          (tester) async {
        if (!localCatalogAvailable) {
          markTestSkipped(
            localCatalogSkipReason ??
                'Optional local catalogue not configured — set PHASE_45_LOCAL_CATALOG',
          );
          return;
        }
        final catalog = localCatalog!;
        final localService = _InlineCatalogService(catalog);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
              ChangeNotifierProvider<SettingsRepository>.value(value: settings),
              ChangeNotifierProvider(
                create: (_) => LibraryMetadataRepository()..initialize(),
              ),
              Provider(
                create: (context) => MediaLocationResolver(
                  config:
                      context.read<MediaProviderConfigService>().mediaAccess,
                  isWindowsDesktop: true,
                ),
              ),
              Provider<ArtworkService>.value(value: ArtworkService()),
              Provider<SearchService>.value(value: SearchService()),
              ChangeNotifierProvider<CatalogService>.value(value: localService),
              ChangeNotifierProvider(
                create: (context) => PlaybackService(
                  mediaLocationResolver: context.read<MediaLocationResolver>(),
                ),
              ),
              ChangeNotifierProvider(create: (_) => ScannerService()),
              ChangeNotifierProvider(create: (_) => ScanHistoryService()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: FolderScreen.fromFolder(catalog.folders.first),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        baseline
          ..observe('optional_local_catalog', 'loaded')
          ..observe('optional_local_item_count', catalog.totalItems);
      });

      testWidgets('R38 optional local catalogue folder browse bounded cache',
          (tester) async {
        if (!localCatalogAvailable) {
          markTestSkipped(
            localCatalogSkipReason ??
                'Optional local catalogue not configured — set PHASE_45_LOCAL_CATALOG',
          );
          return;
        }
        final catalog = localCatalog!;
        final localArtwork = ArtworkService(
          fileExists: (path) => File(path).existsSync(),
        );
        final localService = _InlineCatalogService(catalog);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
              ChangeNotifierProvider<SettingsRepository>.value(value: settings),
              ChangeNotifierProvider(
                create: (_) => LibraryMetadataRepository()..initialize(),
              ),
              Provider(
                create: (context) => MediaLocationResolver(
                  config:
                      context.read<MediaProviderConfigService>().mediaAccess,
                  isWindowsDesktop: true,
                ),
              ),
              Provider<ArtworkService>.value(value: localArtwork),
              Provider<SearchService>.value(value: SearchService()),
              ChangeNotifierProvider<CatalogService>.value(value: localService),
              ChangeNotifierProvider(
                create: (context) => PlaybackService(
                  mediaLocationResolver: context.read<MediaLocationResolver>(),
                ),
              ),
              ChangeNotifierProvider(create: (_) => ScannerService()),
              ChangeNotifierProvider(create: (_) => ScanHistoryService()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: FolderScreen.fromFolder(catalog.folders.first),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 6; i++) {
          await tester.drag(
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            ),
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
        expect(localArtwork.cacheEntryCount, lessThanOrEqualTo(500));
      });
    });
  });
}

Future<String> _writeCatalogFile(
  Directory dir,
  Catalog catalog,
  String filename,
) async {
  final file = File('${dir.path}/$filename');
  await file.writeAsString(jsonEncode(largeCatalogToJson(catalog)));
  return file.path;
}
