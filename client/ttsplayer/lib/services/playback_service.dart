import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/catalog.dart';
import '../models/media_item.dart';
import 'playback_platform.dart';

// ---------------------------------------------------------------------------
// Playback preflight — two questions before every play attempt:
//   1. Is the file there?
//   2. Can this platform initialise a player for it?
// ---------------------------------------------------------------------------

class PlaybackFilePresence {
  final String path;
  final bool isLocal;

  /// Null when [isLocal] is false (remote URL — presence not checked locally).
  final bool? exists;
  final int? lengthBytes;
  final String? error;

  const PlaybackFilePresence({
    required this.path,
    required this.isLocal,
    this.exists,
    this.lengthBytes,
    this.error,
  });

  bool get isPresent => exists == true;
}

Future<PlaybackFilePresence> checkFilePresence(String filePath) async {
  final isRemote = filePath.startsWith('http://') ||
      filePath.startsWith('https://');

  if (isRemote) {
    return PlaybackFilePresence(path: filePath, isLocal: false);
  }

  try {
    final file = filePath.startsWith('file://')
        ? File.fromUri(Uri.parse(filePath))
        : File(filePath);
    final exists = await file.exists();
    if (!exists) {
      return PlaybackFilePresence(
        path: filePath,
        isLocal: true,
        exists: false,
      );
    }
    final length = await file.length();
    return PlaybackFilePresence(
      path: filePath,
      isLocal: true,
      exists: true,
      lengthBytes: length,
    );
  } catch (e) {
    return PlaybackFilePresence(
      path: filePath,
      isLocal: true,
      exists: null,
      error: e.toString(),
    );
  }
}

String initProbeQuestionLabel() {
  if (useMediaKitPlayback) {
    return 'Can Windows initialise a MediaKit Player for it?';
  }
  if (kIsWeb) {
    return 'Can the browser initialise a VideoPlayerController for it?';
  }
  return 'Can ${defaultTargetPlatform.name} initialise a '
      'VideoPlayerController for it?';
}

// ---------------------------------------------------------------------------
// ResumeInfo — result of a saved-position lookup, with offer logic
// ---------------------------------------------------------------------------

class ResumeInfo {
  final Duration savedPosition;

  /// Total duration from the previous playback session.
  /// Null if the item has never been played to the point where duration
  /// was captured (i.e. first-ever play that didn't complete).
  final Duration? totalDuration;

  const ResumeInfo({required this.savedPosition, this.totalDuration});

  /// Minimum saved position for resume to be offered to the user.
  static const minResumePosition = Duration(seconds: 30);

  /// Do not offer resume when this little time remains — the user has
  /// effectively finished the item.
  static const nearEndWindow = Duration(minutes: 2);

  /// True when the resume option should be presented on the detail screen.
  bool get shouldOffer {
    if (savedPosition < minResumePosition) return false;
    if (totalDuration != null) {
      final remaining = totalDuration! - savedPosition;
      if (remaining < nearEndWindow) return false;
    }
    return true;
  }

