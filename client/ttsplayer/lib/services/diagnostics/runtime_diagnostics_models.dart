import '../../models/playback/playback_error_kind.dart';
import 'diagnostic_section_status.dart';

/// Point-in-time application runtime metadata.
class ApplicationDiagnostics {
  const ApplicationDiagnostics({
    required this.status,
    this.appName,
    this.appVersion,
    this.buildNumber,
    this.platform,
    this.startupElapsed,
  });

  final DiagnosticSectionStatus status;
  final String? appName;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;
  final Duration? startupElapsed;
}

/// One configured provider row in diagnostics output.
class ProviderAttemptDiagnostics {
  const ProviderAttemptDiagnostics({
    required this.providerKindLabel,
    required this.healthLabel,
    required this.isActive,
    this.lastErrorSummary,
    this.lastAttemptAt,
    this.lastSuccessAt,
  });

  final String providerKindLabel;
  final String healthLabel;
  final bool isActive;
  final String? lastErrorSummary;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
}

/// Catalogue provider and access configuration summary.
class ProviderDiagnostics {
  const ProviderDiagnostics({
    required this.status,
    this.accessModeLabel,
    this.activeProviderKindLabel,
    this.activeSourceCategoryLabel,
    this.configuredProviderCount,
    this.isUsingFallback,
    this.isDegradedLoad,
    this.isDemoFallback,
    this.lastRefreshAt,
    this.lastSuccessfulLoadAt,
    this.lastLoadStartedAt,
    this.lastCycleErrorSummary,
    this.providers = const [],
  });

  final DiagnosticSectionStatus status;
  final String? accessModeLabel;
  final String? activeProviderKindLabel;
  final String? activeSourceCategoryLabel;
  final int? configuredProviderCount;
  final bool? isUsingFallback;
  final bool? isDegradedLoad;
  final bool? isDemoFallback;
  final DateTime? lastRefreshAt;
  final DateTime? lastSuccessfulLoadAt;
  final DateTime? lastLoadStartedAt;
  final String? lastCycleErrorSummary;
  final List<ProviderAttemptDiagnostics> providers;
}

/// Active catalogue aggregate summary — no paths, titles, or tree contents.
class CatalogueDiagnostics {
  const CatalogueDiagnostics({
    required this.status,
    this.catalogueIdentity,
    this.sourceKindLabel,
    this.generatedAt,
    this.catalogueVersion,
    this.scannerVersion,
    this.libraryCount,
    this.folderCount,
    this.itemCount,
    this.videoItemCount,
    this.audioItemCount,
    this.imageItemCount,
    this.bookItemCount,
    this.comicItemCount,
    this.unknownItemCount,
    this.supportedExtensionCount,
    this.isDemoData,
    this.isDegraded,
    this.isLoading,
    this.lastErrorSummary,
    this.lastSuccessfulReplacementAt,
  });

  final DiagnosticSectionStatus status;
  final String? catalogueIdentity;
  final String? sourceKindLabel;
  final String? generatedAt;
  final int? catalogueVersion;
  final String? scannerVersion;
  final int? libraryCount;
  final int? folderCount;
  final int? itemCount;
  final int? videoItemCount;
  final int? audioItemCount;
  final int? imageItemCount;
  final int? bookItemCount;
  final int? comicItemCount;
  final int? unknownItemCount;
  final int? supportedExtensionCount;
  final bool? isDemoData;
  final bool? isDegraded;
  final bool? isLoading;
  final String? lastErrorSummary;
  final DateTime? lastSuccessfulReplacementAt;
}

/// Artwork candidate cache and Flutter image decode cache health.
class CacheDiagnostics {
  const CacheDiagnostics({
    required this.status,
    this.artworkCandidateCount,
    this.artworkCandidateCapacity,
    this.artworkEvictionCount,
    this.imageCacheBudgetBytes,
    this.imageCacheCurrentBytes,
    this.imageCacheLiveImageCount,
  });

  final DiagnosticSectionStatus status;
  final int? artworkCandidateCount;
  final int? artworkCandidateCapacity;
  final int? artworkEvictionCount;
  final int? imageCacheBudgetBytes;
  final int? imageCacheCurrentBytes;
  final int? imageCacheLiveImageCount;
}

