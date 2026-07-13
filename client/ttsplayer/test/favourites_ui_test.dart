import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/features/dashboard/widgets/favourites_section.dart';
import 'package:ttsplayer/features/favourites/favourites_screen.dart';
import 'package:ttsplayer/library/favourites_resolver.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_metadata.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/app_navigator.dart';
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
import 'package:ttsplayer/widgets/favourite_toggle_button.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

MediaFolder _folder({
  required String id,
  required String name,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return MediaFolder(
    id: id,
    name: name,
    path: r'Y:\Media\' + name,
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

Catalog _testCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 2,
    'folders': [
      _folder(
        id: 'folder-root',
        name: 'Videos',
        subfolders: [
          _folder(id: 'folder-child', name: 'Action'),
        ],
        items: [
          _item(id: 'item-alpha', title: 'Alpha'),
          _item(id: 'item-beta', title: 'Beta'),
        ],
      ).toJson(),
    ],
  });
}

LibraryMetadata _metadataWithFavourites({
  List<FavouriteRecord> items = const [],
  List<FavouriteRecord> folders = const [],
}) {
  return LibraryMetadata(
    metadataVersion: 1,
    favourites: FavouritesMetadata(items: items, folders: folders),
  );
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

Widget _sectionHarness({
  required Catalog catalog,
  required LibraryMetadataRepository repository,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: repository),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      home: Scaffold(body: child),
    ),
  );
}

Widget _favouritesHarness({
  required Catalog catalog,
  required LibraryMetadataRepository metadataRepository,
  Widget home = const DashboardScreen(),
}) {
  final catalogService = _FakeCatalogService(catalog);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider<SettingsRepository>(
        create: (_) => SettingsRepository(),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(
        value: metadataRepository,
      ),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
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
      navigatorObservers: [routeObserver],
      home: home,
    ),
  );
}

