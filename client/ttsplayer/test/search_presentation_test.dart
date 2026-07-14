import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_result_grouper.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_empty_state.dart';
import 'package:ttsplayer/features/search/widgets/search_result_row.dart';
import 'package:ttsplayer/library/folder_display_context.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
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
import 'package:ttsplayer/widgets/empty_state.dart';
import 'package:ttsplayer/widgets/folder_breadcrumb.dart';

MediaFolder _folder({
  required String id,
  required String name,
  String? path,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return MediaFolder(
    id: id,
    name: name,
    path: path ?? r'Y:\Media\' + name,
    itemCount: items.length,
    items: items,
    subfolders: subfolders,
  );
}

MediaItem _item({
  required String id,
  required String title,
  String? filePath,
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath ?? r'Y:\Media\' + title + '.mp4',
  );
}

Catalog _searchCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 4,
    'folders': [
      _folder(
        id: 'lib-videos',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        subfolders: [
          _folder(
            id: 'videos-action',
            name: 'Action',
            path: r'Y:\Media\Videos\Action',
            items: [
              _item(
                id: 'item-adventure',
                title: 'Grand Adventure',
                filePath: r'Y:\Media\Videos\Action\adventure.mp4',
              ),
            ],
          ),
        ],
        items: [
          _item(
            id: 'item-root',
            title: 'Root Clip',
            filePath: r'Y:\Media\Videos\root.mp4',
          ),
        ],
      ).toJson(),
      _folder(
        id: 'lib-archive',
        name: 'Archive',
        path: r'Y:\Media\Archive',
        subfolders: [
          _folder(
            id: 'archive-action',
            name: 'Action',
            path: r'Y:\Media\Archive\Action',
            items: [
              _item(
                id: 'item-backup',
                title: 'Backup Take',
                filePath: r'Y:\Media\Archive\Action\backup.mp4',
              ),
            ],
          ),
        ],
      ).toJson(),
      _folder(
        id: 'lib-remote',
        name: 'Remote Films',
        path: 'https://nas.example/media/Films',
        items: [
          _item(
            id: 'item-remote',
            title: 'HTTPS Sample',
            filePath: 'https://nas.example/media/Films/sample.mp4',
          ),
        ],
      ).toJson(),
    ],
  });
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  void setCatalog(Catalog? catalog) {
    _catalog = catalog;
    notifyListeners();
  }

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  Future<ScannerConfigSummary?> readScannerConfig() async => null;

  @override
  String? get catalogPath => 'bundled';

  @override
  Future<void> rescan() async {}
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

