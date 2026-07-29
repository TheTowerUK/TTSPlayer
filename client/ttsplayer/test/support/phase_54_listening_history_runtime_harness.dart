import 'dart:convert';
import 'dart:io';

/// Production listening-history runtime harness for Phase 5.4 Step 9.
///
/// Wires repository, coordinator, queue, catalogue cache, diagnostics, and
/// settings like [main.dart]. Deterministic threshold scenarios (R3–R4, R6–R8,
/// R10, R12) use [PlaybackService.mediaKitInitOverride] so coordinator ticks
/// do not require 15–45 s wall-clock waits — real libmpv is validated
/// separately in R5 via a dedicated [PlaybackService] instance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_recently_played_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';
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

import 'audio_gate_fixtures.dart';
import 'diagnostics_test_harness.dart';
import '../playback_service_extensions_test.dart';
import 'phase_46_runtime_harness.dart';
import 'phase_54_listening_history_runtime_baseline.dart';
import 'phase_54_listening_history_support.dart';

const phase54RuntimeCatalogueId = 'PHASE54-RUNTIME';
const phase54RuntimeArtist = 'Runtime Artist';
const phase54RuntimeAlbum = 'Runtime Album';
const phase54RuntimeMusicRoot = r'C:\Runtime\Music';
const phase54RuntimeArtistFolder = r'C:\Runtime\Music\Runtime Artist';
const phase54RuntimeAlbumFolder =
    r'C:\Runtime\Music\Runtime Artist\Runtime Album';

const phase54AlbumTrackIds = ['p54-album-t1', 'p54-album-t2', 'p54-album-t3'];
const phase54RootTrackId = 'p54-root';

const phase54SupportedAudioExtensions = {
  '.mp3',
  '.wav',
  '.flac',
  '.m4a',
  '.aac',
  '.ogg',
  '.opus',
};

/// Source classification for real playback fixture (no user paths in docs).
enum Phase54AudioFixtureSource {
  envVariable,
  generatedWav,
  phase53Reuse,
  unavailable,
}

class Phase54ResolvedAudioFixture {
  const Phase54ResolvedAudioFixture({
    required this.source,
    required this.filePath,
    required this.isValid,
  });

  final Phase54AudioFixtureSource source;
  final String filePath;
  final bool isValid;
}