/// Search index lifecycle — observational only; no query or result content.
class SearchDiagnostics {
  const SearchDiagnostics({
    required this.status,
    this.hasIndex,
    this.indexBuildCount,
    this.isBuildInFlight,
    this.indexedCatalogueIdentity,
    this.indexedItemCount,
    this.indexMatchesActiveCatalogue,
    this.lastBuildFailureCategory,
  });

  final DiagnosticSectionStatus status;
  final bool? hasIndex;
  final int? indexBuildCount;
  final bool? isBuildInFlight;
  final String? indexedCatalogueIdentity;
  final int? indexedItemCount;
  final bool? indexMatchesActiveCatalogue;
  final String? lastBuildFailureCategory;
}

/// Playback platform capabilities and current session summary.
class PlaybackDiagnostics {
  const PlaybackDiagnostics({
    required this.status,
    this.engineLabel,
    this.playbackPlatformSupported,
    this.speedSettingsSupported,
    this.hasActiveSession,
    this.isMediaPrepared,
    this.isPlaying,
    this.isInitializing,
    this.canChangePlaybackRate,
    this.canSelectAudioTracks,
    this.canSelectSubtitleTracks,
    this.playbackRate,
    this.errorKind,
    this.errorMessageSummary,
    this.retryAvailable,
    this.audioTrackCount,
    this.subtitleTrackCount,
    this.hasAudioTrackSelected,
    this.hasSubtitleTrackSelected,
    this.sessionItemId,
  });

  final DiagnosticSectionStatus status;
  final String? engineLabel;
  final bool? playbackPlatformSupported;
  final bool? speedSettingsSupported;
  final bool? hasActiveSession;
  final bool? isMediaPrepared;
  final bool? isPlaying;
  final bool? isInitializing;
  final bool? canChangePlaybackRate;
  final bool? canSelectAudioTracks;
  final bool? canSelectSubtitleTracks;
  final double? playbackRate;
  final PlaybackErrorKind? errorKind;
  final String? errorMessageSummary;
  final bool? retryAvailable;
  final int? audioTrackCount;
  final int? subtitleTrackCount;
  final bool? hasAudioTrackSelected;
  final bool? hasSubtitleTrackSelected;
  final String? sessionItemId;
}

/// Music listening history aggregates — counts and flags only (M5.4 Step 7).
class MusicListeningDiagnostics {
  const MusicListeningDiagnostics({
    required this.status,
    this.repositoryLoaded,
    this.storedRecordCount,
    this.continueListeningCount,
    this.recentlyPlayedCount,
    this.completedRecordCount,
    this.incompleteRecordCount,
    this.recoveryWarningPresent,
    this.coordinatorAttached,
    this.sessionActive,
    this.pendingWrite,
    this.persistenceWarningPresent,
    this.lastPersistenceWarningSummary,
  });

  final DiagnosticSectionStatus status;
  final bool? repositoryLoaded;
  final int? storedRecordCount;
  final int? continueListeningCount;
  final int? recentlyPlayedCount;
  final int? completedRecordCount;
  final int? incompleteRecordCount;
  final bool? recoveryWarningPresent;
  final bool? coordinatorAttached;
  final bool? sessionActive;
  final bool? pendingWrite;
  final bool? persistenceWarningPresent;
  final String? lastPersistenceWarningSummary;
}

/// User library metadata aggregates — no item names or ids.
class LibraryDiagnostics {
  const LibraryDiagnostics({
    required this.status,
    this.favouriteItemCount,
    this.favouriteFolderCount,
    this.metadataVersion,
    this.libraryCount,
    this.folderCount,
    this.itemCount,
    this.continueWatchingCount,
  });

  final DiagnosticSectionStatus status;
  final int? favouriteItemCount;
  final int? favouriteFolderCount;
  final int? metadataVersion;
  final int? libraryCount;
  final int? folderCount;
  final int? itemCount;
  final int? continueWatchingCount;
}

