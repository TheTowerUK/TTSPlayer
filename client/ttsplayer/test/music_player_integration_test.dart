import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_navigation.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_track_detail_screen.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/player_screen.dart';
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
import 'package:ttsplayer/features/music/music_library_service.dart';

import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/services/playback_service.dart';

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

MediaItem _videoItem() {
  return MediaItem.fromJson({
    'id': 'video-1',
    'title': 'Sample Video',
    'file_path': r'Y:\Media\Videos\sample.mp4',
    'status': 'available',
    'media_kind': 'video',
  });
}

PlaybackService _serviceWithStubInit() {
  return PlaybackService(
    mediaLocationResolver: MediaLocationResolver(
      config: MediaAccessConfig.development(),
      isWindowsDesktop: true,
    ),
    mediaKitInitOverride: (service, uri, generation) async {
      final fake = FakePlaybackSessionControls();
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
      final item = service.currentItem;
      if (item != null) {
        service.simulatePlaybackMetricsForTest(
          duration: const Duration(minutes: 3),
          position: Duration.zero,
        );
        service.simulateReadyForTest(item);
      }
    },
  );
}

Widget _appHarness({
  required Catalog catalog,
  required PlaybackService playbackService,
  required Widget home,
  MusicPlaybackQueueController? queueController,
}) {
  SharedPreferences.setMockInitialValues({});
  final catalogService = _FakeCatalogService(catalog);
  final queue = queueController ??
      MusicPlaybackQueueController(playbackService: playbackService);
  return MultiProvider(
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
      ChangeNotifierProvider<PlaybackService>.value(value: playbackService),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(value: queue),
      ChangeNotifierProvider<ScannerService>.value(value: ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: ScanHistoryService(),
      ),
      ChangeNotifierProvider<MediaProviderConfigService>(
        create: (_) => MediaProviderConfigService(),
      ),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    catalog = Catalog.fromJson(
      jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
    );
  });

  group('music surface integration', () {
    testWidgets('track detail play opens MusicPlayerScreen', (tester) async {
      final service = _serviceWithStubInit();
      await tester.pumpWidget(
        _appHarness(
          catalog: catalog,
          playbackService: service,
          home: const MusicTrackDetailScreen(trackId: 'track-complete'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_track_play_track-complete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MusicPlayerScreen), findsOneWidget);
    });

    testWidgets('album track play seeds full album queue', (tester) async {
      final service = _serviceWithStubInit();
      final queue = MusicPlaybackQueueController(playbackService: service);
      final queueCatalog = Catalog.fromJson(
        jsonDecode(kCatalogV3QueueSeedingFixture) as Map<String, dynamic>,
      );
      final albumKey = MusicLibraryService()
          .projectionFor(queueCatalog)
          .albums
          .firstWhere((a) => a.displayTitle == 'First Album')
          .groupKey;
      await tester.pumpWidget(
        _appHarness(
          catalog: queueCatalog,
          playbackService: service,
          queueController: queue,
          home: MusicAlbumDetailScreen(albumGroupKey: albumKey),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('music_track_play_qa-t1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MusicPlayerScreen), findsOneWidget);
      expect(find.text('First Track'), findsWidgets);
      expect(queue.queue.length, 3);
      expect(queue.currentTrack?.id, 'qa-t1');
    });

    testWidgets('search audio play opens MusicPlayerScreen', (tester) async {
      final service = _serviceWithStubInit();
      await tester.pumpWidget(
        _appHarness(
          catalog: catalog,
          playbackService: service,
          home: const SearchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Come Together');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      await tester.tap(find.byKey(const Key('search_play_track-complete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MusicPlayerScreen), findsOneWidget);
    });

    test('new audio session replaces prior audio session', () async {
      final service = _serviceWithStubInit();
      final trackA = musicTrackComplete();
      final trackB = MediaItem.fromJson({
        ...trackA.toJson(),
        'id': 'track-partial',
        'title': 'Untitled',
      });

      await service.play(trackA);
      expect(service.currentItem?.id, 'track-complete');

      await service.play(trackB);
      expect(service.currentItem?.id, 'track-partial');
      expect(service.isAudioSession, isTrue);
    });

    test('music replaces active video session', () async {
      final service = _serviceWithStubInit();
      await service.play(_videoItem());
      expect(service.requiresVideoSurface, isTrue);

      await service.play(musicTrackComplete());
      expect(service.isAudioSession, isTrue);
      expect(service.requiresVideoSurface, isFalse);
    });

    test('video replaces active music session and clears queue', () async {
      final service = _serviceWithStubInit();
      final queue = MusicPlaybackQueueController(playbackService: service);
      queue.replaceQueue([musicTrackComplete()]);
      await service.play(musicTrackComplete());
      expect(service.isAudioSession, isTrue);
      expect(queue.isEmpty, isFalse);

      await service.play(_videoItem());
      expect(service.requiresVideoSurface, isTrue);
      expect(queue.isEmpty, isTrue);
    });
  });

  group('regression', () {
    testWidgets('PlayerScreen still renders for video', (tester) async {
      final service = PlaybackService();
      service.simulateReadyForTest(_videoItem());
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 10),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<PlaybackService>.value(
          value: service,
          child: MaterialApp(
            home: PlayerScreen(item: _videoItem(), autoPlay: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text('Preparing video…'), findsNothing);
    });

    test('Continue Watching excludes audio positions', () async {
      final service = PlaybackService();
      await service.persistResumeStateForTest(
        musicTrackComplete().id,
        const Duration(minutes: 2),
        duration: const Duration(minutes: 4),
        item: musicTrackComplete(),
      );

      final entries = await service.getContinueWatching(catalog);
      expect(entries, isEmpty);
    });

    testWidgets('openMusicPlayerScreen ignores non-playable track', (tester) async {
      final service = PlaybackService();
      final missing = MediaItem.fromJson({
        ...musicTrackComplete().toJson(),
        'status': 'missing',
      });

      await tester.pumpWidget(
        _appHarness(
          catalog: catalog,
          playbackService: service,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openMusicPlayerScreen(context, track: missing),
              child: const Text('play'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('play'));
      await tester.pump();

      expect(find.byType(MusicPlayerScreen), findsNothing);
    });
  });
}
