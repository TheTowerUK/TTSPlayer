import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_presentation_metrics.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_results_list.dart';
import 'package:ttsplayer/library/folder_presentation_metrics.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
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

import 'support/large_catalog_factory.dart';

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

Future<String> _writeCatalogFile(
  Directory dir,
  Catalog catalog,
  String filename,
) async {
  final file = File('${dir.path}/$filename');
  await file.writeAsString(jsonEncode(largeCatalogToJson(catalog)));
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FolderPresentationMetrics.reset();
    SearchPresentationMetrics.reset();
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_perf_int_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('performance integration lifecycle', () {
    Future<({
      CatalogService catalogService,
      _CountingArtworkService artwork,
      SearchService search,
      LibraryMetadataRepository metadata,
      CatalogCacheCoordinator coordinator,
    })> wireServices({LibraryMetadataRepository? metadata}) async {
      final artwork = _CountingArtworkService(fileExists: (_) => false);
      final search = SearchService();
      final repo = metadata ?? LibraryMetadataRepository();
      await repo.initialize();

      final coordinator = CatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: repo,
      );

      final catalogService = CatalogService(
        onCatalogReplaced: coordinator.onCatalogReplaced,
      )..includeLegacyCataloguePaths = false;

      return (
        catalogService: catalogService,
        artwork: artwork,
        search: search,
        metadata: repo,
        coordinator: coordinator,
      );
    }

    test('end-to-end browse artwork search replace and failed refresh', () async {
      final wired = await wireServices();
      final catalogA = buildLargeCatalog(
        itemCount: mediumCatalogItemCount,
        catalogueIdentity: 'PERF-A',
      );
      final catalogB = buildLargeCatalog(
        itemCount: smallCatalogItemCount,
        catalogueIdentity: 'PERF-B',
        folderId: 'large-folder',
      );
      final pathA = await _writeCatalogFile(tempDir, catalogA, 'a.json');
      final pathB = await _writeCatalogFile(tempDir, catalogB, 'b.json');

      await wired.catalogService.loadFromFile(pathA);
      expect(wired.artwork.clearInvocations, 1);
      expect(wired.search.indexBuildCount, 0);

      final folder = largeCatalogFolder(wired.catalogService.catalog!);
      var viewPrep = 0;
      LibraryFolderView buildOnce() {
        viewPrep++;
        return buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.defaultOrder,
          filter: LibraryFilter.all,
          catalogSupportedExtensions: wired.catalogService.catalog!.supportedExtensions,
        );
      }

      final view = buildOnce();
      expect(view.items.length, mediumCatalogItemCount);

      for (final item in view.items.take(600)) {
        wired.artwork.forMediaItem(item);
      }
      expect(wired.artwork.cacheEntryCount, lessThanOrEqualTo(500));
      expect(wired.artwork.cacheEvictionCount, greaterThan(0));

      final firstSearch = await wired.search.searchCatalog(
        wired.catalogService.catalog!,
        'Title',
        const SearchFilters.empty(),
      );
      expect(wired.search.indexBuildCount, 1);
      expect(firstSearch, isNotEmpty);

      await wired.search.searchCatalog(
        wired.catalogService.catalog!,
        '00010',
        const SearchFilters.empty(),
      );
      expect(wired.search.indexBuildCount, 1);

      await wired.catalogService.loadFromFile(pathB);
      expect(wired.artwork.clearInvocations, 2);
      expect(wired.search.hasIndex, isFalse);
      expect(wired.search.indexBuildCount, 1);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'PERF-B');

      await wired.search.searchCatalog(
        wired.catalogService.catalog!,
        'Title',
        const SearchFilters.empty(),
      );
      expect(wired.search.indexBuildCount, 2);
      expect(wired.search.catalogueIdentity, 'PERF-B');

      final indexBeforeFail = wired.search.indexBuildCount;
      wired.artwork.forMediaItem(
        wired.catalogService.catalog!.allItems.first,
      );
      final cacheBeforeFail = wired.artwork.cacheEntryCount;
      expect(cacheBeforeFail, greaterThan(0));

      await wired.catalogService.loadFromFile('${tempDir.path}/missing.json');
      expect(wired.artwork.clearInvocations, 2);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'PERF-B');
      expect(wired.search.indexBuildCount, indexBeforeFail);
      expect(wired.artwork.cacheEntryCount, cacheBeforeFail);

      expect(viewPrep, 1);
    });

    test('coordinator callbacks occur once per successful replacement only', () async {
      final wired = await wireServices();
      final pathA = await _writeCatalogFile(
        tempDir,
        buildLargeCatalog(catalogueIdentity: 'ONCE-A', itemCount: 10),
        'once-a.json',
      );
      final pathB = await _writeCatalogFile(
        tempDir,
        buildLargeCatalog(catalogueIdentity: 'ONCE-B', itemCount: 5),
        'once-b.json',
      );

      await wired.catalogService.loadFromFile(pathA);
      wired.search.buildIndex(wired.catalogService.catalog!);
      wired.artwork.forMediaItem(wired.catalogService.catalog!.allItems.first);

      await wired.catalogService.loadFromFile(pathB);
      expect(wired.artwork.clearInvocations, 2);
      expect(wired.search.hasIndex, isFalse);

      await wired.catalogService.loadFromFile('${tempDir.path}/missing.json');
      expect(wired.artwork.clearInvocations, 2);
    });

    test('favourites reconciliation failure does not corrupt catalogue', () async {
      final metadata = _FailingMetadataRepository();
      await metadata.initialize();
      final wired = await wireServices(metadata: metadata);

      final path = await _writeCatalogFile(
        tempDir,
        buildLargeCatalog(catalogueIdentity: 'FAV-FAIL', itemCount: 3),
        'fav.json',
      );

      await wired.catalogService.loadFromFile(path);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'FAV-FAIL');
      expect(wired.artwork.clearInvocations, 1);
    });
  });

  group('search presentation integration', () {
    testWidgets('flatten runs once per list build not per row', (tester) async {
      final catalog = buildLargeCatalog(itemCount: smallCatalogItemCount);
      final search = SearchService()..buildIndex(catalog);
      final results = search.search('Title', const SearchFilters.empty());
      expect(results.length, greaterThan(1));

      Widget harness(Widget child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
            Provider(
              create: (context) => MediaLocationResolver(
                config: context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: true,
              ),
            ),
            Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(900, 420)),
              child: child,
            ),
          ),
        );
      }

      await tester.pumpWidget(
        harness(
          SearchResultsList(
            catalog: catalog,
            results: results,
            onOpenResult: (_) {},
            onBrowseFolder: (_) {},
          ),
        ),
      );
      expect(SearchPresentationMetrics.flattenInvocationCount, 1);

      await tester.pumpWidget(
        harness(
          SearchResultsList(
            catalog: catalog,
            results: results,
            onOpenResult: (_) {},
            onBrowseFolder: (_) {},
          ),
        ),
      );
      expect(SearchPresentationMetrics.flattenInvocationCount, 2);
      expect(SearchPresentationMetrics.flattenInvocationCount, lessThan(results.length));
    });
  });

  group('folder presentation integration', () {
    testWidgets('large folder lazy metrics stay below catalogue size', (tester) async {
      final catalog = buildLargeCatalog(itemCount: mediumCatalogItemCount);
      final folder = largeCatalogFolder(catalog);
      final settings = SettingsRepository();
      await settings.initialize();

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
                config: context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: true,
              ),
            ),
            Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
            Provider(create: (_) => SearchService()),
            ChangeNotifierProvider<CatalogService>.value(
              value: _InlineCatalogService(catalog),
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
                data: const MediaQueryData(size: Size(900, 420)),
                child: FolderScreen.fromFolder(folder),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(FolderPresentationMetrics.viewPreparationCount, 1);
      expect(FolderPresentationMetrics.mediaCardBuildCount, greaterThan(0));
      expect(
        FolderPresentationMetrics.mediaCardBuildCount,
        lessThan(mediumCatalogItemCount),
      );
    });
  });

  group('failure-path integration', () {
    test('search build failure then successful retry', () async {
      final search = SearchService()..simulateBuildFailure = true;
      final catalog = buildLargeCatalog(itemCount: 50);

      await expectLater(
        search.searchCatalog(catalog, 'Title', const SearchFilters.empty()),
        throwsA(isA<SearchIndexBuildException>()),
      );
      expect(search.isBuildInFlight, isFalse);

      search.simulateBuildFailure = false;
      final results = await search.searchCatalog(
        catalog,
        'Title',
        const SearchFilters.empty(),
      );
      expect(results, isNotEmpty);
      expect(search.indexBuildCount, 1);
    });

    test('replacement during in-flight build does not publish stale index', () async {
      final search = SearchService();
      final oldCatalog = buildLargeCatalog(
        itemCount: 20,
        catalogueIdentity: 'STALE',
      );
      final newCatalog = buildLargeCatalog(
        itemCount: 5,
        catalogueIdentity: 'FRESH',
      );

      final buildFuture = search.ensureIndex(oldCatalog);
      search.onCatalogReplaced(newCatalog);
      await buildFuture;

      expect(search.hasIndex, isFalse);
      await search.searchCatalog(newCatalog, 'Title', const SearchFilters.empty());
      expect(search.catalogueIdentity, 'FRESH');
    });
  });
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
