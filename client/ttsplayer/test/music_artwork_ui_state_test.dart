import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_constants.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artists_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/widgets/music_artwork_thumbnail.dart';
import 'package:ttsplayer/features/music/widgets/music_catalog_ui_state.dart';
import 'package:ttsplayer/features/music/widgets/music_list_tiles.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_decode_size.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/widgets/artwork/media_placeholder.dart';

import 'support/phase_56_large_music_catalog_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sanitizeMusicCatalogError', () {
    test('redacts Windows paths and URLs', () {
      expect(
        sanitizeMusicCatalogError(r'Failed reading C:\Media\catalog.json'),
        isNot(contains(r'C:\Media')),
      );
      expect(
        sanitizeMusicCatalogError(
            'Could not fetch https://example.test/c.json'),
        isNot(contains('https://')),
      );
      expect(
        sanitizeMusicCatalogError('Catalogue found but could not be parsed.'),
        'Catalogue found but could not be parsed.',
      );
    });
  });

  group('music display metadata fallbacks', () {
    test('whitespace and missing fields use MusicConstants', () {
      final track = MediaItem(
        id: 't1',
        title: '   ',
        filePath: r'Y:\Music\a.mp3',
        mediaKindRaw: 'audio',
        artist: '  ',
        album: null,
      );
      expect(musicDisplayTitle(track), MusicConstants.unknownTrack);
      expect(musicDisplayArtist(track), MusicConstants.unknownArtist);
      expect(musicDisplayAlbum(track), MusicConstants.unknownAlbum);
    });

    test('albumArtist fills artist when artist missing', () {
      final track = MediaItem(
        id: 't2',
        title: 'Song',
        filePath: r'Y:\Music\a.mp3',
        mediaKindRaw: 'audio',
        albumArtist: 'Comp Artist',
      );
      expect(musicDisplayArtist(track), 'Comp Artist');
    });
  });

  group('MusicArtworkThumbnail', () {
    testWidgets('missing artwork keeps fixed layout and shows placeholder',
        (tester) async {
      final item = MediaItem(
        id: 'no-art',
        title: 'Track',
        filePath: r'Y:\Music\missing\track.mp3',
        mediaKindRaw: 'audio',
      );

      await tester.pumpWidget(
        _artworkHarness(
          child: const Center(
            child: MusicArtworkThumbnail(
              key: Key('thumb'),
              item: null,
              size: 64,
            ),
          ),
          fileExists: (_) => false,
        ),
      );
      await tester.pump();

      final box = tester.getSize(find.byKey(const Key('thumb')));
      expect(box, const Size(64, 64));
      expect(find.byType(MediaPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      // Same box with a real item that cannot resolve artwork.
      await tester.pumpWidget(
        _artworkHarness(
          child: Center(
            child: MusicArtworkThumbnail(
              key: const Key('thumb'),
              item: item,
              size: 64,
            ),
          ),
          fileExists: (_) => false,
        ),
      );
      await tester.pump();
      expect(
          tester.getSize(find.byKey(const Key('thumb'))), const Size(64, 64));
      expect(find.byType(MediaPlaceholder), findsOneWidget);
    });

    testWidgets('invalid path falls back without throwing', (tester) async {
      final item = MediaItem(
        id: 'bad-path',
        title: 'Track',
        filePath: r'Y:\Music\track.mp3',
        mediaKindRaw: 'audio',
        thumbnailPath: r'Y:\Music\does-not-exist.jpg',
      );

      await tester.pumpWidget(
        _artworkHarness(
          child: MusicArtworkThumbnail(item: item, size: 56),
          fileExists: (_) => false,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(MediaPlaceholder), findsOneWidget);
    });

    test('music square decode size matches layout', () {
      expect(ArtworkSurfaceSizes.musicSquareThumbnail(56), const Size(56, 56));
      expect(
          ArtworkSurfaceSizes.musicSquareThumbnail(160), const Size(160, 160));
    });
  });

  group('Music catalog UI states', () {
    testWidgets('loading state is distinct from empty library', (tester) async {
      final catalogService = _FakeCatalogService()..markLoading();

      await tester.pumpWidget(
        _musicHarness(
            catalogService: catalogService, child: const MusicScreen()),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_catalog_loading')), findsOneWidget);
      expect(find.byKey(const Key('music_library_empty')), findsNothing);
    });

    testWidgets('catalogue failure shows sanitized error with retry',
        (tester) async {
      final catalogService = _FakeCatalogService()
        ..setError(r'Could not read C:\Secret\catalog.json');

      await tester.pumpWidget(
        _musicHarness(
            catalogService: catalogService, child: const MusicScreen()),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_catalog_load_error')), findsOneWidget);
      expect(find.textContaining(r'C:\Secret'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('empty music library state is shown', (tester) async {
      final empty = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 0,
        'catalogue': {
          'id': 'EMPTY-AUDIO',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [],
      });
      final catalogService = _FakeCatalogService(empty);

      await tester.pumpWidget(
        _musicHarness(
            catalogService: catalogService, child: const MusicScreen()),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_library_empty')), findsOneWidget);
      expect(find.text('No music in this catalogue.'), findsOneWidget);
    });

    testWidgets('degraded banner when prior catalogue retained after error',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final catalogService = _FakeCatalogService(catalog)
        ..setError('Reload failed; showing previous catalogue.');

      await tester.pumpWidget(
        _musicHarness(
          catalogService: catalogService,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_catalog_degraded_banner')),
          findsOneWidget);
      expect(
        find.byKey(const PageStorageKey<String>('music_artists_list')),
        findsOneWidget,
      );
    });

    testWidgets('invalid album route shows missing empty state',
        (tester) async {
      final catalog = phase56SmallCatalog();
      await tester.pumpWidget(
        _musicHarness(
          catalogService: _FakeCatalogService(catalog),
          child: const MusicAlbumDetailScreen(albumGroupKey: 'missing-album'),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_album_missing')), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });
  });

  group('Artwork rebuild isolation', () {
    testWidgets('playback notify does not recreate artist artwork elements',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final playback = PlaybackService();

      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _musicHarness(
          catalogService: _FakeCatalogService(catalog),
          playback: playback,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pump();

      final before = find.byType(MusicArtworkThumbnail).evaluate().toList();
      expect(before, isNotEmpty);
      final first = before.first;

      playback.notifyListeners();
      await tester.pump();

      final after = find.byType(MusicArtworkThumbnail).evaluate().toList();
      expect(identical(after.first, first), isTrue);
    });
  });
}

Widget _artworkHarness({
  required Widget child,
  required bool Function(String path) fileExists,
}) {
  return MaterialApp(
    home: Provider<ArtworkService>.value(
      value: ArtworkService(fileExists: fileExists),
      child: Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.defaults(),
          isWindowsDesktop: true,
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService([this._catalog]);

  Catalog? _catalog;
  bool _loading = false;
  String? _error;

  void markLoading() {
    _loading = true;
    _catalog = null;
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    _loading = false;
    notifyListeners();
  }

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => _loading;

  @override
  String? get errorMessage => _error;

  @override
  Future<void> refreshCatalogue() async {
    _error = null;
    notifyListeners();
  }
}

Widget _musicHarness({
  required CatalogService catalogService,
  required Widget child,
  PlaybackService? playback,
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
      Provider<MusicLibraryService>.value(value: MusicLibraryService()),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
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
