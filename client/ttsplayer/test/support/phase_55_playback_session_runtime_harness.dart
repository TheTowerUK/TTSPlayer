import 'dart:convert';
import 'dart:io';

/// Production playback-session runtime harness for Phase 5.5 Step 6.
///
/// Wires repository, coordinator, restorer, queue, catalogue cache, diagnostics,
/// and lifecycle observer like [main.dart] / [DashboardScreen]. Deterministic
/// position scenarios use [PlaybackService.mediaKitInitOverride]; MediaKit is
/// initialized at suite level for Windows fidelity.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_listening_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_export_coordinator.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';
import 'package:ttsplayer/widgets/music_playback_session_lifecycle_observer.dart';

import '../playback_service_extensions_test.dart';
import 'audio_gate_fixtures.dart';
import 'diagnostics_test_harness.dart';
import 'phase_55_playback_session_runtime_baseline.dart';

const phase55RuntimeCatalogueId = 'PHASE55-RUNTIME';
const phase55RuntimeArtist = 'PHASE55-SENTINEL-ARTIST';
const phase55RuntimeAlbum = 'PHASE55-SENTINEL-ALBUM';
const phase55RuntimeMusicRoot = r'C:\Runtime\PHASE55\Music';
const phase55RuntimeArtistFolder =
    r'C:\Runtime\PHASE55\Music\PHASE55-SENTINEL-ARTIST';
const phase55RuntimeAlbumFolder =
    r'C:\Runtime\PHASE55\Music\PHASE55-SENTINEL-ARTIST\PHASE55-SENTINEL-ALBUM';

const phase55AlbumTrackIds = [
  'p55-album-t1',
  'p55-album-t2',
  'p55-album-t3',
];
const phase55RootTrackId = 'p55-root';
const phase55VideoItemId = 'p55-video-1';
const phase55MissingTrackId = 'p55-missing-GONE';

const phase55SentinelTitlePrefix = 'PHASE55-SENTINEL-TITLE';
const phase55ExpectedPosition = Duration(seconds: 45);
const phase55PositionTolerance = Duration(seconds: 2);

const phase55VideoResumeProbeId = 'phase55-video-probe';
const phase55VideoResumePositionKey = 'position_$phase55VideoResumeProbeId';
const phase55VideoResumeDurationKey = 'duration_$phase55VideoResumeProbeId';

/// Production [DiagnosticsService] with capture counting for runtime checks.
class Phase55ObservedDiagnosticsService extends DiagnosticsService {
  Phase55ObservedDiagnosticsService({
    required super.catalogService,
    required super.artworkService,
    required super.searchService,
    required super.playbackService,
    required super.mediaProviderConfigService,
    required super.libraryMetadataRepository,
    required super.applicationStartedAt,
    required super.musicListeningRepository,
    required super.musicListeningCoordinator,
    super.musicPlaybackSessionRepository,
    super.musicPlaybackSessionCoordinator,
    super.musicPlaybackQueueController,
    super.musicPlaybackSessionRestorer,
    super.packageInfoLoader,
    super.platformNameProvider,
    super.imageCacheAvailableProvider,
  });

  int captureCount = 0;

  @override
  Future<RuntimeDiagnosticsSnapshot> captureSnapshot() async {
    captureCount++;
    return super.captureSnapshot();
  }
}

/// Full production playback-session stack for Windows runtime validation.
class Phase55RuntimeContext {
  Phase55RuntimeContext._({
    required this.baseline,
    required this.catalog,
    required this.catalogPath,
    required this.catalogService,
    required this.catalogCache,
    required this.musicLibrary,
    required this.metadata,
    required this.settings,
    required this.config,
    required this.artwork,
    required this.search,
    required this.playback,
    required this.listeningRepository,
    required this.listeningCoordinator,
    required this.sessionRepository,
    required this.sessionCoordinator,
    required this.restorer,
    required this.queue,
    required this.diagnostics,
    required this.clipboard,
    required this.applicationStartedAt,
    required this.audioFixturePath,
    required this.tempCatalogDir,
    required this.tempWavDirs,
    required this.coldStartRestorePerformed,
  });

