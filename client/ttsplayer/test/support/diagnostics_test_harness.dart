import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/settings/diagnostics_clipboard.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/services/music_listening_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';

Catalog diagnosticsCatalog({
  required String identity,
  int itemCount = 2,
  int libraryCount = 1,
}) {
  return Catalog.fromJson({
    'generated_at': '2026-07-14T10:00:00+00:00',
    'total_items': itemCount,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
    },
    'folders': [
      for (var i = 0; i < libraryCount; i++)
        {
          'id': 'lib-$i',
          'name': 'Library $i',
          'path': r'Y:\Media\Library',
          'item_count': itemCount,
          'items': [
            for (var j = 0; j < itemCount; j++)
              {
                'id': 'item-$i-$j',
                'title': 'Item $j',
                'file_path': r'Y:\Media\Library\item.mp4',
                'status': 'available',
              },
          ],
          'subfolders': [
            {
              'id': 'sub-$i',
              'name': 'Sub',
              'path': r'Y:\Media\Library\Sub',
              'item_count': 0,
              'items': [],
              'subfolders': [],
            },
          ],
        },
    ],
  });
}

CatalogueProviderSnapshot diagnosticsProviderSnapshot({
  bool degraded = false,
  bool demoFallback = false,
  String? lastError,
}) {
  const local = MediaCatalogueProviderDefinition.localFile(
    r'Y:\Media\catalog.json',
  );
  return CatalogueProviderSnapshot(
    providers: [
      CatalogueProviderAttemptRecord(
        definition: local,
        health: degraded
            ? CatalogueProviderHealth.degraded
            : CatalogueProviderHealth.success,
        lastError: lastError,
        lastAttemptAt: DateTime.utc(2026, 7, 16, 10, 0),
        lastSuccessAt: DateTime.utc(2026, 7, 16, 10, 0),
      ),
    ],
    activeProvider: local,
    loadedCatalogueIdentity: '2026-07-14T10:00:00Z-ABC123',
    accessMode: MediaAccessMode.localPreferred,
    lastCatalogueLoadAt: DateTime.utc(2026, 7, 16, 10, 0),
    isDegradedLoad: degraded,
    isDemoFallback: demoFallback,
  );
}

class StubCatalogService extends CatalogService {
  StubCatalogService({
    Catalog? stubCatalog,
    CatalogueProviderSnapshot? stubSnapshot,
    this.loading = false,
    this.error,
    this.demo = false,
    this.degraded = false,
    this.usingFallback = false,
    this.lastRefresh,
    this.lastLoad,
    this.catalogPathValue,
  })  : _stubSnapshot = stubSnapshot ?? diagnosticsProviderSnapshot(),
        _stubCatalog = stubCatalog;

  Catalog? _stubCatalog;
  final CatalogueProviderSnapshot _stubSnapshot;
  final bool loading;
  final String? error;
  final bool demo;
  final bool degraded;
  final bool usingFallback;
  final DateTime? lastRefresh;
  final DateTime? lastLoad;
  final String? catalogPathValue;

  @override
  Catalog? get catalog => _stubCatalog;

  set stubCatalog(Catalog? value) => _stubCatalog = value;

  @override
  bool get isLoading => loading;

  @override
  String? get errorMessage => error;

  @override
  bool get isUsingFallback => usingFallback;

  @override
  bool get isDemoCatalogue => demo;

  @override
  bool get isDegradedLoad => degraded;

  @override
  CatalogueProviderSnapshot get providerSnapshot => _stubSnapshot;

  @override
  MediaCatalogueProviderDefinition? get activeCatalogueProvider =>
      _stubSnapshot.activeProvider;

  @override
  DateTime? get lastRefreshedAt => lastRefresh;

  @override
  DateTime? get lastCatalogueLoadAt => lastLoad;

  @override
  String? get catalogPath => catalogPathValue ?? _stubSnapshot.catalogPath;

  @override
  Future<void> refreshCatalogue() async {}
}

class ThrowingArtworkService extends ArtworkService {
  @override
  int get cacheEntryCount => throw StateError('artwork unavailable');
}

class ThrowingSearchService extends SearchService {
  @override
  bool get hasIndex => throw StateError('search unavailable');
}

class ThrowingMusicListeningRepository extends MusicListeningRepository {
  ThrowingMusicListeningRepository({super.initialRecords});

  bool throwOnDiagnosticsRead = false;

