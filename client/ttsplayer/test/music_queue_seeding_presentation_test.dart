import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/music_navigation.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_track_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_tracks_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'playback_service_extensions_test.dart';
import 'support/music_catalog_fixtures.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;
}

PlaybackService _stubService() {
  return PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      final fake = FakePlaybackSessionControls();
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
      final item = service.currentItem;
      if (item != null) {
        service.simulateReadyForTest(item);
        service.simulatePlaybackMetricsForTest(
          duration: const Duration(minutes: 3),
          position: Duration.zero,
        );
      }
    },
  );
}

Widget _harness({
  required Catalog catalog,
  required PlaybackService playback,
  required MusicPlaybackQueueController queue,
  required Widget home,
}) {
  SharedPreferences.setMockInitialValues({});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsRepository()),
      ChangeNotifierProvider(create: (_) => LibraryMetadataRepository()),
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
      ChangeNotifierProvider<CatalogService>.value(
        value: _FakeCatalogService(catalog),
      ),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(value: queue),
      ChangeNotifierProvider(create: (_) => ScannerService()),
      ChangeNotifierProvider(create: (_) => ScanHistoryService()),
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pumpPlayerReady(
  WidgetTester tester,
  PlaybackService playback,
  MusicPlaybackQueueController queue,
) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final track = queue.currentTrack;
  if (track != null) {
    playback.simulateReadyForTest(track);
    playback.simulatePlaybackMetricsForTest(
      duration: const Duration(minutes: 3),
      position: Duration.zero,
    );
    playback.notifyListeners();
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late Catalog queueCatalog;
  late MusicLibraryService library;

  setUp(() {
    catalog = Catalog.fromJson(
      jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
    );
    queueCatalog = Catalog.fromJson(
      jsonDecode(kCatalogV3QueueSeedingFixture) as Map<String, dynamic>,
    );
    library = MusicLibraryService();
  });

  group('Album detail queue seeding', () {
    testWidgets('Play album action appears with accessible label', (tester) async {
      final album = library.projectionFor(queueCatalog).albums
          .firstWhere((a) => a.displayTitle == 'First Album');
      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: _stubService(),
          queue: MusicPlaybackQueueController(playbackService: _stubService()),
          home: MusicAlbumDetailScreen(albumGroupKey: album.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_album_play')), findsOneWidget);
      final semantics = tester.getSemantics(find.byKey(const Key('music_album_play')));
      expect(semantics.label, 'Play album First Album');
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
    });

    testWidgets('Play album seeds ordered queue and opens player', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final album = library.projectionFor(queueCatalog).albums
          .firstWhere((a) => a.displayTitle == 'First Album');

      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: playback,
          queue: queue,
          home: MusicAlbumDetailScreen(albumGroupKey: album.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_album_play')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(find.byType(MusicPlayerScreen), findsOneWidget);
      expect(queue.queue.length, 3);
      expect(queue.currentTrack?.id, 'qa-t1');
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Album · First Album'), findsOneWidget);
    });

    testWidgets('Album track play seeds full album at selected index', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final album = library.projectionFor(queueCatalog).albums
          .firstWhere((a) => a.displayTitle == 'First Album');

      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: playback,
          queue: queue,
          home: MusicAlbumDetailScreen(albumGroupKey: album.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      final playSemantics = tester.getSemantics(
        find.byKey(const Key('music_track_play_qa-t1')),
      );
      expect(playSemantics.label, 'Play First Track from album');

      await tester.tap(find.byKey(const Key('music_track_play_qa-t2')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(queue.queue.length, 3);
      expect(queue.currentTrack?.id, 'qa-t2');
      expect(find.text('2 of 3'), findsOneWidget);
    });
  });

  group('Artist detail queue seeding', () {
    testWidgets('Play artist action appears with accessible label', (tester) async {
      final artist = library.projectionFor(queueCatalog).artists
          .firstWhere((a) => a.displayName == 'Queue Artist');

      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: _stubService(),
          queue: MusicPlaybackQueueController(playbackService: _stubService()),
          home: MusicArtistDetailScreen(artistGroupKey: artist.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_artist_play')), findsOneWidget);
      final semantics = tester.getSemantics(find.byKey(const Key('music_artist_play')));
      expect(semantics.label, 'Play artist Queue Artist');
    });

    testWidgets('Artist track play seeds full artist queue', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final artist = library.projectionFor(queueCatalog).artists
          .firstWhere((a) => a.displayName == 'Queue Artist');

      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: playback,
          queue: queue,
          home: MusicArtistDetailScreen(artistGroupKey: artist.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_track_play_qb-t1')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(queue.queue.length, 5);
      expect(queue.currentTrack?.id, 'qb-t1');
      expect(queue.queueSource?.kind.name, 'artist');
      expect(find.byKey(const Key('music_player_queue_source')), findsOneWidget);
      expect(find.text('Artist · Queue Artist'), findsOneWidget);
    });
  });

  group('Ungrouped single-track contexts', () {
    testWidgets('Global tracks play creates one-item queue', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          playback: playback,
          queue: queue,
          home: const MusicTracksScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_track_play_track-complete')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(queue.queue.length, 1);
      expect(find.text('1 of 2'), findsNothing);
    });

    testWidgets('Search play creates one-item queue', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          playback: playback,
          queue: queue,
          home: const SearchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Come Together');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      await tester.tap(find.byKey(const Key('search_play_track-complete')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(queue.queue.length, 1);
    });

    testWidgets('Track detail retains one-track seeding', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        _harness(
          catalog: catalog,
          playback: playback,
          queue: queue,
          home: const MusicTrackDetailScreen(trackId: 'track-complete'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_track_play_track-complete')));
      await _pumpPlayerReady(tester, playback, queue);

      expect(queue.queue.length, 1);
    });
  });

  group('Regression', () {
    testWidgets('player has no shuffle repeat or queue panel', (tester) async {
      final playback = _stubService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final album = library.projectionFor(queueCatalog).albums
          .firstWhere((a) => a.displayTitle == 'First Album');

      await tester.pumpWidget(
        _harness(
          catalog: queueCatalog,
          playback: playback,
          queue: queue,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openMusicPlayerFromAlbum(context, album: album),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await _pumpPlayerReady(tester, playback, queue);

      expect(find.byIcon(Icons.shuffle), findsNothing);
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.text('Queue'), findsNothing);
    });
  });
}