  final Phase55PlaybackSessionRuntimeBaseline baseline;
  final Catalog catalog;
  final String catalogPath;
  final CatalogService catalogService;
  final CatalogCacheCoordinator catalogCache;
  final MusicLibraryService musicLibrary;
  final LibraryMetadataRepository metadata;
  final SettingsRepository settings;
  final MediaProviderConfigService config;
  final ArtworkService artwork;
  final SearchService search;
  final PlaybackService playback;
  final MusicListeningRepository listeningRepository;
  final MusicListeningCoordinator listeningCoordinator;
  final MusicPlaybackSessionRepository sessionRepository;
  final MusicPlaybackSessionCoordinator sessionCoordinator;
  final MusicPlaybackSessionRestorer restorer;
  final MusicPlaybackQueueController queue;
  final Phase55ObservedDiagnosticsService diagnostics;
  final FakeClipboardWriter clipboard;
  final DateTime applicationStartedAt;
  final String audioFixturePath;
  final Directory tempCatalogDir;
  final List<Directory> tempWavDirs;
  final bool coldStartRestorePerformed;

  MusicLibraryProjection get projection => musicLibrary.projectionFor(catalog);

  MediaItem track(String id) =>
      catalog.allItems.firstWhere((item) => item.id == id);

  static Future<Phase55RuntimeContext> create({
    Phase55PlaybackSessionRuntimeBaseline? baseline,
    Map<String, Object>? initialPrefs,
    bool performColdStartRestore = true,
    Duration queueMutationDebounce = const Duration(milliseconds: 250),
  }) async {
    final resolvedBaseline =
        baseline ?? Phase55PlaybackSessionRuntimeBaseline();
    await resolvedBaseline.captureEnvironment();

    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.5.0-dev',
      buildNumber: '42',
      buildSignature: 'sig',
      installerStore: null,
    );
    configureArtworkFlutterImageCache();

