import 'diagnostic_section_status.dart';
import 'diagnostics_redaction.dart';
import 'runtime_diagnostics_models.dart';

/// Stable plain-text export for support bundles (ADR-019 formatter boundary).
String formatDiagnosticsExport(RuntimeDiagnosticsSnapshot snapshot) {
  final buffer = StringBuffer();
  final app = snapshot.application;
  final platform = app.platform ?? 'Unavailable';
  final version = app.appVersion ?? 'Unavailable';
  final build = app.buildNumber ?? 'Unavailable';

  buffer.writeln('TTSPlayer Diagnostics');
  buffer.writeln(
    'Captured: ${snapshot.capturedAt.toUtc().toIso8601String()}',
  );
  buffer.writeln('App: $version (build $build) — $platform');
  buffer.writeln();

  _writeSection(buffer, 'Application', () {
    _writeLine(buffer, 'Status', _sectionStatusLabel(app.status));
    _writeLine(buffer, 'Name', app.appName);
    _writeLine(buffer, 'Version', app.appVersion);
    _writeLine(buffer, 'Build', app.buildNumber);
    _writeLine(buffer, 'Platform', app.platform);
    _writeLine(buffer, 'Startup elapsed', _formatDuration(app.startupElapsed));
  });

  final provider = snapshot.provider;
  _writeSection(buffer, 'Provider', () {
    _writeLine(buffer, 'Status', _sectionStatusLabel(provider.status));
    _writeLine(buffer, 'Access mode', provider.accessModeLabel);
    _writeLine(
      buffer,
      'Active provider kind',
      provider.activeProviderKindLabel,
    );
    _writeLine(
      buffer,
      'Active source category',
      provider.activeSourceCategoryLabel,
    );
    _writeLine(
      buffer,
      'Configured providers',
      _formatInt(provider.configuredProviderCount),
    );
    _writeLine(buffer, 'Using fallback', _formatBool(provider.isUsingFallback));
    _writeLine(buffer, 'Degraded load', _formatBool(provider.isDegradedLoad));
    _writeLine(buffer, 'Demo fallback', _formatBool(provider.isDemoFallback));
    _writeLine(
      buffer,
      'Last refresh',
      _formatDateTime(provider.lastRefreshAt),
    );
    _writeLine(
      buffer,
      'Last successful load',
      _formatDateTime(provider.lastSuccessfulLoadAt),
    );
    _writeLine(
      buffer,
      'Last load started',
      _formatDateTime(provider.lastLoadStartedAt),
    );
    _writeLine(
      buffer,
      'Last cycle error',
      provider.lastCycleErrorSummary,
    );
    for (var i = 0; i < provider.providers.length; i++) {
      final row = provider.providers[i];
      buffer.writeln('Provider ${i + 1}:');
      _writeLine(buffer, '  Kind', row.providerKindLabel);
      _writeLine(buffer, '  Health', row.healthLabel);
      _writeLine(buffer, '  Active', _formatBool(row.isActive));
      _writeLine(buffer, '  Last error', row.lastErrorSummary);
      _writeLine(
        buffer,
        '  Last attempt',
        _formatDateTime(row.lastAttemptAt),
      );
      _writeLine(
        buffer,
        '  Last success',
        _formatDateTime(row.lastSuccessAt),
      );
    }
  });

  final catalogue = snapshot.catalogue;
  _writeSection(buffer, 'Catalogue', () {
    if (catalogue == null) {
      _writeLine(buffer, 'Status', 'Unavailable');
      return;
    }
    _writeLine(buffer, 'Status', _sectionStatusLabel(catalogue.status));
    _writeLine(buffer, 'Identity', catalogue.catalogueIdentity);
    _writeLine(buffer, 'Source', catalogue.sourceKindLabel);
    _writeLine(buffer, 'Generated at', catalogue.generatedAt);
    _writeLine(buffer, 'Libraries', _formatInt(catalogue.libraryCount));
    _writeLine(buffer, 'Folders', _formatInt(catalogue.folderCount));
    _writeLine(buffer, 'Items', _formatInt(catalogue.itemCount));
    _writeLine(buffer, 'Demo data', _formatBool(catalogue.isDemoData));
    _writeLine(buffer, 'Degraded', _formatBool(catalogue.isDegraded));
    _writeLine(buffer, 'Loading', _formatBool(catalogue.isLoading));
    _writeLine(buffer, 'Last error', catalogue.lastErrorSummary);
    _writeLine(
      buffer,
      'Last successful replacement',
      _formatDateTime(catalogue.lastSuccessfulReplacementAt),
    );
  });

  final cache = snapshot.cache;
  _writeSection(buffer, 'Cache', () {
    _writeLine(buffer, 'Status', _sectionStatusLabel(cache.status));
    _writeLine(
      buffer,
      'Artwork candidates',
      _formatInt(cache.artworkCandidateCount),
    );
    _writeLine(
      buffer,
      'Artwork capacity',
      _formatInt(cache.artworkCandidateCapacity),
    );
    _writeLine(
      buffer,
      'Artwork evictions',
      _formatInt(cache.artworkEvictionCount),
    );
    _writeLine(
      buffer,
      'Image cache budget',
      _formatBytes(cache.imageCacheBudgetBytes),
    );
    _writeLine(
      buffer,
      'Image cache current',
      _formatBytes(cache.imageCacheCurrentBytes),
    );
    _writeLine(
      buffer,
      'Image cache live images',
      _formatInt(cache.imageCacheLiveImageCount),
    );
  });

  final search = snapshot.search;
  _writeSection(buffer, 'Search', () {
    _writeLine(buffer, 'Status', _sectionStatusLabel(search.status));
    _writeLine(buffer, 'Has index', _formatBool(search.hasIndex));
    _writeLine(
      buffer,
      'Index build count',
      _formatInt(search.indexBuildCount),
    );
    _writeLine(
      buffer,
      'Build in flight',
      _formatBool(search.isBuildInFlight),
    );
    _writeLine(
      buffer,
      'Indexed identity',
      search.indexedCatalogueIdentity,
    );
    _writeLine(
      buffer,
      'Indexed items',
      _formatInt(search.indexedItemCount),
    );
    _writeLine(
      buffer,
      'Matches active catalogue',
      _formatBool(search.indexMatchesActiveCatalogue),
    );
    _writeLine(
      buffer,
      'Last build failure',
      search.lastBuildFailureCategory,
    );
  });

  final playback = snapshot.playback;
  _writeSection(buffer, 'Playback', () {
    _writeLine(buffer, 'Status', _sectionStatusLabel(playback.status));
    _writeLine(buffer, 'Engine', playback.engineLabel);
    _writeLine(
      buffer,
      'Platform supported',
      _formatBool(playback.playbackPlatformSupported),
    );
    _writeLine(
      buffer,
      'Speed settings supported',
      _formatBool(playback.speedSettingsSupported),
    );
    _writeLine(
      buffer,
      'Active session',
      _formatBool(playback.hasActiveSession),
    );
    _writeLine(
      buffer,
      'Media prepared',
      _formatBool(playback.isMediaPrepared),
    );
    _writeLine(buffer, 'Playing', _formatBool(playback.isPlaying));
    _writeLine(
      buffer,
      'Initializing',
      _formatBool(playback.isInitializing),
    );
    _writeLine(
      buffer,
      'Can change rate',
      _formatBool(playback.canChangePlaybackRate),
    );
    _writeLine(
      buffer,
      'Can select audio',
      _formatBool(playback.canSelectAudioTracks),
    );
    _writeLine(
      buffer,
      'Can select subtitles',
      _formatBool(playback.canSelectSubtitleTracks),
    );
    _writeLine(
      buffer,
      'Playback rate',
      playback.playbackRate?.toString(),
    );
    _writeLine(
      buffer,
      'Error kind',
      playback.errorKind?.name,
    );
    _writeLine(
      buffer,
      'Error message',
      playback.errorMessageSummary,
    );
    _writeLine(
      buffer,
      'Retry available',
      _formatBool(playback.retryAvailable),
    );
    _writeLine(
      buffer,
      'Audio tracks',
      _formatInt(playback.audioTrackCount),
    );
    _writeLine(
      buffer,
      'Subtitle tracks',
      _formatInt(playback.subtitleTrackCount),
    );
    _writeLine(
      buffer,
      'Audio selected',
      _formatBool(playback.hasAudioTrackSelected),
    );
    _writeLine(
      buffer,
      'Subtitle selected',
      _formatBool(playback.hasSubtitleTrackSelected),
    );
    _writeLine(buffer, 'Session item id', playback.sessionItemId);
  });

  final musicListening = snapshot.musicListening;
  _writeSection(buffer, 'Music Listening', () {
    if (musicListening == null) {
      _writeLine(buffer, 'Status', 'Unavailable');
      return;
    }
    _writeLine(
      buffer,
      'Status',
      _sectionStatusLabel(musicListening.status),
    );
    _writeLine(
      buffer,
      'Repository loaded',
      _formatBool(musicListening.repositoryLoaded),
    );
    _writeLine(
      buffer,
      'Stored records',
      _formatInt(musicListening.storedRecordCount),
    );
    _writeLine(
      buffer,
      'Continue listening',
      _formatInt(musicListening.continueListeningCount),
    );
    _writeLine(
      buffer,
      'Recently played',
      _formatInt(musicListening.recentlyPlayedCount),
    );
    _writeLine(
      buffer,
      'Completed records',
      _formatInt(musicListening.completedRecordCount),
    );
    _writeLine(
      buffer,
      'Incomplete records',
      _formatInt(musicListening.incompleteRecordCount),
    );
    _writeLine(
      buffer,
      'Recovery warning present',
      _formatBool(musicListening.recoveryWarningPresent),
    );
    _writeLine(
      buffer,
      'Coordinator attached',
      _formatBool(musicListening.coordinatorAttached),
    );
    _writeLine(
      buffer,
      'Active session',
      _formatBool(musicListening.sessionActive),
    );
    _writeLine(
      buffer,
      'Pending write',
      _formatBool(musicListening.pendingWrite),
    );
    _writeLine(
      buffer,
      'Persistence warning present',
      _formatBool(musicListening.persistenceWarningPresent),
    );
    _writeLine(
      buffer,
      'Last persistence warning',
      musicListening.lastPersistenceWarningSummary,
    );
  });

  final library = snapshot.library;
  _writeSection(buffer, 'Library', () {
    if (library == null) {
      _writeLine(buffer, 'Status', 'Unavailable');
      return;
    }
    _writeLine(buffer, 'Status', _sectionStatusLabel(library.status));
    _writeLine(
      buffer,
      'Favourite items',
      _formatInt(library.favouriteItemCount),
    );
    _writeLine(
      buffer,
      'Favourite folders',
      _formatInt(library.favouriteFolderCount),
    );
    _writeLine(
      buffer,
      'Metadata version',
      _formatInt(library.metadataVersion),
    );
    _writeLine(buffer, 'Libraries', _formatInt(library.libraryCount));
    _writeLine(buffer, 'Folders', _formatInt(library.folderCount));
    _writeLine(buffer, 'Items', _formatInt(library.itemCount));
    _writeLine(
      buffer,
      'Continue watching',
      library.continueWatchingCount == null
          ? 'Not applicable'
          : _formatInt(library.continueWatchingCount),
    );
  });

  buffer.writeln('---');
  buffer.writeln(
    'Generated by TTSPlayer Diagnostics. Do not edit section headings.',
  );
  return buffer.toString();
}

