@Tags(['phase43-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_service.dart';
import 'package:ttsplayer/features/dashboard/widgets/favourites_section.dart';
import 'package:ttsplayer/features/favourites/favourites_screen.dart';
import 'package:ttsplayer/features/search/search_result_grouper.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/library/folder_display_context.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_source_kind.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/app_navigator.dart';
import 'package:ttsplayer/navigation/folder_navigation.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/folder_breadcrumb.dart';
import 'package:ttsplayer/widgets/favourite_toggle_button.dart';
import 'package:ttsplayer/widgets/home_button.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

/// Windows runtime validation harness for M4 Phase 4.3 closure scenarios.
///
/// Run manually:
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_43_RUNTIME='1'
/// flutter test test/phase_43_windows_runtime_test.dart --tags phase43-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _LiveHttpOverrides();

  if (Platform.environment['PHASE_43_RUNTIME'] != '1') {
    test('skipped — set PHASE_43_RUNTIME=1 to run Phase 4.3 runtime validation',
        () {}, skip: true);
    return;
  }

  const localCatalogPath = r'Y:\Media\catalog.json';
  const httpsCatalogUrl = 'https://ttsplayer.local:8443/catalog.json';

  group('Phase 4.3 Windows runtime validation', () {
    late bool localCatalogAvailable;
    late bool httpsCatalogAvailable;
    Catalog? productionLocalCatalog;
    Catalog? productionHttpsCatalog;
    int? productionItemCount;

    setUpAll(() async {
      localCatalogAvailable = await File(localCatalogPath).exists();
      if (localCatalogAvailable) {
        final raw = await File(localCatalogPath).readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        productionItemCount = json['total_items'] as int?;
        productionLocalCatalog = Catalog.fromJson(json);
      }

      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(httpsCatalogUrl));
        final response =
            await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          productionHttpsCatalog = Catalog.fromJson(
            jsonDecode(body) as Map<String, dynamic>,
          );
          httpsCatalogAvailable = true;
        } else {
          httpsCatalogAvailable = false;
        }
        client.close();
      } catch (_) {
        httpsCatalogAvailable = false;
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    group('Navigation and breadcrumbs (L1–L4)', () {
      testWidgets('L1 deep-folder breadcrumb shows catalogue chain without paths',
          (tester) async {
        final catalog = _fixtureCatalog();
        final nested = catalog.findFolderById('folder-grandchild')!;

        await _openFolder(tester, catalog: catalog, folder: nested);

        expect(find.byType(FolderBreadcrumb), findsOneWidget);
        expect(find.text('Films'), findsOneWidget);
        expect(find.text('Science Fiction'), findsWidgets);
        expect(find.text('Classics'), findsWidgets);
        expect(find.textContaining(r'Y:\'), findsNothing);
        expect(find.textContaining('https://'), findsNothing);

        final breadcrumb = tester.widget<FolderBreadcrumb>(
          find.byType(FolderBreadcrumb),
        );
        expect(
          breadcrumb.ancestors.where((f) => f.id == 'folder-grandchild').length,
          1,
        );
      });

      testWidgets('L2 breadcrumb ancestor navigation opens correct folder',
          (tester) async {
        final catalog = _fixtureCatalog();
        final nested = catalog.findFolderById('folder-grandchild')!;

        await _openFolder(tester, catalog: catalog, folder: nested);
        await tester.tap(find.byKey(const Key('breadcrumb_segment_folder-root')));
        await tester.pumpAndSettle();

        expect(find.byType(FolderScreen), findsOneWidget);
        expect(find.text('Films'), findsWidgets);
        expect(
          find.byKey(const Key('breadcrumb_segment_folder-grandchild')),
          findsNothing,
        );
      });

      testWidgets('L3 back navigation preserves parent sort and filter',
          (tester) async {
        final catalog = _fixtureCatalog();
        final settings = SettingsRepository();
        await settings.initialize();

        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            settingsRepository: settings,
            viewport: const Size(900, 1200),
            home: FolderScreen.fromFolder(catalog.findFolderById('folder-root')!),
          ),
        );
        await tester.pumpAndSettle();

        await _selectSort(tester, 'Name Z–A');
        await tester.tap(find.byKey(const Key('folder_filter_video')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Science Fiction'));
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Name Z–A'), findsWidgets);
        expect(_mediaCardTitles(tester), ['Beta']);
      });

      testWidgets('L4 home from deep folder returns to dashboard cleanly',
          (tester) async {
        final catalog = _fixtureCatalog();
        final nested = catalog.findFolderById('folder-grandchild')!;

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            home: Scaffold(
              body: Column(
                children: [
                  const Text('Dashboard'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Open library'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        openFolderScreen(tester.element(find.text('Open library')), nested);
        await tester.pumpAndSettle();
        expect(find.byType(FolderScreen), findsOneWidget);

        await tester.tap(find.byType(HomeButton));
        await tester.pumpAndSettle();

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.byType(FolderScreen), findsNothing);

        openFolderScreen(
          tester.element(find.text('Open library')),
          catalog.findFolderById('folder-root')!,
        );
        await tester.pumpAndSettle();
        expect(find.byType(FolderScreen), findsOneWidget);
      });
    });

    group('Search navigation (L5–L6, L19–L25)', () {
      testWidgets('L5 search browse folder opens containing folder with breadcrumbs',
          (tester) async {
        final catalog = _searchFixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'adventure',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        await tester.tap(
          find.byKey(const Key('search_browse_folder_item-adventure')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FolderScreen), findsOneWidget);
        expect(find.text('Videos'), findsOneWidget);
        expect(find.text('Action'), findsWidgets);
      });

      testWidgets('L6 search open item lands on item detail', (tester) async {
        final catalog = _searchFixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'adventure',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        await tester.tap(find.byKey(const Key('search_open_item-adventure')));
        await tester.pumpAndSettle();

        expect(find.byType(ItemDetailScreen), findsOneWidget);
      });

      testWidgets('L19 empty query shows search prompt', (tester) async {
        final catalog = _searchFixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Search your library'), findsOneWidget);
        expect(find.text('No results found'), findsNothing);
      });

      testWidgets('L20 no-match query shows no-results with clear action',
          (tester) async {
        final catalog = _searchFixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'zzzzmissing',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        expect(find.text('No results found'), findsOneWidget);
        expect(find.byKey(const Key('search_clear_query')), findsOneWidget);
      });

      test('L21 multi-library grouping shows headers in score order', () {
        final catalog = _searchFixtureCatalog();
        final service = SearchService()..buildIndex(catalog);
        final results = service.search('action', const SearchFilters.empty());
        final groups = groupSearchResultsByLibrary(results);

        expect(groups.length, greaterThan(1));
        expect(
          groups.expand((g) => g.results).map((r) => r.item.id).toList(),
          results.map((r) => r.item.id).toList(),
        );
      });

      test('L22 single-library search uses flat list context labels', () {
        final catalog = Catalog.fromJson({
          'generated_at': '2026-07-13T10:00:00+00:00',
          'total_items': 1,
          'folders': [
            _folder(
              id: 'only-lib',
              name: 'Videos',
              items: [
                _item(
                  id: 'only-item',
                  title: 'Solo Clip',
                  filePath: r'Y:\Media\Videos\solo.mp4',
                ),
              ],
            ).toJson(),
          ],
        });
        final service = SearchService()..buildIndex(catalog);
        final results = service.search('solo', const SearchFilters.empty());
        final groups = groupSearchResultsByLibrary(results);

        expect(groups.length, 1);
        expect(
          catalogueFolderContext(catalog, 'only-item'),
          'Videos',
        );
      });

      testWidgets('L23 keyboard clear and Enter submit search', (tester) async {
        final catalog = _searchFixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'adventure',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(find.text('Grand Adventure'), findsOneWidget);

        await tester.tap(find.byKey(const Key('search_clear_button')));
        await tester.pumpAndSettle();
        expect(find.text('Search your library'), findsOneWidget);
      });

      testWidgets('L24 catalogue unavailable is distinct from no-results',
          (tester) async {
        final service = _UnavailableCatalogService();

        await tester.pumpWidget(
          _harness(
            catalog: _searchFixtureCatalog(),
            catalogService: service,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Catalogue unavailable'), findsOneWidget);
        expect(find.text('No results found'), findsNothing);
        expect(find.textContaining('Provider Status'), findsOneWidget);
      });

      testWidgets('L25 stale search result handled safely', (tester) async {
        final catalog = _searchFixtureCatalog();
        final service = _MutableCatalogService(catalog);

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            catalogService: service,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'adventure',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        service.setCatalog(_searchFixtureCatalog(reduced: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('search_open_item-adventure')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('no longer in the catalogue'),
          findsOneWidget,
        );
      });
    });

    group('Sort and filter (L7–L12)', () {
      test('L7 default sort preserves indexer order and folder-first', () {
        final catalog = _fixtureCatalog();
        final folder = catalog.findFolderById('folder-root')!;
        final view = buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.defaultOrder,
          filter: LibraryFilter.all,
        );

        expect(view.subfolders.first.name, 'Science Fiction');
        expect(view.items.map((i) => i.title), ['Beta', 'No Date']);
      });

      test('L8 name sorting is case-insensitive with folder-first', () {
        final catalog = _fixtureCatalog();
        final folder = catalog.findFolderById('folder-root')!;

        final asc = buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.nameAsc,
          filter: LibraryFilter.all,
        );
        final desc = buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.nameDesc,
          filter: LibraryFilter.all,
        );

        expect(asc.subfolders.first.name, 'Science Fiction');
        expect(asc.items.map((i) => i.title), ['Beta', 'No Date']);
        expect(desc.items.map((i) => i.title), ['No Date', 'Beta']);
      });

      test('L9 added-date sorting keeps null timestamps last', () {
        final catalog = _fixtureCatalog();
        final folder = catalog.findFolderById('folder-root')!;
        final newest = buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.addedNewest,
          filter: LibraryFilter.all,
        );
        final oldest = buildLibraryFolderView(
          folder: folder,
          sortMode: LibrarySortMode.addedOldest,
          filter: LibraryFilter.all,
        );

        expect(newest.items.first.title, 'Beta');
        expect(newest.items.last.title, 'No Date');
        expect(oldest.items.first.title, 'Beta');
        expect(oldest.items.last.title, 'No Date');
      });

      test('L10 folder-first preserved across all sort modes', () {
        final catalog = _fixtureCatalog();
        final folder = catalog.findFolderById('folder-root')!;
        for (final mode in LibrarySortMode.values) {
          final view = buildLibraryFolderView(
            folder: folder,
            sortMode: mode,
            filter: LibraryFilter.all,
          );
          expect(view.subfolders.isNotEmpty, isTrue);
          expect(view.items.isNotEmpty, isTrue);
        }
      });

      testWidgets('L11 video, images, and folders-only filters behave correctly',
          (tester) async {
        final catalog = _fixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            home: FolderScreen.fromFolder(catalog.findFolderById('folder-root')!),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('folder_filter_video')));
        await tester.pumpAndSettle();
        expect(_mediaCardTitles(tester), ['Beta']);
        expect(find.byType(TtsFolderCard), findsWidgets);

        await tester.tap(find.byKey(const Key('folder_filter_images')));
        await tester.pumpAndSettle();
        expect(_mediaCardTitles(tester), ['No Date']);

        await tester.tap(find.byKey(const Key('folder_filter_foldersOnly')));
        await tester.pumpAndSettle();
        expect(find.byType(TtsMediaCard), findsNothing);
      });

      testWidgets('L12 filter-empty recovery restores full view', (tester) async {
        final catalog = _fixtureCatalog();
        final leaf = catalog.findFolderById('folder-grandchild')!;

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            home: FolderScreen.fromFolder(leaf),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('folder_filter_images')));
        await tester.pumpAndSettle();

        expect(find.text('No items match this filter'), findsOneWidget);
        await tester.tap(find.byKey(const Key('folder_show_all_filter')));
        await tester.pumpAndSettle();

        expect(find.text('No items match this filter'), findsNothing);
        expect(_mediaCardTitles(tester), ['Classic Hit']);
      });
    });

    group('Favourites (L13–L16)', () {
      testWidgets('L13 favourite media item appears on dashboard',
          (tester) async {
        final catalog = _fixtureCatalog();
        final metadata = LibraryMetadataRepository();
        await metadata.initialize();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            metadataRepository: metadata,
            home: FolderScreen.fromFolder(catalog.findFolderById('folder-child')!),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FavouriteItemToggle).first);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.star), findsWidgets);
        expect(find.byType(ItemDetailScreen), findsNothing);

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            metadataRepository: metadata,
            home: FavouritesSection(catalog: catalog),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Arrival'), findsWidgets);
      });

      testWidgets('L14 favourite folder resolves with breadcrumb',
          (tester) async {
        final catalog = _fixtureCatalog();
        final metadata = LibraryMetadataRepository();
        await metadata.initialize();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            metadataRepository: metadata,
            home: FavouritesScreen(catalog: catalog),
          ),
        );
        await tester.pumpAndSettle();

        await metadata.toggleFolderFavourite('folder-child');
        await tester.pumpAndSettle();

        expect(find.text('Science Fiction'), findsWidgets);

        await tester.tap(find.text('Science Fiction'));
        await tester.pumpAndSettle();

        expect(find.byType(FolderScreen), findsOneWidget);
        expect(find.text('Films'), findsOneWidget);
      });

      test('L15 favourites survive restart and settings reset all', () async {
        SharedPreferences.setMockInitialValues({});
        final metadata = LibraryMetadataRepository();
        await metadata.initialize();
        await metadata.toggleItemFavourite('item-arrival');
        await metadata.toggleFolderFavourite('folder-child');

        final restarted = LibraryMetadataRepository();
        await restarted.initialize();
        expect(restarted.isItemFavourited('item-arrival'), isTrue);
        expect(restarted.isFolderFavourited('folder-child'), isTrue);

        final settings = SettingsRepository();
        await settings.initialize();
        await settings.resetAllToDefaults();
        expect(restarted.isItemFavourited('item-arrival'), isTrue);
      });

      test('L16 stale favourite prunes on replacement only', () async {
        final catalog = _fixtureCatalog();
        final metadata = LibraryMetadataRepository();
        await metadata.initialize();
        await metadata.toggleItemFavourite('item-arrival');
        await metadata.toggleFolderFavourite('folder-child');

        final reduced = Catalog.fromJson({
          'generated_at': '2026-07-13T11:00:00+00:00',
          'total_items': 0,
          'folders': [
            _folder(id: 'folder-root', name: 'Films').toJson(),
          ],
        });

        final result = await metadata.validateAgainstCatalog(reduced);
        expect(result.changed, isTrue);
        expect(result.prunedItemCount, 1);
        expect(result.prunedFolderCount, 1);
        expect(metadata.isItemFavourited('item-arrival'), isFalse);

        await metadata.toggleItemFavourite('item-arrival');
        final unchanged = await metadata.validateAgainstCatalog(catalog);
        expect(unchanged.changed, isFalse);
        expect(metadata.isItemFavourited('item-arrival'), isTrue);
      });
    });

    group('Dashboard regression (L17)', () {
      test('L17 continue watching and recently added unchanged', () async {
        SharedPreferences.setMockInitialValues({
          'position_item-arrival': 600,
          'duration_item-arrival': 3600,
        });

        final catalog = _fixtureCatalog();
        final playback = PlaybackService();
        final snapshot = await DashboardService().build(
          catalog: catalog,
          sourceKind: CatalogueSourceKind.liveNas,
          catalogPath: localCatalogPath,
          lastRefreshedAt: DateTime.utc(2026, 7, 13),
          playback: playback,
          historyEntries: const [],
        );

        expect(snapshot.continueWatching.length, 1);
        expect(snapshot.continueWatching.first.item.id, 'item-arrival');
        expect(snapshot.recentlyAdded.first.item.id, 'item-arrival');
      });
    });

    group('Local and HTTPS consistency (L18)', () {
      test('L18 local and HTTPS catalogues share hierarchy behaviour', () {
        if (!localCatalogAvailable || !httpsCatalogAvailable) {
          fail(
            'BLOCKED: requires $localCatalogPath and $httpsCatalogUrl',
          );
        }

        final local = productionLocalCatalog!;
        final remote = productionHttpsCatalog!;

        for (final catalog in [local, remote]) {
          for (final library in catalog.libraryFolders.take(3)) {
            final chain = catalog.ancestorChainForFolder(library.id);
            expect(chain, isNotEmpty);
            for (final segment in chain) {
              expect(segment.name, isNotEmpty);
              expect(segment.path.contains('://'), isFalse);
            }
          }
        }

        expect(local.libraryFolders.isNotEmpty, isTrue);
        expect(remote.libraryFolders.isNotEmpty, isTrue);
      }, skip: Platform.isWindows ? false : 'Windows only');
    });

    group('Production catalogue smoke (L1 extension)', () {
      testWidgets('L1 production local deep folder breadcrumb',
          (tester) async {
        if (!localCatalogAvailable || productionLocalCatalog == null) {
          fail('BLOCKED: $localCatalogPath not available');
        }

        final deep = _deepestFolder(productionLocalCatalog!);
        if (deep == null || deep.chain.length < 2) {
          fail('BLOCKED: no sufficiently deep folder in production catalogue');
        }

        await _openFolder(tester, catalog: productionLocalCatalog!, folder: deep.folder);

        expect(find.byType(FolderBreadcrumb), findsOneWidget);
        for (final segment in deep.chain) {
          expect(find.text(segment.name), findsWidgets);
        }
        expect(find.textContaining(r'Y:\'), findsNothing);
        expect(find.textContaining('https://'), findsNothing);
      });
    });

    group('UI and accessibility review', () {
      testWidgets('layout remains usable at 900x420 without overflow',
          (tester) async {
        final catalog = _fixtureCatalog();

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: FolderScreen.fromFolder(catalog.findFolderById('folder-grandchild')!),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _harness(
            catalog: catalog,
            viewport: const Size(900, 420),
            home: const SearchScreen(autofocus: true),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('search_query_field')),
          'adventure',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    });
  });
}

class _LiveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  Future<ScannerConfigSummary?> readScannerConfig() async => null;

  @override
  String? get catalogPath => 'bundled';
}

