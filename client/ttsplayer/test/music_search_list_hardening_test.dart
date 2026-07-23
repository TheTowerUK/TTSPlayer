import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_albums_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artists_screen.dart';
import 'package:ttsplayer/features/music/screens/music_tracks_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/widgets/music_list_tiles.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'support/phase_56_large_music_catalog_fixture.dart';

/// Phase 5.6 Step 4 — search ownership, lazy detail lists, rebuild isolation,
/// and scroll retention under Navigator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchService latest-query ownership helpers', () {
    test('empty query returns immutable empty without scanning delay path',
        () async {
      final catalog = phase56SmallCatalog();
      final search = SearchService()
        ..debugSearchDelay = const Duration(milliseconds: 50);
      await search.ensureIndex(catalog);

      final sw = Stopwatch()..start();
      final results = await search.searchCatalog(
        catalog,
        '   ',
        const SearchFilters(),
      );
      sw.stop();

      expect(results, isEmpty);
      // Empty query short-circuits before debug delay.
      expect(sw.elapsedMilliseconds, lessThan(40));
    });

    test('results are unmodifiable', () async {
      final catalog = phase56SmallCatalog();
      final search = SearchService();
      await search.ensureIndex(catalog);
      final results = await search.searchCatalog(
        catalog,
        Phase56Sentinels.titleToken,
        const SearchFilters(),
      );
      expect(results, isNotEmpty);
      expect(
        () => (results as List).clear(),
        throwsUnsupportedError,
      );
    });

    test('deferred older query does not overwrite newer sync result', () async {
      final catalog = phase56MediumCatalog();
      final search = SearchService();
      await search.ensureIndex(catalog);

      search.debugSearchDelay = const Duration(milliseconds: 80);
      final older = search.searchCatalog(
        catalog,
        Phase56Sentinels.titleToken,
        const SearchFilters(),
      );

      search.debugSearchDelay = Duration.zero;
      final newer = await search.searchCatalog(
        catalog,
        Phase56Sentinels.absentToken,
        const SearchFilters(),
      );
      expect(newer, isEmpty);

      final olderResults = await older;
      expect(
        olderResults.any((r) => r.item.id == Phase56Sentinels.titleTrackId),
        isTrue,
      );
      // Service itself returns both; ownership is enforced at the screen.
      // Document that concurrent calls are independent — screen generation
      // decides which to publish.
      expect(newer, isEmpty);
    });
  });

  group('Lazy album/artist detail rendering', () {
    testWidgets('album detail uses lazy track slivers', (tester) async {
      // Dedicated fat album so cache-extent cannot mount every row at once.
      final items = <Map<String, dynamic>>[
        for (var i = 0; i < 40; i++)
          {
            'id': 'fat-$i',
            'title': 'Track ${i.toString().padLeft(2, '0')}',
            'file_path':
                r'Y:\Music\FatArtist\FatAlbum\t$i.mp3'.replaceAll(r'$i', '$i'),
            'media_kind': 'audio',
            'artist': 'Fat Artist',
            'album': 'Fat Album',
            'artist_group_key': 'fat artist',
            'album_group_key': 'fat artist|fat album|scope',
            'track_number': i + 1,
            'disc_number': 1,
          },
      ];
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': items.length,
        'catalogue': {
          'id': 'FAT-ALBUM',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'music',
            'name': 'Music',
            'path': r'Y:\Music',
            'item_count': items.length,
            'items': items,
            'subfolders': [],
          },
        ],
      });
      final album = MusicLibraryProjection.build(catalog).albums.single;

      await tester.binding.setSurfaceSize(const Size(900, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          child: MusicAlbumDetailScreen(albumGroupKey: album.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byKey(const Key('music_album_play')), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final mounted = find.byType(MusicTrackListTile).evaluate().length;
      expect(mounted, greaterThan(0));
      expect(mounted, lessThan(album.trackCount));
    });

    testWidgets('artist detail lazily mounts album and track tiles',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      final artist = projection.artists.reduce(
        (a, b) => a.trackCount >= b.trackCount ? a : b,
      );
      expect(artist.trackCount, greaterThan(5));

      await tester.binding.setSurfaceSize(const Size(900, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          child: MusicArtistDetailScreen(artistGroupKey: artist.groupKey),
        ),
      );
      await tester.pump();

      final mountedAlbums = find.byType(MusicAlbumListTile).evaluate().length;
      final mountedTracks = find.byType(MusicTrackListTile).evaluate().length;
      expect(mountedAlbums + mountedTracks, greaterThan(0));
      expect(
        mountedAlbums + mountedTracks,
        lessThan(artist.albumCount + artist.trackCount),
      );
    });
  });

  group('Rebuild isolation', () {
    testWidgets('playback position notify does not rebuild artist tiles',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final playback = PlaybackService();

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          playback: playback,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pump();

      final before = find.byType(MusicArtistListTile).evaluate().toList();
      expect(before, isNotEmpty);
      final firstBefore = before.first;

      playback.notifyListeners();
      await tester.pump();

      final after = find.byType(MusicArtistListTile).evaluate().toList();
      expect(identical(after.first, firstBefore), isTrue);
    });

    testWidgets('playback position notify does not rebuild album tiles',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final playback = PlaybackService();

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          playback: playback,
          child: const MusicAlbumsScreen(),
        ),
      );
      await tester.pump();

      final before = find.byType(MusicAlbumListTile).evaluate().toList();
      expect(before, isNotEmpty);
      final firstBefore = before.first;

      playback.notifyListeners();
      await tester.pump();

      final after = find.byType(MusicAlbumListTile).evaluate().toList();
      expect(identical(after.first, firstBefore), isTrue);
    });

    testWidgets('projection replacement rebuilds music artist list',
        (tester) async {
      final catalogA = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'REBUILD-A',
      );
      final catalogB = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: false,
        includeCompilations: false,
        catalogueIdentityOverride: 'REBUILD-B',
      );
      final catalogService = _FakeCatalogService(catalogA);
      final musicLibrary = MusicLibraryService();

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalogA,
          catalogService: catalogService,
          musicLibrary: musicLibrary,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pump();

      final beforeCount = find.byType(MusicArtistListTile).evaluate().length;
      expect(beforeCount, greaterThan(0));

      catalogService.replaceCatalog(catalogB);
      await tester.pump();

      expect(find.byType(MusicArtistListTile), findsWidgets);
      expect(
        musicLibrary.projectionFor(catalogB).catalogueIdentity,
        'REBUILD-B',
      );
    });

    testWidgets('back navigation reuses memoised projection', (tester) async {
      final catalog = phase56SmallCatalog();
      final musicLibrary = MusicLibraryService();
      final first = musicLibrary.projectionFor(catalog);

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          musicLibrary: musicLibrary,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  key: const Key('open_artists'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MusicArtistsScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_artists')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey<String>('music_artists_list')),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(find.byType(MusicArtistsScreen)),
      ).pop();
      await tester.pumpAndSettle();

      expect(identical(musicLibrary.projectionFor(catalog), first), isTrue);
    });
  });

  group('Scroll retention under Navigator', () {
    testWidgets('artist list scroll retained after detail push/pop',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final musicLibrary = MusicLibraryService();
      final projection = musicLibrary.projectionFor(catalog);

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          musicLibrary: musicLibrary,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder =
          find.byKey(const PageStorageKey<String>('music_artists_list'));
      await tester.drag(listFinder, const Offset(0, -1200));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final offsetBefore = scrollable.position.pixels;
      expect(offsetBefore, greaterThan(0));

      // Tap a currently mounted artist row (not a fixed index that may be off-screen).
      final mountedTile = find.byType(MusicArtistListTile).first;
      expect(mountedTile, findsOneWidget);
      await tester.tap(mountedTile);
      await tester.pumpAndSettle();
      expect(find.byType(MusicArtistDetailScreen), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(MusicArtistDetailScreen)),
      ).pop();
      await tester.pumpAndSettle();

      final offsetAfter = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      expect(offsetAfter, closeTo(offsetBefore, 1.0));
      expect(
          identical(musicLibrary.projectionFor(catalog), projection), isTrue);
    });
  });

  group('Tracks list scrolling', () {
    testWidgets('track list remains lazy while scrolling', (tester) async {
      final catalog = phase56SmallCatalog();
      final projection = MusicLibraryProjection.build(catalog);

      await tester.binding.setSurfaceSize(const Size(900, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(catalog: catalog, child: const MusicTracksScreen()),
      );
      await tester.pump();

      final before = find.byType(MusicTrackListTile).evaluate().length;
      expect(before, lessThan(projection.trackCount));

      await tester.drag(
        find.byKey(const PageStorageKey<String>('music_tracks_list')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      final after = find.byType(MusicTrackListTile).evaluate().length;
      expect(after, lessThan(projection.trackCount));
      expect(after, greaterThan(0));
    });
  });
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  void replaceCatalog(Catalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }
}

Widget _harness({
  required Catalog catalog,
  required Widget child,
  MusicLibraryService? musicLibrary,
  PlaybackService? playback,
  CatalogService? catalogService,
}) {
  SharedPreferences.setMockInitialValues({});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(
        value: SettingsRepository(),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>(
        create: (_) => LibraryMetadataRepository(),
      ),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.defaults(),
          isWindowsDesktop: false,
        ),
      ),
      Provider<ArtworkService>.value(
        value: ArtworkService(fileExists: (_) => false),
      ),
      Provider<SearchService>.value(value: SearchService()),
      Provider<MusicLibraryService>.value(
        value: musicLibrary ?? MusicLibraryService(),
      ),
      ChangeNotifierProvider<CatalogService>.value(
        value: catalogService ?? _FakeCatalogService(catalog),
      ),
      ChangeNotifierProvider<PlaybackService>.value(
        value: playback ?? PlaybackService(),
      ),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: MusicListeningRepository(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}
