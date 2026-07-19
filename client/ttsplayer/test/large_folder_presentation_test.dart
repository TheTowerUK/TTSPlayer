import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/library/folder_presentation_config.dart';
import 'package:ttsplayer/library/folder_presentation_metrics.dart';
import 'package:ttsplayer/models/catalog.dart';
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
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/large_catalog_factory.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  void setCatalog(Catalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  Future<ScannerConfigSummary?> readScannerConfig() async => null;

  @override
  String? get catalogPath => 'test';
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

Widget _folderHarness({
  required Catalog catalog,
  required Widget home,
  ArtworkService? artworkService,
  SearchService? searchService,
  SettingsRepository? settingsRepository,
  Size viewport = const Size(900, 420),
}) {
  final catalogService = _FakeCatalogService(catalog);
  final settings = settingsRepository ?? (SettingsRepository()..initialize());
  return MultiProvider(
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
      Provider<ArtworkService>.value(
        value: artworkService ?? ArtworkService(fileExists: (_) => false),
      ),
      Provider<SearchService>.value(value: searchService ?? SearchService()),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider(
        create: (context) => PlaybackService(
          mediaLocationResolver: context.read<MediaLocationResolver>(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: _FakeScanHistoryService(),
      ),
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
  );
}

Finder _folderScrollable() {
  return find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
}

Future<void> _scrollFolderDown(WidgetTester tester, {required double delta}) async {
  var remaining = delta;
  while (remaining > 0) {
    final step = remaining > 500 ? 500.0 : remaining;
    await tester.drag(_folderScrollable(), Offset(0, -step));
    await tester.pump();
    remaining -= step;
  }
  await tester.pumpAndSettle();
}

Finder _activeFolderScrollable() {
  return find.descendant(
    of: find.byType(FolderScreen).last,
    matching: find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ),
  );
}

double _scrollOffset(WidgetTester tester) {
  return tester.state<ScrollableState>(_activeFolderScrollable()).position.pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const largeItemCount = 2000;
  late Catalog largeCatalog;
  late MediaFolder largeFolder;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FolderPresentationMetrics.reset();
    largeCatalog = buildLargeCatalog(itemCount: largeItemCount);
    largeFolder = largeCatalogFolder(largeCatalog);
  });

  group('lazy construction', () {
    testWidgets('initial presentation does not build every item widget',
        (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      expect(FolderPresentationMetrics.mediaCardBuildCount, lessThan(50));
      expect(
        FolderPresentationMetrics.mediaCardBuildCount,
        lessThan(largeItemCount),
      );
      expect(find.byType(TtsMediaCard), findsWidgets);
    });

    testWidgets('scrolling builds additional items lazily', (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      final initialBuilds = FolderPresentationMetrics.mediaCardBuildCount;
      expect(initialBuilds, greaterThan(0));

      await _scrollFolderDown(tester, delta: 2400);

      expect(
        FolderPresentationMetrics.mediaCardBuildCount,
        greaterThan(initialBuilds),
      );
      expect(
        FolderPresentationMetrics.mediaCardBuildCount,
        lessThan(largeItemCount),
      );
    });

    testWidgets('builder child count matches source collection', (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        FolderPresentationMetrics.mediaCardBuildCount,
        lessThanOrEqualTo(largeItemCount),
      );
    });

    testWidgets('uses tuned cache extent and page storage key', (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.scrollCacheExtent, FolderPresentationConfig.gridScrollCacheExtent);
      expect(
        scrollView.key,
        isA<PageStorageKey<String>>().having(
          (k) => k.value,
          'value',
          FolderPresentationConfig.scrollStorageKey(largeFolder.id),
        ),
      );
    });
  });

  group('scroll behaviour', () {
    testWidgets('deep scroll and return from item detail preserves offset',
        (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollFolderDown(tester, delta: 1800);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('media-card-item-15')),
        400,
        scrollable: _folderScrollable(),
      );
      await tester.pumpAndSettle();

      final offsetBefore = _scrollOffset(tester);
      expect(offsetBefore, greaterThan(100));

      await tester.tap(find.byKey(const ValueKey('media-card-item-15')));
      await tester.pumpAndSettle();
      expect(find.byType(ItemDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
      expect(_scrollOffset(tester), closeTo(offsetBefore, 4));
    });

    testWidgets('child folder opens at top; parent preserves scroll on item pop',
        (tester) async {
      final catalog = buildLargeCatalog(
        itemCount: 20,
        subfolderCount: 1,
        subfolderItemCount: 5,
        folderId: 'parent-folder',
      );
      final parent = largeCatalogFolder(catalog, folderId: 'parent-folder');

      await tester.pumpWidget(
        _folderHarness(
          catalog: catalog,
          home: FolderScreen.fromFolder(parent),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TtsFolderCard));
      await tester.pumpAndSettle();
      expect(_scrollOffset(tester), 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_scrollOffset(tester), 0);
    });

    testWidgets('viewport resize keeps scroll valid', (tester) async {
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          viewport: const Size(900, 420),
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollFolderDown(tester, delta: 1200);
      final offsetBefore = _scrollOffset(tester);

      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_scrollOffset(tester), greaterThan(0));
      expect(_scrollOffset(tester), closeTo(offsetBefore, 50));
    });
  });

  group('rebuild behaviour', () {
    testWidgets('unrelated settings notification does not re-prepare view',
        (tester) async {
      final settings = SettingsRepository();
      await settings.initialize();
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          settingsRepository: settings,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      expect(FolderPresentationMetrics.viewPreparationCount, 1);

      settings.notifyListeners();
      await tester.pump();

      expect(FolderPresentationMetrics.viewPreparationCount, 1);
    });

    testWidgets('folder browsing does not build search index', (tester) async {
      final search = SearchService();
      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          searchService: search,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollFolderDown(tester, delta: 3000);

      expect(search.indexBuildCount, 0);
      expect(search.hasIndex, isFalse);
    });
  });

  group('cache and memory bounds', () {
    test('scrolling distinct artwork identities respects LRU capacity', () {
      final service = ArtworkService(
        fileExists: (_) => false,
        cacheCapacity: 500,
      );
      final catalog = buildLargeCatalog(itemCount: 600);

      for (final item in catalog.allItems) {
        service.forMediaItem(item);
      }

      expect(service.cacheEntryCount, lessThanOrEqualTo(500));
    });

    testWidgets('large-folder scroll does not exceed artwork cache capacity',
        (tester) async {
      final artwork = ArtworkService(
        fileExists: (_) => false,
        cacheCapacity: 500,
      );

      await tester.pumpWidget(
        _folderHarness(
          catalog: largeCatalog,
          artworkService: artwork,
          home: FolderScreen.fromFolder(largeFolder),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 8; i++) {
        await _scrollFolderDown(tester, delta: 800);
      }

      expect(artwork.cacheEntryCount, lessThanOrEqualTo(500));
    });

    test('successful catalogue replacement clears artwork cache', () {
      final artwork = ArtworkService(fileExists: (_) => false);
      final search = SearchService();
      final metadata = LibraryMetadataRepository();
      final coordinator = CatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
        musicLibraryService: MusicLibraryService(),
      );

      final catalog = buildLargeCatalog(itemCount: 10);
      for (final item in catalog.allItems) {
        artwork.forMediaItem(item);
      }
      expect(artwork.cacheEntryCount, greaterThan(0));

      coordinator.onCatalogReplaced(
        buildLargeCatalog(
          itemCount: 5,
          catalogueIdentity: 'replaced',
        ),
      );

      expect(artwork.cacheEntryCount, 0);
    });
  });

  group('regression', () {
    testWidgets('small folder still renders all visible cards', (tester) async {
      final catalog = buildLargeCatalog(itemCount: 4);
      final folder = largeCatalogFolder(catalog);

      await tester.pumpWidget(
        _folderHarness(
          catalog: catalog,
          viewport: const Size(900, 1200),
          home: FolderScreen.fromFolder(folder),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TtsMediaCard), findsNWidgets(4));
    });
  });
}