  String get formattedPosition {
    final h = savedPosition.inHours;
    final m = savedPosition.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = savedPosition.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// ContinueWatchingEntry — resume row for the dashboard
// ---------------------------------------------------------------------------

class ContinueWatchingEntry {
  final MediaItem item;
  final ResumeInfo resume;

  const ContinueWatchingEntry({required this.item, required this.resume});

  /// Progress fraction 0.0–1.0 when duration is known.
  double? get progressFraction {
    final total = resume.totalDuration;
    if (total == null || total.inSeconds <= 0) return null;
    return resume.savedPosition.inSeconds / total.inSeconds;
  }
}

// ---------------------------------------------------------------------------
// PlaybackService
// ---------------------------------------------------------------------------

class PlaybackService extends ChangeNotifier {
  VideoPlayerController? _videoController;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  List<StreamSubscription<dynamic>> _mediaKitSubs = [];

  MediaItem? _currentItem;
  bool _isInitializing = false;
  String? _errorMessage;

  // Throttle position writes to once every 5 s while playing.
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);
  static const _saveInterval = Duration(seconds: 5);

  // Guard against calling _clearPosition() on every completed tick.
  bool _completionCleared = false;

  /// Incremented whenever persisted resume data changes (save, clear, flush).
  int _resumeDataVersion = 0;

  /// Bumps when [SharedPreferences] resume keys change — dashboard listens for this.
  int get resumeDataVersion => _resumeDataVersion;

  static const _posKeyPrefix = 'position_';
  static const _durKeyPrefix = 'duration_';
  static const _initTimeout = Duration(seconds: 15);

  /// Primary message when open/initialise fails or times out.
  static const playbackFailedMessage =
      'This video could not be opened. It may be unsupported or unavailable.';

  /// Shown beneath playback errors in the player UI.
  static const playbackFailedNote =
      'Some formats, codecs, or large NAS files may not be supported '
      'by the current playback engine.';

  /// Incremented on [stop] to cancel in-flight [play] calls.
  int _playGeneration = 0;

  // Tracks controller flags so state transitions are logged once per change.
  bool? _lastLoggedPlaying;
  bool? _lastLoggedBuffering;

  /// True when the active session uses media_kit (Windows MVP).
  bool get usesMediaKit => useMediaKitPlayback && _mediaKitPlayer != null;

  /// video_player backend — null on Windows when media_kit is active.
  VideoPlayerController? get controller => _videoController;

  /// media_kit video output — null when video_player backend is active.
  VideoController? get mediaKitVideoController => _mediaKitVideoController;

  MediaItem? get currentItem => _currentItem;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;

  bool get isReady => usesMediaKit
      ? _mediaKitPlayer != null && _mediaKitVideoController != null
      : (_videoController?.value.isInitialized ?? false);

  Duration get position => usesMediaKit
      ? _mediaKitPlayer!.state.position
      : (_videoController?.value.position ?? Duration.zero);

  Duration get duration => usesMediaKit
      ? _mediaKitPlayer!.state.duration
      : (_videoController?.value.duration ?? Duration.zero);

  bool get isPlaying => usesMediaKit
      ? _mediaKitPlayer!.state.playing
      : (_videoController?.value.isPlaying ?? false);

  bool get isBuffering => usesMediaKit
      ? _mediaKitPlayer!.state.buffering
      : (_videoController?.value.isBuffering ?? false);

  bool get isCompleted => usesMediaKit
      ? _mediaKitPlayer!.state.completed
      : (_videoController?.value.isCompleted ?? false);

  double get aspectRatio {
    if (usesMediaKit) {
      final w = _mediaKitPlayer!.state.width ?? 0;
      final h = _mediaKitPlayer!.state.height ?? 0;
      if (w > 0 && h > 0) return w / h;
      return 16 / 9;
    }
    final ar = _videoController?.value.aspectRatio ?? 0;
    return ar > 0 ? ar : 16 / 9;
  }

  // ---------------------------------------------------------------------------
  // Resume info — queried by the detail screen before opening the player
  // ---------------------------------------------------------------------------

  Future<ResumeInfo?> resumeInfoFor(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final posSeconds = prefs.getInt('$_posKeyPrefix$itemId') ?? 0;
    if (posSeconds == 0) return null;

    final durSeconds = prefs.getInt('$_durKeyPrefix$itemId');
    return ResumeInfo(
      savedPosition: Duration(seconds: posSeconds),
      totalDuration:
          durSeconds != null ? Duration(seconds: durSeconds) : null,
    );
  }

  /// All in-progress items eligible for Continue Watching on the dashboard.
  Future<List<ContinueWatchingEntry>> getContinueWatching(Catalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <ContinueWatchingEntry>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_posKeyPrefix)) continue;
      final itemId = key.substring(_posKeyPrefix.length);
      final resume = await resumeInfoFor(itemId);
      if (resume == null || !resume.shouldOffer) continue;

      final item = catalog.findItemById(itemId);
      if (item == null || !item.status.isPlayable) continue;