/// Music playback session aggregates — counts and flags only (M5.5 Step 5).
class MusicPlaybackSessionDiagnostics {
  const MusicPlaybackSessionDiagnostics({
    required this.status,
    this.stateVersion,
    this.repositoryLoaded,
    this.persistedSessionPresent,
    this.persistedQueueCount,
    this.liveQueueCount,
    this.activeTrackPresent,
    this.storedPositionAvailable,
    this.restoredOnColdStart,
    this.persistenceEnabled,
    this.pendingQueueDebounce,
    this.pendingWrite,
    this.recoveryWarningPresent,
    this.persistenceWarningPresent,
    this.lastPersistenceWarningSummary,
    this.lastReconciliationRemovedCount,
    this.lastRestorationRestoredCount,
    this.lastRestorationUnresolvedCount,
    this.coordinatorAttached,
  });

  final DiagnosticSectionStatus status;
  final int? stateVersion;
  final bool? repositoryLoaded;
  final bool? persistedSessionPresent;
  final int? persistedQueueCount;
  final int? liveQueueCount;
  final bool? activeTrackPresent;
  final bool? storedPositionAvailable;
  final bool? restoredOnColdStart;
  final bool? persistenceEnabled;
  final bool? pendingQueueDebounce;
  final bool? pendingWrite;
  final bool? recoveryWarningPresent;
  final bool? persistenceWarningPresent;
  final String? lastPersistenceWarningSummary;
  final int? lastReconciliationRemovedCount;
  final int? lastRestorationRestoredCount;
  final int? lastRestorationUnresolvedCount;
  final bool? coordinatorAttached;
}

/// Reading progress aggregates — counts and flags only (M6.5).
class ReadingProgressDiagnostics {
  const ReadingProgressDiagnostics({
    required this.status,
    this.repositoryInitialized,
    this.schemaVersion,
    this.storedRecordCount,
    this.continueReadingCount,
    this.completedRecordCount,
    this.staleOrUnmatchedRecordCount,
    this.invalidSkippedRecordCount,
    this.pendingWrite,
    this.pendingDebounceWrite,
    this.writeInFlight,
    this.lastSuccessfulWriteAt,
    this.lastSuccessfulFlushAt,
    this.lastRepositoryErrorClassification,
    this.recoveryWarningPresent,
    this.pdfRecordCount,
    this.epubRecordCount,
    this.cbzRecordCount,
    this.legacyCbrRecordCount,
    this.unsupportedComicFormatRecordCount,
    this.coordinatorAttached,
    this.sessionActive,
    this.persistenceWarningPresent,
    this.lastPersistenceWarningSummary,
    this.reconciliationRetainedCount,
    this.reconciliationRefreshedCount,
    this.reconciliationRemovedMissingCount,
    this.reconciliationRemovedFormatMismatchCount,
    this.reconciliationUnsupportedComicFormatRetainedCount,
    this.reconciliationPersistenceFailed,
  });

  final DiagnosticSectionStatus status;
  final bool? repositoryInitialized;
  final int? schemaVersion;
  final int? storedRecordCount;
  final int? continueReadingCount;
  final int? completedRecordCount;
  final int? staleOrUnmatchedRecordCount;
  final int? invalidSkippedRecordCount;
  final bool? pendingWrite;
  final bool? pendingDebounceWrite;
  final bool? writeInFlight;
  final DateTime? lastSuccessfulWriteAt;
  final DateTime? lastSuccessfulFlushAt;
  final String? lastRepositoryErrorClassification;
  final bool? recoveryWarningPresent;
  final int? pdfRecordCount;
  final int? epubRecordCount;
  final int? cbzRecordCount;
  final int? legacyCbrRecordCount;
  final int? unsupportedComicFormatRecordCount;
  final bool? coordinatorAttached;
  final bool? sessionActive;
  final bool? persistenceWarningPresent;
  final String? lastPersistenceWarningSummary;
  final int? reconciliationRetainedCount;
  final int? reconciliationRefreshedCount;
  final int? reconciliationRemovedMissingCount;
  final int? reconciliationRemovedFormatMismatchCount;
  final int? reconciliationUnsupportedComicFormatRetainedCount;
  final bool? reconciliationPersistenceFailed;
}