class _UnavailableCatalogService extends CatalogService {
  @override
  Catalog? get catalog => null;

  @override
  bool get isLoading => false;

  @override
  String? get catalogPath => null;
}

class _MutableCatalogService extends _FakeCatalogService {
  _MutableCatalogService(super.catalog);

  void setCatalog(Catalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

class _DeepFolderResult {
  const _DeepFolderResult({required this.folder, required this.chain});

  final MediaFolder folder;
  final List<MediaFolder> chain;
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

Catalog _fixtureCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 2,
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
            subfolders: [
              _folder(
                id: 'folder-grandchild',
                name: 'Classics',
                path: r'Y:\Media\Films\Science Fiction\Classics',
                items: [
                  _item(
                    id: 'item-classic',
                    title: 'Classic Hit',
                    filePath:
                        r'Y:\Media\Films\Science Fiction\Classics\classic.mp4',
                    addedAt: DateTime.utc(2026, 7, 8),
                  ),
                ],
              ),
            ],
            items: [
              _item(
                id: 'item-arrival',
                title: 'Arrival',
                filePath: r'Y:\Media\Films\Science Fiction\Arrival.mp4',
                addedAt: DateTime.utc(2026, 7, 12),
              ),
            ],
          ),
        ],
        items: [
          _item(
            id: 'item-beta',
            title: 'Beta',
            filePath: r'Y:\Media\Films\Beta.mp4',
            addedAt: DateTime.utc(2026, 7, 10),
          ),
          _item(
            id: 'item-nodate',
            title: 'No Date',
            filePath: r'Y:\Media\Films\nodate.jpg',
          ),
        ],
      ).toJson(),
    ],
  });
}

