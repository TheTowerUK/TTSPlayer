import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/models/search_result.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_filter_chips.dart';
import 'package:ttsplayer/features/search/widgets/search_result_row.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/artwork/library_visual_kind.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/utils/media_kind_presentation.dart';
import 'package:ttsplayer/widgets/folder_browse_controls.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/book_comic_catalog_fixtures.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

Widget _harness({
  required Catalog catalog,
  required Widget home,
  Size viewport = const Size(1280, 800),
  PlaybackService? playback,
  SettingsRepository? settings,
  LibraryMetadataRepository? metadata,
}) {
  final catalogService = _FakeCatalogService(catalog);
  return MediaQuery(
    data: MediaQueryData(size: viewport),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
        ChangeNotifierProvider<SettingsRepository>.value(
          value: settings ?? SettingsRepository(),
        ),
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: metadata ?? LibraryMetadataRepository(),
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
          create: (context) =>
              playback ??
              PlaybackService(
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
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: home,
      ),
    ),
  );
}

Catalog _catalog() => Catalog.fromJson(
      jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
    );

late SettingsRepository _settings;
late LibraryMetadataRepository _metadata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _settings = SettingsRepository();
    await _settings.initialize();
    _metadata = LibraryMetadataRepository();
    await _metadata.initialize();
  });

  group('MediaKindPresentation', () {
    test('labels and icons distinguish books and comics', () {
      expect(MediaKindPresentation.label(MediaKind.book), 'Book');
      expect(MediaKindPresentation.label(MediaKind.comic), 'Comic');
      expect(
        MediaKindPresentation.icon(MediaKind.book),
        Icons.menu_book_outlined,
      );
      expect(
        MediaKindPresentation.icon(MediaKind.comic),
        Icons.auto_stories_outlined,
      );
      expect(
        MediaKindPresentation.visualKind(MediaKind.book),
        LibraryVisualKind.literature,
      );
      expect(
        MediaKindPresentation.visualKind(MediaKind.comic),
        LibraryVisualKind.comics,
      );
    });
  });

  group('Artwork placeholders', () {
    test('pdf/epub map to literature; cbz maps to comics', () {
      final artwork = ArtworkService(fileExists: (_) => false);
      expect(
        artwork.visualKindForExtension('pdf'),
        LibraryVisualKind.literature,
      );
      expect(
        artwork.visualKindForExtension('epub'),
        LibraryVisualKind.literature,
      );
      expect(artwork.visualKindForExtension('cbz'), LibraryVisualKind.comics);
      expect(artwork.visualKindForExtension('cbr'), LibraryVisualKind.unknown);
    });
  });

  group('Folder filters', () {
    test('books and comics filters isolate mixed folder items', () {
      final catalog = _catalog();
      final mixed = catalog.findFolderById('mixed')!;

      final books = buildLibraryFolderView(
        folder: mixed,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.books,
      );
      expect(books.items, hasLength(1));
      expect(books.items.single.mediaKind, MediaKind.book);

      final comics = buildLibraryFolderView(
        folder: mixed,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.comics,
      );
      expect(comics.items, hasLength(1));
      expect(comics.items.single.mediaKind, MediaKind.comic);

      final video = buildLibraryFolderView(
        folder: mixed,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.video,
      );
      expect(video.items.every((i) => i.isVideo), isTrue);
      expect(video.items.any((i) => i.isBook || i.isComic), isFalse);
    });

    test('type sort remains deterministic for mixed kinds', () {
      final catalog = _catalog();
      final mixed = catalog.findFolderById('mixed')!;
      final view = buildLibraryFolderView(
        folder: mixed,
        sortMode: LibrarySortMode.type,
        filter: LibraryFilter.all,
      );
      final again = buildLibraryFolderView(
        folder: mixed,
        sortMode: LibrarySortMode.type,
        filter: LibraryFilter.all,
      );
      expect(
        view.items.map((i) => i.id).toList(),
        again.items.map((i) => i.id).toList(),
      );
    });
  });

  group('Media cards', () {
    testWidgets('book and comic cards show kind labels', (tester) async {
      final catalog = _catalog();
      final book = catalog.allItems.firstWhere((i) => i.id == 'book-epub');
      final comic = catalog.allItems.firstWhere((i) => i.id == 'comic-cbz');

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 200,
                  height: 280,
                  child: TtsMediaCard(item: book, onTap: () {}),
                ),
                SizedBox(
                  width: 200,
                  height: 280,
                  child: TtsMediaCard(item: comic, onTap: () {}),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book'), findsWidgets);
      expect(find.text('Comic'), findsWidgets);
      expect(find.textContaining('Ada Lovelace'), findsOneWidget);
      expect(find.textContaining('City Watch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Search presentation', () {
    testWidgets('kind chips include Books and Comics', (tester) async {
      SearchFilters filters = const SearchFilters.empty();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SearchFilterChips(
              libraryNames: const ['Media'],
              extensions: const ['pdf', 'cbz', 'mp4'],
              availableMediaKinds: const [
                MediaKind.video,
                MediaKind.book,
                MediaKind.comic,
              ],
              filters: filters,
              resultCount: 0,
              queryActive: false,
              onFiltersChanged: (next) => filters = next,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search_kind_book')), findsOneWidget);
      expect(find.byKey(const ValueKey('search_kind_comic')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search_kind_book')));
      await tester.pumpAndSettle();
      expect(filters.mediaKind, MediaKind.book);
    });

    testWidgets('search rows label books and comics', (tester) async {
      final catalog = _catalog();
      final book = catalog.allItems.firstWhere((i) => i.id == 'book-epub');
      final comic = catalog.allItems.firstWhere((i) => i.id == 'comic-cbz');

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: Scaffold(
            body: ListView(
              children: [
                SearchResultRow(
                  result: SearchResult(
                    item: book,
                    score: 10,
                    libraryName: 'Media',
                    parentFolderPath: r'Y:\Media\Books',
                    parentFolderName: 'Books',
                  ),
                  displayContext: 'Media / Books',
                  onOpen: () {},
                ),
                SearchResultRow(
                  result: SearchResult(
                    item: comic,
                    score: 10,
                    libraryName: 'Media',
                    parentFolderPath: r'Y:\Media\Comics',
                    parentFolderName: 'Comics',
                  ),
                  displayContext: 'Media / Comics',
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book'), findsOneWidget);
      expect(find.text('Comic'), findsOneWidget);
      expect(find.byKey(Key('search_play_${book.id}')), findsNothing);
      expect(find.byKey(Key('search_play_${comic.id}')), findsNothing);
    });
  });

  group('Item detail', () {
    testWidgets('book detail shows metadata and open book action',
        (tester) async {
      final catalog = _catalog();
      final book = catalog.allItems.firstWhere((i) => i.id == 'book-epub');

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: ItemDetailScreen(item: book),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book'), findsWidgets);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('EPUB'), findsOneWidget);
      expect(find.byKey(const Key('item_detail_open_book')), findsOneWidget);
      expect(find.byKey(const Key('item_detail_reader_pending')), findsNothing);
      expect(find.byType(PlayerScreen), findsNothing);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('comic detail shows series, archive type, and open action',
        (tester) async {
      final catalog = _catalog();
      final comic = catalog.allItems.firstWhere((i) => i.id == 'comic-cbz');

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          home: ItemDetailScreen(item: comic),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comic'), findsWidgets);
      expect(find.text('City Watch'), findsOneWidget);
      expect(find.text('22 pages'), findsOneWidget);
      expect(find.text('ZIP archive'), findsOneWidget);
      expect(find.byKey(const Key('item_detail_open_comic')), findsOneWidget);
      expect(find.byKey(const Key('item_detail_reader_pending')), findsNothing);
      expect(find.byType(PlayerScreen), findsNothing);
    });
  });

  group('A/V isolation', () {
    test('PlaybackService refuses book and comic play', () async {
      final catalog = _catalog();
      final book = catalog.allItems.firstWhere((i) => i.id == 'book-pdf');
      final comic = catalog.allItems.firstWhere((i) => i.id == 'comic-cbr');
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.defaults(),
        isWindowsDesktop: false,
      );
      final playback = PlaybackService(mediaLocationResolver: resolver);

      await playback.play(book);
      expect(playback.currentItem, isNull);
      expect(playback.errorMessage, contains('not playable'));

      await playback.play(comic);
      expect(playback.currentItem, isNull);
    });
  });

  group('Folder UI', () {
    testWidgets('mixed folder shows all kinds and filter chips', (tester) async {
      final catalog = _catalog();
      final mixed = catalog.findFolderById('mixed')!;

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          settings: _settings,
          metadata: _metadata,
          viewport: const Size(1400, 900),
          home: FolderScreen.fromFolder(mixed),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FolderBrowseControls), findsOneWidget);
      expect(find.byKey(const Key('folder_filter_books')), findsOneWidget);
      expect(find.byKey(const Key('folder_filter_comics')), findsOneWidget);
      expect(find.text('Mixed Manual'), findsOneWidget);
      expect(find.text('Mixed Issue'), findsOneWidget);
      expect(find.text('Mixed Clip'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('folder_filter_books')));
      await tester.tap(find.byKey(const Key('folder_filter_books')));
      await tester.pumpAndSettle();
      expect(find.text('Mixed Manual'), findsOneWidget);
      expect(find.text('Mixed Issue'), findsNothing);
      expect(find.text('Mixed Clip'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('folder_filter_comics')));
      await tester.tap(find.byKey(const Key('folder_filter_comics')));
      await tester.pumpAndSettle();
      expect(find.text('Mixed Issue'), findsOneWidget);
      expect(find.text('Mixed Manual'), findsNothing);
    });

    testWidgets('books filter empty state offers show all', (tester) async {
      final catalog = _catalog();
      final videos = catalog.findFolderById('videos')!;

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          settings: _settings,
          metadata: _metadata,
          home: FolderScreen.fromFolder(videos),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('folder_filter_books')));
      await tester.pumpAndSettle();
      expect(find.text('No items match this filter'), findsOneWidget);
      expect(find.byKey(const Key('folder_show_all_filter')), findsOneWidget);
    });

    testWidgets('filter chips remain keyboard reachable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
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
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('folder_filter_books')), findsOneWidget);
      expect(find.byKey(const Key('folder_filter_comics')), findsOneWidget);
    });
  });
}
