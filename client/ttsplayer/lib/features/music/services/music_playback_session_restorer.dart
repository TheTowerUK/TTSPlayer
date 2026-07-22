import 'package:flutter/foundation.dart';

import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../services/playback_service.dart';
import '../models/music_library_projection.dart';
import '../models/music_playback_session_restore_result.dart';
import '../music_library_service.dart';
import 'music_playback_queue_controller.dart';
import 'music_playback_session_coordinator.dart';
import 'music_playback_session_repository.dart';

/// Restores persisted music playback session into the live queue on cold start.
///
/// Orchestrates catalogue reconciliation, track resolution, and queue hydration.
/// Does not autoplay or navigate.
class MusicPlaybackSessionRestorer {
  MusicPlaybackSessionRestorer({
    required MusicPlaybackSessionRepository repository,
    required MusicPlaybackQueueController queueController,
    required MusicLibraryService musicLibraryService,
    required PlaybackService playbackService,
    required MusicPlaybackSessionCoordinator sessionCoordinator,
  })  : _repository = repository,
        _queue = queueController,
        _musicLibrary = musicLibraryService,
        _playback = playbackService,
        _coordinator = sessionCoordinator;

  final MusicPlaybackSessionRepository _repository;
  final MusicPlaybackQueueController _queue;
  final MusicLibraryService _musicLibrary;
  final PlaybackService _playback;
  final MusicPlaybackSessionCoordinator _coordinator;

  bool _coldStartRestoreAttempted = false;

  /// When true, [restoreOnColdStart] throws before mutating the queue (tests).
  @visibleForTesting
  bool simulateQueueRestoreFailure = false;

  bool get coldStartRestoreAttempted => _coldStartRestoreAttempted;

  /// Restores the reconciled persisted session after catalogue load.
  ///
  /// Safe to call once per process; subsequent calls return [skipped] result.
  Future<MusicPlaybackSessionRestoreResult> restoreOnColdStart(
    Catalog catalog,
  ) async {
    if (_coldStartRestoreAttempted) {
      return MusicPlaybackSessionRestoreResult(
        persistedQueueCount: _repository.session.queueTrackIds.length,
        restoredQueueCount: _queue.queue.items.length,
        unresolvedCount: 0,
        restoredActiveTrackId: _queue.currentTrack?.id,
        restoredPosition: _queue.restoredStartPosition ?? Duration.zero,
        queueEmpty: _queue.isEmpty,
        skipped: true,
      );
    }
    _coldStartRestoreAttempted = true;

    try {
      final recoveryWarnings = <String>[];
      if (!_repository.isLoaded) {
        final loadResult = await _repository.initialize();
        recoveryWarnings.addAll(loadResult.recoveryWarnings);
      } else {
        recoveryWarnings.addAll(_repository.lastRecoveryWarnings);
      }

      final sessionBefore = _repository.session;
      await _repository.validateAgainstCatalog(catalog);
      final session = _repository.session;
      final persistedCount = sessionBefore.queueTrackIds.length;

      if (session.isEmpty) {
        _queue.clearQueueOnly();
        _completeColdStart();
        return MusicPlaybackSessionRestoreResult(
          persistedQueueCount: persistedCount,
          restoredQueueCount: 0,
          unresolvedCount: 0,
          queueEmpty: true,
          warnings: recoveryWarnings,
        );
      }

      final projection = _musicLibrary.projectionFor(catalog);
      final resolvedItems = _resolveQueueItems(
        session.queueTrackIds,
        catalog,
        projection,
      );
      final uniquePersistedIds = _uniqueTrackIds(sessionBefore.queueTrackIds);
      final unresolvedCount = uniquePersistedIds.length - resolvedItems.length;

      if (resolvedItems.isEmpty) {
        _queue.clearQueueOnly();
        _completeColdStart();
        return MusicPlaybackSessionRestoreResult(
          persistedQueueCount: persistedCount,
          restoredQueueCount: 0,
          unresolvedCount: unresolvedCount,
          queueEmpty: true,
          warnings: recoveryWarnings,
        );
      }

      var activeId = session.activeTrackId;
      var position = session.playbackPosition;
      var activeFellBack = false;

      final resolvedIds = resolvedItems.map((item) => item.id).toSet();
      if (activeId == null || !resolvedIds.contains(activeId)) {
        activeId = resolvedItems.first.id;
        position = Duration.zero;
        activeFellBack = true;
      } else {
        final activeItem =
            resolvedItems.firstWhere((item) => item.id == activeId);
        position = normalizeRestorePosition(
          position: position,
          activeTrack: activeItem,
        );
      }

      if (simulateQueueRestoreFailure) {
        throw StateError('Simulated queue restore failure.');
      }

      try {
        _queue.restoreSession(
          items: resolvedItems,
          activeTrackId: activeId,
          position: position,
        );
      } catch (e, stackTrace) {
        debugPrint(
          '[MusicPlaybackSessionRestorer] queue restore failed: $e\n$stackTrace',
        );
        _queue.clearQueueOnly();
        _completeColdStart();
        return MusicPlaybackSessionRestoreResult(
          persistedQueueCount: persistedCount,
          restoredQueueCount: 0,
          unresolvedCount: unresolvedCount,
          queueEmpty: true,
          warnings: const ['Could not restore music playback queue.'],
        );
      }

      assert(_playback.currentItem == null && !_playback.isPlaying);

      _completeColdStart();
      return MusicPlaybackSessionRestoreResult(
        persistedQueueCount: persistedCount,
        restoredQueueCount: resolvedItems.length,
        unresolvedCount: unresolvedCount,
        restoredActiveTrackId: activeId,
        activeTrackFellBack: activeFellBack,
        restoredPosition: position,
        warnings: recoveryWarnings,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[MusicPlaybackSessionRestorer] restoreOnColdStart failed: '
        '$e\n$stackTrace',
      );
      _queue.clearQueueOnly();
      _completeColdStart();
      return const MusicPlaybackSessionRestoreResult(
        persistedQueueCount: 0,
        restoredQueueCount: 0,
        unresolvedCount: 0,
        queueEmpty: true,
        warnings: ['Music playback session restoration failed unexpectedly.'],
      );
    }
  }