/// Reader cache/session aggregates for diagnostics (M6.6).
///
/// No paths, titles, archive entry names, or unstable memory readings.
class ReaderSessionDiagnostics {
  const ReaderSessionDiagnostics({
    required this.status,
    this.lastReaderFormat,
    this.lastReaderOpenDurationMs,
    this.lastFirstContentDurationMs,
    this.lastCleanupResult,
    this.comicCacheMaxEntries,
    this.comicCacheMaxBytes,
    this.comicCacheEntryCount,
    this.comicCacheEstimatedBytes,
    this.epubCacheMaxEntries,
    this.epubCacheMaxBytes,
    this.epubCacheEntryCount,
    this.epubCacheEstimatedBytes,
    this.pdfLimitRenderingCache,
    this.pdfMaxImageBytesCachedOnMemory,
  });

  final DiagnosticSectionStatus status;
  final String? lastReaderFormat;
  final int? lastReaderOpenDurationMs;
  final int? lastFirstContentDurationMs;
  final String? lastCleanupResult;
  final int? comicCacheMaxEntries;
  final int? comicCacheMaxBytes;
  final int? comicCacheEntryCount;
  final int? comicCacheEstimatedBytes;
  final int? epubCacheMaxEntries;
  final int? epubCacheMaxBytes;
  final int? epubCacheEntryCount;
  final int? epubCacheEstimatedBytes;
  final bool? pdfLimitRenderingCache;
  final int? pdfMaxImageBytesCachedOnMemory;
}

/// Active CBZ comic reader diagnostics (Phase 6.4C Step 5).
///
/// No paths, archive entry names, page bytes, or exception text.
class ComicReaderDiagnostics {
  const ComicReaderDiagnostics({
    required this.status,
    required this.active,
    this.archiveType,
    this.itemIdentity,
    this.pageNumber,
    this.pageCount,
    this.fitMode,
    this.chromeVisible,
    this.viewState,
    this.cacheEntryCount,
    this.cacheEstimatedBytes,
    this.cacheMaxEntries,
    this.cacheMaxBytes,
    this.failedPagesTracked,
    this.currentPageFailureCategory,
    this.retryAvailable,
    this.lastSafeErrorCategory,
    this.progressSessionActive,
    this.sessionCompleted,
  });

  final DiagnosticSectionStatus status;
  final bool active;
  final String? archiveType;
  final String? itemIdentity;
  final int? pageNumber;
  final int? pageCount;
  final String? fitMode;
  final bool? chromeVisible;
  final String? viewState;
  final int? cacheEntryCount;
  final int? cacheEstimatedBytes;
  final int? cacheMaxEntries;
  final int? cacheMaxBytes;
  final int? failedPagesTracked;
  final String? currentPageFailureCategory;
  final bool? retryAvailable;
  final String? lastSafeErrorCategory;
  final bool? progressSessionActive;
  final bool? sessionCompleted;
}

/// Immutable point-in-time diagnostics snapshot (ADR-018).
class RuntimeDiagnosticsSnapshot {
  const RuntimeDiagnosticsSnapshot({
    required this.capturedAt,
    required this.application,
    required this.provider,
    this.catalogue,
    required this.cache,
    required this.search,
    required this.playback,
    this.musicListening,
    this.musicPlaybackSession,
    this.readingProgress,
    this.readerSession,
    this.comicReader,
    this.library,
  });

  final DateTime capturedAt;
  final ApplicationDiagnostics application;
  final ProviderDiagnostics provider;
  final CatalogueDiagnostics? catalogue;
  final CacheDiagnostics cache;
  final SearchDiagnostics search;
  final PlaybackDiagnostics playback;
  final MusicListeningDiagnostics? musicListening;
  final MusicPlaybackSessionDiagnostics? musicPlaybackSession;
  final ReadingProgressDiagnostics? readingProgress;
  final ReaderSessionDiagnostics? readerSession;
  final ComicReaderDiagnostics? comicReader;
  final LibraryDiagnostics? library;
}
