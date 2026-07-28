import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/music/services/music_listening_coordinator.dart';
import '../../features/music/services/music_listening_repository.dart';
import '../../features/music/services/music_playback_queue_controller.dart';
import '../../features/music/services/music_playback_session_coordinator.dart';
import '../../features/music/services/music_playback_session_repository.dart';
import '../../features/music/services/music_playback_session_restorer.dart';
import '../../features/reading/services/reading_progress_coordinator.dart';
import '../../features/reading/services/reading_progress_diagnostics_projection.dart';
import '../../features/reading/services/reading_progress_repository.dart';
import '../../features/reading/services/reader_session_telemetry.dart';
import '../../features/books/reader/book_pdf_viewer_params.dart';
import '../../features/search/search_service.dart';
import '../../models/catalogue_provider_snapshot.dart';
import '../../models/media_folder.dart';
import '../../models/media_kind.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/catalog_service.dart';
import '../../services/library/library_metadata_repository.dart';
import '../../services/media_access/media_access_config.dart';
import '../../services/media_access/media_catalogue_provider.dart';
import '../../services/media_access/media_provider_config_service.dart';
import '../../services/playback_platform.dart';
import '../../services/playback_service.dart';
import 'diagnostic_section_status.dart';
import 'diagnostics_export_formatter.dart';
import 'diagnostics_redaction.dart';
import 'runtime_diagnostics_models.dart';

/// Read-only aggregation of runtime diagnostics (ADR-017).
///
/// Observes production services without mutating them. Production services
/// must not import this type.
class DiagnosticsService {
  DiagnosticsService({
    required CatalogService catalogService,
    required ArtworkService artworkService,
    required SearchService searchService,
    required PlaybackService playbackService,
    required MediaProviderConfigService mediaProviderConfigService,
    required LibraryMetadataRepository libraryMetadataRepository,
    required DateTime applicationStartedAt,
    MusicListeningRepository? musicListeningRepository,
    MusicListeningCoordinator? musicListeningCoordinator,
    MusicPlaybackSessionRepository? musicPlaybackSessionRepository,
    MusicPlaybackSessionCoordinator? musicPlaybackSessionCoordinator,
    MusicPlaybackQueueController? musicPlaybackQueueController,
    MusicPlaybackSessionRestorer? musicPlaybackSessionRestorer,
    ReadingProgressRepository? readingProgressRepository,
    ReadingProgressCoordinator? readingProgressCoordinator,
    Future<PackageInfo> Function()? packageInfoLoader,
    String Function()? platformNameProvider,
    bool Function()? imageCacheAvailableProvider,
  })  : _catalogService = catalogService,
        _artworkService = artworkService,
        _searchService = searchService,
        _playbackService = playbackService,
        _mediaProviderConfigService = mediaProviderConfigService,
        _libraryMetadataRepository = libraryMetadataRepository,
        _musicListeningRepository = musicListeningRepository,
        _musicListeningCoordinator = musicListeningCoordinator,
        _musicPlaybackSessionRepository = musicPlaybackSessionRepository,
        _musicPlaybackSessionCoordinator = musicPlaybackSessionCoordinator,
        _musicPlaybackQueueController = musicPlaybackQueueController,
        _musicPlaybackSessionRestorer = musicPlaybackSessionRestorer,
        _readingProgressRepository = readingProgressRepository,
        _readingProgressCoordinator = readingProgressCoordinator,
        _applicationStartedAt = applicationStartedAt,
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _platformNameProvider = platformNameProvider ?? _defaultPlatformName,
        _imageCacheAvailableProvider =
            imageCacheAvailableProvider ?? _defaultImageCacheAvailable;

