@Tags(['phase62-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_filter_chips.dart';
import 'package:ttsplayer/features/search/widgets/search_result_row.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/screens/player_screen.dart';
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
import 'package:ttsplayer/widgets/tts_media_card.dart';

import 'support/book_comic_catalog_fixtures.dart';

/// Windows runtime validation for M6 Phase 6.2 books/comics browsing.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_62_RUNTIME='1'
/// flutter test test/phase_62_books_comics_windows_runtime_test.dart --tags phase62-runtime
/// ```
///
/// Optional: `PHASE_62_LOCAL_CATALOG` — path to a local `catalog.json`.
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_62_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_62_RUNTIME=1 to run Phase 6.2 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 6.2 runtime validation is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  Catalog loadRuntimeCatalog() {
    final localPath = Platform.environment['PHASE_62_LOCAL_CATALOG'];
    if (localPath != null && localPath.trim().isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Catalog.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
      }
    }
    return Catalog.fromJson(
      jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
    );
  }

  late Catalog catalog;
  late SettingsRepository settings;
  late LibraryMetadataRepository metadata;
  late SearchService search;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    catalog = loadRuntimeCatalog();
    settings = SettingsRepository();
    await settings.initialize();
    metadata = LibraryMetadataRepository();
    await metadata.initialize();
    search = SearchService();
    search.buildIndex(catalog);
  });

  tearDown(() {
    search.invalidateIndex();
  });

  Widget harness({required Widget home, Size size = const Size(1280, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
          ChangeNotifierProvider<SettingsRepository>.value(value: settings),
          ChangeNotifierProvider<LibraryMetadataRepository>.value(
            value: metadata,
          ),
          Provider(
            create: (context) => MediaLocationResolver(
              config: context.read<MediaProviderConfigService>().mediaAccess,
              isWindowsDesktop: true,
            ),
          ),
          Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
          ChangeNotifierProvider<CatalogService>.value(
            value: _InlineCatalogService(catalog),
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
          Provider.value(value: search),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: home,
        ),
      ),
    );
  }

  Future<void> pumpHarness(
    WidgetTester tester, {
    required Widget home,
    Size size = const Size(1280, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(harness(home: home, size: size));
    await tester.pumpAndSettle();
  }

  testWidgets('R1 mixed folder distinguishes books and comics', (tester) async {
    final mixed = catalog.findFolderById('mixed');
    expect(mixed, isNotNull, reason: 'fixture mixed folder required');

    await pumpHarness(tester, home: FolderScreen.fromFolder(mixed!));

    expect(find.byType(TtsMediaCard), findsWidgets);
    expect(find.text('Book'), findsWidgets);
    expect(find.text('Comic'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R2 book/comic filters and keyboard focus', (tester) async {
    final mixed = catalog.findFolderById('mixed')!;
    await pumpHarness(tester, home: FolderScreen.fromFolder(mixed));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('folder_filter_books')));
    await tester.tap(find.byKey(const Key('folder_filter_books')));
    await tester.pumpAndSettle();
    expect(find.text('Mixed Manual'), findsOneWidget);
    expect(find.text('Mixed Issue'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('folder_filter_comics')));
    await tester.tap(find.byKey(const Key('folder_filter_comics')));
    await tester.pumpAndSettle();
    expect(find.text('Mixed Issue'), findsOneWidget);
    expect(find.text('Mixed Manual'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('folder_filter_all')));
    await tester.tap(find.byKey(const Key('folder_filter_all')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('R3 search title/author/series and kind chips', (tester) async {
    await pumpHarness(tester, home: const SearchScreen());

    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(SearchResultRow), findsWidgets);
    expect(find.text('Book'), findsWidgets);

    expect(find.byType(SearchFilterChips), findsOneWidget);
    expect(find.byKey(const ValueKey('search_kind_book')), findsOneWidget);
    expect(find.byKey(const ValueKey('search_kind_comic')), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'City Watch');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Comic'), findsWidgets);

    final bookOnly = search.search(
      'Mixed',
      const SearchFilters(mediaKind: MediaKind.book),
    );
    expect(bookOnly.every((r) => r.item.mediaKind == MediaKind.book), isTrue);
  });

  testWidgets('R4 item detail book stub and comic open do not launch A/V player',
      (tester) async {
    final book = catalog.allItems.firstWhere((i) => i.isBook);
    final comic = catalog.allItems.firstWhere((i) => i.isComic);

    await pumpHarness(tester, home: ItemDetailScreen(item: book));
    expect(find.byKey(const Key('item_detail_reader_pending')), findsOneWidget);
    expect(find.byType(PlayerScreen), findsNothing);

    await pumpHarness(tester, home: ItemDetailScreen(item: comic));
    expect(find.byKey(const Key('item_detail_open_comic')), findsOneWidget);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R5 layout stable at 900x420 and 150% scale', (tester) async {
    final mixed = catalog.findFolderById('mixed')!;
    await pumpHarness(
      tester,
      home: FolderScreen.fromFolder(mixed),
      size: const Size(900, 420),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.5;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 800),
          devicePixelRatio: 1.5,
          textScaler: TextScaler.linear(1.25),
        ),
        child: MultiProvider(
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
            Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
            ChangeNotifierProvider<CatalogService>.value(
              value: _InlineCatalogService(catalog),
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
            Provider.value(value: search),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: FolderScreen.fromFolder(mixed),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('R6 back navigation from detail returns to folder', (tester) async {
    final mixed = catalog.findFolderById('mixed')!;
    await pumpHarness(tester, home: FolderScreen.fromFolder(mixed));

    final card = find.ancestor(
      of: find.text('Mixed Manual'),
      matching: find.byType(TtsMediaCard),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FolderScreen), findsOneWidget);
    expect(find.text('Mixed Manual'), findsOneWidget);
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

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}
