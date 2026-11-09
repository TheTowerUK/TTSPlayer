import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/books/reader/book_reader_screen.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_screen.dart';
import 'package:ttsplayer/features/favourites/favourites_screen.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_presentation_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_metadata.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/navigation/media_item_navigation.dart';
import 'package:ttsplayer/navigation/single_reader_folder.dart';
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
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/book_test_fixtures.dart';
import 'support/comic_test_fixtures.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  final Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  String? get catalogPath => 'bundled';
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

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
    itemCount: items.length +
        subfolders.fold<int>(0, (sum, folder) => sum + folder.itemCount),
    items: items,
    subfolders: subfolders,
  );
}

MediaItem _item({
  required String id,
  required String title,
  required String filePath,
  required String kind,
  MediaItemStatus status = MediaItemStatus.available,
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: kind,
    status: status,
  );
}

Catalog _catalogOf(MediaFolder parent) {
  return Catalog.fromJson({
    'generated_at': '2026-11-09T00:00:00+00:00',
    'total_items': parent.totalItems,
    'folders': [parent.toJson()],
  });
}

Catalog _parentWithLeaves(List<MediaFolder> leaves) {
  return _catalogOf(
    _folder(
      id: 'folder-hartley',
      name: 'A. J. Hartley',
      path: r'Y:\Media\Literature\Books\Calibre\A. J. Hartley',
      subfolders: leaves,
    ),
  );
}

Widget _harness({
  required Catalog catalog,
  required Widget home,
  LibraryMetadataRepository? metadata,
  Size viewport = const Size(1280, 800),
}) {
  return MediaQuery(
    data: MediaQueryData(size: viewport),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
        ChangeNotifierProvider(create: (_) => SettingsRepository()),
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: metadata ?? LibraryMetadataRepository(),
        ),
        Provider(
          create: (context) => MediaLocationResolver(
            config: context.read<MediaProviderConfigService>().mediaAccess,
            isWindowsDesktop: true,
          ),
        ),
        Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
        ChangeNotifierProvider<CatalogService>.value(
          value: _FakeCatalogService(catalog),
        ),
        ChangeNotifierProvider(
          create: (context) => PlaybackService(
            mediaLocationResolver: context.read<MediaLocationResolver>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ScannerService()),
        ChangeNotifierProvider<ScanHistoryService>.value(
          value: _FakeScanHistoryService(),
        ),
        Provider(create: (_) => SearchService()),
        ChangeNotifierProvider<ReadingProgressRepository>.value(
          value: ReadingProgressRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) => ReadingProgressCoordinator(
            repository: context.read<ReadingProgressRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MetadataEnrichmentRepository(),
        ),
        Provider(create: (_) => const MetadataPresentationService()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: home,
      ),
    ),
  );
}