Widget _searchHarness({
  required Catalog catalog,
  CatalogService? catalogService,
  SettingsRepository? settingsRepository,
  Size viewport = const Size(900, 420),
  Key? screenKey,
}) {
  final service = catalogService ?? _FakeCatalogService(catalog);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider<SettingsRepository>(
        create: (_) => settingsRepository ?? (SettingsRepository()..initialize()),
      ),
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
      ChangeNotifierProvider<CatalogService>.value(value: service),
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
          child: SearchScreen(key: screenKey, autofocus: true),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('groupSearchResultsByLibrary', () {
    test('groups by library preserving score order within groups', () {
      final service = SearchService();
      final catalog = _searchCatalog();
      service.buildIndex(catalog);
      final results = service.search('action', const SearchFilters.empty());

      final groups = groupSearchResultsByLibrary(results);
      expect(groups.length, greaterThanOrEqualTo(1));
      expect(
        groups.expand((g) => g.results).map((r) => r.item.id).toList(),
        results.map((r) => r.item.id).toList(),
      );
    });
  });

  group('catalogueFolderContext', () {
    test('uses catalogue hierarchy not raw paths', () {
      final catalog = _searchCatalog();
      expect(
        catalogueFolderContext(catalog, 'item-adventure'),
        'Videos · Action',
      );
      expect(
        catalogueFolderContext(catalog, 'item-backup'),
        'Archive · Action',
      );
      expect(
        catalogueFolderContext(catalog, 'item-remote'),
        'Remote Films',
      );
      expect(catalogueFolderContext(catalog, 'item-adventure'), isNot(contains('Y:')));
      expect(
        catalogueFolderContext(catalog, 'item-remote'),
        isNot(contains('https://')),
      );
    });
  });

  group('SearchScreen presentation', () {
    testWidgets('1 empty search query shows prompt state', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      expect(find.text('Search your library'), findsOneWidget);
      expect(find.byType(SearchEmptyState), findsOneWidget);
    });

    testWidgets('2 query with no matches shows no-results state', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'zzzzmissing');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('No results found'), findsOneWidget);
      expect(find.textContaining('adjust the filters'), findsOneWidget);
    });

    testWidgets('3 clear-query action returns to empty-query state', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Grand Adventure'), findsOneWidget);

      await tester.tap(find.byKey(const Key('search_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Search your library'), findsOneWidget);
      expect(find.text('Grand Adventure'), findsNothing);
    });

    testWidgets('4 search result count updates correctly', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'action');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.textContaining('result'), findsOneWidget);
    });

    testWidgets('5 and 6 media results are identified with Media label',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('Media'), findsWidgets);
      expect(find.byKey(const Key('search_result_item-adventure')), findsOneWidget);
    });

    testWidgets('7 result shows library or containing-folder context',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'backup');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('Archive · Action'), findsOneWidget);
    });

    testWidgets('8 folder browse opens catalogue-driven navigation',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('search_browse_folder_item-adventure')));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
    });

    testWidgets('9 folder browse produces correct breadcrumbs', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('search_browse_folder_item-adventure')));
      await tester.pumpAndSettle();

      expect(find.byType(FolderBreadcrumb), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Action'), findsWidgets);
    });

    testWidgets('10 media result opens item detail', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('search_open_item-adventure')));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsOneWidget);
    });

    testWidgets('11 long result titles do not overflow', (tester) async {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: 'lib',
            name: 'Videos',
            items: [
              _item(
                id: 'long-item',
                title: 'A' * 120,
                filePath: r'Y:\Media\Videos\long.mp4',
              ),
            ],
          ).toJson(),
        ],
      });

      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'AAAA');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(SearchResultRow), findsOneWidget);
    });

    testWidgets('12 raw paths are not shown as user-facing context',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'https');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.textContaining('https://'), findsNothing);
      expect(find.textContaining(r'Y:\Media'), findsNothing);
      expect(find.text('Remote Films'), findsWidgets);
    });

    testWidgets('13 duplicate folder names distinguished by hierarchy context',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'backup');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Archive · Action'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Videos · Action'), findsOneWidget);
    });

    testWidgets('14 search filters continue to work', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'sample');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('HTTPS Sample'), findsOneWidget);

      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('HTTPS Sample'), findsNothing);
    });

    test('15 query clearing does not alter persisted library default sort',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultLibrarySortMode(LibrarySortMode.nameAsc);

      await settings.saveDefaultLibrarySortMode(LibrarySortMode.nameAsc);
      expect(settings.defaultLibrarySortMode, LibrarySortMode.nameAsc);
    });

    testWidgets('16 search does not persist temporary state across reopen',
        (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog, screenKey: const ValueKey('a')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester.pumpWidget(_searchHarness(catalog: catalog, screenKey: const ValueKey('b')));
      await tester.pumpAndSettle();

      expect(find.text('Search your library'), findsOneWidget);
    });

    testWidgets('17 stale result is handled safely', (tester) async {
      final catalog = _searchCatalog();
      final service = _FakeCatalogService(catalog);

      await tester.pumpWidget(
        _searchHarness(catalog: catalog, catalogService: service),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Grand Adventure'), findsOneWidget);

      final reduced = Catalog.fromJson({
        'generated_at': '2026-07-13T11:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: 'lib-videos',
            name: 'Videos',
            path: r'Y:\Media\Videos',
            items: [
              _item(
                id: 'item-root',
                title: 'Root Clip',
                filePath: r'Y:\Media\Videos\root.mp4',
              ),
            ],
          ).toJson(),
        ],
      });
      service.setCatalog(reduced);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_open_item-adventure')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no longer in the catalogue'),
        findsOneWidget,
      );
    });

    testWidgets('18 keyboard Enter activates search', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('Grand Adventure'), findsOneWidget);
    });

    testWidgets('19 keyboard activation opens a result', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(_searchHarness(catalog: catalog));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'adventure');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('search_open_item-adventure')));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsOneWidget);
    });

    testWidgets('20 results remain scrollable at 900x420', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(
        _searchHarness(catalog: catalog, viewport: const Size(900, 420)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_query_field')), 'mp4');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('24 catalogue unavailable is distinct from no-results',
        (tester) async {
      final service = _FakeCatalogService(null);
      await tester.pumpWidget(
        _searchHarness(
          catalog: _searchCatalog(),
          catalogService: service,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catalogue unavailable'), findsOneWidget);
      expect(find.text('No results found'), findsNothing);
      expect(find.textContaining('Provider Status'), findsOneWidget);
    });

    test('27 catalogue remains immutable after search presentation helpers',
        () {
      final catalog = _searchCatalog();
      final before = jsonEncode(catalog.folders.map((f) => f.toJson()).toList());

      catalogueFolderContext(catalog, 'item-adventure');
      final service = SearchService();
      service.buildIndex(catalog);
      groupSearchResultsByLibrary(service.search('action', const SearchFilters.empty()));

      expect(jsonEncode(catalog.folders.map((f) => f.toJson()).toList()), before);
    });
  });

  group('Library state copy alignment', () {
    testWidgets('21 empty folder copy remains distinct from filter-empty',
        (tester) async {
      final emptyCatalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 0,
        'folders': [
          _folder(id: 'empty', name: 'Empty').toJson(),
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsRepository()..initialize()),
            ChangeNotifierProvider(create: (_) => LibraryMetadataRepository()..initialize()),
            ChangeNotifierProvider(create: (_) => ScannerService()),
            ChangeNotifierProvider<CatalogService>.value(
              value: _FakeCatalogService(emptyCatalog),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: FolderScreen.fromFolder(emptyCatalog.folders.single),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This folder is empty.'), findsOneWidget);
      expect(find.text('No items match this filter'), findsNothing);
    });

    testWidgets('22 favourites empty state remains correct', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: EmptyState(
              icon: Icons.star_border,
              title: 'No favourites yet',
              subtitle:
                  'Add folders or media to favourites to find them quickly here.',
            ),
          ),
        ),
      );

      expect(find.text('No favourites yet'), findsOneWidget);
    });

    testWidgets('23 missing-folder state remains correct', (tester) async {
      final catalog = _searchCatalog();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsRepository()..initialize()),
            ChangeNotifierProvider(create: (_) => LibraryMetadataRepository()..initialize()),
            ChangeNotifierProvider(create: (_) => ScannerService()),
            ChangeNotifierProvider<CatalogService>.value(
              value: _FakeCatalogService(catalog),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const FolderScreen(
              folderPath: r'Y:\Media\Missing',
              folderName: 'Missing',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no longer in the catalogue'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
    });
  });
}
