import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_listening_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'catalog_cache_test_support.dart';
import 'diagnostics_test_harness.dart';
import 'music_catalog_fixtures.dart';
import '../playback_service_extensions_test.dart';

/// Deterministic clock for coordinator throttle tests — no wall-clock waits.
class Phase54TestClock {
  Phase54TestClock([DateTime? start])
      : _now = start ?? DateTime.utc(2026, 7, 21, 12);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration delta) => _now = _now.add(delta);
}

/// Production listening stack wired like [main.dart] (test-safe playback stub).
class Phase54ListeningStack {
  Phase54ListeningStack._({
    required this.playback,
    required this.repository,
    required this.queue,
    required this.coordinator,
    required this.catalogCache,
    required this.musicLibrary,
    required this.metadata,
    required this.clock,
  });

  final PlaybackService playback;
  final MusicListeningRepository repository;
  final MusicPlaybackQueueController queue;
  final MusicListeningCoordinator coordinator;
  final CatalogCacheCoordinator catalogCache;
  final MusicLibraryService musicLibrary;
  final LibraryMetadataRepository metadata;
  final Phase54TestClock clock;

  static Future<Phase54ListeningStack> create({
    Map<String, Object>? initialPrefs,
    DateTime? startTime,
    MusicListeningRepository? repository,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    final playback = stubPhase54PlaybackService();
    final repo = repository ?? MusicListeningRepository();
    if (!repo.isLoaded) {
      await repo.initialize();
    }
    final queue = MusicPlaybackQueueController(playbackService: playback);
    final clock = Phase54TestClock(startTime);
    final coordinator = MusicListeningCoordinator(
      repository: repo,
      playbackService: playback,
      queueController: queue,
      now: clock.now,
    );
    queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
    coordinator.attach();

    final musicLibrary = MusicLibraryService();
    final metadata = LibraryMetadataRepository();
    if (!metadata.isLoaded) {
      await metadata.initialize();
    }

    final catalogCache = createTestCatalogCacheCoordinator(
      artworkService: ArtworkService(fileExists: (_) => false),
      searchService: SearchService(),
      musicLibraryService: musicLibrary,
      libraryMetadataRepository: metadata,
      musicListeningRepository: repo,
      playbackService: playback,
      musicPlaybackQueueController: queue,
    );

    return Phase54ListeningStack._(
      playback: playback,
      repository: repo,
      queue: queue,
      coordinator: coordinator,
      catalogCache: catalogCache,
      musicLibrary: musicLibrary,
      metadata: metadata,
      clock: clock,
    );
  }

  Future<void> primeTrack(
    MediaItem track, {
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 4),
    bool playing = true,
  }) async {
    if (queue.currentTrack?.id != track.id) {
      queue.seedSingleTrack(track);
    }
    await queue.playCurrent();
    playback.simulateReadyForTest(track);
    playback.simulatePlaybackMetricsForTest(
      duration: duration,
      position: position,
      completed: false,
    );
    playback.simulatePlayingForTest(playing: playing);
    playback.notifyListeners();
    await coordinator.waitForIdleForTest();
  }

  Future<void> tick({
    required Duration position,
    bool? playing,
    bool completed = false,
    Duration clockStep = const Duration(seconds: 1),
  }) async {
    clock.advance(clockStep);
    playback.simulatePlaybackMetricsForTest(
      position: position,
      completed: completed,
    );
    if (playing != null) {
      playback.simulatePlayingForTest(playing: playing);
    }
    coordinator.handlePlaybackTickForTest();
    await coordinator.waitForIdleForTest();
  }

  Future<void> playForSeconds(
    MediaItem track,
    int seconds, {
    Duration startPosition = Duration.zero,
    bool stopAtEnd = false,
  }) async {
    await primeTrack(track, position: startPosition);
    for (var i = 1; i <= seconds; i++) {
      await tick(position: startPosition + Duration(seconds: i));
    }
    if (stopAtEnd) {
      await tick(
        position: startPosition + Duration(seconds: seconds),
        playing: false,
      );
    }
  }

