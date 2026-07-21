import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/models/music_listening_policy.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/music_listening_presentation.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_recently_played_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
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

import 'support/music_catalog_fixtures.dart';
import 'playback_service_extensions_test.dart';

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

Catalog _mixedCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
  );
}

Catalog _queueSeedingCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV3QueueSeedingFixture) as Map<String, dynamic>,
  );
}

MusicListeningRecord _record({
  required String trackId,
  Duration lastPosition = const Duration(seconds: 45),
  Duration? duration = const Duration(minutes: 4),
  bool completed = false,
  DateTime? lastPlayedAt,
  String title = 'Title',
}) {
  final playedAt = lastPlayedAt ?? DateTime.utc(2026, 7, 21, 12);
  return MusicListeningRecord(
    trackId: trackId,
    title: title,
    artist: 'Artist',
    album: 'Album',
    duration: duration,
    lastPosition: lastPosition,
    completed: completed,
    completedAt: completed ? playedAt : null,
    lastPlayedAt: playedAt,
  );
}

Widget _listeningHarness({
  required Catalog catalog,
  required MusicListeningRepository repository,
  required Widget child,
  MusicPlaybackQueueController? queueController,
  PlaybackService? playbackService,
}) {
  SharedPreferences.setMockInitialValues({});
  final catalogService = _FakeCatalogService(catalog);
  final playback = playbackService ?? PlaybackService();

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
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: repository,
      ),
      ChangeNotifierProvider<ScannerService>.value(value: ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: ScanHistoryService(),
      ),
      ChangeNotifierProvider<MediaProviderConfigService>(
        create: (_) => MediaProviderConfigService(),
      ),
      if (queueController != null)
        ChangeNotifierProvider<MusicPlaybackQueueController>.value(
          value: queueController,
        ),
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _pumpListeningUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openClearHistoryMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('music_recently_played_menu')));
  await _pumpListeningUi(tester);
  await tester.tap(
    find.byKey(const Key('music_clear_listening_history_menu_item')),
  );
  await _pumpListeningUi(tester);
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
          duration: const Duration(minutes: 4),
          position: Duration.zero,
        );
        service.simulateReadyForTest(item);
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicListeningPresentation helpers', () {
    test(
        'historyPlaybackStartPosition respects completion and resume threshold',
        () {
      expect(
        historyPlaybackStartPosition(
          _record(trackId: 'a', completed: true),
        ),
        Duration.zero,
      );
      expect(
        historyPlaybackStartPosition(
          _record(trackId: 'a', lastPosition: const Duration(seconds: 20)),
        ),
        Duration.zero,
      );
      expect(
        historyPlaybackStartPosition(
          _record(trackId: 'a', lastPosition: const Duration(seconds: 45)),
        ),
        const Duration(seconds: 45),
      );
    });

    test('listeningProgressFraction clamps and handles unknown duration', () {
      expect(listeningProgressFraction(_record(trackId: 'a', completed: true)),
          isNull);
      expect(
        listeningProgressFraction(
          _record(
            trackId: 'a',
            lastPosition: const Duration(minutes: 5),
          ),
        ),
        1.0,
      );
      expect(
        listeningProgressFraction(
          MusicListeningRecord(
            trackId: 'a',
            title: 'T',
            artist: 'A',
            album: 'B',
            lastPosition: const Duration(minutes: 2),
            completed: false,
            lastPlayedAt: DateTime.utc(2026, 7, 21),
          ),
        ),
        isNull,
      );
    });

    test('resolvePlayableListeningEntries uses trackId only', () {
      final catalog = _mixedCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      final entries = resolvePlayableListeningEntries(
        [
          _record(trackId: 'track-complete'),
          _record(trackId: 'missing-id', title: 'Shared Title'),
        ],
        projection,
      );

      expect(entries, hasLength(1));
      expect(entries.single.record.trackId, 'track-complete');
      expect(entries.single.mediaItem?.id, 'track-complete');
    });

    test('findAlbumContainingTrack returns album for abbey road track', () {
      final catalog = _mixedCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      final album = findAlbumContainingTrack(projection, 'track-complete');
      expect(album, isNotNull);
      expect(album!.tracks.any((t) => t.id == 'track-complete'), isTrue);
    });
  });

  group('Music landing Continue Listening', () {
    testWidgets('section appears for eligible resumable records',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      final saveResult = await repository.upsert(
        _record(
          trackId: 'track-complete',
          lastPosition: const Duration(minutes: 2),
          duration: const Duration(minutes: 10),
        ),
      );
      expect(saveResult.success, isTrue);
      expect(repository.continueListening(), hasLength(1));

      final projection = MusicLibraryProjection.build(_mixedCatalog());
      expect(
        resolvePlayableListeningEntries(
          repository.continueListening(),
          projection,
        ),
        hasLength(1),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsOneWidget);
      expect(find.text('CONTINUE LISTENING'), findsOneWidget);
      expect(
        find.byKey(const Key('music_continue_listening_card_track-complete')),
        findsOneWidget,
      );
    });

    testWidgets('section hidden when no eligible records', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);
    });

    testWidgets('completed and sub-30-second records are excluded',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'track-complete',
          completed: true,
          lastPosition: Duration.zero,
        ),
      );
      await repository.upsert(
        _record(
          trackId: 'track-partial',
          lastPosition: const Duration(seconds: 20),
          lastPlayedAt: DateTime.utc(2026, 7, 21, 13),
        ),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);
    });

    testWidgets(
        'Recently Played tile remains accessible when Continue Listening empty',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'track-complete',
          completed: true,
          lastPosition: Duration.zero,
        ),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(
          find.byKey(const Key('music_recently_played_tile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('music_recently_played_tile')));
      await _pumpListeningUi(tester);
      expect(find.byType(MusicRecentlyPlayedScreen), findsOneWidget);
    });

    testWidgets('repository notifications refresh Continue Listening',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);

      await repository.upsert(
        _record(
          trackId: 'track-complete',
          lastPosition: const Duration(seconds: 60),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsOneWidget);
    });

    test('continueListening UI cap is enforced by repository query', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      for (var i = 0; i < 12; i++) {
        await repository.upsert(
          _record(
            trackId: 'track-$i',
            lastPosition: const Duration(seconds: 45),
            lastPlayedAt: DateTime.utc(2026, 7, 21, 12, i),
          ),
        );
      }

      expect(
        repository
            .continueListening(
              limit: MusicListeningPolicy.defaultContinueListeningQueryCap,
            )
            .length,
        MusicListeningPolicy.defaultContinueListeningQueryCap,
      );
    });
  });

  group('Recently Played screen', () {
    testWidgets('lists completed and incomplete records in order',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'track-partial',
          lastPosition: const Duration(seconds: 35),
          lastPlayedAt: DateTime.utc(2026, 7, 21, 10),
        ),
      );
      await repository.upsert(
        _record(
          trackId: 'track-complete',
          completed: true,
          lastPosition: Duration.zero,
          lastPlayedAt: DateTime.utc(2026, 7, 21, 12),
        ),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      final tiles = find.byType(ListTile);
      expect(tiles, findsNWidgets(2));
      expect(
        find.byKey(const Key('music_recently_played_tile_track-complete')),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no records', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(
          find.byKey(const Key('music_recently_played_empty')), findsOneWidget);
    });

    testWidgets('stale record tile is disabled', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'missing-track'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      final tile = tester.widget<ListTile>(
        find.byKey(const Key('music_recently_played_tile_missing-track')),
      );
      expect(tile.enabled, isFalse);
      expect(find.byIcon(Icons.play_arrow_outlined), findsNothing);
    });
  });

  group('Listening history navigation', () {
    testWidgets('resumable item seeds album queue and opens player',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'qa-t1',
          lastPosition: const Duration(seconds: 75),
          duration: const Duration(minutes: 10),
        ),
      );

      final playback = _serviceWithStubInit();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _queueSeedingCatalog(),
          repository: repository,
          queueController: queue,
          playbackService: playback,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await repository.upsert(
        _record(
          trackId: 'qa-t1',
          lastPosition: const Duration(seconds: 75),
          duration: const Duration(minutes: 10),
        ),
      );
      await _pumpListeningUi(tester);

      await tester.tap(
        find.byKey(const Key('music_continue_listening_card_qa-t1')),
      );
      await _pumpListeningUi(tester);
      await _pumpListeningUi(tester);

      expect(find.byType(MusicPlayerScreen), findsOneWidget);
      expect(queue.currentTrack?.id, 'qa-t1');
      expect(queue.queue.items.length, 3);
    });

    testWidgets('completed Recently Played item uses zero start position',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'track-complete',
          completed: true,
          lastPosition: Duration.zero,
        ),
      );

      final playback = _serviceWithStubInit();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          queueController: queue,
          playbackService: playback,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      await tester.tap(
        find.byKey(const Key('music_recently_played_tile_track-complete')),
      );
      await _pumpListeningUi(tester);

      final screen =
          tester.widget<MusicPlayerScreen>(find.byType(MusicPlayerScreen));
      expect(screen.startPosition, Duration.zero);
    });
  });

  group('Clear listening history', () {
    testWidgets('menu appears when history exists', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
            trackId: 'track-complete',
            lastPosition: const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(
          find.byKey(const Key('music_recently_played_menu')), findsOneWidget);
    });

    testWidgets('menu hidden when history empty', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_recently_played_menu')), findsNothing);
    });

    testWidgets('menu hidden while repository loading', (tester) async {
      final repository = MusicListeningRepository(
        initialRecords: [_record(trackId: 'track-complete')],
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_recently_played_menu')), findsNothing);
    });

    testWidgets('menu opens confirmation dialog with scope text',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);

      expect(
        find.byKey(const Key('music_clear_listening_history_dialog')),
        findsOneWidget,
      );
      expect(find.text('Clear listening history?'), findsOneWidget);
      expect(find.textContaining('Continue Listening'), findsOneWidget);
      expect(find.textContaining('video watch history'), findsOneWidget);
    });

    testWidgets('Cancel preserves history', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);

      await tester.tap(find.text('Cancel'));
      await _pumpListeningUi(tester);

      expect(repository.storedRecordCount, 1);
      expect(find.byType(MusicRecentlyPlayedScreen), findsOneWidget);
    });

    testWidgets('Escape dismisses dialog without clearing', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpListeningUi(tester);

      expect(repository.storedRecordCount, 1);
    });

    testWidgets('Clear removes rows and shows success message', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);

      await tester
          .tap(find.byKey(const Key('confirm_clear_listening_history')));
      await _pumpListeningUi(tester);
      await _pumpListeningUi(tester);

      expect(repository.storedRecordCount, 0);
      expect(
          find.byKey(const Key('music_recently_played_empty')), findsOneWidget);
      expect(
        find.byKey(const Key('music_clear_listening_history_success')),
        findsOneWidget,
      );
    });

    testWidgets('failure preserves rows and shows failure message',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));
      repository.simulatePersistFailure = true;

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);

      await tester
          .tap(find.byKey(const Key('confirm_clear_listening_history')));
      await _pumpListeningUi(tester);

      expect(repository.storedRecordCount, 1);
      expect(
          find.byKey(const Key('music_recently_played_list')), findsOneWidget);
      expect(
        find.byKey(const Key('music_clear_listening_history_failure')),
        findsOneWidget,
      );
    });

    testWidgets('Music landing updates after clear', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        _record(
          trackId: 'track-complete',
          lastPosition: const Duration(minutes: 2),
          duration: const Duration(minutes: 10),
        ),
      );

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicRecentlyPlayedScreen(),
        ),
      );
      await _pumpListeningUi(tester);
      await _openClearHistoryMenu(tester);
      await tester
          .tap(find.byKey(const Key('confirm_clear_listening_history')));
      await _pumpListeningUi(tester);

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);
      expect(
          find.byKey(const Key('music_recently_played_tile')), findsOneWidget);
      expect(find.textContaining('0 tracks in history'), findsOneWidget);
    });

    testWidgets('MusicScreen landing has no clear action', (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(_record(trackId: 'track-complete'));

      await tester.pumpWidget(
        _listeningHarness(
          catalog: _mixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpListeningUi(tester);

      expect(find.text('Clear listening history'), findsNothing);
      expect(find.byKey(const Key('music_recently_played_menu')), findsNothing);
    });
  });

  group('Dashboard regression', () {
    testWidgets('dashboard does not show music Continue Listening section',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
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
            ChangeNotifierProvider<CatalogService>(
              create: (_) => _FakeCatalogService(_mixedCatalog()),
            ),
            ChangeNotifierProvider<PlaybackService>(
              create: (_) => PlaybackService(),
            ),
            ChangeNotifierProvider<ScannerService>(
              create: (_) => ScannerService(),
            ),
            ChangeNotifierProvider<ScanHistoryService>(
              create: (_) => ScanHistoryService(),
            ),
            ChangeNotifierProvider<MediaProviderConfigService>(
              create: (_) => MediaProviderConfigService(),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Continue Listening'), findsNothing);
    });
  });
}