/// Production [DiagnosticsService] with observability hooks for runtime validation.
class Phase54ObservedDiagnosticsService extends DiagnosticsService {
  Phase54ObservedDiagnosticsService({
    required super.catalogService,
    required super.artworkService,
    required super.searchService,
    required super.playbackService,
    required super.mediaProviderConfigService,
    required super.libraryMetadataRepository,
    required super.applicationStartedAt,
    required super.musicListeningRepository,
    required super.musicListeningCoordinator,
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

/// Full production listening-history stack for Windows runtime validation.
class Phase54RuntimeContext {
  Phase54RuntimeContext._({
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
    required this.repository,
    required this.coordinator,
    required this.queue,
    required this.diagnostics,
    required this.clipboard,
    required this.applicationStartedAt,
    required this.clock,
    required this.audioFixture,
    required this.tempCatalogDir,
  });

  final Phase54ListeningHistoryRuntimeBaseline baseline;
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
  final MusicListeningRepository repository;
  final MusicListeningCoordinator coordinator;
  final MusicPlaybackQueueController queue;
  final Phase54ObservedDiagnosticsService diagnostics;
  final FakeClipboardWriter clipboard;
  final DateTime applicationStartedAt;
  final Phase54TestClock clock;
  final Phase54ResolvedAudioFixture audioFixture;
  final Directory tempCatalogDir;

  MusicLibraryProjection get projection => musicLibrary.projectionFor(catalog);

  MediaItem track(String id) =>
      catalog.allItems.firstWhere((item) => item.id == id);

  static Future<Phase54RuntimeContext> create({
    Phase54ListeningHistoryRuntimeBaseline? baseline,
    Map<String, Object>? initialPrefs,
  }) async {
    final resolvedBaseline =
        baseline ?? Phase54ListeningHistoryRuntimeBaseline();
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
      basename: 'p54_album_t1',
    );
    final wav2 = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p54_album_t2',
    );
    final wav3 = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p54_album_t3',
    );
    final rootWav = await writeMonoWavFixture(
      duration: const Duration(seconds: 3),
      basename: 'p54_root',
    );

    final audioFixture = phase54ResolveAudioFixture(fallbackPath: wav1.path);
    resolvedBaseline.realAudioExercised = audioFixture.isValid;

    final catalogJson = phase54RuntimeCatalogJson(
      albumPaths: {
        phase54AlbumTrackIds[0]: wav1.path,
        phase54AlbumTrackIds[1]: wav2.path,
        phase54AlbumTrackIds[2]: wav3.path,
      },
      rootPath: rootWav.path,
    );
    final catalog = Catalog.fromJson(catalogJson);
    resolvedBaseline.catalogueIdentity = catalog.catalogueIdentity;

    final tempDir =
        await Directory.systemTemp.createTemp('p54_runtime_catalog_');
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

    final repository = MusicListeningRepository();
    final initStopwatch = Stopwatch()..start();
    await repository.initialize();
    resolvedBaseline.observe(
      'repository_init_ms',
      initStopwatch.elapsedMilliseconds,
    );

    final queue = MusicPlaybackQueueController(playbackService: playback);
    final clock = Phase54TestClock();
    final coordinator = MusicListeningCoordinator(
      repository: repository,
      playbackService: playback,
      queueController: queue,
      now: clock.now,
    );
    queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
    coordinator.attach();

    final catalogCache = CatalogCacheCoordinator(
      artworkService: artwork,
      searchService: search,
      musicLibraryService: musicLibrary,
      libraryMetadataRepository: metadata,
      musicPlaybackQueueController: queue,
      musicListeningRepository: repository,
      musicPlaybackSessionRepository: MusicPlaybackSessionRepository(),
      readingProgressRepository: ReadingProgressRepository(),
      metadataEnrichmentRepository: MetadataEnrichmentRepository(),
    );

    final catalogService = CatalogService(
      settingsRepository: settings,
      onCatalogReplaced: catalogCache.onCatalogReplaced,
    )..includeLegacyCataloguePaths = false;
    await catalogService.loadFromFile(catalogPath);

    final applicationStartedAt = DateTime.now().toUtc().subtract(
          const Duration(minutes: 2),
        );
    final diagnostics = Phase54ObservedDiagnosticsService(
      catalogService: catalogService,
      artworkService: artwork,
      searchService: search,
      playbackService: playback,
      mediaProviderConfigService: config,
      libraryMetadataRepository: metadata,
      musicListeningRepository: repository,
      musicListeningCoordinator: coordinator,
      applicationStartedAt: applicationStartedAt,
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => true,
    );
    final clipboard = FakeClipboardWriter();

    return Phase54RuntimeContext._(
      baseline: resolvedBaseline,
      catalog: catalog,
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
      repository: repository,
      coordinator: coordinator,
      queue: queue,
      diagnostics: diagnostics,
      clipboard: clipboard,
      applicationStartedAt: applicationStartedAt,
      clock: clock,
      audioFixture: audioFixture,
      tempCatalogDir: tempDir,
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
        value: coordinator,
      ),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: repository,
      ),
      ChangeNotifierProvider(create: (_) => ScannerService()),
      ChangeNotifierProvider(create: (_) => ScanHistoryService()),
    ];
  }

  Widget musicApp({required Widget home}) {
    return MultiProvider(
      providers: coreProviders(),
      child: MaterialApp(theme: AppTheme.dark, home: home),
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

  Widget settingsApp() {
    return MultiProvider(
      providers: coreProviders(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    );
  }

  Future<void> clearHistory() async {
    await repository.clearAll();
  }

  Future<void> dispose() async {
    coordinator.dispose();
    await queue.onPlayerRouteClosed();
    await playback.stop();
    playback.clearReadySimulationForTest();
    if (tempCatalogDir.existsSync()) {
      tempCatalogDir.deleteSync(recursive: true);
    }
  }

  Future<void> seedAndSimulatePlay(
    MediaItem track, {
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 4),
  }) async {
    if (queue.currentTrack?.id != track.id) {
      queue.seedSingleTrack(track);
    }
    await queue.playCurrent();
    playback.simulateReadyForTest(track);
    playback.simulatePlaybackMetricsForTest(
      duration: duration,
      position: position,
    );
    playback.simulatePlayingForTest(playing: true);
    playback.notifyListeners();
    await coordinator.waitForIdleForTest();
  }

  Future<void> simulateTick({
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

  Future<void> simulatePlayForSeconds(
    MediaItem track,
    int seconds, {
    Duration startPosition = Duration.zero,
    bool stopAtEnd = false,
  }) async {
    await seedAndSimulatePlay(track, position: startPosition);
    for (var i = 1; i <= seconds; i++) {
      await simulateTick(position: startPosition + Duration(seconds: i));
    }
    if (stopAtEnd) {
      await simulateTick(
        position: startPosition + Duration(seconds: seconds),
        playing: false,
      );
    }
  }

  Future<void> prepareRealPlayback(MediaItem track) async {
    playback.clearReadySimulationForTest();
    if (queue.currentTrack?.id != track.id) {
      queue.seedSingleTrack(track);
    }
    queue.onPlayerRouteOpened();
    await queue.playCurrent();
  }

  Future<RuntimeDiagnosticsSnapshot> timedCapture(String label) async {
    final stopwatch = Stopwatch()..start();
    final snapshot = await diagnostics.captureSnapshot();
    baseline.observe('${label}_ms', stopwatch.elapsedMilliseconds);
    return snapshot;
  }

  Future<MusicListeningRepository> reloadRepository() async {
    final reloaded = MusicListeningRepository();
    await reloaded.initialize();
    return reloaded;
  }
}

Map<String, dynamic> phase54RuntimeCatalogJson({
  required Map<String, String> albumPaths,
  required String rootPath,
}) {
  final scratch = MediaItem(
    id: 'scratch',
    title: 'scratch',
    filePath: '${phase54RuntimeAlbumFolder}\\01.wav',
    mediaKindRaw: 'audio',
    artist: phase54RuntimeArtist,
    album: phase54RuntimeAlbum,
    albumArtist: phase54RuntimeArtist,
  );
  final artistKey = MusicLibraryProjection.artistGroupKeyForItem(scratch);
  final albumKey = MusicLibraryProjection.albumGroupKeyForItem(scratch);

  return {
    'generated_at': '2026-07-22T04:00:00+00:00',
    'total_items': 4,
    'catalogue': {
      'id': phase54RuntimeCatalogueId,
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': phase54RuntimeMusicRoot,
        'item_count': 4,
        'items': [
          {
            'id': phase54RootTrackId,
            'title': 'Runtime Root Track',
            'file_path': rootPath,
            'status': 'available',
            'media_kind': 'audio',
            'artist': phase54RuntimeArtist,
            'album': 'Singles',
            'year': 2024,
            'duration_seconds': 180,
          },
        ],
        'subfolders': [
          {
            'id': 'artist',
            'name': phase54RuntimeArtist,
            'path': phase54RuntimeArtistFolder,
            'item_count': 3,
            'items': [],
            'subfolders': [
              {
                'id': 'album',
                'name': phase54RuntimeAlbum,
                'path': phase54RuntimeAlbumFolder,
                'item_count': 3,
                'items': [
                  for (var i = 0; i < phase54AlbumTrackIds.length; i++)
                    {
                      'id': phase54AlbumTrackIds[i],
                      'title': 'Runtime Album Track ${i + 1}',
                      'file_path': albumPaths[phase54AlbumTrackIds[i]],
                      'status': 'available',
                      'media_kind': 'audio',
                      'artist': phase54RuntimeArtist,
                      'album': phase54RuntimeAlbum,
                      'album_artist': phase54RuntimeArtist,
                      'track_number': i + 1,
                      'disc_number': 1,
                      'year': 2024,
                      'duration_seconds': 180,
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

Map<String, dynamic> phase54ReplacementCatalogJson({
  required String retainedTrackPath,
  required String rootPath,
}) {
  final scratch = MediaItem(
    id: 'scratch',
    title: 'scratch',
    filePath: '${phase54RuntimeAlbumFolder}\\01.wav',
    mediaKindRaw: 'audio',
    artist: phase54RuntimeArtist,
    album: phase54RuntimeAlbum,
    albumArtist: phase54RuntimeArtist,
  );
  final artistKey = MusicLibraryProjection.artistGroupKeyForItem(scratch);
  final albumKey = MusicLibraryProjection.albumGroupKeyForItem(scratch);

  return {
    'generated_at': '2026-07-22T04:30:00+00:00',
    'total_items': 2,
    'catalogue': {
      'id': '${phase54RuntimeCatalogueId}-REPLACED',
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': phase54RuntimeMusicRoot,
        'item_count': 2,
        'items': [
          {
            'id': phase54RootTrackId,
            'title': 'Runtime Root Track',
            'file_path': rootPath,
            'status': 'available',
            'media_kind': 'audio',
            'artist': phase54RuntimeArtist,
            'album': 'Singles',
            'year': 2024,
            'duration_seconds': 180,
          },
        ],
        'subfolders': [
          {
            'id': 'artist',
            'name': phase54RuntimeArtist,
            'path': phase54RuntimeArtistFolder,
            'item_count': 1,
            'items': [],
            'subfolders': [
              {
                'id': 'album',
                'name': phase54RuntimeAlbum,
                'path': phase54RuntimeAlbumFolder,
                'item_count': 1,
                'items': [
                  {
                    'id': phase54AlbumTrackIds[0],
                    'title': 'Refreshed Album Track One',
                    'file_path': retainedTrackPath,
                    'status': 'available',
                    'media_kind': 'audio',
                    'artist': phase54RuntimeArtist,
                    'album': phase54RuntimeAlbum,
                    'album_artist': phase54RuntimeArtist,
                    'track_number': 1,
                    'disc_number': 1,
                    'year': 2024,
                    'duration_seconds': 180,
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

String _extension(String path) {
  final index = path.lastIndexOf('.');
  if (index <= 0 || index == path.length - 1) return '';
  return path.substring(index);
}

Phase54ResolvedAudioFixture phase54ResolveAudioFixture({
  required String fallbackPath,
}) {
  final fromEnv = Platform.environment['PHASE_54_AUDIO_FILE'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final file = File(fromEnv);
    if (file.existsSync()) {
      final ext = _extension(fromEnv).toLowerCase();
      if (phase54SupportedAudioExtensions.contains(ext)) {
        return Phase54ResolvedAudioFixture(
          source: Phase54AudioFixtureSource.envVariable,
          filePath: file.absolute.path,
          isValid: true,
        );
      }
    }
  }

  if (File(fallbackPath).existsSync()) {
    return Phase54ResolvedAudioFixture(
      source: Phase54AudioFixtureSource.generatedWav,
      filePath: fallbackPath,
      isValid: true,
    );
  }

  return const Phase54ResolvedAudioFixture(
    source: Phase54AudioFixtureSource.unavailable,
    filePath: '',
    isValid: false,
  );
}

String phase54ResolveLibMpvPath() {
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

Future<void> phase54WaitFor(
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

Future<void> phase54ConfigureViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> phase54PumpMusicScreen(
    WidgetTester tester, Phase54RuntimeContext ctx) async {
  await tester.pumpWidget(ctx.musicApp(home: const MusicScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> phase54PumpRecentlyPlayed(
  WidgetTester tester,
  Phase54RuntimeContext ctx,
) async {
  await tester.pumpWidget(
    ctx.musicApp(home: const MusicRecentlyPlayedScreen()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> phase54OpenDiagnosticsFromSettings(
  WidgetTester tester,
  Phase54RuntimeContext ctx,
) async {
  await tester.pumpWidget(ctx.settingsApp());
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('view_diagnostics')).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.ensureVisible(find.byKey(const Key('view_diagnostics')));
  await tester.tap(find.byKey(const Key('view_diagnostics')));
  await tester.pumpAndSettle();
  tester.takeException();
}

Future<void> phase54PumpDiagnostics(
  WidgetTester tester,
  Phase54RuntimeContext ctx,
) async {
  await tester.pumpWidget(ctx.diagnosticsApp());
  await tester.pump();
  await tester.pumpAndSettle();
}

const phase54ForbiddenFragments = <String>[
  r'Y:\Media',
  r'C:\Users',
  r'\\SERVER',
  '/volume1/Media',
  'file://',
  'http://',
  'https://',
  'p54-album-t',
  'p54-root',
  'Runtime Album Track',
  'Runtime Root Track',
  'Runtime Artist',
  'Runtime Album',
  '.wav',
  '.mp3',
];

void phase54AssertNoForbiddenContent(String text) {
  for (final fragment in phase54ForbiddenFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason: 'forbidden fragment: $fragment',
    );
  }
  expect(exportContainsSensitiveData(text), isFalse);
}

void phase54AssertExportHeadings(String export) {
  phase46AssertExportHeadings(export);
}

void phase54AssertDiagnosticsSectionOrder(WidgetTester tester) {
  for (final heading in const [
    'Application',
    'Provider',
    'Catalogue',
    'Cache',
    'Search',
    'Playback',
    'Music Listening',
    'Library',
  ]) {
    expect(find.text(heading), findsOneWidget);
  }
}

String phase54AudioFixtureSourceLabel(Phase54AudioFixtureSource source) {
  switch (source) {
    case Phase54AudioFixtureSource.envVariable:
      return 'PHASE_54_AUDIO_FILE';
    case Phase54AudioFixtureSource.generatedWav:
      return 'generated_mono_wav';
    case Phase54AudioFixtureSource.phase53Reuse:
      return 'phase53_fixture_reuse';
    case Phase54AudioFixtureSource.unavailable:
      return 'unavailable';
  }
}

Future<Phase54OptionalLocalCatalogResult> phase54TryOptionalLocalCatalog(
  Phase54RuntimeContext ctx,
) async {
  final path = Platform.environment['PHASE_54_LOCAL_CATALOG'];
  if (path == null || path.isEmpty) {
    return Phase54OptionalLocalCatalogResult.skipped('unset');
  }

  final file = File(path);
  if (!file.existsSync()) {
    return Phase54OptionalLocalCatalogResult.failed('file missing');
  }

  final beforeCount = ctx.repository.storedRecordCount;
  try {
    await ctx.catalogService.loadFromFile(path);
    await Future<void>.delayed(Duration.zero);
    final catalog = ctx.catalogService.catalog;
    if (catalog == null) {
      return Phase54OptionalLocalCatalogResult.failed(
          'catalog null after load');
    }
    final audioCount = catalog.allItems.where((item) => item.isAudio).length;
    if (ctx.repository.storedRecordCount != beforeCount) {
      return Phase54OptionalLocalCatalogResult.failed(
        'history mutated unexpectedly',
      );
    }
    if (audioCount == 0) {
      return Phase54OptionalLocalCatalogResult.loaded(noAudioItems: true);
    }
    return Phase54OptionalLocalCatalogResult.loaded(noAudioItems: false);
  } catch (_) {
    return Phase54OptionalLocalCatalogResult.failed('load threw');
  }
}

class Phase54OptionalLocalCatalogResult {
  Phase54OptionalLocalCatalogResult._(this.status, this.detail);

  final String status;
  final String detail;

  factory Phase54OptionalLocalCatalogResult.skipped(String reason) =>
      Phase54OptionalLocalCatalogResult._('skipped', reason);

  factory Phase54OptionalLocalCatalogResult.failed(String reason) =>
      Phase54OptionalLocalCatalogResult._('failed', reason);

  factory Phase54OptionalLocalCatalogResult.loaded(
      {required bool noAudioItems}) {
    return Phase54OptionalLocalCatalogResult._(
      'loaded',
      noAudioItems ? 'no audio items' : 'audio items present',
    );
  }
}

String phase54ExportText(RuntimeDiagnosticsSnapshot snapshot) {
  return formatDiagnosticsExport(snapshot);
}