  final CatalogService _catalogService;
  final ArtworkService _artworkService;
  final SearchService _searchService;
  final PlaybackService _playbackService;
  final MediaProviderConfigService _mediaProviderConfigService;
  final LibraryMetadataRepository _libraryMetadataRepository;
  final MusicListeningRepository? _musicListeningRepository;
  final MusicListeningCoordinator? _musicListeningCoordinator;
  final MusicPlaybackSessionRepository? _musicPlaybackSessionRepository;
  final MusicPlaybackSessionCoordinator? _musicPlaybackSessionCoordinator;
  final MusicPlaybackQueueController? _musicPlaybackQueueController;
  final MusicPlaybackSessionRestorer? _musicPlaybackSessionRestorer;
  final ReadingProgressRepository? _readingProgressRepository;
  final ReadingProgressCoordinator? _readingProgressCoordinator;
  final DateTime _applicationStartedAt;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final String Function() _platformNameProvider;
  final bool Function() _imageCacheAvailableProvider;

  PackageInfo? _cachedPackageInfo;

  /// When the application process started — fixed for the service lifetime.
  DateTime get applicationStartedAt => _applicationStartedAt;

  /// Builds a point-in-time snapshot of runtime diagnostics.
  Future<RuntimeDiagnosticsSnapshot> captureSnapshot() async {
    final capturedAt = DateTime.now().toUtc();
    final application = await _captureApplication(capturedAt);
    final provider = _captureProvider();
    final catalogue = _captureCatalogue();
    final cache = _captureCache();
    final search = _captureSearch(catalogue);
    final playback = _capturePlayback();
    final musicListening = _captureMusicListening();
    final musicPlaybackSession = _captureMusicPlaybackSession();
    final readingProgress = _captureReadingProgress();
    final readerSession = _captureReaderSession();
    final comicReader = _captureComicReader();
    final library = _captureLibrary(catalogue);

    return RuntimeDiagnosticsSnapshot(
      capturedAt: capturedAt,
      application: application,
      provider: provider,
      catalogue: catalogue,
      cache: cache,
      search: search,
      playback: playback,
      musicListening: musicListening,
      musicPlaybackSession: musicPlaybackSession,
      readingProgress: readingProgress,
      readerSession: readerSession,
      comicReader: comicReader,
      library: library,
    );
  }

  /// Stable plain-text export for support bundles (formatter only — no I/O).
  String formatExport(RuntimeDiagnosticsSnapshot snapshot) {
    return formatDiagnosticsExport(snapshot);
  }

