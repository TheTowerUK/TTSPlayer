import 'dart:convert';
import 'dart:io';

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
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_export_coordinator.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

import '../playback_service_extensions_test.dart';
import 'audio_gate_fixtures.dart';
import 'diagnostics_test_harness.dart';
import 'phase_56_large_music_catalog_fixture.dart';
import 'phase_56_runtime_baseline.dart';

/// Forbidden fragments for Phase 5.6 diagnostics redaction checks.
const phase56ForbiddenFragments = <String>[
  Phase56Sentinels.titleToken,
  Phase56Sentinels.artistToken,
  Phase56Sentinels.albumToken,
  Phase56Sentinels.titleTrackId,
  Phase56Sentinels.artistTrackId,
  Phase56Sentinels.albumTrackId,
  r'Y:\Media',
  r'Y:/Media',
  'file://',
  'thumbnail_path',
  'file_path',
  'queueTrackIds',
];

String phase56ResolveLibMpvPath() {
  final override = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }
  for (final candidate in [
    r'build\windows\x64\runner\Release\libmpv-2.dll',
    r'build\windows\x64\runner\Debug\libmpv-2.dll',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  return 'libmpv-2.dll';
}

void phase56AssertNoForbiddenContent(String text) {
  for (final fragment in phase56ForbiddenFragments) {
    expect(
      text.toLowerCase().contains(fragment.toLowerCase()),
      isFalse,
      reason: 'diagnostics export must not contain sensitive fragment',
    );
  }
  expect(exportContainsSensitiveData(text), isFalse);
}

/// Production-like music library stack for Phase 5.6 Windows runtime.
class Phase56RuntimeContext {
  Phase56RuntimeContext._({
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
    required this.tempCatalogDir,
    required this.tempWavDirs,
    required this.artworkTempFiles,
    required this.existingArtworkPaths,
    required this.playableTrackId,
  });

  final Phase56RuntimeBaseline baseline;
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
  final DiagnosticsService diagnostics;
  final FakeClipboardWriter clipboard;
  final Directory tempCatalogDir;
  final List<Directory> tempWavDirs;
  final List<String> artworkTempFiles;
  final Set<String> existingArtworkPaths;
  final String playableTrackId;

  MusicLibraryProjection get projection =>
      musicLibrary.projectionFor(catalogService.catalog ?? catalog);

  static Future<Phase56RuntimeContext> create({
    required Phase56RuntimeBaseline baseline,
    Phase56CatalogProfile profile = Phase56CatalogProfile.large,
    bool includePlayableWav = true,
  }) async {
    await baseline.captureEnvironment();
    baseline.fixtureProfile = profile.name;

    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.5.0-dev',
      buildNumber: '56',
      buildSignature: 'runtime',
      installerStore: null,
    );
    configureArtworkFlutterImageCache();

    final tempWavDirs = <Directory>[];
    final artworkTempFiles = <String>[];
    final existingArtworkPaths = <String>{};
    String? wavPath;
    // Prefer a fully-keyed track (a000/b00/t00–t01 omit album/artist keys).
    String playableId = 'p56-a001-b00-t00';
    if (includePlayableWav) {
      final wav = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'p56_runtime_track',
      );
      tempWavDirs.add(wav.file.parent);
      wavPath = wav.path;
    }

    var catalog = generatePhase56MusicCatalog(
      profile: profile,
      includeSentinels: true,
      includeCompilations: true,
      includeMissingMetadata: true,
    );

    if (wavPath != null) {
      catalog = _withPlayablePath(catalog, playableId, wavPath);
    }

    final tempDir =
        await Directory.systemTemp.createTemp('p56_runtime_catalog_');
    final catalogPath = '${tempDir.path}${Platform.pathSeparator}catalog.json';
    final writeSw = Stopwatch()..start();
    await File(catalogPath).writeAsString(
      jsonEncode(_catalogToJson(catalog)),
    );
    writeSw.stop();
    baseline.observe('catalog_fixture_write_ms', writeSw.elapsedMilliseconds);

    final settings = SettingsRepository();
    await settings.initialize();
    final config = MediaProviderConfigService();
    await config.load();
    final metadata = LibraryMetadataRepository();
    await metadata.initialize();
    final musicLibrary = MusicLibraryService();
    final artwork = ArtworkService(
      fileExists: existingArtworkPaths.contains,
    );
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
            duration: const Duration(minutes: 3),
            position: Duration.zero,
          );
          service.simulateReadyForTest(item);
        }
      },
    );

    final listeningRepository = MusicListeningRepository();
    await listeningRepository.initialize();
    final sessionRepository = MusicPlaybackSessionRepository();
    await sessionRepository.initialize();

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
    );

    final catalogService = CatalogService(
      settingsRepository: settings,
      onCatalogReplaced: catalogCache.onCatalogReplaced,
    )..includeLegacyCataloguePaths = false;

    final loadSw = Stopwatch()..start();
    await catalogService.loadFromFile(catalogPath);
    loadSw.stop();
    baseline.observe('catalog_load_ms', loadSw.elapsedMilliseconds);

    final loaded = catalogService.catalog;
    expect(loaded, isNotNull);

    await restorer.restoreOnColdStart(loaded!);

    final diagnostics = DiagnosticsService(
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
      applicationStartedAt: DateTime.now().toUtc(),
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => true,
    );

    return Phase56RuntimeContext._(
      baseline: baseline,
      catalog: loaded,
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
      clipboard: FakeClipboardWriter(),
      tempCatalogDir: tempDir,
      tempWavDirs: tempWavDirs,
      artworkTempFiles: artworkTempFiles,
      existingArtworkPaths: existingArtworkPaths,
      playableTrackId: playableId,
    );
  }

  /// Writes a tiny valid JPEG and registers it for [ArtworkService] resolution.
  Future<String> writeValidArtworkJpeg() async {
    // Minimal 1×1 JPEG.
    const bytes = <int>[
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0xFF,
      0xDB,
      0x00,
      0x43,
      0x00,
      0x08,
      0x06,
      0x06,
      0x07,
      0x06,
      0x05,
      0x08,
      0x07,
      0x07,
      0x07,
      0x09,
      0x09,
      0x08,
      0x0A,
      0x0C,
      0x14,
      0x0D,
      0x0C,
      0x0B,
      0x0B,
      0x0C,
      0x19,
      0x12,
      0x13,
      0x0F,
      0x14,
      0x1D,
      0x1A,
      0x1F,
      0x1E,
      0x1D,
      0x1A,
      0x1C,
      0x1C,
      0x20,
      0x24,
      0x2E,
      0x27,
      0x20,
      0x22,
      0x2C,
      0x23,
      0x1C,
      0x1C,
      0x28,
      0x37,
      0x29,
      0x2C,
      0x30,
      0x31,
      0x34,
      0x34,
      0x34,
      0x1F,
      0x27,
      0x39,
      0x3D,
      0x38,
      0x32,
      0x3C,
      0x2E,
      0x33,
      0x34,
      0x32,
      0xFF,
      0xC0,
      0x00,
      0x0B,
      0x08,
      0x00,
      0x01,
      0x00,
      0x01,
      0x01,
      0x01,
      0x11,
      0x00,
      0xFF,
      0xC4,
      0x00,
      0x1F,
      0x00,
      0x00,
      0x01,
      0x05,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0A,
      0x0B,
      0xFF,
      0xC4,
      0x00,
      0xB5,
      0x10,
      0x00,
      0x02,
      0x01,
      0x03,
      0x03,
      0x02,
      0x04,
      0x03,
      0x05,
      0x05,
      0x04,
      0x04,
      0x00,
      0x00,
      0x01,
      0x7D,
      0x01,
      0x02,
      0x03,
      0x00,
      0x04,
      0x11,
      0x05,
      0x12,
      0x21,
      0x31,
      0x41,
      0x06,
      0x13,
      0x51,
      0x61,
      0x07,
      0x22,
      0x71,
      0x14,
      0x32,
      0x81,
      0x91,
      0xA1,
      0x08,
      0x23,
      0x42,
      0xB1,
      0xC1,
      0x15,
      0x52,
      0xD1,
      0xF0,
      0x24,
      0x33,
      0x62,
      0x72,
      0x82,
      0x09,
      0x0A,
      0x16,
      0x17,
      0x18,
      0x19,
      0x1A,
      0x25,
      0x26,
      0x27,
      0x28,
      0x29,
      0x2A,
      0x34,
      0x35,
      0x36,
      0x37,
      0x38,
      0x39,
      0x3A,
      0x43,
      0x44,
      0x45,
      0x46,
      0x47,
      0x48,
      0x49,
      0x4A,
      0x53,
      0x54,
      0x55,
      0x56,
      0x57,
      0x58,
      0x59,
      0x5A,
      0x63,
      0x64,
      0x65,
      0x66,
      0x67,
      0x68,
      0x69,
      0x6A,
      0x73,
      0x74,
      0x75,
      0x76,
      0x77,
      0x78,
      0x79,
      0x7A,
      0x83,
      0x84,
      0x85,
      0x86,
      0x87,
      0x88,
      0x89,
      0x8A,
      0x92,
      0x93,
      0x94,
      0x95,
      0x96,
      0x97,
      0x98,
      0x99,
      0x9A,
      0xA2,
      0xA3,
      0xA4,
      0xA5,
      0xA6,
      0xA7,
      0xA8,
      0xA9,
      0xAA,
      0xB2,
      0xB3,
      0xB4,
      0xB5,
      0xB6,
      0xB7,
      0xB8,
      0xB9,
      0xBA,
      0xC2,
      0xC3,
      0xC4,
      0xC5,
      0xC6,
      0xC7,
      0xC8,
      0xC9,
      0xCA,
      0xD2,
      0xD3,
      0xD4,
      0xD5,
      0xD6,
      0xD7,
      0xD8,
      0xD9,
      0xDA,
      0xE1,
      0xE2,
      0xE3,
      0xE4,
      0xE5,
      0xE6,
      0xE7,
      0xE8,
      0xE9,
      0xEA,
      0xF1,
      0xF2,
      0xF3,
      0xF4,
      0xF5,
      0xF6,
      0xF7,
      0xF8,
      0xF9,
      0xFA,
      0xFF,
      0xDA,
      0x00,
      0x08,
      0x01,
      0x01,
      0x00,
      0x00,
      0x3F,
      0x00,
      0x7F,
      0xFF,
      0xD9,
    ];
    final file = File(
      '${tempCatalogDir.path}${Platform.pathSeparator}'
      'p56_art_${artworkTempFiles.length}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    artworkTempFiles.add(file.path);
    existingArtworkPaths.add(file.path);
    return file.path;
  }

  List<SingleChildWidget> providers({Widget? child}) {
    return [
      ChangeNotifierProvider<SettingsRepository>.value(value: settings),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: metadata),
      ChangeNotifierProvider<MediaProviderConfigService>.value(value: config),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      ),
      Provider<ArtworkService>.value(value: artwork),
      Provider<SearchService>.value(value: search),
      Provider<MusicLibraryService>.value(value: musicLibrary),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: listeningRepository,
      ),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(value: queue),
      ChangeNotifierProvider<MusicListeningCoordinator>.value(
        value: listeningCoordinator,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionRepository>.value(
        value: sessionRepository,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionCoordinator>.value(
        value: sessionCoordinator,
      ),
      Provider<MusicPlaybackSessionRestorer>.value(value: restorer),
      Provider<DiagnosticsService>.value(value: diagnostics),
    ];
  }

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: providers(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: child,
      ),
    );
  }

  Future<String> exportDiagnostics() async {
    final coordinator = DiagnosticsExportCoordinator(
      diagnosticsService: diagnostics,
      clipboardWriter: clipboard,
    );
    await coordinator.copyDiagnostics();
    return clipboard.lastWrittenText ?? '';
  }

  Future<void> replaceCatalog(Catalog next) async {
    final path =
        '${tempCatalogDir.path}${Platform.pathSeparator}catalog_b.json';
    await File(path).writeAsString(jsonEncode(_catalogToJson(next)));
    final sw = Stopwatch()..start();
    await catalogService.loadFromFile(path);
    sw.stop();
    baseline.observe('catalog_replace_ms', sw.elapsedMilliseconds);
  }

  Future<void> reloadOriginalCatalog() async {
    await catalogService.loadFromFile(catalogPath);
  }

  MediaItem? trackById(String id) =>
      (catalogService.catalog ?? catalog).findItemById(id);

  Future<void> resetScenarioState() async {
    try {
      await listeningCoordinator.drainPendingWrites();
    } catch (_) {}
    try {
      await sessionCoordinator.drainPendingWrites();
    } catch (_) {}
    try {
      await queue.onPlayerRouteClosed();
    } catch (_) {}
    try {
      await playback.stop();
    } catch (_) {}
    playback.clearReadySimulationForTest();
    queue.clearQueueOnly();
    await listeningRepository.clearAll();
    await sessionRepository.clear();
    search.debugSearchDelay = null;
    clipboard.lastWrittenText = null;
    clipboard.writeCount = 0;
  }

  Future<void> seedAndSimulatePlay(
    MediaItem track, {
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 3),
  }) async {
    if (queue.currentTrack?.id != track.id) {
      queue.seedSingleTrack(track);
    }
    queue.onPlayerRouteOpened();
    await queue.playCurrent();
    playback.simulateReadyForTest(track);
    playback.simulatePlaybackMetricsForTest(
      duration: duration,
      position: position,
    );
    playback.simulatePlayingForTest(playing: true);
    playback.notifyListeners();
    await listeningCoordinator.waitForIdleForTest();
  }

  Future<void> simulateTick({
    required Duration position,
    bool? playing,
    bool completed = false,
  }) async {
    playback.simulatePlaybackMetricsForTest(
      position: position,
      completed: completed,
    );
    if (playing != null) {
      playback.simulatePlayingForTest(playing: playing);
    }
    listeningCoordinator.handlePlaybackTickForTest();
    await listeningCoordinator.waitForIdleForTest();
  }

  Future<void> simulatePlayForSeconds(MediaItem track, int seconds) async {
    await seedAndSimulatePlay(track);
    for (var i = 1; i <= seconds; i++) {
      await simulateTick(position: Duration(seconds: i));
    }
    await simulateTick(position: Duration(seconds: seconds), playing: false);
    await sessionCoordinator.drainPendingWrites();
  }

  Future<void> dispose() async {
    try {
      await resetScenarioState();
    } catch (_) {}
    try {
      listeningCoordinator.dispose();
    } catch (_) {}
    try {
      sessionCoordinator.dispose();
    } catch (_) {}
    try {
      await playback.stop();
    } catch (_) {}
    try {
      if (tempCatalogDir.existsSync()) {
        tempCatalogDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    for (final dir in tempWavDirs) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    for (final path in artworkTempFiles) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}

Catalog _withPlayablePath(Catalog catalog, String trackId, String wavPath) {
  final json = _catalogToJson(catalog);
  void walk(List<dynamic> folders) {
    for (final folder in folders) {
      final map = folder as Map<String, dynamic>;
      final items = map['items'] as List<dynamic>? ?? const [];
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        if (item['id'] == trackId) {
          item['file_path'] = wavPath;
        }
      }
      walk(map['subfolders'] as List<dynamic>? ?? const []);
    }
  }

  walk(json['folders'] as List<dynamic>);
  return Catalog.fromJson(json);
}

Map<String, dynamic> _catalogToJson(Catalog catalog) {
  return {
    'generated_at': catalog.generatedAt,
    'total_items': catalog.totalItems,
    'catalogue': {
      'id': catalog.catalogueInfo?.id ?? catalog.catalogueIdentity,
      'scanner_version': catalog.catalogueInfo?.scannerVersion ?? '0.4.0',
      'catalogue_version': catalog.catalogueInfo?.catalogueVersion ?? 3,
    },
    'folders': [
      for (final folder in catalog.folders) folder.toJson(),
    ],
  };
}

Future<void> phase56ConfigureViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}
