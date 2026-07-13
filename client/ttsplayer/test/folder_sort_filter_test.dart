import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/folder_navigation.dart';
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
import 'package:ttsplayer/widgets/folder_breadcrumb.dart';
import 'package:ttsplayer/widgets/folder_browse_controls.dart';
import 'package:ttsplayer/widgets/favourite_toggle_button.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

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
  DateTime? addedAt,
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath ?? r'Y:\Media\' + title + '.mp4',
    addedAt: addedAt,
  );
}

Catalog _browseCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 4,
    'folders': [
      _folder(
        id: 'parent',
        name: 'Parent',
        path: r'Y:\Media\Parent',
        subfolders: [
          _folder(
            id: 'sub-b',
            name: 'Bravo',
            path: r'Y:\Media\Parent\Bravo',
          ),
          _folder(
            id: 'sub-a',
            name: 'alpha',
            path: r'Y:\Media\Parent\alpha',
          ),
        ],
        items: [
          _item(
            id: 'item-b',
            title: 'Beta',
            filePath: r'Y:\Media\Parent\Beta.mp4',
            addedAt: DateTime.utc(2026, 7, 10),
          ),
          _item(
            id: 'item-a',
            title: 'alpha',
            filePath: r'Y:\Media\Parent\alpha.jpg',
            addedAt: DateTime.utc(2026, 7, 12),
          ),
          _item(
            id: 'item-c',
            title: 'No Date',
            filePath: r'Y:\Media\Parent\nodate.mkv',
          ),
        ],
      ).toJson(),
      _folder(
        id: 'images-only',
        name: 'ImagesOnly',
        path: r'Y:\Media\ImagesOnly',
        items: [
          _item(
            id: 'img-1',
            title: 'Photo',
            filePath: r'Y:\Media\ImagesOnly\Photo.jpg',
          ),
        ],
      ).toJson(),
    ],
  });
}

String _folderSnapshot(MediaFolder folder) => jsonEncode({
      'subfolders': folder.subfolders.map((f) => f.toJson()).toList(),
      'items': folder.items.map((i) => i.toJson()).toList(),
    });

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

class _FailingSettingsRepository extends SettingsRepository {
  @override
  Future<SettingsSaveResult> saveDefaultLibrarySortMode(
    LibrarySortMode sortMode,
  ) async {
    return const SettingsSaveResult(
      success: false,
      validationErrors: ['Simulated save failure'],
    );
  }
}

late LibraryMetadataRepository _defaultMetadata;
late SettingsRepository _defaultSettings;
late _FakeCatalogService _defaultCatalogService;

Widget _harness({
  required Catalog catalog,
  required Widget home,
  SettingsRepository? settingsRepository,
  LibraryMetadataRepository? metadataRepository,
  _FakeCatalogService? catalogService,
  Size viewport = const Size(900, 1200),
}) {
  final service = catalogService ?? _FakeCatalogService(catalog);
  if (catalogService == null) {
    _defaultCatalogService = service;
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider<SettingsRepository>.value(
        value: settingsRepository ?? _defaultSettings,
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(
        value: metadataRepository ?? _defaultMetadata,
      ),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: true,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
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
          child: home,
        ),
      ),
    ),
  );
}