    final wav1 = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p55_album_t1',
    );
    final wav2 = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p55_album_t2',
    );
    final wav3 = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p55_album_t3',
    );
    final rootWav = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p55_root',
    );
    final tempWavDirs = <Directory>[
      wav1.file.parent,
      wav2.file.parent,
      wav3.file.parent,
      rootWav.file.parent,
    ];

    final catalogJson = phase55RuntimeCatalogJson(
      albumPaths: {
        phase55AlbumTrackIds[0]: wav1.path,
        phase55AlbumTrackIds[1]: wav2.path,
        phase55AlbumTrackIds[2]: wav3.path,
      },
      rootPath: rootWav.path,
    );
    final catalog = Catalog.fromJson(catalogJson);
    resolvedBaseline.catalogueIdentity = catalog.catalogueIdentity;

    final tempDir =
        await Directory.systemTemp.createTemp('p55_runtime_catalog_');
    final catalogPath = '${tempDir.path}/catalog.json';
    await File(catalogPath).writeAsString(jsonEncode(catalogJson));

    final settings = SettingsRepository();
    await settings.initialize();
    final config = MediaProviderConfigService();
    await config.load();
    final metadata = LibraryMetadataRepository();
    await metadata.initialize();
    final musicLibrary = MusicLibraryService();
    final artwork = ArtworkService(fileExists: (_) => false);
    final search = SearchService();

    final playback = PlaybackService(
      mediaLocationResolver: MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      ),
      defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
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

    final listeningRepository = MusicListeningRepository();
    await listeningRepository.initialize();

    final sessionRepository = MusicPlaybackSessionRepository();
    final initStopwatch = Stopwatch()..start();
    await sessionRepository.initialize();
    resolvedBaseline.observe(
      'session_repository_init_ms',
      initStopwatch.elapsedMilliseconds,
    );

    final queue = MusicPlaybackQueueController(playbackService: playback);
    final listeningCoordinator = MusicListeningCoordinator(
      repository: listeningRepository,
      playbackService: playback,
      queueController: queue,
    );
    queue.pendingListeningWriteDrain = listeningCoordinator.drainPendingWrites;
    listeningCoordinator.attach();

    final sessionCoordinator = MusicPlaybackSessionCoordinator(
      repository: sessionRepository,
      playbackService: playback,
      queueController: queue,
      queueMutationDebounce: queueMutationDebounce,
    );

    final restorer = MusicPlaybackSessionRestorer(
      repository: sessionRepository,
      queueController: queue,
      musicLibraryService: musicLibrary,
      playbackService: playback,
      sessionCoordinator: sessionCoordinator,
    );

    final catalogCache = CatalogCacheCoordinator(
      artworkService: artwork,
      searchService: search,
      musicLibraryService: musicLibrary,
      libraryMetadataRepository: metadata,
      musicPlaybackQueueController: queue,
      musicListeningRepository: listeningRepository,
      musicPlaybackSessionRepository: sessionRepository,
      readingProgressRepository: ReadingProgressRepository(),
    );

    final catalogService = CatalogService(
      settingsRepository: settings,
      onCatalogReplaced: catalogCache.onCatalogReplaced,
    )..includeLegacyCataloguePaths = false;
    await catalogService.loadFromFile(catalogPath);

    var coldStartRestorePerformed = false;
    if (performColdStartRestore) {
      await restorer.restoreOnColdStart(catalogService.catalog ?? catalog);
      coldStartRestorePerformed = true;
    } else {
      // Match production pre-restore state: coordinator not yet enabled.
      sessionCoordinator.attach(deferPersistenceUntilColdStartComplete: true);
    }

    final applicationStartedAt = DateTime.now().toUtc().subtract(
          const Duration(minutes: 2),
        );
    final diagnostics = Phase55ObservedDiagnosticsService(
      catalogService: catalogService,
      artworkService: artwork,
      searchService: search,
      playbackService: playback,
      mediaProviderConfigService: config,
      libraryMetadataRepository: metadata,
      musicListeningRepository: listeningRepository,
      musicListeningCoordinator: listeningCoordinator,
      musicPlaybackSessionRepository: sessionRepository,
      musicPlaybackSessionCoordinator: sessionCoordinator,
      musicPlaybackQueueController: queue,
      musicPlaybackSessionRestorer: restorer,
      applicationStartedAt: applicationStartedAt,
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => true,
    );
    final clipboard = FakeClipboardWriter();

    return Phase55RuntimeContext._(
      baseline: resolvedBaseline,
      catalog: catalogService.catalog ?? catalog,
      catalogPath: catalogPath,
      catalogService: catalogService,
      catalogCache: catalogCache,
      musicLibrary: musicLibrary,
      metadata: metadata,
      settings: settings,
      config: config,
      artwork: artwork,
      search: search,
      playback: playback,
      listeningRepository: listeningRepository,
      listeningCoordinator: listeningCoordinator,
      sessionRepository: sessionRepository,
      sessionCoordinator: sessionCoordinator,
      restorer: restorer,
      queue: queue,
      diagnostics: diagnostics,
      clipboard: clipboard,
      applicationStartedAt: applicationStartedAt,
      audioFixturePath: wav1.path,
      tempCatalogDir: tempDir,
      tempWavDirs: tempWavDirs,
      coldStartRestorePerformed: coldStartRestorePerformed,
    );
  }

  List<SingleChildWidget> coreProviders() {
    return [
      Provider<DiagnosticsService>.value(value: diagnostics),
      ChangeNotifierProvider<SettingsRepository>.value(value: settings),
      ChangeNotifierProvider<MediaProviderConfigService>.value(value: config),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: metadata),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: config.mediaAccess,
          isWindowsDesktop: true,
        ),
      ),
      Provider<ArtworkService>.value(value: artwork),
      Provider<SearchService>.value(value: search),
      Provider<MusicLibraryService>.value(value: musicLibrary),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(value: queue),
      ChangeNotifierProvider<MusicListeningCoordinator>.value(
        value: listeningCoordinator,
      ),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: listeningRepository,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionRepository>.value(
        value: sessionRepository,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionCoordinator>.value(
        value: sessionCoordinator,
      ),
      Provider<MusicPlaybackSessionRestorer>.value(value: restorer),
      ChangeNotifierProvider(create: (_) => ScannerService()),
      ChangeNotifierProvider(create: (_) => ScanHistoryService()),
    ];
  }

  Widget lifecycleApp({required Widget home}) {
    return MultiProvider(
      providers: coreProviders(),
      child: MusicPlaybackSessionLifecycleObserver(
        coordinator: sessionCoordinator,
        child: MaterialApp(theme: AppTheme.dark, home: home),
      ),
    );
  }

  Widget diagnosticsApp() {
    return MultiProvider(
      providers: coreProviders(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: DiagnosticsScreen(clipboardWriter: clipboard),
      ),
    );
  }

  Future<Map<String, Object>> snapshotPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, Object>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  Future<Map<String, dynamic>?> readSessionEnvelope() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MusicPlaybackSessionRepository.storageKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<String>> persistedQueueIds() async {
    final envelope = await readSessionEnvelope();
    final session = envelope?['session'] as Map<String, dynamic>?;
    if (session == null) return const [];
    return (session['queueTrackIds'] as List<dynamic>).cast<String>();
  }

  Future<String?> persistedActiveTrackId() async {
    final envelope = await readSessionEnvelope();
    final session = envelope?['session'] as Map<String, dynamic>?;
    return session?['activeTrackId'] as String?;
  }

  Future<Duration> persistedPosition() async {
    final envelope = await readSessionEnvelope();
    final session = envelope?['session'] as Map<String, dynamic>?;
    final ms = session?['playbackPositionMs'];
    if (ms is int) return Duration(milliseconds: ms);
    return Duration.zero;
  }

  Future<void> seedThreeTrackQueue({int startIndex = 0}) async {
    final items = [
      track(phase55AlbumTrackIds[0]),
      track(phase55AlbumTrackIds[1]),
      track(phase55AlbumTrackIds[2]),
    ];
    queue.replaceQueue(items, startIndex: startIndex);
    await sessionCoordinator.waitForIdleForTest();
    await sessionCoordinator.drainPendingWrites();
  }

  Future<void> playAndSeekToMeaningfulPosition({
    Duration position = phase55ExpectedPosition,
  }) async {
    queue.onPlayerRouteOpened();
    await queue.playCurrent();
    final item = queue.currentTrack;
    expect(item, isNotNull);
    playback.simulateReadyForTest(item!);
    playback.simulatePlaybackMetricsForTest(
      duration: const Duration(minutes: 4),
      position: position,
    );
    playback.simulatePlayingForTest(playing: true);
    playback.notifyListeners();
    sessionCoordinator.handlePlaybackTickForTest();
    await sessionCoordinator.drainPendingWrites();
  }

  Future<void> pauseAndFlush() async {
    playback.simulatePlayingForTest(playing: false);
    playback.notifyListeners();
    sessionCoordinator.handlePlaybackTickForTest();
    await sessionCoordinator.onAppLifecyclePaused();
    await sessionCoordinator.drainPendingWrites();
  }

  Future<RuntimeDiagnosticsSnapshot> timedCapture(String label) async {
    final stopwatch = Stopwatch()..start();
    final snapshot = await diagnostics.captureSnapshot();
    baseline.observe('${label}_ms', stopwatch.elapsedMilliseconds);
    return snapshot;
  }

  Future<String> exportDiagnostics() async {
    final coordinator = DiagnosticsExportCoordinator(
      diagnosticsService: diagnostics,
      clipboardWriter: clipboard,
    );
    final result = await coordinator.copyDiagnostics();
    expect(result, isA<DiagnosticsExportSuccess>());
    return clipboard.lastWrittenText!;
  }

  Future<void> dispose() async {
    sessionCoordinator.dispose();
    listeningCoordinator.dispose();
    await queue.onPlayerRouteClosed();
    await playback.stop();
    playback.clearReadySimulationForTest();
    if (tempCatalogDir.existsSync()) {
      tempCatalogDir.deleteSync(recursive: true);
    }
    for (final dir in tempWavDirs) {
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {
          // Best-effort cleanup of generated fixtures.
        }
      }
    }
  }
}

