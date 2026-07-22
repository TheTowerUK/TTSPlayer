import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/playback_service.dart';
import '../models/music_playback_session.dart';
import '../models/music_playback_session_policy.dart';
import 'music_playback_session_repository.dart';
import 'music_playback_queue_controller.dart';

/// Observes music queue and playback lifecycle and persists session snapshots
/// (M5.5 Step 2).
///
/// Does not restore sessions on startup or modify listening history / video keys.
class MusicPlaybackSessionCoordinator extends ChangeNotifier {
  MusicPlaybackSessionCoordinator({
    required MusicPlaybackSessionRepository repository,
    required PlaybackService playbackService,
    required MusicPlaybackQueueController queueController,
    DateTime Function()? now,
    Duration queueMutationDebounce =
        MusicPlaybackSessionPolicy.queueMutationDebounce,
    Duration positionPersistInterval =
        MusicPlaybackSessionPolicy.positionPersistInterval,
  })  : _repository = repository,
        _playback = playbackService,
        _queue = queueController,
        _now = now ?? DateTime.now,
        _queueMutationDebounce = queueMutationDebounce,
        _positionPersistInterval = positionPersistInterval;

  final MusicPlaybackSessionRepository _repository;
  final PlaybackService _playback;
  final MusicPlaybackQueueController _queue;
  final DateTime Function() _now;
  final Duration _queueMutationDebounce;
  final Duration _positionPersistInterval;

  Timer? _queueDebounceTimer;
  int _snapshotGeneration = 0;
  int _lastPersistedGeneration = 0;
  bool _attached = false;
  bool _disposed = false;
  bool _coldStartPersistenceEnabled = true;
  bool _wasPlaying = false;
  Duration? _lastObservedPosition;
  DateTime? _lastPositionPersistAt;
  String? _lastPersistenceWarning;
  Future<void>? _inFlightWrite;
  String? _lastObservedActiveTrackId;

  String? get lastPersistenceWarning => _lastPersistenceWarning;

  bool get isAttached => _attached;

  bool get persistenceWarningPresent => _lastPersistenceWarning != null;

  /// Subscribes to queue and playback lifecycle events.
  void attach({bool deferPersistenceUntilColdStartComplete = false}) {
    if (_attached || _disposed) return;
    _queue.addListener(_onQueueChanged);
    _playback.addListener(_onPlaybackChanged);
    _attached = true;
    _coldStartPersistenceEnabled = !deferPersistenceUntilColdStartComplete;
  }

  /// Enables persistence after cold-start restore without rewriting storage.
  void enablePersistenceAfterColdStartRestore({Duration? restoredPosition}) {
    _lastObservedActiveTrackId = _queue.currentTrack?.id;
    _lastObservedPosition = restoredPosition ?? Duration.zero;
    _snapshotGeneration++;
    _lastPersistedGeneration = _snapshotGeneration;
    _coldStartPersistenceEnabled = true;
  }

  /// Flushes the current session snapshot on app lifecycle pause when wired.
  Future<void> onAppLifecyclePaused() async {
    if (_disposed) return;
    await _persistImmediate(reason: _PersistReason.lifecycle);
  }

  @visibleForTesting
  Future<void> waitForIdleForTest() => drainPendingWrites();

  /// Awaits in-flight persistence work.
  Future<void> drainPendingWrites() async {
    final pending = _inFlightWrite;
    if (pending != null) {
      await pending;
    }
  }

  void _onQueueChanged() {
    if (_disposed || !_attached || !_coldStartPersistenceEnabled) return;

    if (_queue.isEmpty) {
      _lastObservedActiveTrackId = null;
      unawaited(
        _scheduleWrite(
          _persistEmpty(reason: _PersistReason.queueCleared),
        ),
      );
      return;
    }

    final activeId = _queue.currentTrack?.id;
    if (activeId != null && activeId != _lastObservedActiveTrackId) {
      _lastObservedActiveTrackId = activeId;
      unawaited(
        _scheduleWrite(
          _persistImmediate(reason: _PersistReason.activeTrackChange),
        ),
      );
      return;
    }

    _scheduleDebouncedQueuePersist();
  }

  void _onPlaybackChanged() {
    if (_disposed || !_attached || !_coldStartPersistenceEnabled) return;

    if (_queue.isEmpty) {
      _wasPlaying = false;
      _lastObservedPosition = null;
      return;
    }

    final item = _playback.currentItem;
    final playing = _playback.isPlaying && !_playback.isBuffering;
    final completed = _playback.isCompleted;
    final position = _playback.position;

    if (item != null && item.isAudio) {
      final lastPosition = _lastObservedPosition;
      if (lastPosition != null) {
        final jump = (position - lastPosition).abs();
        if (jump > MusicPlaybackSessionPolicy.seekDetectionThreshold) {
          unawaited(
            _scheduleWrite(
              _persistImmediate(reason: _PersistReason.seek),
            ),
          );
        }
      }
      _lastObservedPosition = position;

      if (playing) {
        unawaited(
          _scheduleWrite(
            _persistThrottledPosition(),
          ),
        );
      } else if (_wasPlaying && !playing && !completed) {
        unawaited(
          _scheduleWrite(
            _persistImmediate(reason: _PersistReason.pause),
          ),
        );
      }
    } else if (!_queue.isEmpty) {
      unawaited(
        _scheduleWrite(
          _persistImmediate(reason: _PersistReason.stop),
        ),
      );
      _lastObservedPosition = null;
    }

    _wasPlaying = playing;
  }