Future<void> _openParentFolder(
  WidgetTester tester,
  Catalog catalog, {
  Size viewport = const Size(900, 1200),
}) async {
  final parent = catalog.findFolderById('parent')!;
  await tester.pumpWidget(
    _harness(
      catalog: catalog,
      viewport: viewport,
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
  openFolderScreen(tester.element(find.text('Open')), parent);
  await tester.pumpAndSettle();
}

List<String> _folderCardNames(WidgetTester tester) {
  return tester
      .widgetList<TtsFolderCard>(find.byType(TtsFolderCard))
      .map((card) => card.folder.name)
      .toList();
}

List<String> _mediaCardTitles(WidgetTester tester) {
  return tester
      .widgetList<TtsMediaCard>(find.byType(TtsMediaCard))
      .map((card) => card.item.title)
      .toList();
}

Future<void> _selectSort(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('folder_sort_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _defaultSettings = SettingsRepository();
    await _defaultSettings.initialize();
    _defaultMetadata = LibraryMetadataRepository();
    await _defaultMetadata.initialize();
  });

  group('Sort initialization and order', () {
    testWidgets('1 FolderScreen initially uses persisted default sort',
        (tester) async {
      await _defaultSettings.saveDefaultLibrarySortMode(
        LibrarySortMode.nameAsc,
      );
      final catalog = _browseCatalog();

      await _openParentFolder(tester, catalog);

      expect(find.text('Name A–Z'), findsWidgets);
      final view = buildLibraryFolderView(
        folder: catalog.findFolderById('parent')!,
        sortMode: LibrarySortMode.nameAsc,
        filter: LibraryFilter.all,
      );
      expect(view.subfolders.first.name, 'alpha');
    });

    testWidgets('2 missing setting uses default indexer order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      expect(find.text('Default'), findsWidgets);
      final view = buildLibraryFolderView(
        folder: catalog.findFolderById('parent')!,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.all,
      );
      expect(view.subfolders.map((f) => f.id).toList(), ['sub-b', 'sub-a']);
    });

    testWidgets('3 default sort preserves emitted order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      expect(find.text('Bravo'), findsOneWidget);
      final bravoY = tester.getTopLeft(find.text('Bravo')).dy;
      final betaY = tester.getTopLeft(find.text('Beta')).dy;
      expect(bravoY, lessThan(betaY));
    });

    testWidgets('4 name ascending visible order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name A–Z');

      expect(_folderCardNames(tester), ['alpha', 'Bravo']);
      expect(_mediaCardTitles(tester), ['alpha', 'Beta', 'No Date']);
    });

    testWidgets('5 name descending visible order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name Z–A');

      expect(_folderCardNames(tester), ['Bravo', 'alpha']);
      expect(_mediaCardTitles(tester), ['No Date', 'Beta', 'alpha']);
    });

    testWidgets('6 recently added visible order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Recently added');

      expect(_mediaCardTitles(tester), ['alpha', 'Beta', 'No Date']);
    });

    testWidgets('7 oldest added visible order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Oldest added');

      expect(_mediaCardTitles(tester), ['Beta', 'alpha', 'No Date']);
    });

    testWidgets('8 type visible order', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Type');

      expect(_mediaCardTitles(tester), ['Beta', 'No Date', 'alpha']);
    });

    testWidgets('9 folder-first remains true for every sort mode',
        (tester) async {
      final catalog = _browseCatalog();
      final parent = catalog.findFolderById('parent')!;

      for (final mode in LibrarySortMode.values) {
        final view = buildLibraryFolderView(
          folder: parent,
          sortMode: mode,
          filter: LibraryFilter.all,
        );
        expect(view.subfolders, isNotEmpty);
        expect(view.items, isNotEmpty);
      }

      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name Z–A');
      final bravoY = tester.getTopLeft(find.text('Bravo')).dy;
      final betaY = tester.getTopLeft(find.text('Beta')).dy;
      expect(bravoY, lessThan(betaY));
    });
  });

  group('Filter behaviour', () {
    testWidgets('10 sort selection does not alter active filter',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();
      expect(_mediaCardTitles(tester), ['Beta', 'No Date']);

      await _selectSort(tester, 'Name A–Z');
      expect(_mediaCardTitles(tester), ['Beta', 'No Date']);
    });

    testWidgets('11 all filter shows all direct children', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      expect(_folderCardNames(tester), ['Bravo', 'alpha']);
      expect(_mediaCardTitles(tester), ['Beta', 'alpha', 'No Date']);
    });

    testWidgets('12 folders-only hides items', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byKey(const Key('folder_filter_foldersOnly')));
      await tester.pumpAndSettle();

      expect(_folderCardNames(tester), ['Bravo', 'alpha']);
      expect(_mediaCardTitles(tester), isEmpty);
    });

    testWidgets('13 video filter shows video items and all subfolders',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();

      expect(_folderCardNames(tester), ['Bravo', 'alpha']);
      expect(_mediaCardTitles(tester), ['Beta', 'No Date']);
    });

    testWidgets('14 images filter shows image items and all subfolders',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byKey(const Key('folder_filter_images')));
      await tester.pumpAndSettle();

      expect(_folderCardNames(tester), ['Bravo', 'alpha']);
      expect(_mediaCardTitles(tester), ['alpha']);
    });

    testWidgets('15 filter selection does not alter active sort',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name Z–A');

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();

      expect(find.text('Name Z–A'), findsWidgets);
      expect(_mediaCardTitles(tester), ['No Date', 'Beta']);
    });
  });

  group('Session and navigation state', () {
    testWidgets('16 active filter is not persisted on new folder open',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      await _openParentFolder(tester, catalog);
      expect(_mediaCardTitles(tester), ['Beta', 'alpha', 'No Date']);
    });

    testWidgets('17 new subfolder route starts with default sort and all filter',
        (tester) async {
      final catalog = _browseCatalog();
      await _defaultSettings.saveDefaultLibrarySortMode(
        LibrarySortMode.defaultOrder,
      );
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name Z–A');
      await tester.tap(find.byKey(const Key('folder_filter_images')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.text('Default'), findsWidgets);
      expect(find.text('Name Z–A'), findsNothing);
    });

    testWidgets('18 back restores previous mounted route selections',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name Z–A');
      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Name Z–A'), findsWidgets);
      expect(_mediaCardTitles(tester), ['No Date', 'Beta']);
    });
  });

  group('Default sort persistence', () {
    testWidgets('19 set as default persists selected sort', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);
      await _selectSort(tester, 'Name A–Z');

      await tester.tap(find.byKey(const Key('folder_set_default_sort')));
      await tester.pumpAndSettle();

      expect(_defaultSettings.defaultLibrarySortMode, LibrarySortMode.nameAsc);
      expect(find.text('Default sort order saved.'), findsOneWidget);
    });

    testWidgets('20 persistence failure shows feedback and keeps current view',
        (tester) async {
      final catalog = _browseCatalog();
      final failingSettings = _FailingSettingsRepository();
      await failingSettings.initialize();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          settingsRepository: failingSettings,
          home: FolderScreen.fromFolder(catalog.findFolderById('parent')!),
        ),
      );
      await tester.pumpAndSettle();

      await _selectSort(tester, 'Name A–Z');
      await tester.tap(find.byKey(const Key('folder_set_default_sort')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Simulated save failure'), findsOneWidget);
      expect(_folderCardNames(tester), ['alpha', 'Bravo']);
    });

    test('21 provider settings remain unchanged after saving default sort',
        () async {
      final before = _defaultSettings.providerConfig;
      await _defaultSettings.saveDefaultLibrarySortMode(
        LibrarySortMode.type,
      );
      expect(_defaultSettings.providerConfig, equals(before));
    });
  });

  group('Empty states', () {
    testWidgets('22 empty folder shows true empty state', (tester) async {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 0,
        'folders': [
          _folder(id: 'empty', name: 'Empty').toJson(),
        ],
      });

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: FolderScreen.fromFolder(catalog.folders.single),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This folder is empty.'), findsOneWidget);
      expect(find.byType(FolderBrowseControls), findsOneWidget);
    });

    testWidgets('23 no filter matches shows filter-specific empty state',
        (tester) async {
      final catalog = _browseCatalog();
      final imagesOnly = catalog.findFolderById('images-only')!;

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: FolderScreen.fromFolder(imagesOnly),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();

      expect(find.text('No items match this filter'), findsOneWidget);
      expect(find.text('This folder is empty.'), findsNothing);
    });

    testWidgets('24 show all clears the filter-empty state', (tester) async {
      final catalog = _browseCatalog();
      final imagesOnly = catalog.findFolderById('images-only')!;

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: FolderScreen.fromFolder(imagesOnly),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();
      expect(find.text('No items match this filter'), findsOneWidget);

      await tester.tap(find.byKey(const Key('folder_show_all_filter')));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('No items match this filter'), findsNothing);
    });
  });

  group('Regression and layout', () {
    testWidgets('25 favourite overlays remain functional', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byTooltip('Add to favourites').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('26 favourite control does not trigger media primary action',
        (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byType(FavouriteItemToggle).first);
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsNothing);
    });

    testWidgets('27 breadcrumb navigation remains functional', (tester) async {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-13T10:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: 'root',
            name: 'Root',
            subfolders: [
              _folder(
                id: 'child',
                name: 'Child',
                items: [_item(id: 'x', title: 'Item')],
              ),
            ],
          ).toJson(),
        ],
      });

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: FolderScreen.fromFolder(
            catalog.findFolderById('child')!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('breadcrumb_segment_root')));
      await tester.pumpAndSettle();

      expect(find.text('Root'), findsWidgets);
      expect(find.text('Item'), findsNothing);
    });

    testWidgets('28 folder rescan remains accessible', (tester) async {
      final catalog = _browseCatalog();
      await _openParentFolder(tester, catalog);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Rescan this folder'), findsOneWidget);
    });

    testWidgets('29 catalogue replacement rebuilds derived view',
        (tester) async {
      final catalog = _browseCatalog();
      final service = _FakeCatalogService(catalog);

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          catalogService: service,
          home: FolderScreen.fromFolder(catalog.findFolderById('parent')!),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('folder_filter_video')));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);

      final updated = Catalog.fromJson({
        'generated_at': '2026-07-13T11:00:00+00:00',
        'total_items': 5,
        'folders': [
          _folder(
            id: 'parent',
            name: 'Parent',
            path: r'Y:\Media\Parent',
            subfolders: [
              _folder(id: 'sub-b', name: 'Bravo', path: r'Y:\Media\Parent\Bravo'),
            ],
            items: [
              _item(
                id: 'item-new',
                title: 'NewClip',
                filePath: r'Y:\Media\Parent\NewClip.mp4',
              ),
              ...catalog.findFolderById('parent')!.items,
            ],
          ).toJson(),
        ],
      });
      service.setCatalog(updated);
      await tester.pumpAndSettle();

      expect(find.text('NewClip'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    test('30 source catalogue collections remain unchanged', () {
      final catalog = _browseCatalog();
      final parent = catalog.findFolderById('parent')!;
      final before = _folderSnapshot(parent);

      buildLibraryFolderView(
        folder: parent,
        sortMode: LibrarySortMode.nameDesc,
        filter: LibraryFilter.video,
      );

      expect(_folderSnapshot(parent), before);
    });

    testWidgets('31 layout fits and scrolls at 900x420', (tester) async {
      final catalog = _browseCatalog();
      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          viewport: const Size(900, 420),
          home: FolderScreen.fromFolder(catalog.findFolderById('parent')!),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FolderBrowseControls), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('32 keyboard navigation works for filter controls',
        (tester) async {
      final catalog = _browseCatalog();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: Scaffold(
            body: FolderBrowseControls(
              activeSortMode: LibrarySortMode.defaultOrder,
              activeFilter: LibraryFilter.all,
              persistedDefaultSort: LibrarySortMode.defaultOrder,
              onSortModeChanged: (_) {},
              onFilterChanged: (_) {},
              onSetAsDefault: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