  Future<ApplicationDiagnostics> _captureApplication(
      DateTime capturedAt) async {
    try {
      _cachedPackageInfo ??= await _packageInfoLoader();
      final info = _cachedPackageInfo!;
      final elapsed = capturedAt.difference(_applicationStartedAt);
      return ApplicationDiagnostics(
        status: DiagnosticSectionStatus.complete,
        appName: info.appName,
        appVersion: info.version,
        buildNumber: info.buildNumber,
        platform: _platformNameProvider(),
        startupElapsed: elapsed.isNegative ? Duration.zero : elapsed,
      );
    } catch (_) {
      return const ApplicationDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
      );
    }
  }

  ProviderDiagnostics _captureProvider() {
    try {
      final snapshot = _catalogService.providerSnapshot;
      final config = _mediaProviderConfigService.config;
      final active = snapshot.activeProvider;
      final rows = snapshot.providers
          .map(
            (record) => ProviderAttemptDiagnostics(
              providerKindLabel: providerKindLabel(record.definition.kind.name),
              healthLabel: record.health.name,
              isActive: record.isActive,
              lastErrorSummary: _safeErrorSummary(record.lastError),
              lastAttemptAt: record.lastAttemptAt,
              lastSuccessAt: record.lastSuccessAt,
            ),
          )
          .toList(growable: false);

      return ProviderDiagnostics(
        status: DiagnosticSectionStatus.complete,
        accessModeLabel: _accessModeLabel(snapshot.accessMode),
        activeProviderKindLabel: active == null
            ? 'Unavailable'
            : providerKindLabel(active.kind.name),
        activeSourceCategoryLabel: _activeSourceCategoryLabel(snapshot, active),
        configuredProviderCount: config.catalogueProviders.length,
        isUsingFallback: _catalogService.isUsingFallback,
        isDegradedLoad: snapshot.isDegradedLoad,
        isDemoFallback: snapshot.isDemoFallback,
        lastRefreshAt: _catalogService.lastRefreshedAt,
        lastSuccessfulLoadAt: snapshot.lastCatalogueLoadAt,
        lastLoadStartedAt: snapshot.lastLoadStartedAt,
        lastCycleErrorSummary: _safeErrorSummary(snapshot.lastCycleError),
        providers: rows,
      );
    } catch (_) {
      return const ProviderDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
        providers: [],
      );
    }
  }

  CatalogueDiagnostics? _captureCatalogue() {
    try {
      final catalog = _catalogService.catalog;
      if (catalog == null) {
        return null;
      }
      var video = 0;
      var audio = 0;
      var image = 0;
      var book = 0;
      var comic = 0;
      var unknown = 0;
      for (final item in catalog.allItems) {
        switch (item.mediaKind) {
          case MediaKind.video:
            video++;
          case MediaKind.audio:
            audio++;
          case MediaKind.image:
            image++;
          case MediaKind.book:
            book++;
          case MediaKind.comic:
            comic++;
          case MediaKind.unknown:
            unknown++;
        }
      }
      return CatalogueDiagnostics(
        status: DiagnosticSectionStatus.complete,
        catalogueIdentity: redactIdentity(catalog.catalogueIdentity),
        sourceKindLabel: _catalogService.catalogueSourceLabel,
        generatedAt: catalog.generatedAt,
        catalogueVersion: catalog.catalogueInfo?.catalogueVersion,
        scannerVersion: catalog.catalogueInfo?.scannerVersion,
        libraryCount: catalog.folders.length,
        folderCount: _countFolders(catalog.folders),
        itemCount: catalog.totalItems,
        videoItemCount: video,
        audioItemCount: audio,
        imageItemCount: image,
        bookItemCount: book,
        comicItemCount: comic,
        unknownItemCount: unknown,
        supportedExtensionCount: catalog.supportedExtensions.length,
        isDemoData: _catalogService.isDemoCatalogue,
        isDegraded: _catalogService.isDegradedLoad,
        isLoading: _catalogService.isLoading,
        lastErrorSummary: _safeErrorSummary(_catalogService.errorMessage),
        lastSuccessfulReplacementAt: _catalogService.lastCatalogueLoadAt,
      );
    } catch (_) {
      return const CatalogueDiagnostics(
          status: DiagnosticSectionStatus.unavailable);
    }
  }

  CacheDiagnostics _captureCache() {
    try {
      int? budgetBytes;
      int? currentBytes;
      int? liveImageCount;
      if (_imageCacheAvailableProvider()) {
        final imageCache = PaintingBinding.instance.imageCache;
        budgetBytes = imageCache.maximumSizeBytes;
        currentBytes = imageCache.currentSizeBytes;
        liveImageCount = imageCache.liveImageCount;
      }

      return CacheDiagnostics(
        status: DiagnosticSectionStatus.complete,
        artworkCandidateCount: _artworkService.cacheEntryCount,
        artworkCandidateCapacity: _artworkService.cacheCapacity,
        artworkEvictionCount: _artworkService.cacheEvictionCount,
        imageCacheBudgetBytes: budgetBytes,
        imageCacheCurrentBytes: currentBytes,
        imageCacheLiveImageCount: liveImageCount,
      );
    } catch (_) {
      return const CacheDiagnostics(
          status: DiagnosticSectionStatus.unavailable);
    }
  }

  SearchDiagnostics _captureSearch(CatalogueDiagnostics? catalogue) {
    try {
      final indexedIdentity = _searchService.catalogueIdentity;
      final activeIdentity = _catalogService.catalog?.catalogueIdentity;
      final bool? matchesActive =
          activeIdentity == null ? null : indexedIdentity == activeIdentity;

      return SearchDiagnostics(
        status: DiagnosticSectionStatus.complete,
        hasIndex: _searchService.hasIndex,
        indexBuildCount: _searchService.indexBuildCount,
        isBuildInFlight: _searchService.isBuildInFlight,
        indexedCatalogueIdentity: redactIdentity(indexedIdentity),
        indexedItemCount: _searchService.indexedItemCount,
        indexMatchesActiveCatalogue: matchesActive,
        lastBuildFailureCategory: null,
      );
    } catch (_) {
      return const SearchDiagnostics(
          status: DiagnosticSectionStatus.unavailable);
    }
  }

  PlaybackDiagnostics _capturePlayback() {
    try {
      final hasSession = _playbackService.currentItem != null;
      final errorKind = _playbackService.playbackErrorKind;
      final sessionItemId =
          hasSession ? redactIdentity(_playbackService.currentItem!.id) : null;

      return PlaybackDiagnostics(
        status: DiagnosticSectionStatus.complete,
        engineLabel: useMediaKitPlayback ? 'media_kit' : 'video_player',
        playbackPlatformSupported: !kIsWeb,
        speedSettingsSupported: playbackSpeedSettingsSupported,
        hasActiveSession: hasSession,
        isMediaPrepared: hasSession ? _playbackService.isReady : null,
        isPlaying: hasSession ? _playbackService.isPlaying : null,
        isInitializing: hasSession ? _playbackService.isInitializing : null,
        canChangePlaybackRate:
            hasSession ? _playbackService.canChangePlaybackRate : null,
        canSelectAudioTracks:
            hasSession ? _playbackService.canSelectAudioTracks : null,
        canSelectSubtitleTracks:
            hasSession ? _playbackService.canSelectSubtitleTracks : null,
        playbackRate: hasSession ? _playbackService.playbackRate : null,
        errorKind: errorKind,
        errorMessageSummary: _safeErrorSummary(_playbackService.errorMessage),
        retryAvailable: hasSession ? errorKind != null : null,
        audioTrackCount:
            hasSession ? _playbackService.availableAudioTracks.length : null,
        subtitleTrackCount:
            hasSession ? _playbackService.availableSubtitleTracks.length : null,
        hasAudioTrackSelected:
            hasSession ? _playbackService.selectedAudioTrackId != null : null,
        hasSubtitleTrackSelected: hasSession
            ? _playbackService.selectedSubtitleTrackId != null
            : null,
        sessionItemId: sessionItemId,
      );
    } catch (_) {
      return const PlaybackDiagnostics(
          status: DiagnosticSectionStatus.unavailable);
    }
  }

  MusicListeningDiagnostics? _captureMusicListening() {
    final repository = _musicListeningRepository;
    if (repository == null) {
      return null;
    }

    try {
      if (!repository.isLoaded) {
        return null;
      }

      var status = DiagnosticSectionStatus.complete;
      bool? coordinatorAttached;
      bool? sessionActive;
      bool? pendingWrite;
      bool? persistenceWarningPresent;
      String? lastPersistenceWarningSummary;

      final coordinator = _musicListeningCoordinator;
      if (coordinator != null) {
        try {
          coordinatorAttached = coordinator.isAttached;
          sessionActive = coordinator.sessionActive;
          pendingWrite = coordinator.pendingWrite;
          persistenceWarningPresent = coordinator.persistenceWarningPresent;
          lastPersistenceWarningSummary = _safeErrorSummary(
            coordinator.lastPersistenceWarning,
          );
        } catch (_) {
          status = DiagnosticSectionStatus.partial;
        }
      }

      return MusicListeningDiagnostics(
        status: status,
        repositoryLoaded: true,
        storedRecordCount: repository.storedRecordCount,
        continueListeningCount: repository.continueListeningCount,
        recentlyPlayedCount: repository.recentlyPlayedVisibleCount,
        completedRecordCount: repository.completedRecordCount,
        incompleteRecordCount: repository.incompleteRecordCount,
        recoveryWarningPresent: repository.recoveryWarningPresent,
        coordinatorAttached: coordinatorAttached,
        sessionActive: sessionActive,
        pendingWrite: pendingWrite,
        persistenceWarningPresent: persistenceWarningPresent,
        lastPersistenceWarningSummary: lastPersistenceWarningSummary,
      );
    } catch (_) {
      return const MusicListeningDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
        repositoryLoaded: false,
      );
    }
  }

  MusicPlaybackSessionDiagnostics? _captureMusicPlaybackSession() {
    final repository = _musicPlaybackSessionRepository;
    if (repository == null) {
      return null;
    }

    try {
      if (!repository.isLoaded) {
        return null;
      }

      var status = DiagnosticSectionStatus.complete;
      bool? coordinatorAttached;
      bool? persistenceEnabled;
      bool? pendingQueueDebounce;
      bool? pendingWrite;
      bool? persistenceWarningPresent;
      String? lastPersistenceWarningSummary;

      final coordinator = _musicPlaybackSessionCoordinator;
      if (coordinator != null) {
        try {
          coordinatorAttached = coordinator.isAttached;
          persistenceEnabled = coordinator.persistenceEnabled;
          pendingQueueDebounce = coordinator.pendingQueueDebounce;
          pendingWrite = coordinator.pendingWrite;
          persistenceWarningPresent = coordinator.persistenceWarningPresent;
          lastPersistenceWarningSummary = _safeErrorSummary(
            coordinator.lastPersistenceWarning,
          );
        } catch (_) {
          status = DiagnosticSectionStatus.partial;
        }
      }

      final queue = _musicPlaybackQueueController;
      final liveQueueCount = queue?.queue.items.length;
      final activeTrackPresent = queue?.currentTrack != null;
      final restoredPosition = queue?.restoredStartPosition;
      final persistedSession = repository.session;
      final storedPositionAvailable =
          persistedSession.playbackPosition > Duration.zero ||
              (restoredPosition != null && restoredPosition > Duration.zero);

      final restorer = _musicPlaybackSessionRestorer;
      final lastRestore = restorer?.lastRestoreResult;
      final restoredOnColdStart = restorer?.coldStartRestoreAttempted == true &&
          (lastRestore?.restoredQueueCount ?? 0) > 0;

      final lastValidation = repository.lastValidationResult;

      return MusicPlaybackSessionDiagnostics(
        status: status,
        stateVersion: MusicPlaybackSessionRepository.currentStateVersion,
        repositoryLoaded: true,
        persistedSessionPresent: repository.hasPersistedSession,
        persistedQueueCount: repository.persistedTrackCount,
        liveQueueCount: liveQueueCount,
        activeTrackPresent: activeTrackPresent,
        storedPositionAvailable: storedPositionAvailable,
        restoredOnColdStart: restoredOnColdStart,
        persistenceEnabled: persistenceEnabled,
        pendingQueueDebounce: pendingQueueDebounce,
        pendingWrite: pendingWrite,
        recoveryWarningPresent: repository.recoveryWarningPresent,
        persistenceWarningPresent: persistenceWarningPresent,
        lastPersistenceWarningSummary: lastPersistenceWarningSummary,
        lastReconciliationRemovedCount: lastValidation?.removedCount,
        lastRestorationRestoredCount: lastRestore?.restoredQueueCount,
        lastRestorationUnresolvedCount: lastRestore?.unresolvedCount,
        coordinatorAttached: coordinatorAttached,
      );
    } catch (_) {
      return const MusicPlaybackSessionDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
        repositoryLoaded: false,
      );
    }
  }

  ReadingProgressDiagnostics? _captureReadingProgress() {
    final repository = _readingProgressRepository;
    if (repository == null) {
      return null;
    }

    try {
      if (!repository.isLoaded) {
        return null;
      }

      var status = DiagnosticSectionStatus.complete;
      bool? coordinatorAttached;
      bool? sessionActive;
      bool? pendingWrite;
      bool? pendingDebounceWrite;
      bool? writeInFlight;
      bool? persistenceWarningPresent;
      String? lastPersistenceWarningSummary;
      DateTime? lastSuccessfulFlushAt;

      final coordinator = _readingProgressCoordinator;
      if (coordinator != null) {
        try {
          coordinatorAttached = true;
          sessionActive = coordinator.sessionActive;
          pendingWrite = coordinator.pendingWrite;
          pendingDebounceWrite = coordinator.pendingDebounceWrite;
          writeInFlight = coordinator.writeInFlight;
          persistenceWarningPresent =
              coordinator.lastPersistenceWarning != null;
          lastPersistenceWarningSummary = _safeErrorSummary(
            coordinator.lastPersistenceWarning,
          );
          lastSuccessfulFlushAt = coordinator.lastSuccessfulFlushAt;
        } catch (_) {
          status = DiagnosticSectionStatus.partial;
        }
      }

      final catalog = _catalogService.catalog;
      final projection = ReadingProgressDiagnosticsProjection.build(
        repository: repository,
        catalog: catalog,
      );
      final reconciliation = projection.lastReconciliation;

      return ReadingProgressDiagnostics(
        status: status,
        repositoryInitialized: projection.initialized,
        schemaVersion: projection.schemaVersion,
        storedRecordCount: projection.storedRecordCount,
        continueReadingCount: projection.continueReadingCount,
        completedRecordCount: projection.completedRecordCount,
        staleOrUnmatchedRecordCount: projection.staleOrUnmatchedRecordCount,
        invalidSkippedRecordCount: projection.invalidSkippedRecordCount,
        pendingWrite: pendingWrite,
        pendingDebounceWrite: pendingDebounceWrite,
        writeInFlight: writeInFlight,
        lastSuccessfulWriteAt: projection.lastSuccessfulWriteAt,
        lastSuccessfulFlushAt: lastSuccessfulFlushAt,
        lastRepositoryErrorClassification: _safeErrorSummary(
          projection.lastRepositoryErrorClassification,
        ),
        recoveryWarningPresent: projection.recoveryWarningPresent,
        pdfRecordCount: projection.pdfRecordCount,
        epubRecordCount: projection.epubRecordCount,
        cbzRecordCount: projection.cbzRecordCount,
        legacyCbrRecordCount: projection.legacyCbrRecordCount,
        unsupportedComicFormatRecordCount:
            projection.unsupportedComicFormatRecordCount,
        coordinatorAttached: coordinatorAttached,
        sessionActive: sessionActive,
        persistenceWarningPresent: persistenceWarningPresent,
        lastPersistenceWarningSummary: lastPersistenceWarningSummary,
        reconciliationRetainedCount: reconciliation?.retainedCount,
        reconciliationRefreshedCount: reconciliation?.refreshedCount,
        reconciliationRemovedMissingCount: reconciliation?.removedMissingCount,
        reconciliationRemovedFormatMismatchCount:
            reconciliation?.removedFormatMismatchCount,
        reconciliationUnsupportedComicFormatRetainedCount:
            reconciliation?.unsupportedComicFormatRetainedCount,
        reconciliationPersistenceFailed: reconciliation?.persistenceFailed,
      );
    } catch (_) {
      return const ReadingProgressDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
        repositoryInitialized: false,
      );
    }
  }

  ReaderSessionDiagnostics _captureReaderSession() {
    try {
      final snap = ReaderSessionTelemetry.instance.snapshot();
      return ReaderSessionDiagnostics(
        status: DiagnosticSectionStatus.complete,
        lastReaderFormat: snap.lastReaderFormat,
        lastReaderOpenDurationMs: snap.lastReaderOpenDurationMs,
        lastFirstContentDurationMs: snap.lastFirstContentDurationMs,
        lastCleanupResult: snap.lastCleanupResult,
        comicCacheMaxEntries: snap.comicCacheMaxEntries,
        comicCacheMaxBytes: snap.comicCacheMaxBytes,
        comicCacheEntryCount: snap.comicCacheEntryCount,
        comicCacheEstimatedBytes: snap.comicCacheEstimatedBytes,
        epubCacheMaxEntries: snap.epubCacheMaxEntries,
        epubCacheMaxBytes: snap.epubCacheMaxBytes,
        epubCacheEntryCount: snap.epubCacheEntryCount,
        epubCacheEstimatedBytes: snap.epubCacheEstimatedBytes,
        pdfLimitRenderingCache: TtsPlayerPdfViewerPolicy.limitRenderingCache,
        pdfMaxImageBytesCachedOnMemory:
            TtsPlayerPdfViewerPolicy.maxImageBytesCachedOnMemory,
      );
    } catch (_) {
      return const ReaderSessionDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
      );
    }
  }

  ComicReaderDiagnostics _captureComicReader() {
    try {
      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot();
      if (snap == null) {
        return const ComicReaderDiagnostics(
          status: DiagnosticSectionStatus.complete,
          active: false,
        );
      }
      return ComicReaderDiagnostics(
        status: DiagnosticSectionStatus.complete,
        active: true,
        archiveType: snap.archiveType,
        itemIdentity: redactIdentity(snap.itemIdentity),
        pageNumber:
            snap.pageIndex == null ? null : snap.pageIndex! + 1,
        pageCount: snap.pageCount,
        fitMode: snap.fitMode,
        chromeVisible: snap.chromeVisible,
        viewState: snap.zoomedBeyondBase == null
            ? null
            : (snap.zoomedBeyondBase! ? 'Zoomed' : 'Base'),
        cacheEntryCount: snap.cacheEntryCount,
        cacheEstimatedBytes: snap.cacheEstimatedBytes,
        cacheMaxEntries: snap.cacheMaxEntries,
        cacheMaxBytes: snap.cacheMaxBytes,
        failedPagesTracked: snap.failedPagesTracked,
        currentPageFailureCategory: snap.currentPageFailureCategory == null
            ? null
            : redactSensitiveText(snap.currentPageFailureCategory),
        retryAvailable: snap.retryAvailable,
        lastSafeErrorCategory: snap.lastSafeErrorCategory == null
            ? null
            : redactSensitiveText(snap.lastSafeErrorCategory),
        progressSessionActive: snap.progressSessionActive,
        sessionCompleted: snap.sessionCompleted,
      );
    } catch (_) {
      return const ComicReaderDiagnostics(
        status: DiagnosticSectionStatus.unavailable,
        active: false,
      );
    }
  }

  LibraryDiagnostics? _captureLibrary(CatalogueDiagnostics? catalogue) {
    try {
      if (!_libraryMetadataRepository.isLoaded) {
        return null;
      }

      return LibraryDiagnostics(
        status: DiagnosticSectionStatus.complete,
        favouriteItemCount: _libraryMetadataRepository.favouriteItems.length,
        favouriteFolderCount:
            _libraryMetadataRepository.favouriteFolders.length,
        metadataVersion: _libraryMetadataRepository.metadata.metadataVersion,
        libraryCount: catalogue?.libraryCount,
        folderCount: catalogue?.folderCount,
        itemCount: catalogue?.itemCount,
        continueWatchingCount: null,
      );
    } catch (_) {
      return const LibraryDiagnostics(
          status: DiagnosticSectionStatus.unavailable);
    }
  }

  static String _defaultPlatformName() {
    if (kIsWeb) {
      return 'web';
    }
    return Platform.operatingSystem;
  }

  static bool _defaultImageCacheAvailable() {
    return WidgetsBinding.instance.isRootWidgetAttached ||
        WidgetsBinding.instance.platformDispatcher.views.isNotEmpty;
  }

  static String _accessModeLabel(MediaAccessMode mode) {
    switch (mode) {
      case MediaAccessMode.localPreferred:
        return 'Local preferred';
      case MediaAccessMode.httpRequired:
        return 'HTTP required';
    }
  }

  static String _activeSourceCategoryLabel(
    CatalogueProviderSnapshot snapshot,
    MediaCatalogueProviderDefinition? active,
  ) {
    if (snapshot.isDemoFallback || snapshot.demoActiveWithoutProvider) {
      return 'Demo';
    }
    if (active == null) {
      return 'Unavailable';
    }
    switch (active.kind) {
      case MediaCatalogueProviderKind.localFile:
        return 'Local file';
      case MediaCatalogueProviderKind.http:
        return 'HTTPS';
    }
  }

  static int _countFolders(List<MediaFolder> folders) {
    var count = folders.length;
    for (final folder in folders) {
      count += _countFolders(folder.subfolders);
    }
    return count;
  }

  static String? _safeErrorSummary(String? message) {
    if (message == null || message.isEmpty) {
      return null;
    }
    final redacted = redactSensitiveText(message);
    return redacted.isEmpty ? null : redacted;
  }
}