  void dispose() {
    coordinator.dispose();
  }
}

PlaybackService stubPhase54PlaybackService() {
  return PlaybackService(
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

MediaItem phase54AudioTrack(
  String id, {
  String title = 'Track',
  String artist = 'Artist',
  String album = 'Album',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
    artist: artist,
    album: album,
  );
}

Catalog phase54MixedCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
  );
}

Catalog phase54QueueSeedingCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV3QueueSeedingFixture) as Map<String, dynamic>,
  );
}

Catalog phase54AudioCatalog(Map<String, String> trackTitles) {
  return Catalog.fromJson(phase54AudioCatalogJson(trackTitles));
}

Map<String, dynamic> phase54AudioCatalogJson(Map<String, String> trackTitles) {
  return {
    'generated_at': '2026-07-21T12:00:00+00:00',
    'total_items': trackTitles.length,
    'catalogue': {
      'id': 'P54-${trackTitles.length}',
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': r'Y:\Media\Music',
        'item_count': trackTitles.length,
        'items': [
          for (final entry in trackTitles.entries)
            {
              'id': entry.key,
              'title': entry.value,
              'file_path': 'Y:\\Media\\Music\\${entry.key}.mp3',
              'status': 'available',
              'media_kind': 'audio',
              'artist': 'Artist',
              'album': 'Album',
            },
        ],
        'subfolders': [],
      },
    ],
  };
}

MusicListeningRecord phase54Record({
  required String trackId,
  Duration lastPosition = const Duration(seconds: 45),
  bool completed = false,
  DateTime? lastPlayedAt,
  String title = 'Title',
  String artist = 'Artist',
  String album = 'Album',
}) {
  final playedAt = lastPlayedAt ?? DateTime.utc(2026, 7, 21, 12);
  return MusicListeningRecord(
    trackId: trackId,
    title: title,
    artist: artist,
    album: album,
    duration: const Duration(minutes: 4),
    lastPosition: lastPosition,
    completed: completed,
    completedAt: completed ? playedAt : null,
    lastPlayedAt: playedAt,
  );
}

MusicLibraryProjection phase54Projection(Catalog catalog) {
  return MusicLibraryService().projectionFor(catalog);
}

Future<MusicListeningRepository> phase54ReloadRepository() async {
  final reloaded = MusicListeningRepository();
  await reloaded.initialize();
  return reloaded;
}

Future<DiagnosticsService> phase54DiagnosticsForRepository(
  MusicListeningRepository repository, {
  Phase54ListeningStack? stack,
}) async {
  return buildDiagnosticsHarness(
    catalog: phase54MixedCatalog(),
    musicListeningRepository: repository,
    musicListeningCoordinator: stack?.coordinator,
  );
}

class Phase54FakeCatalogService extends CatalogService {
  Phase54FakeCatalogService(this._catalog);

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

Widget phase54WidgetHarness({
  required Catalog catalog,
  required MusicListeningRepository repository,
  required Widget child,
  MusicPlaybackQueueController? queue,
  PlaybackService? playback,
  MusicLibraryService? musicLibrary,
}) {
  final catalogService = Phase54FakeCatalogService(catalog);
  final playbackService = playback ?? stubPhase54PlaybackService();
  final queueController =
      queue ?? MusicPlaybackQueueController(playbackService: playbackService);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>(
        create: (_) => SettingsRepository(),
      ),
      Provider<ArtworkService>.value(
        value: ArtworkService(fileExists: (_) => false),
      ),
      Provider<MusicLibraryService>.value(
        value: musicLibrary ?? MusicLibraryService(),
      ),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider<PlaybackService>.value(value: playbackService),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: repository,
      ),
      ChangeNotifierProvider<ScannerService>(create: (_) => ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>(
        create: (_) => ScanHistoryService(),
      ),
      ChangeNotifierProvider<MediaProviderConfigService>(
        create: (_) => MediaProviderConfigService(),
      ),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(
        value: queueController,
      ),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.defaults(),
          isWindowsDesktop: false,
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}