  void _scheduleDebouncedQueuePersist() {
    _snapshotGeneration++;
    final generation = _snapshotGeneration;
    _queueDebounceTimer?.cancel();
    _queueDebounceTimer = Timer(_queueMutationDebounce, () {
      if (_disposed || generation != _snapshotGeneration) return;
      unawaited(
        _scheduleWrite(
          _persistSnapshot(
            generation: generation,
            reason: _PersistReason.queueMutation,
          ),
        ),
      );
    });
  }

  Future<void> _persistImmediate({required _PersistReason reason}) {
    _snapshotGeneration++;
    _queueDebounceTimer?.cancel();
    _queueDebounceTimer = null;
    return _scheduleWrite(
      _persistSnapshot(
        generation: _snapshotGeneration,
        reason: reason,
        force: true,
      ),
    );
  }

  Future<void> _persistThrottledPosition() async {
    final now = _now();
    if (_lastPositionPersistAt != null &&
        now.difference(_lastPositionPersistAt!) < _positionPersistInterval) {
      return;
    }

    _snapshotGeneration++;
    final generation = _snapshotGeneration;
    await _scheduleWrite(
      _persistSnapshot(
        generation: generation,
        reason: _PersistReason.throttledPosition,
      ),
    );
  }

  Future<void> _persistEmpty({required _PersistReason reason}) async {
    _snapshotGeneration++;
    _queueDebounceTimer?.cancel();
    _queueDebounceTimer = null;
    final generation = _snapshotGeneration;
    if (_disposed || generation != _snapshotGeneration) return;

    final write = _repository.clear();
    _inFlightWrite = write;
    try {
      final result = await write;
      if (_disposed || generation != _snapshotGeneration) return;
      if (!result.success) {
        _lastPersistenceWarning = result.errorMessage;
      } else {
        _lastPersistenceWarning = null;
        _lastPersistedGeneration = generation;
      }
      notifyListeners();
    } finally {
      if (identical(_inFlightWrite, write)) {
        _inFlightWrite = null;
      }
    }
  }

  Future<void> _persistSnapshot({
    required int generation,
    required _PersistReason reason,
    bool force = false,
  }) async {
    if (_disposed || generation != _snapshotGeneration) return;
    if (_queue.isEmpty) {
      await _persistEmpty(reason: reason);
      return;
    }

    final snapshot = _buildSnapshot();
    if (_disposed || generation != _snapshotGeneration) return;

    if (!force && reason == _PersistReason.throttledPosition) {
      final now = _now();
      if (_lastPositionPersistAt != null &&
          now.difference(_lastPositionPersistAt!) < _positionPersistInterval) {
        return;
      }
    }

    final write = _repository.save(snapshot);
    _inFlightWrite = write;
    try {
      final result = await write;
      if (_disposed || generation != _snapshotGeneration) return;
      if (!result.success) {
        _lastPersistenceWarning = result.errorMessage;
        if (kDebugMode && reason != _PersistReason.throttledPosition) {
          debugPrint(
            '[MusicPlaybackSessionCoordinator] persist failed: '
            '${result.errorMessage}',
          );
        }
      } else {
        _lastPersistenceWarning = null;
        _lastPersistedGeneration = generation;
        if (reason == _PersistReason.throttledPosition ||
            reason == _PersistReason.pause ||
            reason == _PersistReason.seek ||
            reason == _PersistReason.stop ||
            reason == _PersistReason.lifecycle) {
          _lastPositionPersistAt = _now();
        }
      }
      notifyListeners();
    } finally {
      if (identical(_inFlightWrite, write)) {
        _inFlightWrite = null;
      }
    }
  }

  MusicPlaybackSession _buildSnapshot() {
    final trackIds = [
      for (final item in _queue.queue.items) item.id,
    ];
    final activeId = _queue.currentTrack?.id;
    final position = _playback.currentItem?.isAudio == true &&
            _playback.currentItem?.id == activeId
        ? _playback.position
        : Duration.zero;

    return MusicPlaybackSession(
      queueTrackIds: trackIds,
      activeTrackId: activeId,
      playbackPosition: position.isNegative ? Duration.zero : position,
      updatedAt: _now().toUtc(),
    );
  }

  Future<void> _scheduleWrite(Future<void> write) {
    _inFlightWrite = write;
    return write.whenComplete(() {
      if (identical(_inFlightWrite, write)) {
        _inFlightWrite = null;
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queueDebounceTimer?.cancel();
    _queueDebounceTimer = null;
    _queue.removeListener(_onQueueChanged);
    _playback.removeListener(_onPlaybackChanged);
    if (!_queue.isEmpty) {
      unawaited(
        _persistSnapshot(
          generation: ++_snapshotGeneration,
          reason: _PersistReason.dispose,
          force: true,
        ),
      );
    }
    super.dispose();
  }

  @visibleForTesting
  void handlePlaybackTickForTest() => _onPlaybackChanged();

  @visibleForTesting
  void handleQueueTickForTest() => _onQueueChanged();

  @visibleForTesting
  int get snapshotGenerationForTest => _snapshotGeneration;

  @visibleForTesting
  int get lastPersistedGenerationForTest => _lastPersistedGeneration;
}

enum _PersistReason {
  queueMutation,
  queueCleared,
  activeTrackChange,
  throttledPosition,
  pause,
  seek,
  stop,
  lifecycle,
  dispose,
}
