import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/widgets/libraries_section.dart';
import 'package:ttsplayer/features/favourites/favourites_screen.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_metadata.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/app_navigator.dart';
import 'package:ttsplayer/navigation/folder_navigation.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
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
import 'package:ttsplayer/widgets/folder_breadcrumb.dart';

MediaFolder _folder({
  required String id,
  required String name,
  String? path,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  final resolvedPath = path ?? r'Y:\Media\' + name;
  return MediaFolder(
    id: id,
    name: name,
    path: resolvedPath,
    itemCount: items.length,
    items: items,
    subfolders: subfolders,
  );
}

MediaItem _item({
  required String id,
  required String title,
  String filePath = r'Y:\Media\sample.mp4',
}) {
  return MediaItem(id: id, title: title, filePath: filePath);
}

Catalog _nestedCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 1,
    'folders': [
      _folder(
        id: 'folder-root',
        name: 'Films',
        path: r'Y:\Media\Films',
        subfolders: [
          _folder(
            id: 'folder-child',
            name: 'Science Fiction',
            path: r'Y:\Media\Films\Science Fiction',
            items: [
              _item(
                id: 'item-nested',
                title: 'Arrival',
                filePath: r'Y:\Media\Films\Science Fiction\Arrival.mp4',
              ),
            ],
          ),
        ],
      ).toJson(),
    ],
  });
}

Catalog _duplicateNameCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 0,
    'folders': [
      _folder(
        id: 'lib-a',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        subfolders: [
          _folder(
            id: 'action-a',
            name: 'Action',
            path: r'Y:\Media\Videos\Action',
          ),
        ],
      ).toJson(),
      _folder(
        id: 'lib-b',
        name: 'Archive',
        path: r'Y:\Media\Archive',
        subfolders: [
          _folder(
            id: 'action-b',
            name: 'Action',
            path: r'Y:\Media\Archive\Action',
          ),
        ],
      ).toJson(),
    ],
  });
}

Catalog _deepCatalog() {
  MediaFolder leaf = _folder(
    id: 'folder-l5',
    name: 'Leaf',
    path: r'Y:\Media\L1\L2\L3\L4\L5',
  );
  for (var level = 4; level >= 1; level--) {
    leaf = _folder(
      id: 'folder-l$level',
      name: 'Level $level',
      path: r'Y:\Media\' + List.generate(level, (i) => 'L${i + 1}').join(r'\'),
      subfolders: [leaf],
    );
  }
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 0,
    'folders': [leaf.toJson()],
  });
}

Catalog _httpStyleCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 1,
    'folders': [
      _folder(
        id: 'http-root',
        name: 'Remote Films',
        path: 'https://nas.example/media/Films',
        subfolders: [
          _folder(
            id: 'http-child',
            name: 'Drama',
            path: 'https://nas.example/media/Films/Drama',
            items: [
              _item(
                id: 'http-item',
                title: 'Sample',
                filePath:
                    'https://nas.example/media/Films/Drama/sample.mp4',
              ),
            ],
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
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

Future<LibraryMetadataRepository> _seededRepository({
  List<FavouriteRecord> folders = const [],
}) async {
  final metadata = LibraryMetadata(
    metadataVersion: 1,
    favourites: FavouritesMetadata(
      items: const [],
      folders: folders,
    ),
  );
  SharedPreferences.setMockInitialValues({
    LibraryMetadataRepository.storageKey:
        jsonEncode(metadata.toPersistenceJson()),
  });
  final repository = LibraryMetadataRepository();
  await repository.initialize();
  return repository;
}

late LibraryMetadataRepository _defaultRepository;

Widget _harness({
  required Catalog catalog,
  required Widget home,
  LibraryMetadataRepository? metadataRepository,
  Size viewport = const Size(1100, 800),
}) {
  final catalogService = _FakeCatalogService(catalog);
  final metadata = metadataRepository ?? _defaultRepository;

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider<SettingsRepository>(
        create: (_) => SettingsRepository(),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: metadata),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: true,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
      Provider(create: (_) => SearchService()),
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
      navigatorKey: rootNavigatorKey,
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQueryData(size: viewport),
            child: home,
          );
        },
      ),
    ),
  );
}