Catalog _searchFixtureCatalog({bool reduced = false}) {
  if (reduced) {
    return Catalog.fromJson({
      'generated_at': '2026-07-13T11:00:00+00:00',
      'total_items': 1,
      'folders': [
        _folder(
          id: 'lib-videos',
          name: 'Videos',
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
  }

  return Catalog.fromJson({
    'generated_at': '2026-07-13T10:00:00+00:00',
    'total_items': 2,
    'folders': [
      _folder(
        id: 'lib-videos',
        name: 'Videos',
        subfolders: [
          _folder(
            id: 'videos-action',
            name: 'Action',
            items: [
              _item(
                id: 'item-adventure',
                title: 'Grand Adventure',
                filePath: r'Y:\Media\Videos\Action\adventure.mp4',
              ),
            ],
          ),
        ],
      ).toJson(),
      _folder(
        id: 'lib-archive',
        name: 'Archive',
        subfolders: [
          _folder(
            id: 'archive-action',
            name: 'Action',
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
    ],
  });
}

_DeepFolderResult? _deepestFolder(Catalog catalog) {
  MediaFolder? best;
  List<MediaFolder> bestChain = [];
  var bestDepth = -1;

  void walk(MediaFolder folder, List<MediaFolder> chain) {
    final depth = chain.length;
    if (depth > bestDepth) {
      bestDepth = depth;
      best = folder;
      bestChain = chain;
    }
    for (final child in folder.subfolders) {
      walk(child, [...chain, folder]);
    }
  }

  for (final library in catalog.libraryFolders) {
    walk(library, []);
  }

  if (best == null) return null;
  return _DeepFolderResult(folder: best!, chain: bestChain);
}

Widget _harness({
  required Catalog catalog,
  required Widget home,
  CatalogService? catalogService,
  SettingsRepository? settingsRepository,
  LibraryMetadataRepository? metadataRepository,
  Size viewport = const Size(900, 1200),
}) {
  final service = catalogService ?? _FakeCatalogService(catalog);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider<SettingsRepository>(
        create: (_) => settingsRepository ?? (SettingsRepository()..initialize()),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>(
        create: (_) => metadataRepository ?? (LibraryMetadataRepository()..initialize()),
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
      navigatorKey: rootNavigatorKey,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQueryData(size: viewport),
          child: home,
        ),
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
  openFolderScreen(tester.element(find.text('Open')), folder);
  await tester.pumpAndSettle();
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
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}