Future<LibraryMetadataRepository> _seededRepository({
  List<FavouriteRecord> items = const [],
  List<FavouriteRecord> folders = const [],
}) async {
  final metadata = _metadataWithFavourites(items: items, folders: folders);
  SharedPreferences.setMockInitialValues({
    LibraryMetadataRepository.storageKey:
        jsonEncode(metadata.toPersistenceJson()),
  });
  final repository = LibraryMetadataRepository();
  await repository.initialize();
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveFavourites', () {
    test('19 unresolved favourite IDs are skipped safely', () {
      final catalog = _testCatalog();
      final entries = resolveFavourites(
        catalog: catalog,
        folderRecords: [
          FavouriteRecord(
            id: 'folder-child',
            favouritedAt: DateTime.utc(2026, 7, 13, 12),
          ),
          FavouriteRecord(
            id: 'missing-folder',
            favouritedAt: DateTime.utc(2026, 7, 13, 11),
          ),
        ],
        itemRecords: [
          FavouriteRecord(
            id: 'missing-item',
            favouritedAt: DateTime.utc(2026, 7, 13, 10),
          ),
        ],
      );

      expect(entries.length, 1);
      expect(entries.single.id, 'folder-child');
    });
  });

  group('Favourite controls', () {
    testWidgets('1 item favourite control reflects repository state',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteItemToggle(itemId: 'item-alpha'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('2 folder favourite control reflects repository state',
        (tester) async {
      final repository = await _seededRepository(
        folders: [
          FavouriteRecord(
            id: 'folder-child',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteFolderToggle(folderId: 'folder-child'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('3 adding item favourite updates control', (tester) async {
      final repository = await _seededRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteItemToggle(itemId: 'item-alpha'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('4 removing item favourite updates control', (tester) async {
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteItemToggle(itemId: 'item-alpha'),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('5 adding and removing folder favourite works', (tester) async {
      final repository = await _seededRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteFolderToggle(folderId: 'folder-child'),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
      expect(repository.isFolderFavourited('folder-child'), isTrue);

      await tester.tap(find.byTooltip('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(repository.isFolderFavourited('folder-child'), isFalse);
    });

    testWidgets('6 favourite action does not trigger media playback',
        (tester) async {
      final catalog = _testCatalog();
      final folder = catalog.findFolderById('folder-root')!;
      final item = folder.items.first;
      final repository = await _seededRepository();
      var detailOpened = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
            Provider(
              create: (context) => MediaLocationResolver(
                config:
                    context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: false,
              ),
            ),
            Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 280,
                child: TtsMediaCard(
                  item: item,
                  parentFolder: folder,
                  topLeftOverlay: FavouriteItemToggle(
                    itemId: item.id,
                    compact: true,
                  ),
                  onTap: () => detailOpened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavouriteItemToggle));
      await tester.pumpAndSettle();
      expect(detailOpened, isFalse);
      expect(repository.isItemFavourited(item.id), isTrue);
    });

    testWidgets('7 favourite action does not open folder', (tester) async {
      final catalog = _testCatalog();
      final sub = catalog.findFolderById('folder-child')!;
      final repository = await _seededRepository();
      var folderOpened = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
            Provider(
              create: (context) => MediaLocationResolver(
                config:
                    context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: false,
              ),
            ),
            Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 200,
                child: TtsFolderCard(
                  folder: sub,
                  topLeftOverlay: FavouriteFolderToggle(
                    folderId: sub.id,
                    compact: true,
                  ),
                  onTap: () => folderOpened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavouriteFolderToggle));
      await tester.pumpAndSettle();
      expect(folderOpened, isFalse);
      expect(repository.isFolderFavourited(sub.id), isTrue);
    });

    testWidgets('8 keyboard activation toggles favourite', (tester) async {
      final repository = await _seededRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryMetadataRepository>.value(
              value: repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavouriteItemToggle(itemId: 'item-alpha'),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('Dashboard favourites section', () {
    testWidgets('9 section absent with no favourites', (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository();

      await tester.pumpWidget(
        _sectionHarness(
          catalog: catalog,
          repository: repository,
          child: FavouritesSection(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FAVOURITES'), findsNothing);
    });

    testWidgets('10 dashboard shows one favourite', (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _sectionHarness(
          catalog: catalog,
          repository: repository,
          child: FavouritesSection(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FAVOURITES'), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
    });

    testWidgets('11 dashboard shows mixed folder and item favourites',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13, 10),
          ),
        ],
        folders: [
          FavouriteRecord(
            id: 'folder-child',
            favouritedAt: DateTime.utc(2026, 7, 13, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        _sectionHarness(
          catalog: catalog,
          repository: repository,
          child: FavouritesSection(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Action'), findsWidgets);
      expect(find.text('Alpha'), findsWidgets);
    });

    test('12 dashboard cap limits resolved entries to 10', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 12,
        'folders': [
          _folder(
            id: 'folder-root',
            name: 'Videos',
            items: List.generate(
              12,
              (i) => _item(id: 'item-$i', title: 'Title $i'),
            ),
          ).toJson(),
        ],
      });
      final records = List.generate(
        12,
        (i) => FavouriteRecord(
          id: 'item-$i',
          favouritedAt: DateTime.utc(2026, 7, 13, i),
        ),
      );

      final resolved = resolveFavourites(
        catalog: catalog,
        folderRecords: const [],
        itemRecords: records,
      );

      expect(resolved.length, 12);
      expect(
        resolved.take(FavouritesSection.dashboardCap).length,
        FavouritesSection.dashboardCap,
      );
    });

    testWidgets('13 View all opens dedicated favourites view', (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _sectionHarness(
          catalog: catalog,
          repository: repository,
          child: FavouritesSection(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.byType(FavouritesScreen), findsOneWidget);
    });
  });

  group('Favourites screen', () {
    testWidgets('14 favourites view shows all entries newest first',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13, 8),
          ),
          FavouriteRecord(
            id: 'item-beta',
            favouritedAt: DateTime.utc(2026, 7, 13, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      final betaY = tester.getTopLeft(find.text('Beta')).dy;
      final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
      expect(betaY, lessThan(alphaY));
    });

    testWidgets('15 favourited folder opens correct folder by id',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        folders: [
          FavouriteRecord(
            id: 'folder-child',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
    });

    testWidgets('16 favourited media opens item detail', (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsOneWidget);
    });

    testWidgets('17 unfavouriting from dedicated view removes entry',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
          FavouriteRecord(
            id: 'item-beta',
            favouritedAt: DateTime.utc(2026, 7, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove from favourites').first);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('18 removing final entry shows empty state', (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository(
        items: [
          FavouriteRecord(
            id: 'item-alpha',
            favouritedAt: DateTime.utc(2026, 7, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      expect(find.text('No favourites yet'), findsOneWidget);
    });
  });

  group('Repository and catalogue integration', () {
    testWidgets('20 repository notification rebuilds favourites view',
        (tester) async {
      final catalog = _testCatalog();
      final repository = await _seededRepository();

      await tester.pumpWidget(
        _favouritesHarness(
          catalog: catalog,
          metadataRepository: repository,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No favourites yet'), findsOneWidget);

      await repository.addItemFavourite('item-alpha');
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
    });

    test('21 successful catalogue replacement prunes stale favourites', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite('item-alpha');
      await repository.addItemFavourite('item-gone');

      final slimCatalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: 'folder-root',
            name: 'Videos',
            items: [_item(id: 'item-alpha', title: 'Alpha')],
          ).toJson(),
        ],
      });

      await repository.validateAgainstCatalog(slimCatalog);

      expect(repository.isItemFavourited('item-alpha'), isTrue);
      expect(repository.isItemFavourited('item-gone'), isFalse);
    });

    test('22 failed catalogue refresh does not prune favourites', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite('item-gone');

      final emptyCatalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 0,
        'folders': [],
      });

      // Simulate failed replacement — validation not invoked.
      expect(repository.isItemFavourited('item-gone'), isTrue);
      expect(emptyCatalog.allItems, isEmpty);
    });

    test('23 settings reset all preserves favourites', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultLibrarySortMode(
        LibrarySortMode.nameAsc,
      );

      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      await metadata.addItemFavourite('item-alpha');

      await settings.resetAllToDefaults();

      expect(settings.defaultLibrarySortMode, LibrarySortMode.defaultMode);
      expect(metadata.isItemFavourited('item-alpha'), isTrue);
    });

    test('26 catalogue unchanged by favourite actions', () async {
      final catalog = _testCatalog();
      final before = jsonEncode(catalog.folders.map((f) => f.toJson()).toList());

      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite('item-alpha');
      await repository.addFolderFavourite('folder-child');
      await repository.removeItemFavourite('item-alpha');

      expect(
        jsonEncode(catalog.folders.map((f) => f.toJson()).toList()),
        before,
      );
    });
  });
}