Future<void> _openParent(
  WidgetTester tester, {
  required Catalog catalog,
  LibraryMetadataRepository? metadata,
}) async {
  await tester.pumpWidget(
    _harness(
      catalog: catalog,
      metadata: metadata,
      home: FolderScreen.fromFolder(catalog.folders.single),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 80,
}) async {
  await tester.runAsync(() async {
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late LibraryMetadataRepository metadata;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('tts_single_reader_folder_');
    metadata = LibraryMetadataRepository();
    await metadata.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') return tmp.path;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('singlePlayableReaderItem', () {
    test('returns playable EPUB in a leaf folder', () {
      final item = _item(
        id: 'epub-1',
        title: 'Act of Will',
        filePath: r'Y:\Media\Act of Will.epub',
        kind: 'book',
      );
      final folder = _folder(
        id: 'leaf',
        name: 'Act of Will (7565)',
        items: [item],
      );
      expect(singlePlayableReaderItem(folder), same(item));
      expect(mediaItemActivationFor(item), MediaItemActivation.reader);
    });

    test('returns playable PDF in a leaf folder', () {
      final item = _item(
        id: 'pdf-1',
        title: 'Manual',
        filePath: r'Y:\Media\Manual.pdf',
        kind: 'book',
      );
      expect(
        singlePlayableReaderItem(
            _folder(id: 'leaf', name: 'Manual', items: [item])),
        same(item),
      );
    });

    test('returns playable CBZ comic in a leaf folder', () {
      final item = _item(
        id: 'cbz-1',
        title: 'Issue 1',
        filePath: r'Y:\Media\issue.cbz',
        kind: 'comic',
      );
      expect(
        singlePlayableReaderItem(
          _folder(id: 'leaf', name: 'Issue 1 (1)', items: [item]),
        ),
        same(item),
      );
    });

    test('rejects unplayable single items', () {
      final missing = _item(
        id: 'missing',
        title: 'Gone',
        filePath: r'Y:\Media\gone.epub',
        kind: 'book',
        status: MediaItemStatus.missing,
      );
      expect(
        singlePlayableReaderItem(
          _folder(id: 'leaf', name: 'Gone', items: [missing]),
        ),
        isNull,
      );
    });

    test('rejects unsupported book formats', () {
      final txt = _item(
        id: 'txt',
        title: 'Notes',
        filePath: r'Y:\Media\notes.txt',
        kind: 'book',
      );
      expect(
        singlePlayableReaderItem(
          _folder(id: 'leaf', name: 'Notes', items: [txt]),
        ),
        isNull,
      );
    });

    test('rejects videos, multi-item folders, and nested folders', () {
      final video = _item(
        id: 'vid',
        title: 'Film',
        filePath: r'Y:\Media\film.mp4',
        kind: 'video',
      );
      expect(
        singlePlayableReaderItem(
          _folder(id: 'movies', name: 'Film (1)', items: [video]),
        ),
        isNull,
      );

      final a = _item(
        id: 'a',
        title: 'A',
        filePath: r'Y:\Media\a.epub',
        kind: 'book',
      );
      final b = _item(
        id: 'b',
        title: 'B',
        filePath: r'Y:\Media\b.epub',
        kind: 'book',
      );
      expect(
        singlePlayableReaderItem(
          _folder(id: 'multi', name: 'Omnibus', items: [a, b]),
        ),
        isNull,
      );

      final nested = _folder(
        id: 'series',
        name: 'Series',
        subfolders: [
          _folder(
            id: 'vol1',
            name: 'Vol 1',
            items: [
              _item(
                id: 'vol1-book',
                title: 'Vol 1',
                filePath: r'Y:\Media\vol1.epub',
                kind: 'book',
              ),
            ],
          ),
        ],
      );
      expect(singlePlayableReaderItem(nested), isNull);
    });
  });

  group('FolderScreen shortcut', () {
    testWidgets('single playable EPUB leaf opens the reader directly',
        (tester) async {
      final file = writeEpub(
        tmp,
        'act-of-will.epub',
        chapters: [
          const MapEntry('ch1.xhtml', '<html><body><p>One</p></body></html>'),
        ],
      );
      final leaf = _folder(
        id: 'leaf-epub',
        name: 'Act of Will (7565)',
        items: [
          _item(
            id: 'item-epub',
            title: 'Act of Will',
            filePath: file.path,
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      await tester.tap(find.text('Act of Will (7565)'));
      await _pumpUntilFound(tester, find.byType(BookReaderScreen));

      expect(find.byType(BookReaderScreen), findsOneWidget);
      expect(find.byType(FolderScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(ItemDetailScreen), findsNothing);
    });

    testWidgets('single playable PDF leaf opens the reader directly',
        (tester) async {
      final file = writePdf(tmp, 'manual.pdf', pages: 2);
      final leaf = _folder(
        id: 'leaf-pdf',
        name: 'Manual (1)',
        items: [
          _item(
            id: 'item-pdf',
            title: 'Manual',
            filePath: file.path,
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      await tester.tap(find.text('Manual (1)'));
      await _pumpUntilFound(tester, find.byType(BookReaderScreen));

      expect(find.byType(BookReaderScreen), findsOneWidget);
      expect(find.byType(FolderScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('single supported comic leaf opens the reader directly',
        (tester) async {
      final file = writeCbz(tmp, 'issue.cbz', {'page_001.png': tinyPng()});
      final leaf = _folder(
        id: 'leaf-cbz',
        name: 'Issue 1 (1)',
        items: [
          _item(
            id: 'item-cbz',
            title: 'Issue 1',
            filePath: file.path,
            kind: 'comic',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      await tester.tap(find.text('Issue 1 (1)'));
      await _pumpUntilFound(tester, find.byType(ComicReaderScreen));

      expect(find.byType(ComicReaderScreen), findsOneWidget);
      expect(find.byType(FolderScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('single unplayable item opens the folder normally',
        (tester) async {
      final leaf = _folder(
        id: 'leaf-missing',
        name: 'Gone (1)',
        items: [
          _item(
            id: 'item-missing',
            title: 'Gone Book',
            filePath: r'Y:\Media\gone.epub',
            kind: 'book',
            status: MediaItemStatus.missing,
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      await tester.tap(find.byKey(const ValueKey('folder-card-leaf-missing')));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen, skipOffstage: false), findsNWidgets(2));
      expect(find.byType(TtsMediaCard), findsOneWidget);
      expect(find.text('Gone Book'), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);
      expect(
        find.byKey(const Key('folder_details_leaf-missing')),
        findsNothing,
      );
    });

    testWidgets('multi-item and nested folders retain browsing',
        (tester) async {
      final multi = _folder(
        id: 'leaf-multi',
        name: 'Omnibus',
        items: [
          _item(
            id: 'item-a',
            title: 'Book A',
            filePath: r'Y:\Media\a.epub',
            kind: 'book',
          ),
          _item(
            id: 'item-b',
            title: 'Book B',
            filePath: r'Y:\Media\b.epub',
            kind: 'book',
          ),
        ],
      );
      final nested = _folder(
        id: 'folder-series',
        name: 'Series',
        subfolders: [
          _folder(
            id: 'folder-vol1',
            name: 'Vol 1 (1)',
            items: [
              _item(
                id: 'item-vol1',
                title: 'Vol 1',
                filePath: r'Y:\Media\vol1.epub',
                kind: 'book',
              ),
            ],
          ),
        ],
      );
      final catalog = _parentWithLeaves([multi, nested]);

      await _openParent(tester, catalog: catalog, metadata: metadata);

      await tester.tap(find.byKey(const ValueKey('folder-card-leaf-multi')));
      await tester.pumpAndSettle();
      expect(find.byType(FolderScreen, skipOffstage: false), findsNWidgets(2));
      expect(find.text('Book A'), findsOneWidget);
      expect(find.text('Book B'), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('folder-card-folder-series')));
      await tester.pumpAndSettle();
      expect(find.byType(FolderScreen, skipOffstage: false), findsNWidgets(2));
      expect(find.byType(TtsFolderCard), findsWidgets);
      expect(find.text('Vol 1 (1)'), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);
    });

    testWidgets('information control opens Details without the reader',
        (tester) async {
      final file = writeEpub(
        tmp,
        'details.epub',
        chapters: [
          const MapEntry('ch1.xhtml', '<html><body><p>One</p></body></html>'),
        ],
      );
      final leaf = _folder(
        id: 'leaf-details',
        name: 'Act of Will (7565)',
        items: [
          _item(
            id: 'item-details',
            title: 'Act of Will',
            filePath: file.path,
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      expect(
        find.byKey(const Key('folder_details_leaf-details')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('folder_details_leaf-details')));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);
      expect(
        find.byType(FolderScreen, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('back from reader returns to the parent folder',
        (tester) async {
      final file = writeEpub(
        tmp,
        'back.epub',
        chapters: [
          const MapEntry('ch1.xhtml', '<html><body><p>One</p></body></html>'),
        ],
      );
      final leaf = _folder(
        id: 'leaf-back',
        name: 'Act of Will (7565)',
        items: [
          _item(
            id: 'item-back',
            title: 'Act of Will',
            filePath: file.path,
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await _openParent(tester, catalog: catalog, metadata: metadata);
      await tester.tap(find.text('Act of Will (7565)'));
      await _pumpUntilFound(tester, find.byType(BookReaderScreen));
      expect(find.byType(BookReaderScreen), findsOneWidget);
      expect(find.byType(FolderScreen, skipOffstage: false), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BookReaderScreen), findsNothing);
      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.text('A. J. Hartley'), findsWidgets);
      expect(find.text('Act of Will (7565)'), findsOneWidget);
    });
  });

  group('Other surfaces stay on existing navigation', () {
    testWidgets('Search Browse Folder still opens the leaf folder',
        (tester) async {
      final leaf = _folder(
        id: 'leaf-search',
        name: 'Act of Will (7565)',
        path:
            r'Y:\Media\Literature\Books\Calibre\A. J. Hartley\Act of Will (7565)',
        items: [
          _item(
            id: 'item-search',
            title: 'Act of Will',
            filePath:
                r'Y:\Media\Literature\Books\Calibre\A. J. Hartley\Act of Will (7565)\Act of Will.epub',
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          metadata: metadata,
          home: const SearchScreen(autofocus: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Act of Will');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      await tester
          .tap(find.byKey(const Key('search_browse_folder_item-search')));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.byType(TtsMediaCard), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);
      expect(find.text('Act of Will (7565)'), findsWidgets);
    });

    testWidgets('Favourites folder opening still browses the folder',
        (tester) async {
      final leaf = _folder(
        id: 'leaf-fav',
        name: 'Act of Will (7565)',
        items: [
          _item(
            id: 'item-fav',
            title: 'Act of Will',
            filePath: r'Y:\Media\Act of Will.epub',
            kind: 'book',
          ),
        ],
      );
      final catalog = _parentWithLeaves([leaf]);
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode(
          LibraryMetadata(
            metadataVersion: 1,
            favourites: FavouritesMetadata(
              items: const [],
              folders: [
                FavouriteRecord(
                  id: 'leaf-fav',
                  favouritedAt: DateTime.utc(2026, 11, 9),
                ),
              ],
            ),
          ).toPersistenceJson(),
        ),
      });
      final favMetadata = LibraryMetadataRepository();
      await favMetadata.initialize();

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          metadata: favMetadata,
          home: FavouritesScreen(catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Act of Will (7565)'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.byType(TtsMediaCard), findsOneWidget);
      expect(find.byType(BookReaderScreen), findsNothing);
    });

    testWidgets('Continue Reading still opens the reader', (tester) async {
      final file = writeEpub(
        tmp,
        'continue.epub',
        chapters: [
          const MapEntry('ch1.xhtml', '<html><body><p>One</p></body></html>'),
        ],
      );
      final item = _item(
        id: 'item-continue',
        title: 'Continue Book',
        filePath: file.path,
        kind: 'book',
      );
      final catalog = _catalogOf(
        _folder(id: 'books', name: 'Books', items: [item]),
      );
      final entry = ContinueReadingEntry(
        item: item,
        record: ReadingProgressRecord(
          mediaId: item.id,
          mediaKind: MediaKind.book,
          readerFormat: ReadingReaderFormat.epub,
          title: item.title,
          location: const EpubReadingLocationPayload(
            spineIndex: 0,
            spineHref: 'ch1.xhtml',
            spineCountAtSave: 1,
          ),
          progressFraction: 0.2,
          completed: false,
          lastReadAt: DateTime.utc(2026, 11, 9),
        ),
        progressPercent: 20,
        locationLabel: 'Chapter 1',
        availability: ContinueReadingAvailability.available,
      );

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          metadata: metadata,
          home: Scaffold(
            body: ContinueReadingSection(entries: [entry]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('continue_reading_card_item-continue')));
      await _pumpUntilFound(tester, find.byType(BookReaderScreen));

      expect(find.byType(BookReaderScreen), findsOneWidget);
      expect(find.byType(FolderScreen), findsNothing);
    });
  });
}