  @override
  int get storedRecordCount {
    if (throwOnDiagnosticsRead) {
      throw StateError('music listening unavailable');
    }
    return super.storedRecordCount;
  }
}

class ThrowingSessionMusicListeningCoordinator
    extends MusicListeningCoordinator {
  ThrowingSessionMusicListeningCoordinator({
    required super.repository,
    required super.playbackService,
    required super.queueController,
  });

  @override
  bool get sessionActive => throw StateError('coordinator session unavailable');
}

Future<MusicListeningRepository> initializedMusicListeningRepository({
  List<MusicListeningRecord>? initialRecords,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = MusicListeningRepository();
  await repository.initialize();
  for (final record in initialRecords ?? const <MusicListeningRecord>[]) {
    await repository.upsert(record);
  }
  return repository;
}

MusicListeningCoordinator musicListeningCoordinatorHarness({
  required MusicListeningRepository repository,
  PlaybackService? playbackService,
  MusicPlaybackQueueController? queueController,
}) {
  final playback = playbackService ?? PlaybackService();
  final queue = queueController ??
      MusicPlaybackQueueController(playbackService: playback);
  final coordinator = MusicListeningCoordinator(
    repository: repository,
    playbackService: playback,
    queueController: queue,
  );
  coordinator.attach();
  return coordinator;
}

Future<MusicPlaybackSessionRepository>
    initializedMusicPlaybackSessionRepository({
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  final repository = MusicPlaybackSessionRepository();
  await repository.initialize();
  return repository;
}

MusicPlaybackSessionCoordinator musicPlaybackSessionCoordinatorHarness({
  required MusicPlaybackSessionRepository repository,
  PlaybackService? playbackService,
  MusicPlaybackQueueController? queueController,
  bool attach = true,
  bool deferPersistence = false,
}) {
  final playback = playbackService ?? PlaybackService();
  final queue = queueController ??
      MusicPlaybackQueueController(playbackService: playback);
  final coordinator = MusicPlaybackSessionCoordinator(
    repository: repository,
    playbackService: playback,
    queueController: queue,
    queueMutationDebounce: const Duration(milliseconds: 50),
  );
  if (attach) {
    coordinator.attach(
        deferPersistenceUntilColdStartComplete: deferPersistence);
  }
  return coordinator;
}

Future<DiagnosticsService> buildDiagnosticsHarness({
  Catalog? catalog,
  CatalogueProviderSnapshot? providerSnapshot,
  ArtworkService? artworkService,
  SearchService? searchService,
  PlaybackService? playbackService,
  LibraryMetadataRepository? libraryMetadataRepository,
  MediaProviderConfigService? configService,
  MusicListeningRepository? musicListeningRepository,
  MusicListeningCoordinator? musicListeningCoordinator,
  MusicPlaybackSessionRepository? musicPlaybackSessionRepository,
  MusicPlaybackSessionCoordinator? musicPlaybackSessionCoordinator,
  MusicPlaybackQueueController? musicPlaybackQueueController,
  MusicPlaybackSessionRestorer? musicPlaybackSessionRestorer,
  ReadingProgressRepository? readingProgressRepository,
  ReadingProgressCoordinator? readingProgressCoordinator,
  bool withInitializedMusicPlaybackSession = false,
  bool withInitializedMusicListening = false,
  bool withInitializedReadingProgress = false,
  DateTime? applicationStartedAt,
  Future<PackageInfo> Function()? packageInfoLoader,
  bool Function()? imageCacheAvailableProvider,
  bool withInitializedLibrary = true,
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  PackageInfo.setMockInitialValues(
    appName: 'TTSPlayer',
    packageName: 'ttsplayer',
    version: '0.5.0-dev',
    buildNumber: '42',
    buildSignature: 'sig',
    installerStore: null,
  );

  final metadata = libraryMetadataRepository ?? LibraryMetadataRepository();
  if (withInitializedLibrary && !metadata.isLoaded) {
    await metadata.initialize();
  }

  final config = configService ?? MediaProviderConfigService();
  if (configService == null) {
    await config.load();
  }

  MusicListeningRepository? musicRepo = musicListeningRepository;
  if (withInitializedMusicListening && musicRepo == null) {
    musicRepo = await initializedMusicListeningRepository();
  }

  MusicPlaybackSessionRepository? sessionRepo = musicPlaybackSessionRepository;
  if (withInitializedMusicPlaybackSession && sessionRepo == null) {
    sessionRepo = await initializedMusicPlaybackSessionRepository();
  }

  ReadingProgressRepository? readingRepo = readingProgressRepository;
  if (withInitializedReadingProgress && readingRepo == null) {
    readingRepo = ReadingProgressRepository();
    await readingRepo.initialize();
  }

  return DiagnosticsService(
    catalogService: StubCatalogService(
      stubCatalog: catalog,
      stubSnapshot: providerSnapshot,
      demo: catalog == null,
    ),
    artworkService: artworkService ?? ArtworkService(fileExists: (_) => true),
    searchService: searchService ?? SearchService(),
    playbackService: playbackService ?? PlaybackService(),
    mediaProviderConfigService: config,
    libraryMetadataRepository: metadata,
    musicListeningRepository: musicRepo,
    musicListeningCoordinator: musicListeningCoordinator,
    musicPlaybackSessionRepository: sessionRepo,
    musicPlaybackSessionCoordinator: musicPlaybackSessionCoordinator,
    musicPlaybackQueueController: musicPlaybackQueueController,
    musicPlaybackSessionRestorer: musicPlaybackSessionRestorer,
    readingProgressRepository: readingRepo,
    readingProgressCoordinator: readingProgressCoordinator,
    applicationStartedAt:
        applicationStartedAt ?? DateTime.utc(2026, 7, 16, 9, 0),
    packageInfoLoader: packageInfoLoader,
    platformNameProvider: () => 'windows',
    imageCacheAvailableProvider: imageCacheAvailableProvider ?? (() => false),
  );
}

MediaItem diagnosticsMediaItem({String id = 'media-1'}) {
  return MediaItem.fromJson({
    'id': id,
    'title': 'Sample Title',
    'file_path': r'Y:\Media\sample.mp4',
    'status': 'available',
  });
}

MediaFolder diagnosticsMediaFolder() {
  return MediaFolder.fromJson({
    'id': 'folder-1',
    'name': 'Videos',
    'path': r'Y:\Media\Videos',
    'item_count': 1,
    'items': [],
    'subfolders': [],
  });
}

RuntimeDiagnosticsSnapshot minimalSnapshot({
  DateTime? capturedAt,
  SearchDiagnostics? search,
  PlaybackDiagnostics? playback,
  MusicListeningDiagnostics? musicListening,
  MusicPlaybackSessionDiagnostics? musicPlaybackSession,
  ReadingProgressDiagnostics? readingProgress,
  LibraryDiagnostics? library,
  ProviderDiagnostics? provider,
  CacheDiagnostics? cache,
  bool omitLibrary = false,
  bool omitMusicListening = false,
  bool omitMusicPlaybackSession = false,
  bool omitReadingProgress = false,
}) {
  final at = capturedAt ?? DateTime.utc(2026, 7, 16, 12);
  return RuntimeDiagnosticsSnapshot(
    capturedAt: at,
    application: const ApplicationDiagnostics(
      status: DiagnosticSectionStatus.complete,
      appName: 'TTSPlayer',
      appVersion: '0.5.0-dev',
      buildNumber: '42',
      platform: 'windows',
      startupElapsed: Duration(minutes: 3),
    ),
    provider: provider ??
        const ProviderDiagnostics(
          status: DiagnosticSectionStatus.complete,
          accessModeLabel: 'Local preferred',
        ),
    catalogue: const CatalogueDiagnostics(
      status: DiagnosticSectionStatus.complete,
      catalogueIdentity: '2026-07-14T1…',
      itemCount: 2,
      libraryCount: 1,
      folderCount: 2,
    ),
    cache: cache ??
        const CacheDiagnostics(
          status: DiagnosticSectionStatus.complete,
          artworkCandidateCount: 1,
          artworkCandidateCapacity: 500,
          imageCacheCurrentBytes: 44 * 1024 * 1024,
          imageCacheBudgetBytes: 100 * 1024 * 1024,
        ),
    search: search ??
        const SearchDiagnostics(
          status: DiagnosticSectionStatus.complete,
          hasIndex: false,
          indexBuildCount: 0,
        ),
    playback: playback ??
        const PlaybackDiagnostics(
          status: DiagnosticSectionStatus.complete,
          engineLabel: 'media_kit',
          hasActiveSession: false,
        ),
    musicListening: omitMusicListening
        ? null
        : (musicListening ??
            const MusicListeningDiagnostics(
              status: DiagnosticSectionStatus.complete,
              repositoryLoaded: true,
              storedRecordCount: 0,
              continueListeningCount: 0,
              recentlyPlayedCount: 0,
              completedRecordCount: 0,
              incompleteRecordCount: 0,
              recoveryWarningPresent: false,
              coordinatorAttached: true,
              sessionActive: false,
              pendingWrite: false,
              persistenceWarningPresent: false,
            )),
    musicPlaybackSession: omitMusicPlaybackSession
        ? null
        : (musicPlaybackSession ??
            const MusicPlaybackSessionDiagnostics(
              status: DiagnosticSectionStatus.complete,
              stateVersion: 1,
              repositoryLoaded: true,
              persistedSessionPresent: false,
              persistedQueueCount: 0,
              liveQueueCount: 0,
              activeTrackPresent: false,
              storedPositionAvailable: false,
              restoredOnColdStart: false,
              persistenceEnabled: true,
              pendingQueueDebounce: false,
              pendingWrite: false,
              recoveryWarningPresent: false,
              persistenceWarningPresent: false,
              coordinatorAttached: true,
            )),
    readingProgress: omitReadingProgress
        ? null
        : (readingProgress ??
            const ReadingProgressDiagnostics(
              status: DiagnosticSectionStatus.complete,
              repositoryInitialized: true,
              schemaVersion: 1,
              storedRecordCount: 0,
              continueReadingCount: 0,
              completedRecordCount: 0,
              staleOrUnmatchedRecordCount: 0,
              invalidSkippedRecordCount: 0,
              pendingWrite: false,
              pendingDebounceWrite: false,
              writeInFlight: false,
              recoveryWarningPresent: false,
              pdfRecordCount: 0,
              epubRecordCount: 0,
              cbzRecordCount: 0,
              cbrRecordCount: 0,
              cbrUnavailableRecordCount: 0,
              coordinatorAttached: true,
              sessionActive: false,
              persistenceWarningPresent: false,
            )),
    library: omitLibrary
        ? null
        : (library ??
            const LibraryDiagnostics(
              status: DiagnosticSectionStatus.complete,
              favouriteItemCount: 0,
              favouriteFolderCount: 0,
            )),
  );
}

/// Test double with controllable [captureSnapshot] behaviour.
class FakeDiagnosticsService extends DiagnosticsService {
  FakeDiagnosticsService({
    required super.catalogService,
    required super.artworkService,
    required super.searchService,
    required super.playbackService,
    required super.mediaProviderConfigService,
    required super.libraryMetadataRepository,
    required super.applicationStartedAt,
    super.musicListeningRepository,
    super.musicListeningCoordinator,
    super.readingProgressRepository,
    super.readingProgressCoordinator,
  });

  int captureCount = 0;
  Duration captureDelay = Duration.zero;
  Object? throwOnCapture;
  RuntimeDiagnosticsSnapshot Function(int captureCount)? snapshotFactory;

  @override
  Future<RuntimeDiagnosticsSnapshot> captureSnapshot() async {
    captureCount++;
    if (captureDelay > Duration.zero) {
      await Future<void>.delayed(captureDelay);
    }
    if (throwOnCapture != null) {
      throw throwOnCapture!;
    }
    if (snapshotFactory != null) {
      return snapshotFactory!(captureCount);
    }
    return minimalSnapshot();
  }

  Object? throwOnFormat;

  @override
  String formatExport(RuntimeDiagnosticsSnapshot snapshot) {
    if (throwOnFormat != null) {
      throw throwOnFormat!;
    }
    return super.formatExport(snapshot);
  }
}

class FakeClipboardWriter implements DiagnosticsClipboardWriter {
  String? lastWrittenText;
  int writeCount = 0;
  Object? throwOnWrite;

  @override
  Future<void> writeText(String text) async {
    writeCount++;
    if (throwOnWrite != null) {
      throw throwOnWrite!;
    }
    lastWrittenText = text;
  }
}

Widget diagnosticsScreenHarness(
  DiagnosticsService service, {
  DiagnosticsClipboardWriter? clipboardWriter,
}) {
  return Provider<DiagnosticsService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: DiagnosticsScreen(
        clipboardWriter: clipboardWriter ?? FakeClipboardWriter(),
      ),
    ),
  );
}