Future<void> _openFolder(
  WidgetTester tester, {
  required Catalog catalog,
  required MediaFolder folder,
}) async {
  await tester.pumpWidget(
    _harness(
      catalog: catalog,
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final context = tester.element(find.text('Open'));
  openFolderScreen(context, folder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LibraryMetadataRepository defaultRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    defaultRepository = LibraryMetadataRepository();
    await defaultRepository.initialize();
    _defaultRepository = defaultRepository;
  });

  group('FolderBreadcrumb widget', () {
    testWidgets('1 root folder breadcrumb contains one segment', (tester) async {
      final catalog = _nestedCatalog();
      final root = catalog.folders.single;

      await _openFolder(tester, catalog: catalog, folder: root);

      expect(find.byType(FolderBreadcrumb), findsOneWidget);
      expect(find.text('Films'), findsWidgets);
      expect(find.byKey(const Key('breadcrumb_segment_folder-root')), findsNothing);
    });

    testWidgets('2 nested folder breadcrumb is root-to-target', (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Science Fiction'), findsWidgets);
    });

    testWidgets('3 current folder appears exactly once in breadcrumb chain',
        (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      final breadcrumb = tester.widget<FolderBreadcrumb>(
        find.byType(FolderBreadcrumb),
      );
      expect(
        breadcrumb.ancestors.where((f) => f.id == 'folder-child').length,
        1,
      );
    });

    testWidgets('4 intermediate ancestor is clickable', (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      expect(
        find.byKey(const Key('breadcrumb_segment_folder-root')),
        findsOneWidget,
      );
    });

    testWidgets('5 clicking ancestor opens correct folder', (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      await tester.tap(find.byKey(const Key('breadcrumb_segment_folder-root')));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.text('Films'), findsWidgets);
      expect(
        find.byKey(const Key('breadcrumb_segment_folder-child')),
        findsNothing,
      );
    });

    testWidgets('6 clicking current segment does not push another route',
        (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      expect(find.byType(FolderScreen), findsOneWidget);
      await tester.tap(find.text('Science Fiction').first);
      await tester.pumpAndSettle();
      expect(find.byType(FolderScreen), findsOneWidget);
    });
  });

  group('Entry-point breadcrumb alignment', () {
    testWidgets('7 dashboard library navigation produces correct breadcrumbs',
        (tester) async {
      final catalog = _nestedCatalog();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: Scaffold(
            body: LibrariesSection(libraries: catalog.libraryFolders),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderBreadcrumb), findsOneWidget);
      expect(find.text('Films'), findsWidgets);
      expect(find.textContaining(r'Y:\Media'), findsNothing);
    });

    testWidgets('8 favourites folder navigation produces correct breadcrumbs',
        (tester) async {
      final catalog = _nestedCatalog();
      final repository = await _seededRepository(
        folders: [
          FavouriteRecord(
            id: 'folder-child',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Science Fiction'));
      await tester.pumpAndSettle();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Science Fiction'), findsWidgets);
    });

    testWidgets('9 search folder navigation produces correct breadcrumbs',
        (tester) async {
      final catalog = _nestedCatalog();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: const SearchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Arrival');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Browse folder'));
      await tester.pumpAndSettle();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Science Fiction'), findsWidgets);
    });

    testWidgets('10 folder-card navigation preserves expected chain',
        (tester) async {
      final catalog = _nestedCatalog();
      final root = catalog.folders.single;

      await _openFolder(tester, catalog: catalog, folder: root);
      await tester.tap(find.text('Science Fiction'));
      await tester.pumpAndSettle();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Science Fiction'), findsWidgets);
    });
  });

  group('Navigation and missing-folder handling', () {
    testWidgets('11 back returns to the previous route', (tester) async {
      final catalog = _nestedCatalog();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: Scaffold(
            body: LibrariesSection(libraries: catalog.libraryFolders),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();
      expect(find.byType(FolderScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsNothing);
      expect(find.byType(LibrariesSection), findsOneWidget);
    });

    testWidgets('12 unknown folder shows unavailable state', (tester) async {
      final catalog = _nestedCatalog();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: const FolderScreen(
            folderPath: r'Y:\Media\Missing',
            folderName: 'Missing',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back to Dashboard'), findsOneWidget);
      expect(find.textContaining('no longer in the catalogue'), findsOneWidget);
      expect(find.byType(FolderBreadcrumb), findsNothing);
    });
  });

  group('Breadcrumb label semantics', () {
    testWidgets('13 no raw filesystem or HTTP path in breadcrumbs',
        (tester) async {
      final catalog = _httpStyleCatalog();
      final nested = catalog.findFolderById('http-child')!;

      await _openFolder(tester, catalog: catalog, folder: nested);

      expect(find.textContaining('https://'), findsNothing);
      expect(find.textContaining('nas.example'), findsNothing);
      expect(find.text('Remote Films'), findsOneWidget);
      expect(find.text('Drama'), findsWidgets);
    });

    testWidgets('14 HTTP-style item paths do not affect breadcrumb labels',
        (tester) async {
      final catalog = _httpStyleCatalog();
      final root = catalog.folders.single;

      await _openFolder(tester, catalog: catalog, folder: root);

      expect(find.text('Remote Films'), findsWidgets);
      expect(find.textContaining('.mp4'), findsNothing);
    });

    testWidgets('15 duplicate folder names distinguished by hierarchy',
        (tester) async {
      final catalog = _duplicateNameCatalog();
      final actionB = catalog.findFolderById('action-b')!;

      await _openFolder(tester, catalog: catalog, folder: actionB);

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Action'), findsWidgets);
      expect(find.text('Videos'), findsNothing);
    });
  });

  group('Layout and accessibility', () {
    testWidgets('16 deep hierarchy remains horizontally scrollable',
        (tester) async {
      final catalog = _deepCatalog();
      final leaf = catalog.findFolderById('folder-l5')!;

      await _openFolder(tester, catalog: catalog, folder: leaf);

      expect(find.byType(SingleChildScrollView), findsWidgets);

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(FolderBreadcrumb),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollable.scrollDirection, Axis.horizontal);
    });

    testWidgets('17 long folder names do not overflow', (tester) async {
      final longName = 'A' * 80;
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 0,
        'folders': [
          _folder(id: 'long-folder', name: longName).toJson(),
        ],
      });

      await _openFolder(
        tester,
        catalog: catalog,
        folder: catalog.folders.single,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsWidgets);
    });

    testWidgets('18 keyboard activation opens ancestor', (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;
      final ancestors = catalog.ancestorChainForFolder(nested.id);
      var navigatedTo = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: FolderBreadcrumb(
              ancestors: ancestors,
              currentFolderId: nested.id,
              onAncestorSelected: (folder) => navigatedTo = folder.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(navigatedTo, 'folder-root');
    });

    testWidgets('19 breadcrumb widget fits at 900x420', (tester) async {
      final catalog = _nestedCatalog();
      final nested = catalog.findFolderById('folder-child')!;

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          viewport: const Size(900, 420),
          home: FolderScreen.fromFolder(nested),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FolderBreadcrumb), findsOneWidget);
    });

    testWidgets('20 current-folder favourite control remains usable',
        (tester) async {
      final catalog = _nestedCatalog();
      final root = catalog.folders.single;

      await _openFolder(tester, catalog: catalog, folder: root);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Add to favourites'), findsOneWidget);
      expect(find.text('Rescan this folder'), findsOneWidget);
    });
  });

  group('Catalogue integrity', () {
    test('23 catalogue hierarchy helpers remain unchanged after navigation',
        () {
      final catalog = _nestedCatalog();
      final chain = catalog.ancestorChainForFolder('folder-child');

      expect(chain.map((f) => f.name).toList(), ['Films', 'Science Fiction']);
      expect(chain.last.id, 'folder-child');
      expect(catalog.findFolderById('folder-root')?.name, 'Films');
    });

    test('24 breadcrumb construction uses catalogue ancestry not path split',
        () {
      final catalog = _nestedCatalog();
      final folder = catalog.findFolderByPath(
        r'Y:\Media\Films\Science Fiction',
      )!;
      final chain = catalog.ancestorChainForFolder(folder.id);

      expect(chain.every((f) => !f.name.contains(r'\')), isTrue);
      expect(chain.every((f) => !f.name.contains('Y:')), isTrue);
      expect(chain.map((f) => f.id).toList(),
          ['folder-root', 'folder-child']);
    });
  });
}
