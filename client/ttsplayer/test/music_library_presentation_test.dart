import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_albums_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artists_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_track_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_tracks_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
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

import 'support/music_catalog_fixtures.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  set stubCatalog(Catalog? value) {
    _catalog = value;
    notifyListeners();
  }

  @override
  bool get isLoading => false;
}

Widget _musicHarness({
  required Catalog catalog,
  required Widget child,
}) {
  SharedPreferences.setMockInitialValues({});
  final catalogService = _FakeCatalogService(catalog);
  final settings = SettingsRepository();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(value: settings),
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
      Provider<MusicLibraryService>.value(value: MusicLibraryService()),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider<PlaybackService>.value(value: PlaybackService()),
      ChangeNotifierProvider<ScannerService>.value(value: ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: ScanHistoryService(),
      ),
      ChangeNotifierProvider<MediaProviderConfigService>(
        create: (_) => MediaProviderConfigService(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

Catalog _mixedCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Music landing', () {
    testWidgets('shows counts and navigation tiles', (tester) async {
      await tester.pumpWidget(
        _musicHarness(catalog: _mixedCatalog(), child: const MusicScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_landing')), findsOneWidget);
      expect(find.textContaining('artists'), findsWidgets);
      expect(find.byKey(const Key('music_nav_Artists')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('empty state when no audio items', (tester) async {
      final videoOnly = Catalog.fromJson({
        'generated_at': '2026-07-19T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {'id': 'VIDEO-ONLY', 'catalogue_version': 3},
        'folders': [
          {
            'id': 'v',
            'name': 'Videos',
            'path': r'Y:\Videos',
            'item_count': 1,
            'items': [
              {
                'id': 'v1',
                'title': 'Clip',
                'file_path': r'Y:\Videos\clip.mp4',
                'media_kind': 'video',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      await tester.pumpWidget(
        _musicHarness(catalog: videoOnly, child: const MusicScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No music in this catalogue.'), findsOneWidget);
    });
  });

  group('Music navigation', () {
    testWidgets('artists list opens artist detail', (tester) async {
      await tester.pumpWidget(
        _musicHarness(catalog: _mixedCatalog(), child: const MusicArtistsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_artists_list')), findsOneWidget);
      await tester.tap(find.text('The Beatles'));
      await tester.pumpAndSettle();

      expect(find.byType(MusicArtistDetailScreen), findsOneWidget);
      expect(find.text('Abbey Road'), findsWidgets);
    });

    testWidgets('album detail shows per-track play actions', (tester) async {
      await tester.pumpWidget(
        _musicHarness(catalog: _mixedCatalog(), child: const MusicAlbumsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_albums_list')), findsOneWidget);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(MusicAlbumDetailScreen), findsOneWidget);
      expect(find.text('Come Together'), findsOneWidget);
      expect(find.byKey(const Key('music_track_play_track-complete')), findsOneWidget);
    });

    testWidgets('track row opens detail without starting playback', (tester) async {
      await tester.pumpWidget(
        _musicHarness(catalog: _mixedCatalog(), child: const MusicTracksScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Come Together'));
      await tester.pumpAndSettle();

      expect(find.byType(MusicTrackDetailScreen), findsOneWidget);
      expect(find.byType(MusicPlayerScreen), findsNothing);
      expect(find.byKey(const Key('music_track_play_track-complete')), findsOneWidget);
    });

    testWidgets('catalogue replacement rebuilds landing counts', (tester) async {
      final catalogService = _FakeCatalogService(_mixedCatalog());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsRepository>(
              create: (_) => SettingsRepository(),
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
            Provider<MusicLibraryService>.value(value: MusicLibraryService()),
            ChangeNotifierProvider<CatalogService>.value(value: catalogService),
            ChangeNotifierProvider<PlaybackService>.value(value: PlaybackService()),
            ChangeNotifierProvider<ScannerService>.value(value: ScannerService()),
            ChangeNotifierProvider<ScanHistoryService>.value(
              value: ScanHistoryService(),
            ),
            ChangeNotifierProvider<MediaProviderConfigService>(
              create: (_) => MediaProviderConfigService(),
            ),
          ],
          child: const MaterialApp(home: MusicScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('tracks'), findsWidgets);

      catalogService.stubCatalog = Catalog.fromJson({
        'generated_at': '2026-07-19T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {'id': 'REPLACED', 'catalogue_version': 3},
        'folders': [
          {
            'id': 'music',
            'name': 'Music',
            'path': r'Y:\Music',
            'item_count': 1,
            'items': [
              {
                'id': 'only',
                'title': 'Solo',
                'file_path': r'Y:\Music\solo.mp3',
                'media_kind': 'audio',
                'artist': 'Solo Artist',
                'artist_group_key': 'solo artist',
              },
            ],
            'subfolders': [],
          },
        ],
      });
      await tester.pumpAndSettle();

      expect(find.text('1 artists · 1 albums · 1 tracks'), findsOneWidget);
    });
  });

  group('Dashboard music entry', () {
    testWidgets('shows music section when catalogue has audio', (tester) async {
      final catalogService = _FakeCatalogService(_mixedCatalog());
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CatalogService>.value(value: catalogService),
            Provider<MusicLibraryService>.value(value: MusicLibraryService()),
            ChangeNotifierProvider<MediaProviderConfigService>(
              create: (_) => MediaProviderConfigService(),
            ),
            ChangeNotifierProvider<SettingsRepository>(
              create: (_) => SettingsRepository(),
            ),
            ChangeNotifierProvider<LibraryMetadataRepository>(
              create: (_) => LibraryMetadataRepository(),
            ),
            ChangeNotifierProvider<ScannerService>(
              create: (_) => ScannerService(),
            ),
            ChangeNotifierProvider<ScanHistoryService>(
              create: (_) => ScanHistoryService(),
            ),
            ChangeNotifierProvider<PlaybackService>(
              create: (_) => PlaybackService(),
            ),
            Provider<SearchService>.value(value: SearchService()),
            Provider<ArtworkService>.value(
              value: ArtworkService(fileExists: (_) => false),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Consumer<CatalogService>(
                    builder: (context, svc, _) {
                      final cat = svc.catalog!;
                      final projection = context
                          .read<MusicLibraryService>()
                          .projectionFor(cat);
                      return Text('tracks:${projection.trackCount}');
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('tracks:'), findsOneWidget);
    });
  });
}
