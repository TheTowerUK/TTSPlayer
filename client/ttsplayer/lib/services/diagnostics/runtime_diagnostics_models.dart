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
    this.libraryCount,
    this.folderCount,
    this.itemCount,
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
  final int? libraryCount;
  final int? folderCount;
  final int? itemCount;
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
    this.library,
  });

  final DateTime capturedAt;
  final ApplicationDiagnostics application;
  final ProviderDiagnostics provider;
  final CatalogueDiagnostics? catalogue;
  final CacheDiagnostics cache;
  final SearchDiagnostics search;
  final PlaybackDiagnostics playback;
  final LibraryDiagnostics? library;
}
