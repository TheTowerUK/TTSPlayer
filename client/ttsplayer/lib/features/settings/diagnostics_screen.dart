import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/diagnostics/diagnostic_section_status.dart';
import '../../services/diagnostics/diagnostics_service.dart';
import '../../services/diagnostics/runtime_diagnostics_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tts_app_bar.dart';
import 'diagnostics_clipboard.dart';
import 'diagnostics_export_coordinator.dart';
import 'diagnostics_formatters.dart';
import 'widgets/diagnostics_section.dart';
import 'widgets/diagnostics_value_row.dart';

/// Read-only runtime diagnostics (M4 Phase 4.6).
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    DiagnosticsClipboardWriter? clipboardWriter,
  }) : _clipboardWriter = clipboardWriter;

  final DiagnosticsClipboardWriter? _clipboardWriter;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  RuntimeDiagnosticsSnapshot? _snapshot;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _copying = false;
  String? _screenError;
  String? _refreshMessage;
  int _captureGeneration = 0;
  int _copyGeneration = 0;

  DiagnosticsExportCoordinator? _exportCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureSnapshot(initial: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exportCoordinator ??= DiagnosticsExportCoordinator(
      diagnosticsService: context.read<DiagnosticsService>(),
      clipboardWriter:
          widget._clipboardWriter ?? const FlutterDiagnosticsClipboardWriter(),
    );
  }

  bool get _operationInFlight => _refreshing || _copying;

  Future<void> _captureSnapshot({required bool initial}) async {
    if (_operationInFlight) return;

    final generation = ++_captureGeneration;
    if (initial) {
      setState(() {
        _initialLoading = true;
        _screenError = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _refreshMessage = null;
      });
    }

    try {
      final snapshot =
          await context.read<DiagnosticsService>().captureSnapshot();
      if (!mounted || generation != _captureGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _initialLoading = false;
        _refreshing = false;
        _screenError = null;
        _refreshMessage = null;
      });
    } catch (_) {
      if (!mounted || generation != _captureGeneration) return;
      setState(() {
        _initialLoading = false;
        _refreshing = false;
        if (_snapshot == null) {
          _screenError = 'Diagnostics could not be collected.';
        } else {
          _refreshMessage = 'Refresh failed. Showing the previous snapshot.';
        }
      });
    }
  }

  Future<void> _copyDiagnostics() async {
    if (_operationInFlight || _snapshot == null) return;

    final generation = ++_copyGeneration;
    setState(() => _copying = true);

    final result = await _exportCoordinator!.copyDiagnostics();
    if (!mounted || generation != _copyGeneration) return;

    setState(() => _copying = false);

    switch (result) {
      case DiagnosticsExportSuccess(:final snapshot):
        setState(() => _snapshot = snapshot);
        _showCopyFeedback('Diagnostics copied to clipboard.');
      case DiagnosticsExportCaptureFailure():
        _showCopyFeedback('Diagnostics could not be collected. Try again.');
      case DiagnosticsExportFormatFailure():
        _showCopyFeedback('Diagnostics could not be copied.');
      case DiagnosticsExportClipboardFailure():
        _showCopyFeedback('Diagnostics could not be copied.');
    }
  }

  void _showCopyFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TtsAppBar(
        title: 'Diagnostics',
        showHome: true,
        extraActions: [
          IconButton(
            key: const Key('refresh_diagnostics'),
            tooltip: 'Refresh diagnostics',
            onPressed: _initialLoading || _operationInFlight
                ? null
                : () => _captureSnapshot(initial: false),
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading && _snapshot == null) {
      return const Center(
        key: Key('diagnostics_loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.base),
            Text('Collecting diagnostics…'),
          ],
        ),
      );
    }

    if (_screenError != null && _snapshot == null) {
      return Center(
        key: const Key('diagnostics_screen_error'),
        child: Padding(
          padding: AppSpacing.insetPage,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppSpacing.base),
              Text(_screenError!),
              const SizedBox(height: AppSpacing.base),
              FilledButton.icon(
                key: const Key('diagnostics_retry'),
                onPressed: () => _captureSnapshot(initial: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: AppSpacing.insetPage,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Read-only runtime state for troubleshooting.',
                  style: AppTypography.bodyMuted,
                ),
                if (_refreshMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DecoratedBox(
                    key: const Key('diagnostics_refresh_error'),
                    decoration: BoxDecoration(
                      color: AppColors.warningBannerBg,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(_refreshMessage!)),
                          TextButton(
                            onPressed: _refreshing
                                ? null
                                : () => _captureSnapshot(initial: false),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_refreshing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    key: Key('diagnostics_refresh_progress'),
                  ),
                ],
                if (_copying) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    key: Key('diagnostics_copy_progress'),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                _buildApplicationSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildProviderSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildCatalogueSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildCacheSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildSearchSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildPlaybackSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildMusicListeningSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildMusicPlaybackSessionSection(snapshot),
                const SizedBox(height: AppSpacing.section),
                _buildLibrarySection(snapshot),
                const SizedBox(height: AppSpacing.section),
                Tooltip(
                  message: 'Copy diagnostics',
                  child: FilledButton.icon(
                    key: const Key('copy_diagnostics'),
                    onPressed: _operationInFlight ? null : _copyDiagnostics,
                    icon: _copying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy),
                    label: const Text('Copy diagnostics'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('refresh_diagnostics_button'),
                  onPressed: _operationInFlight
                      ? null
                      : () => _captureSnapshot(initial: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh diagnostics'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationSection(RuntimeDiagnosticsSnapshot snapshot) {
    final app = snapshot.application;
    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_application'),
      title: 'Application',
      status: app.status,
      children: [
        DiagnosticsValueRow(
          label: 'Name',
          value: DiagnosticsFormatters.textValue(app.appName),
        ),
        DiagnosticsValueRow(
          label: 'Version',
          value: DiagnosticsFormatters.textValue(app.appVersion),
          valueKey: const Key('diagnostics_app_version'),
        ),
        DiagnosticsValueRow(
          label: 'Build',
          value: DiagnosticsFormatters.textValue(app.buildNumber),
        ),
        DiagnosticsValueRow(
          label: 'Platform',
          value: DiagnosticsFormatters.textValue(app.platform),
        ),
        DiagnosticsValueRow(
          label: 'Startup elapsed',
          value: DiagnosticsFormatters.durationValue(app.startupElapsed),
        ),
        DiagnosticsValueRow(
          label: 'Captured at',
          value: DiagnosticsFormatters.dateTimeUtc(snapshot.capturedAt),
          valueKey: const Key('diagnostics_captured_at'),
        ),
      ],
    );
  }

  Widget _buildProviderSection(RuntimeDiagnosticsSnapshot snapshot) {
    final provider = snapshot.provider;
    final rows = <Widget>[
      DiagnosticsValueRow(
        label: 'Access mode',
        value: DiagnosticsFormatters.textValue(provider.accessModeLabel),
      ),
      DiagnosticsValueRow(
        label: 'Active provider kind',
        value:
            DiagnosticsFormatters.textValue(provider.activeProviderKindLabel),
      ),
      DiagnosticsValueRow(
        label: 'Active source',
        value:
            DiagnosticsFormatters.textValue(provider.activeSourceCategoryLabel),
      ),
      DiagnosticsValueRow(
        label: 'Configured providers',
        value: DiagnosticsFormatters.intValue(provider.configuredProviderCount),
      ),
      DiagnosticsValueRow(
        label: 'Using fallback',
        value: DiagnosticsFormatters.boolValue(provider.isUsingFallback),
      ),
      DiagnosticsValueRow(
        label: 'Degraded load',
        value: DiagnosticsFormatters.boolValue(provider.isDegradedLoad),
      ),
      DiagnosticsValueRow(
        label: 'Demo fallback',
        value: DiagnosticsFormatters.boolValue(provider.isDemoFallback),
      ),
      DiagnosticsValueRow(
        label: 'Last refresh',
        value: DiagnosticsFormatters.dateTimeUtc(provider.lastRefreshAt),
      ),
      DiagnosticsValueRow(
        label: 'Last successful load',
        value: DiagnosticsFormatters.dateTimeUtc(provider.lastSuccessfulLoadAt),
      ),
      DiagnosticsValueRow(
        label: 'Last load started',
        value: DiagnosticsFormatters.dateTimeUtc(provider.lastLoadStartedAt),
      ),
      DiagnosticsValueRow(
        label: 'Last cycle error',
        value: DiagnosticsFormatters.textValue(provider.lastCycleErrorSummary),
      ),
    ];

    for (var i = 0; i < provider.providers.length; i++) {
      final row = provider.providers[i];
      rows.addAll([
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Provider ${i + 1}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        DiagnosticsValueRow(
          label: 'Kind',
          value: DiagnosticsFormatters.textValue(row.providerKindLabel),
        ),
        DiagnosticsValueRow(
          label: 'Health',
          value: DiagnosticsFormatters.healthLabel(row.healthLabel),
        ),
        DiagnosticsValueRow(
          label: 'Active',
          value: DiagnosticsFormatters.boolValue(row.isActive),
        ),
        DiagnosticsValueRow(
          label: 'Last error',
          value: DiagnosticsFormatters.textValue(row.lastErrorSummary),
        ),
        DiagnosticsValueRow(
          label: 'Last attempt',
          value: DiagnosticsFormatters.dateTimeUtc(row.lastAttemptAt),
        ),
        DiagnosticsValueRow(
          label: 'Last success',
          value: DiagnosticsFormatters.dateTimeUtc(row.lastSuccessAt),
        ),
      ]);
    }

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_provider'),
      title: 'Provider',
      status: provider.status,
      children: rows,
    );
  }

  Widget _buildCatalogueSection(RuntimeDiagnosticsSnapshot snapshot) {
    final catalogue = snapshot.catalogue;
    if (catalogue == null) {
      return const DiagnosticsSection(
        sectionKey: Key('diagnostics_section_catalogue'),
        title: 'Catalogue',
        status: DiagnosticSectionStatus.unavailable,
        children: [
          DiagnosticsValueRow(
            label: 'Availability',
            value: 'Unavailable',
          ),
        ],
      );
    }

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_catalogue'),
      title: 'Catalogue',
      status: catalogue.status,
      children: [
        DiagnosticsValueRow(
          label: 'Identity',
          value: DiagnosticsFormatters.textValue(catalogue.catalogueIdentity),
        ),
        DiagnosticsValueRow(
          label: 'Source',
          value: DiagnosticsFormatters.textValue(catalogue.sourceKindLabel),
        ),
        DiagnosticsValueRow(
          label: 'Generated at',
          value: DiagnosticsFormatters.textValue(catalogue.generatedAt),
        ),
        DiagnosticsValueRow(
          label: 'Libraries',
          value: DiagnosticsFormatters.intValue(catalogue.libraryCount),
          valueKey: const Key('diagnostics_catalogue_libraries'),
        ),
        DiagnosticsValueRow(
          label: 'Folders',
          value: DiagnosticsFormatters.intValue(catalogue.folderCount),
        ),
        DiagnosticsValueRow(
          label: 'Items',
          value: DiagnosticsFormatters.intValue(catalogue.itemCount),
        ),
        DiagnosticsValueRow(
          label: 'Demo data',
          value: DiagnosticsFormatters.boolValue(catalogue.isDemoData),
        ),
        DiagnosticsValueRow(
          label: 'Degraded',
          value: DiagnosticsFormatters.boolValue(catalogue.isDegraded),
        ),
        DiagnosticsValueRow(
          label: 'Loading',
          value: DiagnosticsFormatters.boolValue(catalogue.isLoading),
        ),
        DiagnosticsValueRow(
          label: 'Last error',
          value: DiagnosticsFormatters.textValue(catalogue.lastErrorSummary),
        ),
        DiagnosticsValueRow(
          label: 'Last successful replacement',
          value: DiagnosticsFormatters.dateTimeUtc(
            catalogue.lastSuccessfulReplacementAt,
          ),
        ),
      ],
    );
  }

  Widget _buildCacheSection(RuntimeDiagnosticsSnapshot snapshot) {
    final cache = snapshot.cache;
    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_cache'),
      title: 'Cache',
      status: cache.status,
      children: [
        DiagnosticsValueRow(
          label: 'Artwork candidates',
          value: DiagnosticsFormatters.intValue(cache.artworkCandidateCount),
          valueKey: const Key('diagnostics_cache_entries'),
        ),
        DiagnosticsValueRow(
          label: 'Artwork capacity',
          value: DiagnosticsFormatters.intValue(cache.artworkCandidateCapacity),
        ),
        DiagnosticsValueRow(
          label: 'Artwork evictions',
          value: DiagnosticsFormatters.intValue(cache.artworkEvictionCount),
        ),
        DiagnosticsValueRow(
          label: 'Image cache',
          value: DiagnosticsFormatters.bytesOfTotal(
            cache.imageCacheCurrentBytes,
            cache.imageCacheBudgetBytes,
          ),
          valueKey: const Key('diagnostics_image_cache'),
        ),
        DiagnosticsValueRow(
          label: 'Live images',
          value: DiagnosticsFormatters.intValue(cache.imageCacheLiveImageCount),
        ),
      ],
    );
  }

  Widget _buildSearchSection(RuntimeDiagnosticsSnapshot snapshot) {
    final search = snapshot.search;
    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_search'),
      title: 'Search',
      status: search.status,
      children: [
        DiagnosticsValueRow(
          label: 'Index present',
          value: DiagnosticsFormatters.boolValue(search.hasIndex),
          valueKey: const Key('diagnostics_search_has_index'),
        ),
        DiagnosticsValueRow(
          label: 'Index build count',
          value: DiagnosticsFormatters.intValue(search.indexBuildCount),
        ),
        DiagnosticsValueRow(
          label: 'Build in flight',
          value: DiagnosticsFormatters.boolValue(search.isBuildInFlight),
        ),
        DiagnosticsValueRow(
          label: 'Indexed identity',
          value:
              DiagnosticsFormatters.textValue(search.indexedCatalogueIdentity),
        ),
        DiagnosticsValueRow(
          label: 'Indexed items',
          value: DiagnosticsFormatters.intValue(search.indexedItemCount),
        ),
        DiagnosticsValueRow(
          label: 'Matches active catalogue',
          value: DiagnosticsFormatters.boolValue(
              search.indexMatchesActiveCatalogue),
        ),
        DiagnosticsValueRow(
          label: 'Last build failure',
          value: search.lastBuildFailureCategory == null
              ? DiagnosticsFormatters.notApplicable()
              : DiagnosticsFormatters.textValue(
                  search.lastBuildFailureCategory),
        ),
      ],
    );
  }

  Widget _buildPlaybackSection(RuntimeDiagnosticsSnapshot snapshot) {
    final playback = snapshot.playback;
    final hasSession = playback.hasActiveSession == true;

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_playback'),
      title: 'Playback',
      status: playback.status,
      children: [
        DiagnosticsValueRow(
          label: 'Engine',
          value: DiagnosticsFormatters.textValue(playback.engineLabel),
        ),
        DiagnosticsValueRow(
          label: 'Platform supported',
          value: DiagnosticsFormatters.boolValue(
              playback.playbackPlatformSupported),
        ),
        DiagnosticsValueRow(
          label: 'Speed settings supported',
          value:
              DiagnosticsFormatters.boolValue(playback.speedSettingsSupported),
        ),
        DiagnosticsValueRow(
          label: 'Active session',
          value: DiagnosticsFormatters.boolValue(playback.hasActiveSession),
          valueKey: const Key('diagnostics_playback_active'),
        ),
        if (!hasSession)
          const DiagnosticsValueRow(
            label: 'Session state',
            value: 'Inactive',
          ),
        DiagnosticsValueRow(
          label: 'Media prepared',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.isMediaPrepared)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Playing',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.isPlaying)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Initializing',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.isInitializing)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Can change rate',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.canChangePlaybackRate)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Can select audio',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.canSelectAudioTracks)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Can select subtitles',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(
                  playback.canSelectSubtitleTracks)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Playback rate',
          value: hasSession && playback.playbackRate != null
              ? playback.playbackRate!.toString()
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Error kind',
          value: DiagnosticsFormatters.playbackErrorKind(playback.errorKind),
        ),
        DiagnosticsValueRow(
          label: 'Error message',
          value: DiagnosticsFormatters.textValue(playback.errorMessageSummary),
        ),
        DiagnosticsValueRow(
          label: 'Retry available',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.retryAvailable)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Audio tracks',
          value: hasSession
              ? DiagnosticsFormatters.intValue(playback.audioTrackCount)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Subtitle tracks',
          value: hasSession
              ? DiagnosticsFormatters.intValue(playback.subtitleTrackCount)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Audio selected',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(playback.hasAudioTrackSelected)
              : DiagnosticsFormatters.notApplicable(),
        ),
        DiagnosticsValueRow(
          label: 'Subtitle selected',
          value: hasSession
              ? DiagnosticsFormatters.boolValue(
                  playback.hasSubtitleTrackSelected)
              : DiagnosticsFormatters.notApplicable(),
        ),
      ],
    );
  }

  Widget _buildMusicListeningSection(RuntimeDiagnosticsSnapshot snapshot) {
    final musicListening = snapshot.musicListening;
    if (musicListening == null) {
      return const DiagnosticsSection(
        sectionKey: Key('diagnostics_section_music_listening'),
        title: 'Music Listening',
        status: DiagnosticSectionStatus.unavailable,
        children: [
          DiagnosticsValueRow(
            label: 'Availability',
            value: 'Unavailable',
          ),
        ],
      );
    }

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_music_listening'),
      title: 'Music Listening',
      status: musicListening.status,
      children: [
        DiagnosticsValueRow(
          label: 'Repository loaded',
          value:
              DiagnosticsFormatters.boolValue(musicListening.repositoryLoaded),
          valueKey: const Key('diagnostics_music_listening_loaded'),
        ),
        DiagnosticsValueRow(
          label: 'Stored records',
          value:
              DiagnosticsFormatters.intValue(musicListening.storedRecordCount),
          valueKey: const Key('diagnostics_music_listening_stored'),
        ),
        DiagnosticsValueRow(
          label: 'Continue listening',
          value: DiagnosticsFormatters.intValue(
            musicListening.continueListeningCount,
          ),
          valueKey: const Key('diagnostics_music_listening_continue'),
        ),
        DiagnosticsValueRow(
          label: 'Recently played',
          value: DiagnosticsFormatters.intValue(
              musicListening.recentlyPlayedCount),
        ),
        DiagnosticsValueRow(
          label: 'Completed records',
          value: DiagnosticsFormatters.intValue(
              musicListening.completedRecordCount),
        ),
        DiagnosticsValueRow(
          label: 'Incomplete records',
          value: DiagnosticsFormatters.intValue(
              musicListening.incompleteRecordCount),
        ),
        DiagnosticsValueRow(
          label: 'Recovery warning present',
          value: DiagnosticsFormatters.boolValue(
            musicListening.recoveryWarningPresent,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Coordinator attached',
          value: DiagnosticsFormatters.boolValue(
              musicListening.coordinatorAttached),
        ),
        DiagnosticsValueRow(
          label: 'Active session',
          value: DiagnosticsFormatters.boolValue(musicListening.sessionActive),
          valueKey: const Key('diagnostics_music_listening_session'),
        ),
        DiagnosticsValueRow(
          label: 'Pending write',
          value: DiagnosticsFormatters.boolValue(musicListening.pendingWrite),
        ),
        DiagnosticsValueRow(
          label: 'Persistence warning present',
          value: DiagnosticsFormatters.boolValue(
            musicListening.persistenceWarningPresent,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Last persistence warning',
          value: DiagnosticsFormatters.textValue(
            musicListening.lastPersistenceWarningSummary,
          ),
        ),
      ],
    );
  }

  Widget _buildMusicPlaybackSessionSection(
      RuntimeDiagnosticsSnapshot snapshot) {
    final session = snapshot.musicPlaybackSession;
    if (session == null) {
      return const DiagnosticsSection(
        sectionKey: Key('diagnostics_section_music_playback_session'),
        title: 'Music Playback Session',
        status: DiagnosticSectionStatus.unavailable,
        children: [
          DiagnosticsValueRow(
            label: 'Availability',
            value: 'Unavailable',
          ),
        ],
      );
    }

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_music_playback_session'),
      title: 'Music Playback Session',
      status: session.status,
      children: [
        DiagnosticsValueRow(
          label: 'State version',
          value: DiagnosticsFormatters.intValue(session.stateVersion),
        ),
        DiagnosticsValueRow(
          label: 'Repository loaded',
          value: DiagnosticsFormatters.boolValue(session.repositoryLoaded),
          valueKey: const Key('diagnostics_music_playback_session_loaded'),
        ),
        DiagnosticsValueRow(
          label: 'Persisted session present',
          value:
              DiagnosticsFormatters.boolValue(session.persistedSessionPresent),
        ),
        DiagnosticsValueRow(
          label: 'Persisted queue items',
          value: DiagnosticsFormatters.intValue(session.persistedQueueCount),
          valueKey: const Key('diagnostics_music_playback_session_persisted'),
        ),
        DiagnosticsValueRow(
          label: 'Live queue items',
          value: DiagnosticsFormatters.intValue(session.liveQueueCount),
          valueKey: const Key('diagnostics_music_playback_session_live'),
        ),
        DiagnosticsValueRow(
          label: 'Active track selected',
          value: DiagnosticsFormatters.boolValue(session.activeTrackPresent),
        ),
        DiagnosticsValueRow(
          label: 'Stored position available',
          value:
              DiagnosticsFormatters.boolValue(session.storedPositionAvailable),
        ),
        DiagnosticsValueRow(
          label: 'Restored on cold start',
          value: DiagnosticsFormatters.boolValue(session.restoredOnColdStart),
        ),
        DiagnosticsValueRow(
          label: 'Persistence enabled',
          value: DiagnosticsFormatters.boolValue(session.persistenceEnabled),
        ),
        DiagnosticsValueRow(
          label: 'Pending queue debounce',
          value: DiagnosticsFormatters.boolValue(session.pendingQueueDebounce),
        ),
        DiagnosticsValueRow(
          label: 'Pending write',
          value: DiagnosticsFormatters.boolValue(session.pendingWrite),
        ),
        DiagnosticsValueRow(
          label: 'Recovery warning present',
          value:
              DiagnosticsFormatters.boolValue(session.recoveryWarningPresent),
        ),
        DiagnosticsValueRow(
          label: 'Persistence warning present',
          value: DiagnosticsFormatters.boolValue(
            session.persistenceWarningPresent,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Last persistence warning',
          value: DiagnosticsFormatters.textValue(
            session.lastPersistenceWarningSummary,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Last reconciliation removed',
          value: DiagnosticsFormatters.intValue(
            session.lastReconciliationRemovedCount,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Last restoration restored',
          value: DiagnosticsFormatters.intValue(
            session.lastRestorationRestoredCount,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Last restoration unresolved',
          value: DiagnosticsFormatters.intValue(
            session.lastRestorationUnresolvedCount,
          ),
        ),
        DiagnosticsValueRow(
          label: 'Coordinator attached',
          value: DiagnosticsFormatters.boolValue(session.coordinatorAttached),
        ),
      ],
    );
  }

  Widget _buildLibrarySection(RuntimeDiagnosticsSnapshot snapshot) {
    final library = snapshot.library;
    if (library == null) {
      return const DiagnosticsSection(
        sectionKey: Key('diagnostics_section_library'),
        title: 'Library',
        status: DiagnosticSectionStatus.unavailable,
        children: [
          DiagnosticsValueRow(
            label: 'Availability',
            value: 'Unavailable',
          ),
        ],
      );
    }

    return DiagnosticsSection(
      sectionKey: const Key('diagnostics_section_library'),
      title: 'Library',
      status: library.status,
      children: [
        DiagnosticsValueRow(
          label: 'Favourite items',
          value: DiagnosticsFormatters.intValue(library.favouriteItemCount),
          valueKey: const Key('diagnostics_library_favourites'),
        ),
        DiagnosticsValueRow(
          label: 'Favourite folders',
          value: DiagnosticsFormatters.intValue(library.favouriteFolderCount),
        ),
        DiagnosticsValueRow(
          label: 'Metadata version',
          value: DiagnosticsFormatters.intValue(library.metadataVersion),
        ),
        DiagnosticsValueRow(
          label: 'Libraries',
          value: DiagnosticsFormatters.intValue(library.libraryCount),
        ),
        DiagnosticsValueRow(
          label: 'Folders',
          value: DiagnosticsFormatters.intValue(library.folderCount),
        ),
        DiagnosticsValueRow(
          label: 'Media items',
          value: DiagnosticsFormatters.intValue(library.itemCount),
        ),
        DiagnosticsValueRow(
          label: 'Continue watching',
          value: library.continueWatchingCount == null
              ? DiagnosticsFormatters.notApplicable()
              : DiagnosticsFormatters.intValue(library.continueWatchingCount),
        ),
      ],
    );
  }
}
