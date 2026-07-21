import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/media_item.dart';
import '../../../services/playback_service.dart';
import '../models/music_listening_policy.dart';
import '../models/music_listening_record.dart';
import '../music_constants.dart';
import 'music_listening_repository.dart';
import 'music_playback_queue_controller.dart';

/// Observes music playback and persists listening history (M5.4 Step 3).
///
/// Does not modify video Continue Watching keys or [PlaybackService] resume
/// persistence. All writes go through [MusicListeningRepository].
class MusicListeningCoordinator extends ChangeNotifier {
  MusicListeningCoordinator({
    required MusicListeningRepository repository,
    required PlaybackService playbackService,
    required MusicPlaybackQueueController queueController,
    DateTime Function()? now,
  })  : _repository = repository,
        _playback = playbackService,
        _queue = queueController,
        _now = now ?? DateTime.now;

  final MusicListeningRepository _repository;
  final PlaybackService _playback;
  final MusicPlaybackQueueController _queue;
  final DateTime Function() _now;

  _ListeningSession? _session;
  bool _attached = false;
  bool _disposed = false;
  String? _lastPersistenceWarning;
  bool _wasPlaying = false;
  bool _completionHandled = false;
  Future<void>? _inFlightWrite;

  /// Most recent persistence warning for diagnostics (redacted-safe text).
  String? get lastPersistenceWarning => _lastPersistenceWarning;

  bool get isAttached => _attached;

  /// Whether a music listening session is currently being tracked.
  bool get sessionActive => _session != null;

  /// Whether a listening-history write is in flight.
  bool get pendingWrite => _inFlightWrite != null;

  /// Whether the most recent persistence attempt failed.
  bool get persistenceWarningPresent => _lastPersistenceWarning != null;

  /// Subscribes to playback and queue lifecycle events.
  void attach() {
    if (_attached || _disposed) return;
    _playback.addListener(_onPlaybackChanged);
    _queue.addListener(_onQueueChanged);
    _attached = true;
  }