  void _completeColdStart() {
    if (!_coordinator.isAttached) {
      _coordinator.attach(deferPersistenceUntilColdStartComplete: true);
    }
    _coordinator.enablePersistenceAfterColdStartRestore(
      restoredPosition: _queue.restoredStartPosition,
    );
  }

  /// Resolves playable audio tracks in persisted order without duplicates.
  @visibleForTesting
  static List<MediaItem> resolveQueueItemsForCatalog({
    required List<String> queueTrackIds,
    required Catalog catalog,
    required MusicLibraryProjection projection,
  }) {
    return _resolveQueueItems(queueTrackIds, catalog, projection);
  }

  static List<MediaItem> _resolveQueueItems(
    List<String> queueTrackIds,
    Catalog catalog,
    MusicLibraryProjection projection,
  ) {
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final trackId in queueTrackIds) {
      if (!seen.add(trackId)) continue;
      final item = _resolvePlayableAudioTrack(trackId, catalog, projection);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  static MediaItem? _resolvePlayableAudioTrack(
    String trackId,
    Catalog catalog,
    MusicLibraryProjection projection,
  ) {
    final fromCatalog = catalog.findItemById(trackId);
    if (fromCatalog != null &&
        fromCatalog.isAudio &&
        fromCatalog.status.isPlayable) {
      return fromCatalog;
    }

    final fromProjection = projection.findTrackById(trackId);
    if (fromProjection != null &&
        fromProjection.isAudio &&
        fromProjection.status.isPlayable) {
      return fromProjection;
    }
    return null;
  }

  static List<String> _uniqueTrackIds(List<String> trackIds) {
    final unique = <String>[];
    final seen = <String>{};
    for (final id in trackIds) {
      if (seen.add(id)) unique.add(id);
    }
    return unique;
  }

  /// Clamps restore position to valid bounds and near-end policy.
  @visibleForTesting
  static Duration normalizeRestorePosition({
    required Duration position,
    required MediaItem? activeTrack,
  }) {
    var normalized = position.isNegative ? Duration.zero : position;
    final durationSeconds = activeTrack?.durationSeconds;
    if (durationSeconds == null || durationSeconds <= 0) {
      return normalized;
    }

    final total = Duration(seconds: durationSeconds);
    if (normalized > total) {
      normalized = total;
    }

    final remaining = total - normalized;
    if (remaining < ResumeInfo.nearEndWindow) {
      return Duration.zero;
    }
    return normalized;
  }
}