      entries.add(ContinueWatchingEntry(item: item, resume: resume));
    }

    entries.sort(
      (a, b) => b.resume.savedPosition.compareTo(a.resume.savedPosition),
    );
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Playback control
  // ---------------------------------------------------------------------------

  Future<void> play(MediaItem item, {Duration? startPosition}) async {
    if (!item.status.isPlayable) {
      _errorMessage = _statusMessage(item);
      _logState('Error: item not playable (${item.status.name})');
      notifyListeners();
      return;
    }

    final generation = ++_playGeneration;
    await _disposeController();

    _currentItem = item;
    _isInitializing = true;
    _errorMessage = null;
    _completionCleared = false;
    _resetStateTracking();
    notifyListeners();

    try {
      final presence = await checkFilePresence(item.filePath);
      _logFilePresenceAnswer(presence);

      if (presence.isLocal && presence.exists == false) {
        _logInitProbeAnswer(skipped: true, reason: 'file missing');
        _errorMessage =
            'File not found. It may have been moved or deleted since the last scan.';
        return;
      }

      _logState('Creating controller...');
      final controllerType = _controllerTypeLabel();
      _logState('Platform: ${defaultTargetPlatform.name}');
      _logState('Controller type: $controllerType');

      _logState('Initialising...');
      _logInitProbeAnswer(testing: true);
      try {
        if (useMediaKitPlayback) {
          await _initMediaKit(item.filePath, generation);
        } else {
          await _initVideoPlayer(item.filePath, generation);
        }
      } catch (e) {
        _logInitProbeAnswer(success: false, reason: e.toString());
        rethrow;
      }
      _logInitProbeAnswer(success: true);

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      _logState('Initialised');

      final mediaDuration = duration;
      await _saveDuration(item.id, mediaDuration);

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      final Duration seekTo;
      if (startPosition != null) {
        seekTo = startPosition;
      } else {
        final saved = await _savedPosition(item.id);
        final remaining = mediaDuration - saved;
        final eligible = saved >= ResumeInfo.minResumePosition &&
            remaining >= ResumeInfo.nearEndWindow;
        seekTo = eligible ? saved : Duration.zero;
      }

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      if (seekTo > Duration.zero) {
        await seekToPosition(seekTo);
      }

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      await startPlayback();
    } catch (e, stack) {
      if (generation != _playGeneration) return;
      _logState('Error: $e');
      debugPrint('[PlaybackService] play failed: $e\n$stack');
      _errorMessage = _friendlyError(e);
      await _disposeController();
    } finally {
      if (generation == _playGeneration) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry({Duration? startPosition}) async {
    if (_currentItem == null) return;
    await play(_currentItem!, startPosition: startPosition);
  }

  Future<void> togglePlayPause() async {
    if (!isReady) return;
    if (usesMediaKit) {
      if (_mediaKitPlayer!.state.playing) {
        await _mediaKitPlayer!.pause();
        await _flushPosition();
      } else {
        await _mediaKitPlayer!.play();
      }
    } else {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        await _flushPosition();
      } else {
        await _videoController!.play();
      }
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await seekToPosition(position);
    notifyListeners();
  }

  Future<void> stop() async {
    _playGeneration++;
    await _flushPosition();
    await _disposeController();
    _currentItem = null;
    _errorMessage = null;
    _isInitializing = false;
    notifyListeners();
  }

  /// Test helper — persists resume state without starting playback.
  @visibleForTesting
  Future<void> persistResumeStateForTest(
    String itemId,
    Duration position, {
    Duration? duration,
  }) async {
    await _savePosition(itemId, position);
    if (duration != null) {
      await _saveDuration(itemId, duration);
    }
    notifyListeners();
  }

  /// Test helper — clears persisted resume state without playback.
  @visibleForTesting
  Future<void> clearResumeStateForTest(String itemId) async {
    await _clearPosition(itemId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Backend-specific init / control
  // ---------------------------------------------------------------------------

  Future<void> _initMediaKit(String filePath, int generation) async {
    _mediaKitPlayer = Player();
    _mediaKitVideoController = VideoController(_mediaKitPlayer!);
    _attachMediaKitListeners(generation);

    final media = Media(mediaUriForPlayback(filePath));
    await _mediaKitPlayer!.open(media, play: false).timeout(
      _initTimeout,
      onTimeout: () => throw TimeoutException(
        'MediaKit open timed out after ${_initTimeout.inSeconds}s',
      ),
    );

    if (generation != _playGeneration) return;

    if (_mediaKitPlayer!.state.duration <= Duration.zero) {
      await _mediaKitPlayer!.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(
            _initTimeout,
            onTimeout: () => throw TimeoutException(
              'MediaKit duration probe timed out after '
              '${_initTimeout.inSeconds}s',
            ),
          );
    }
  }

  Future<void> _initVideoPlayer(String filePath, int generation) async {
    _videoController = _buildVideoPlayerController(filePath);
    await _videoController!.initialize().timeout(
      _initTimeout,
      onTimeout: () => throw TimeoutException(
        'Video initialization timed out after ${_initTimeout.inSeconds}s',
      ),
    );
    if (generation != _playGeneration) return;
    _videoController!.addListener(_onVideoPlayerTick);
  }

  Future<void> seekToPosition(Duration position) async {
    if (usesMediaKit) {
      await _mediaKitPlayer!.seek(position);
    } else {
      await _videoController?.seekTo(position);
    }
  }

  Future<void> startPlayback() async {
    if (usesMediaKit) {
      await _mediaKitPlayer!.play();
    } else {
      await _videoController!.play();
    }
  }

  void _attachMediaKitListeners(int generation) {
    final player = _mediaKitPlayer!;

    void onUpdate() {
      if (generation != _playGeneration) return;
      _onPlaybackTick();
    }

    _mediaKitSubs = [
      player.stream.playing.listen((_) => onUpdate()),
      player.stream.buffering.listen((_) => onUpdate()),
      player.stream.position.listen((_) => onUpdate()),
      player.stream.duration.listen((_) => onUpdate()),
      player.stream.completed.listen((_) => onUpdate()),
      player.stream.width.listen((_) => onUpdate()),
      player.stream.height.listen((_) => onUpdate()),
    ];
  }

  // ---------------------------------------------------------------------------
  // Position persistence
  // ---------------------------------------------------------------------------

  Future<void> _savePosition(String itemId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_posKeyPrefix$itemId', position.inSeconds);
    _markResumeDataChanged();
    notifyListeners();
  }

  Future<void> _saveDuration(String itemId, Duration duration) async {
    if (duration == Duration.zero) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_durKeyPrefix$itemId', duration.inSeconds);
  }

  Future<Duration> _savedPosition(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('$_posKeyPrefix$itemId') ?? 0;
    return Duration(seconds: seconds);
  }

  Future<void> _clearPosition(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_posKeyPrefix$itemId');
    _markResumeDataChanged();
    notifyListeners();
  }

  void _markResumeDataChanged() {
    _resumeDataVersion++;
  }

  Future<void> _flushPosition() async {
    if (_currentItem == null || !isReady) return;
    final pos = position;
    if (pos > Duration.zero) {
      await _savePosition(_currentItem!.id, pos);
      _lastPositionSave = DateTime.now();
    }
  }

  static VideoPlayerController _buildVideoPlayerController(String filePath) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(filePath));
    }
    if (filePath.startsWith('file://')) {
      return VideoPlayerController.file(File.fromUri(Uri.parse(filePath)));
    }
    return VideoPlayerController.file(File(filePath));
  }

  // ---------------------------------------------------------------------------
  // Tick listeners — shared resume / logging behaviour
  // ---------------------------------------------------------------------------

  void _onVideoPlayerTick() {
    _onPlaybackTick();
  }

  void _onPlaybackTick() {
    if (!isReady) return;

    _logControllerStateTransitions();

    if (isCompleted && _currentItem != null && !_completionCleared) {
      _completionCleared = true;
      unawaited(_clearPosition(_currentItem!.id));
    }

    final pos = position;
    if (isPlaying && pos > Duration.zero && _currentItem != null) {
      final now = DateTime.now();
      if (now.difference(_lastPositionSave) >= _saveInterval) {
        _lastPositionSave = now;
        unawaited(_savePosition(_currentItem!.id, pos));
      }
    }

    notifyListeners();
  }

  Future<void> _disposeController() async {
    for (final sub in _mediaKitSubs) {
      await sub.cancel();
    }
    _mediaKitSubs = [];

    final mediaKitPlayer = _mediaKitPlayer;
    _mediaKitPlayer = null;
    _mediaKitVideoController = null;

    final videoController = _videoController;
    _videoController = null;

    if (mediaKitPlayer == null && videoController == null) return;

    _resetStateTracking();
    _logState('Dispose');

    videoController?.removeListener(_onVideoPlayerTick);
    try {
      await videoController?.dispose();
    } catch (e, stack) {
      debugPrint('[PlaybackService] video_player dispose failed: $e\n$stack');
    }

    try {
      await mediaKitPlayer?.dispose();
    } catch (e, stack) {
      debugPrint('[PlaybackService] media_kit dispose failed: $e\n$stack');
    }
  }

  // ---------------------------------------------------------------------------
  // Playback diagnostics logging
  // ---------------------------------------------------------------------------

  void _logState(String message) {
    debugPrint('[PlaybackService] $message');
  }

  void _resetStateTracking() {
    _lastLoggedPlaying = null;
    _lastLoggedBuffering = null;
  }

  void _logControllerStateTransitions() {
    if (isBuffering) {
      if (_lastLoggedBuffering != true) {
        _logState('Buffering');
        _lastLoggedBuffering = true;
      }
    } else {
      _lastLoggedBuffering = false;
    }

    if (isPlaying) {
      if (_lastLoggedPlaying != true) {
        _logState('Playing');
        _lastLoggedPlaying = true;
      }
    } else {
      _lastLoggedPlaying = false;
    }
  }

  static String _controllerTypeLabel() {
    if (useMediaKitPlayback) return 'media_kit.Player';
    return 'VideoPlayerController';
  }

  void _logFilePresenceAnswer(PlaybackFilePresence presence) {
    if (!presence.isLocal) {
      _logState('Is the file there? skipped (remote URL — ${presence.path})');
      return;
    }

    if (presence.error != null) {
      _logState(
        'Is the file there? unknown (check error: ${presence.error})',
      );
      _logState('Path: ${presence.path}');
      return;
    }

    if (presence.exists == true) {
      _logState(
        'Is the file there? yes (${presence.lengthBytes} bytes)',
      );
      _logState('Path: ${presence.path}');
      return;
    }

    _logState('Is the file there? no');
    _logState('Path: ${presence.path}');
  }

  void _logInitProbeAnswer({
    bool testing = false,
    bool skipped = false,
    bool? success,
    String? reason,
  }) {
    final question = initProbeQuestionLabel();
    if (testing) {
      _logState('$question → testing...');
      return;
    }
    if (skipped) {
      _logState('$question → skipped ($reason)');
      return;
    }
    if (success == true) {
      _logState('$question → yes');
      return;
    }
    _logState('$question → no${reason != null ? ' ($reason)' : ''}');
  }

  static String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return playbackFailedMessage;
    }

    final raw = e.toString();
    if (raw.contains('No such file') || raw.contains('FileNotFound')) {
      return 'File not found. It may have been moved or deleted since the last scan.';
    }
    if (raw.contains('Permission') || raw.contains('Access')) {
      return 'Access denied. Check that the NAS share is mounted and accessible.';
    }
    if (raw.contains('NetworkError') || raw.contains('SocketException')) {
      return 'Network error. Check your connection to the NAS.';
    }
    if (raw.contains('format') ||
        raw.contains('codec') ||
        raw.contains('PlatformException') ||
        raw.contains('UnimplementedError')) {
      return playbackFailedMessage;
    }
    return playbackFailedMessage;
  }

  static String _statusMessage(MediaItem item) {
    return switch (item.status) {
      MediaItemStatus.missing =>
        'This file is no longer found on the NAS. Rescan to update the catalogue.',
      MediaItemStatus.unavailable =>
        'This file could not be read during the last scan.',
      MediaItemStatus.restricted => 'Access to this file is restricted.',
      MediaItemStatus.unsupported => 'This file type is not supported.',
      MediaItemStatus.skipped => 'This file was skipped during indexing.',
      _ => 'This item cannot be played.',
    };
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