void _writeSection(
  StringBuffer buffer,
  String title,
  void Function() writeBody,
) {
  buffer.writeln('=== $title ===');
  writeBody();
  buffer.writeln();
}

void _writeLine(StringBuffer buffer, String label, String? value) {
  final rendered = value == null || value.isEmpty ? 'Unavailable' : value;
  buffer.writeln('$label: $rendered');
}

String _sectionStatusLabel(DiagnosticSectionStatus status) {
  switch (status) {
    case DiagnosticSectionStatus.complete:
      return 'Complete';
    case DiagnosticSectionStatus.partial:
      return 'Partial';
    case DiagnosticSectionStatus.unavailable:
      return 'Unavailable';
  }
}

String _formatBool(bool? value) {
  if (value == null) {
    return 'Unavailable';
  }
  return value ? 'true' : 'false';
}

String _formatInt(int? value) {
  if (value == null) {
    return 'Unavailable';
  }
  return value.toString();
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Unavailable';
  }
  return value.toUtc().toIso8601String();
}

String _formatDuration(Duration? value) {
  if (value == null) {
    return 'Unavailable';
  }
  final seconds = value.inSeconds;
  if (seconds < 60) {
    return '${seconds}s';
  }
  final minutes = value.inMinutes;
  final remSeconds = seconds % 60;
  if (minutes < 60) {
    return remSeconds == 0 ? '${minutes}m' : '${minutes}m ${remSeconds}s';
  }
  final hours = value.inHours;
  final remMinutes = minutes % 60;
  return remMinutes == 0 ? '${hours}h' : '${hours}h ${remMinutes}m';
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return 'Unavailable';
  }
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

/// Verifies export text does not contain known sensitive patterns.
bool exportContainsSensitiveData(String export) {
  return containsSensitivePatterns(export);
}