Map<String, dynamic> phase55RuntimeCatalogJson({
  required Map<String, String> albumPaths,
  required String rootPath,
  bool includeVideo = true,
}) {
  final scratch = MediaItem(
    id: 'scratch',
    title: 'scratch',
    filePath: '${phase55RuntimeAlbumFolder}\\01.wav',
    mediaKindRaw: 'audio',
    artist: phase55RuntimeArtist,
    album: phase55RuntimeAlbum,
    albumArtist: phase55RuntimeArtist,
  );
  final artistKey = MusicLibraryProjection.artistGroupKeyForItem(scratch);
  final albumKey = MusicLibraryProjection.albumGroupKeyForItem(scratch);

  final albumItems = [
    for (var i = 0; i < phase55AlbumTrackIds.length; i++)
      {
        'id': phase55AlbumTrackIds[i],
        'title': '$phase55SentinelTitlePrefix ${i + 1}',
        'file_path': albumPaths[phase55AlbumTrackIds[i]],
        'status': 'available',
        'media_kind': 'audio',
        'artist': phase55RuntimeArtist,
        'album': phase55RuntimeAlbum,
        'album_artist': phase55RuntimeArtist,
        'track_number': i + 1,
        'disc_number': 1,
        'year': 2024,
        'duration_seconds': 240,
        'artist_group_key': artistKey,
        'album_group_key': albumKey,
      },
  ];

  final rootItems = <Map<String, dynamic>>[
    {
      'id': phase55RootTrackId,
      'title': '$phase55SentinelTitlePrefix Root',
      'file_path': rootPath,
      'status': 'available',
      'media_kind': 'audio',
      'artist': phase55RuntimeArtist,
      'album': 'Singles',
      'year': 2024,
      'duration_seconds': 180,
    },
  ];
  if (includeVideo) {
    rootItems.add({
      'id': phase55VideoItemId,
      'title': '$phase55SentinelTitlePrefix Video',
      'file_path': r'C:\Runtime\PHASE55\Video\phase55_sentinel.mp4',
      'status': 'available',
      'media_kind': 'video',
      'year': 2024,
      'duration_seconds': 600,
    });
  }

  return {
    'generated_at': '2026-07-23T06:00:00+00:00',
    'total_items': albumItems.length + rootItems.length,
    'catalogue': {
      'id': phase55RuntimeCatalogueId,
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': phase55RuntimeMusicRoot,
        'item_count': albumItems.length + rootItems.length,
        'items': rootItems,
        'subfolders': [
          {
            'id': 'artist',
            'name': phase55RuntimeArtist,
            'path': phase55RuntimeArtistFolder,
            'item_count': albumItems.length,
            'items': [],
            'subfolders': [
              {
                'id': 'album',
                'name': phase55RuntimeAlbum,
                'path': phase55RuntimeAlbumFolder,
                'item_count': albumItems.length,
                'items': albumItems,
                'subfolders': [],
              },
            ],
          },
        ],
      },
    ],
  };
}

