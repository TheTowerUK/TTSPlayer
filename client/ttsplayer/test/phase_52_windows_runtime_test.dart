@Tags(['phase52-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/widgets/music_section.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/screens/music_track_detail_screen.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
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

import 'support/large_music_catalog_factory.dart';
import 'support/catalog_cache_test_support.dart';
import 'support/music_catalog_fixtures.dart';

/// Windows runtime validation harness for M5 Phase 5.2 music library browsing.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_52_RUNTIME='1'
/// flutter test test/phase_52_windows_runtime_test.dart --tags phase52-runtime
/// ```
///
/// Optional: `PHASE_52_LOCAL_CATALOG` — path to a local `catalog.json` (not required).
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_52_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_52_RUNTIME=1 to run Phase 5.2 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.2 runtime validation is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  Catalog loadRuntimeCatalog() {
    final localPath = Platform.environment['PHASE_52_LOCAL_CATALOG'];
    if (localPath != null && localPath.trim().isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Catalog.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
      }
    }

    return buildLargeMusicCatalog(
      artistCount: smallMusicArtistCount,
      albumsPerArtist: smallMusicAlbumsPerArtist,
      tracksPerAlbum: smallMusicTracksPerAlbum,
      catalogueIdentity: 'PHASE52-RUNTIME',
    );
  }

  group('Phase 5.2 Windows runtime validation', () {
    late Catalog mixedCatalog;
    late MusicLibraryService musicLibrary;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mixedCatalog = loadRuntimeCatalog();
      musicLibrary = MusicLibraryService();
    });

    Widget harness({required Widget home, Catalog? catalog}) {
      final cat = catalog ?? mixedCatalog;
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
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
          Provider<SearchService>.value(value: SearchService()),
          Provider<MusicLibraryService>.value(value: musicLibrary),
          ChangeNotifierProvider<CatalogService>.value(
            value: _InlineCatalogService(cat),
          ),
          ChangeNotifierProvider(
            create: (context) => PlaybackService(
              mediaLocationResolver: context.read<MediaLocationResolver>(),
            ),
          ),
          ChangeNotifierProvider(create: (_) => ScannerService()),
          ChangeNotifierProvider(create: (_) => ScanHistoryService()),
          ChangeNotifierProvider(
            create: (_) => SettingsRepository()..initialize(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: home),
      );
    }

    testWidgets('R1 music landing shows counts and navigation', (tester) async {
      await tester.pumpWidget(harness(home: const MusicScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_landing')), findsOneWidget);
      expect(find.byKey(const Key('music_nav_Artists')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('R2 artists navigation and detail', (tester) async {
      await tester.pumpWidget(harness(home: const MusicScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();

      expect(find.byKey(const PageStorageKey<String>('music_artists_list')), findsOneWidget);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(MusicArtistDetailScreen), findsOneWidget);
    });

    testWidgets('R3 album detail shows ordered tracks without play controls',
        (tester) async {
      final projection = musicLibrary.projectionFor(mixedCatalog);
      final albumKey = projection.albums.first.groupKey;

      await tester.pumpWidget(
        harness(home: MusicAlbumDetailScreen(albumGroupKey: albumKey)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MusicAlbumDetailScreen), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('R4 track detail is read-only', (tester) async {
      final trackId = musicLibrary.projectionFor(mixedCatalog).tracks.first.id;

      await tester.pumpWidget(
        harness(home: MusicTrackDetailScreen(trackId: trackId)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('music_track_detail_$trackId')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('R5 dashboard music entry visible when audio exists',
        (tester) async {
      await tester.pumpWidget(
        harness(home: const Scaffold(body: MusicSection())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_music_entry')), findsOneWidget);
    });

    testWidgets('R6 search audio result opens read-only track detail',
        (tester) async {
      final metadataCatalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        harness(
          catalog: metadataCatalog,
          home: const SearchScreen(autofocus: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_query_field')),
        'Together',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('Audio'), findsWidgets);
      await tester.tap(find.byKey(const Key('search_open_track-complete')));
      await tester.pumpAndSettle();

      expect(find.byType(MusicTrackDetailScreen), findsOneWidget);
      expect(find.byType(ItemDetailScreen), findsNothing);
    });

    testWidgets('R7 catalogue replacement invalidates projection', (tester) async {
      final artwork = ArtworkService(fileExists: (_) => false);
      final search = SearchService();
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
        musicLibraryService: musicLibrary,
      );

      final first = buildLargeMusicCatalog(
        artistCount: 2,
        albumsPerArtist: 1,
        tracksPerAlbum: 2,
        catalogueIdentity: 'PHASE52-A',
      );
      musicLibrary.projectionFor(first);
      expect(musicLibrary.hasCachedProjectionFor('PHASE52-A'), isTrue);

      coordinator.onCatalogReplaced(first);
      expect(musicLibrary.hasCachedProjectionFor('PHASE52-A'), isFalse);
    });

    testWidgets('R8 mixed fixture unknown metadata remains browsable',
        (tester) async {
      final metadataCatalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        harness(catalog: metadataCatalog, home: const MusicScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('artists'), findsWidgets);
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();

      expect(find.text('Unknown Artist'), findsWidgets);
      expect(find.text('The Beatles'), findsOneWidget);
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