  /// Flushes active session on app lifecycle pause when wired by the shell.
  Future<void> onAppLifecyclePaused() async {
    if (_disposed) return;
    await _flushActiveSession(
      markCompleted: false,
      force: true,
      reason: _FlushReason.lifecycle,
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

  @visibleForTesting
  Future<void> waitForIdleForTest() => drainPendingWrites();

  /// Awaits any in-flight listening-history write (e.g. before queue auto-advance).
  Future<void> drainPendingWrites() async {
    final pending = _inFlightWrite;
    if (pending != null) {
      await pending;
    }
  }

  void _onQueueChanged() {
    if (_disposed) return;

    final track = _queue.currentTrack;
    if (track == null || !track.isAudio) {
      if (_session != null) {
        unawaited(
          _scheduleWrite(
            _flushActiveSession(
              markCompleted: false,
              force: true,
              reason: _FlushReason.queueCleared,
            ),
          ),
        );
      }
      return;
    }

    if (_session != null && _session!.trackId != track.id) {
      unawaited(
        _scheduleWrite(
          _flushActiveSession(
            markCompleted: false,
            force: true,
            reason: _FlushReason.trackChange,
          ),
        ),
      );
      _beginSession(track);
    } else if (_session == null && _playback.currentItem?.id == track.id) {
      _beginSession(track);
    }
  }

  void _onPlaybackChanged() {
    if (_disposed || !_attached) return;

    final item = _playback.currentItem;
    if (item == null || !item.isAudio) {
      if (_session != null) {
        unawaited(
          _scheduleWrite(
            _flushActiveSession(
              markCompleted: false,
              force: true,
              reason: _FlushReason.nonAudioSession,
            ),
          ),
        );
      }
      _wasPlaying = false;
      return;
    }

    if (_session == null || _session!.trackId != item.id) {
      if (_session != null) {
        unawaited(
          _scheduleWrite(
            _flushActiveSession(
              markCompleted: false,
              force: true,
              reason: _FlushReason.trackChange,
            ),
          ),
        );
      }
      _beginSession(item);
    }

    final session = _session;
    if (session == null) return;

    final playing = _playback.isPlaying && !_playback.isBuffering;
    final completed = _playback.isCompleted;

    if (completed && !_completionHandled) {
      _completionHandled = true;
      unawaited(
        _scheduleWrite(
          _flushActiveSession(
            markCompleted: true,
            force: true,
            reason: _FlushReason.naturalCompletion,
          ),
        ),
      );
      _wasPlaying = false;
      return;
    }

    if (!completed) {
      _completionHandled = false;
    }

    if (playing) {
      _accumulateListening(session, _playback.position);
      unawaited(
        _scheduleWrite(
          _flushActiveSession(
            markCompleted: false,
            force: false,
            reason: _FlushReason.throttledProgress,
          ),
        ),
      );
    } else if (_wasPlaying && !playing && !completed) {
      unawaited(
        _scheduleWrite(
          _flushActiveSession(
            markCompleted: false,
            force: true,
            reason: _FlushReason.pauseOrStop,
          ),
        ),
      );
    }

    _wasPlaying = playing;
  }

  void _beginSession(MediaItem item) {
    final existing = _repository.getByTrackId(item.id);
    final resumePosition = existing == null || existing.completed
        ? Duration.zero
        : existing.lastPosition;
    _session = _ListeningSession(
      item: item,
      hadExistingRecord: existing != null,
      replayingCompleted: existing?.completed ?? false,
      maxPosition: resumePosition,
      lastTickPosition: resumePosition,
      baselinePosition: resumePosition,
    );
    _completionHandled = false;
    _wasPlaying = false;
  }

  void _accumulateListening(_ListeningSession session, Duration position) {
    final last = session.lastTickPosition;
    if (last != null) {
      final delta = position - last;
      if (delta > Duration.zero &&
          delta <=
              MusicListeningPolicy.persistInterval +
                  const Duration(seconds: 1)) {
        session.accumulatedListening += delta;
      }
    }
    session.lastTickPosition = position;
    if (position > session.maxPosition) {
      session.maxPosition = position;
    }
  }

  Future<void> _flushActiveSession({
    required bool markCompleted,
    required bool force,
    required _FlushReason reason,
  }) async {
    if (_disposed) return;
    final session = _session;
    if (session == null) return;

    if (!markCompleted && reason == _FlushReason.trackChange) {
      await _persistSession(
        session: session,
        markCompleted: false,
        force: true,
      );
      _session = null;
      return;
    }

    if (reason == _FlushReason.naturalCompletion) {
      await _persistSession(
        session: session,
        markCompleted: true,
        force: true,
      );
      _session = null;
      return;
    }

    if (reason == _FlushReason.queueCleared ||
        reason == _FlushReason.nonAudioSession) {
      await _persistSession(
        session: session,
        markCompleted: false,
        force: true,
      );
      _session = null;
      return;
    }

    await _persistSession(
      session: session,
      markCompleted: markCompleted,
      force: force,
    );

    if (reason == _FlushReason.trackChange ||
        reason == _FlushReason.queueCleared ||
        reason == _FlushReason.nonAudioSession) {
      _session = null;
    }
  }

  Future<void> _persistSession({
    required _ListeningSession session,
    required bool markCompleted,
    required bool force,
  }) async {
    if (_disposed) return;

    if (_playback.position > session.maxPosition) {
      session.maxPosition = _playback.position;
    }

    final thresholdMet =
        session.accumulatedListening >= MusicListeningPolicy.minListenThreshold;
    final meaningfulProgress = session.accumulatedListening > Duration.zero;
    final positionAdvanced = session.maxPosition > session.baselinePosition;
    final canPersist = markCompleted ||
        thresholdMet ||
        (session.hadExistingRecord &&
            (meaningfulProgress || force || positionAdvanced));
    if (!canPersist) return;

    if (!force && session.lastPersistAt != null) {
      final elapsed = _now().difference(session.lastPersistAt!);
      if (elapsed < MusicListeningPolicy.persistInterval) {
        return;
      }
    }

    final record = _recordFromSession(
      session: session,
      markCompleted: markCompleted,
    );
    final result = await _repository.upsert(record);
    if (!result.success) {
      _lastPersistenceWarning = result.errorMessage;
      notifyListeners();
      return;
    }

    session.hadExistingRecord = true;
    session.lastPersistAt = _now();
    if (markCompleted) {
      session.replayingCompleted = false;
    } else if (session.replayingCompleted && thresholdMet) {
      session.replayingCompleted = false;
    }
    _lastPersistenceWarning = null;
    notifyListeners();
  }

  MusicListeningRecord _recordFromSession({
    required _ListeningSession session,
    required bool markCompleted,
  }) {
    final item = session.item;
    final duration =
        _playback.duration > Duration.zero ? _playback.duration : null;
    final position = markCompleted ? Duration.zero : session.maxPosition;

    var completed = markCompleted;
    DateTime? completedAt;
    if (!markCompleted && session.replayingCompleted) {
      final thresholdMet = session.accumulatedListening >=
          MusicListeningPolicy.minListenThreshold;
      if (!thresholdMet) {
        completed = true;
        completedAt = _repository.getByTrackId(item.id)?.completedAt;
      }
    }

    return MusicListeningRecord(
      trackId: item.id,
      title: item.title,
      artist: item.artist ?? MusicConstants.unknownArtist,
      album: item.album ?? MusicConstants.unknownAlbum,
      duration: duration,
      lastPosition: position,
      completed: completed,
      completedAt: completed ? (completedAt ?? _now().toUtc()) : null,
      lastPlayedAt: _now().toUtc(),
    ).normalized();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _playback.removeListener(_onPlaybackChanged);
    _queue.removeListener(_onQueueChanged);
    _session = null;
    super.dispose();
  }

  @visibleForTesting
  Duration accumulatedListeningForTest(String trackId) {
    if (_session?.trackId != trackId) return Duration.zero;
    return _session!.accumulatedListening;
  }

  @visibleForTesting
  void handlePlaybackTickForTest() => _onPlaybackChanged();
}

enum _FlushReason {
  throttledProgress,
  pauseOrStop,
  trackChange,
  naturalCompletion,
  queueCleared,
  nonAudioSession,
  lifecycle,
}

class _ListeningSession {
  _ListeningSession({
    required this.item,
    required this.hadExistingRecord,
    required this.replayingCompleted,
    required this.baselinePosition,
    this.maxPosition = Duration.zero,
    this.lastTickPosition,
  });

  final MediaItem item;
  String get trackId => item.id;

  bool hadExistingRecord;
  bool replayingCompleted;
  final Duration baselinePosition;
  Duration accumulatedListening = Duration.zero;
  Duration maxPosition = Duration.zero;
  Duration? lastTickPosition;
  DateTime? lastPersistAt;
}