Map<String, dynamic> phase55ReconciliationCatalogJson({
  required String retainedTrack1Path,
  required String retainedTrack2Path,
  required String rootPath,
}) {
  final scratch = MediaItem(
    id: 'scratch',
    title: 'scratch',
    filePath: '${phase55RuntimeAlbumFolder}\\01.wav',
    mediaKindRaw: 'audio',
    artist: phase55RuntimeArtist,
    album: phase55RuntimeAlbum,
    albumArtist: phase55RuntimeArtist,
  );
  final artistKey = MusicLibraryProjection.artistGroupKeyForItem(scratch);
  final albumKey = MusicLibraryProjection.albumGroupKeyForItem(scratch);

  return {
    'generated_at': '2026-07-23T06:30:00+00:00',
    'total_items': 3,
    'catalogue': {
      'id': '${phase55RuntimeCatalogueId}-RECONCILED',
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': phase55RuntimeMusicRoot,
        'item_count': 3,
        'items': [
          {
            'id': phase55RootTrackId,
            'title': '$phase55SentinelTitlePrefix Root',
            'file_path': rootPath,
            'status': 'available',
            'media_kind': 'audio',
            'artist': phase55RuntimeArtist,
            'album': 'Singles',
            'year': 2024,
            'duration_seconds': 180,
          },
        ],
        'subfolders': [
          {
            'id': 'artist',
            'name': phase55RuntimeArtist,
            'path': phase55RuntimeArtistFolder,
            'item_count': 2,
            'items': [],
            'subfolders': [
              {
                'id': 'album',
                'name': phase55RuntimeAlbum,
                'path': phase55RuntimeAlbumFolder,
                'item_count': 2,
                'items': [
                  {
                    'id': phase55AlbumTrackIds[0],
                    'title': '$phase55SentinelTitlePrefix 1',
                    'file_path': retainedTrack1Path,
                    'status': 'available',
                    'media_kind': 'audio',
                    'artist': phase55RuntimeArtist,
                    'album': phase55RuntimeAlbum,
                    'album_artist': phase55RuntimeArtist,
                    'track_number': 1,
                    'disc_number': 1,
                    'year': 2024,
                    'duration_seconds': 240,
                    'artist_group_key': artistKey,
                    'album_group_key': albumKey,
                  },
                  {
                    'id': phase55AlbumTrackIds[1],
                    'title': '$phase55SentinelTitlePrefix 2',
                    'file_path': retainedTrack2Path,
                    'status': 'available',
                    'media_kind': 'audio',
                    'artist': phase55RuntimeArtist,
                    'album': phase55RuntimeAlbum,
                    'album_artist': phase55RuntimeArtist,
                    'track_number': 2,
                    'disc_number': 1,
                    'year': 2024,
                    'duration_seconds': 240,
                    'artist_group_key': artistKey,
                    'album_group_key': albumKey,
                  },
                ],
                'subfolders': [],
              },
            ],
          },
        ],
      },
    ],
  };
}

Map<String, dynamic> phase55EmptyAudioCatalogJson() {
  return {
    'generated_at': '2026-07-23T07:00:00+00:00',
    'total_items': 1,
    'catalogue': {
      'id': '${phase55RuntimeCatalogueId}-EMPTY-AUDIO',
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'video-only',
        'name': 'Videos',
        'path': r'C:\Runtime\PHASE55\Videos',
        'item_count': 1,
        'items': [
          {
            'id': 'p55-video-only',
            'title': '$phase55SentinelTitlePrefix Video Only',
            'file_path': r'C:\Runtime\PHASE55\Videos\only.mp4',
            'status': 'available',
            'media_kind': 'video',
            'year': 2024,
            'duration_seconds': 120,
          },
        ],
        'subfolders': [],
      },
    ],
  };
}

String phase55ResolveLibMpvPath() {
  final fromEnv = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }

  for (final relative in [
    r'build\windows\x64\runner\Debug\libmpv-2.dll',
    r'build\windows\x64\runner\Release\libmpv-2.dll',
  ]) {
    final file = File(relative);
    if (file.existsSync()) return file.absolute.path;
  }

  fail(
    'libmpv-2.dll not found. Run `flutter build windows --release` or set '
    'LIBMPV_LIBRARY_PATH.',
  );
}

Future<void> phase55WaitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for condition');
}

void phase55AssertNoForbiddenContent(String text) {
  for (final fragment in phase55ForbiddenFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason: 'forbidden fragment: $fragment',
    );
  }
  expect(exportContainsSensitiveData(text), isFalse);
  expect(text.contains(MusicPlaybackSessionRepository.storageKey), isFalse);
  expect(text.contains('"queueTrackIds"'), isFalse);
  expect(text.contains('playbackPositionMs'), isFalse);
}

const phase55ForbiddenFragments = <String>[
  r'Y:\Media',
  r'C:\Users',
  r'C:\Runtime\PHASE55',
  r'\\SERVER',
  '/volume1/Media',
  'file://',
  'http://',
  'https://',
  'p55-album-t',
  'p55-root',
  'p55-video',
  'p55-missing',
  phase55SentinelTitlePrefix,
  phase55RuntimeArtist,
  phase55RuntimeAlbum,
  '.wav',
  '.mp3',
  '.mp4',
];

void phase55AssertPositionNear(
  Duration actual,
  Duration expected, {
  Duration tolerance = phase55PositionTolerance,
}) {
  final delta = (actual - expected).abs();
  expect(
    delta <= tolerance,
    isTrue,
    reason: 'position $actual not within $tolerance of $expected '
        '(delta=$delta)',
  );
}

Future<void> phase55SeedIsolationMarkers() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(phase55VideoResumePositionKey, 123);
  await prefs.setInt(phase55VideoResumeDurationKey, 3600);
}

Future<void> phase55AssertIsolationMarkersUnchanged({
  required int expectedListeningCount,
  required String? expectedSettingsRaw,
}) async {
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getInt(phase55VideoResumePositionKey), 123);
  expect(prefs.getInt(phase55VideoResumeDurationKey), 3600);
  expect(
    prefs.getString(SettingsRepository.storageKey),
    expectedSettingsRaw,
  );

  final listeningRaw = prefs.getString(MusicListeningRepository.storageKey);
  if (expectedListeningCount == 0) {
    if (listeningRaw == null) return;
    final decoded = jsonDecode(listeningRaw) as Map<String, dynamic>;
    final records = decoded['records'] as List<dynamic>? ?? const [];
    expect(records, isEmpty);
  }
}
