import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/catalog.dart';
import '../models/media_item.dart';
import '../models/playback/playback_action_result.dart';
import '../models/playback/playback_audio_track.dart';
import '../models/playback/playback_error_kind.dart';
import '../models/playback/playback_rate_presets.dart';
import '../models/playback/playback_session_mode.dart';
import '../models/playback/playback_subtitle_track.dart';
import 'media_access/media_location_resolver.dart';
import 'media_access/media_provider_config.dart';
import 'media_access/resolved_media_location.dart';
import 'playback/playback_error_mapper.dart';
import 'playback/playback_error_messages.dart';
import 'playback/playback_session_controls.dart';
import 'playback/media_kit_session_controls.dart';
import 'playback/unsupported_session_controls.dart';
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

Future<PlaybackFilePresence> checkFilePresence(String pathOrUri) async {
  final isRemote = pathOrUri.startsWith('http://') ||
      pathOrUri.startsWith('https://');

  if (isRemote) {
    return PlaybackFilePresence(path: pathOrUri, isLocal: false);
  }

  try {
    final file = pathOrUri.startsWith('file://')
        ? File.fromUri(Uri.parse(pathOrUri))
        : File(pathOrUri);
    final exists = await file.exists();
    if (!exists) {
      return PlaybackFilePresence(
        path: pathOrUri,
        isLocal: true,
        exists: false,
      );
    }
    final length = await file.length();
    return PlaybackFilePresence(
      path: pathOrUri,
      isLocal: true,
      exists: true,
      lengthBytes: length,
    );
  } catch (e) {
    return PlaybackFilePresence(
      path: pathOrUri,
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

typedef DefaultPlaybackRateProvider = double Function();

typedef MediaKitInitOverride = Future<void> Function(
  PlaybackService service,
  String mediaUri,
  int generation,
);

double _fallbackDefaultPlaybackRate() => PlaybackRatePresets.defaultRate;

class PlaybackService extends ChangeNotifier {
  PlaybackService({
    MediaLocationResolver? mediaLocationResolver,
    DefaultPlaybackRateProvider? defaultPlaybackRateProvider,
    @visibleForTesting MediaKitInitOverride? mediaKitInitOverride,
    @visibleForTesting PlaybackSessionControls? initialSessionControls,
  })  : _mediaLocationResolver =
            mediaLocationResolver ?? _defaultMediaLocationResolver(),
        _defaultPlaybackRateProvider =
            defaultPlaybackRateProvider ?? _fallbackDefaultPlaybackRate,
        _mediaKitInitOverride = mediaKitInitOverride,
        _sessionControls = initialSessionControls;

  final MediaLocationResolver _mediaLocationResolver;
  final DefaultPlaybackRateProvider _defaultPlaybackRateProvider;
  final MediaKitInitOverride? _mediaKitInitOverride;

  PlaybackSessionControls? _sessionControls;

  static MediaLocationResolver _defaultMediaLocationResolver() {
    return MediaLocationResolver(
      config: MediaProviderConfig.defaults().mediaAccess,
      isWindowsDesktop: !kIsWeb && Platform.isWindows,
    );
  }

  /// Resolves catalogue paths at the playback boundary (tests / diagnostics).
  @visibleForTesting
  ResolvedMediaLocation resolveCataloguePath(String filePath) {
    return _mediaLocationResolver.resolve(filePath);
  }

  VideoPlayerController? _videoController;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  List<StreamSubscription<dynamic>> _mediaKitSubs = [];

  MediaItem? _currentItem;
  bool _isInitializing = false;
  String? _errorMessage;
  PlaybackErrorKind? _playbackErrorKind;

  double _playbackRate = PlaybackRatePresets.defaultRate;
  bool _hasSessionRateOverride = false;
  List<PlaybackAudioTrack> _availableAudioTracks = const [];
  List<PlaybackSubtitleTrack> _availableSubtitleTracks = const [];
  String? _selectedAudioTrackId;
  String? _selectedSubtitleTrackId;

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
      'This media could not be opened. It may be unsupported or unavailable.';

  /// Shown beneath playback errors in the player UI.
  static const playbackFailedNote = PlaybackErrorMessages.playbackFailedNote;

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

  /// Active session presentation mode derived from [currentItem] media kind.
  PlaybackSessionMode get sessionMode {
    final item = _currentItem;
    if (item == null) return PlaybackSessionMode.video;
    return playbackSessionModeFor(item);
  }

  /// Whether the UI must attach a video surface for the current session.
  bool get requiresVideoSurface => sessionMode == PlaybackSessionMode.video;

  bool get isAudioSession => sessionMode == PlaybackSessionMode.audio;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  PlaybackErrorKind? get playbackErrorKind => _playbackErrorKind;

  double get playbackRate => _playbackRate;

  List<double> get supportedPlaybackRates => PlaybackRatePresets.supported;

  bool get canChangePlaybackRate =>
      isReady && (_sessionControls?.supportsPlaybackRate ?? false);

  bool get canSelectAudioTracks =>
      isReady &&
      (_sessionControls?.supportsTrackSelection ?? false) &&
      _availableAudioTracks.length >= 2;

  bool get canSelectSubtitleTracks =>
      isReady &&
      (_sessionControls?.supportsTrackSelection ?? false) &&
      _availableSubtitleTracks.isNotEmpty;

  List<PlaybackAudioTrack> get availableAudioTracks =>
      List.unmodifiable(_availableAudioTracks);

  List<PlaybackSubtitleTrack> get availableSubtitleTracks =>
      List.unmodifiable(_availableSubtitleTracks);

  String? get selectedAudioTrackId => _selectedAudioTrackId;

  /// Null when subtitles are off.
  String? get selectedSubtitleTrackId => _selectedSubtitleTrackId;

  @visibleForTesting
  void attachSessionControlsForTest(PlaybackSessionControls controls) {
    _sessionControls = controls;
    _syncCapabilityStateFromControls();
    notifyListeners();
  }

  @visibleForTesting
  PlaybackSessionControls? get sessionControls => _sessionControls;

  @visibleForTesting
  bool get hasSessionRateOverride => _hasSessionRateOverride;

  bool _forceReadyForTest = false;
  bool _forcePlayingForTest = false;
  Duration? _forcedDurationForTest;
  Duration? _forcedPositionForTest;
  bool _forcedCompletedForTest = false;
  bool _forcedBufferingForTest = false;

  bool get isReady =>
      _forceReadyForTest ||
      (usesMediaKit
          ? _mediaKitPlayer != null &&
              (isAudioSession || _mediaKitVideoController != null)
          : (_videoController?.value.isInitialized ?? false));

  Duration get duration => _forcedDurationForTest ??
      (usesMediaKit
          ? _mediaKitPlayer!.state.duration
          : (_videoController?.value.duration ?? Duration.zero));

  Duration get position => _forcedPositionForTest ??
      (usesMediaKit
          ? _mediaKitPlayer!.state.position
          : (_videoController?.value.position ?? Duration.zero));

  bool get isPlaying => _forceReadyForTest
      ? _forcePlayingForTest
      : (usesMediaKit
          ? _mediaKitPlayer!.state.playing
          : (_videoController?.value.isPlaying ?? false));

  bool get isBuffering => _forceReadyForTest
      ? _forcedBufferingForTest
      : (usesMediaKit
          ? _mediaKitPlayer!.state.buffering
          : (_videoController?.value.isBuffering ?? false));

  bool get isCompleted =>
      (_forceReadyForTest && _forcedCompletedForTest) ||
      (usesMediaKit
          ? _mediaKitPlayer!.state.completed
          : (_videoController?.value.isCompleted ?? false));

  double get aspectRatio {
    if (isAudioSession) return 1.0;
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
      if (!item.isContinueWatchingEligible) continue;

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
    _clearPlaybackError();
    _resetCapabilityState();
    _completionCleared = false;
    _resetStateTracking();
    notifyListeners();

    try {
      final location = _mediaLocationResolver.resolve(item.filePath);
      if (!location.isPlayable || location.uri == null) {
        _setPlaybackError(PlaybackErrorMapper.fromResolver(location));
        _logState('Error: media location unresolved (${location.status.name})');
        return;
      }

      final mediaUri = location.uri!;
      final presence = await checkFilePresence(mediaUri);
      _logFilePresenceAnswer(presence);

      if (presence.isLocal && presence.exists == false) {
        _logInitProbeAnswer(skipped: true, reason: 'file missing');
        _setPlaybackError(PlaybackErrorMapper.fileMissing());
        return;
      }

      _logState('Creating controller...');
      final controllerType = _controllerTypeLabel();
      _logState('Platform: ${defaultTargetPlatform.name}');
      _logState('Controller type: $controllerType');
      _logState('Session mode: ${sessionMode.name}');

      _logState('Initialising...');
      _logInitProbeAnswer(testing: true);
      try {
        if (useMediaKitPlayback) {
          await _initMediaKit(mediaUri, generation);
        } else {
          await _initVideoPlayer(mediaUri, generation);
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

      await _applyDefaultPlaybackRate();

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      final mediaDuration = duration;
      if (item.isContinueWatchingEligible) {
        await _saveDuration(item.id, mediaDuration);
      }

      if (generation != _playGeneration) {
        await _disposeController();
        return;
      }

      final Duration seekTo;
      if (startPosition != null) {
        seekTo = startPosition;
      } else if (!item.isContinueWatchingEligible) {
        seekTo = Duration.zero;
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
      _setPlaybackError(PlaybackErrorMapper.fromException(e));
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
    _clearPlaybackError();
    notifyListeners();
    await play(_currentItem!, startPosition: startPosition);
  }

  Future<void> togglePlayPause() async {
    if (!isReady) return;
    if (_forceReadyForTest) {
      _forcePlayingForTest = !_forcePlayingForTest;
      notifyListeners();
      return;
    }
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
    _clearPlaybackError();
    _resetCapabilityState();
    _isInitializing = false;
    clearReadySimulationForTest();
    notifyListeners();
  }

  Future<PlaybackActionResult> setPlaybackRate(double rate) async {
    if (!isReady || _sessionControls == null) {
      return const PlaybackActionResult.invalidArgument('Playback not ready');
    }
    if (!PlaybackRatePresets.isSupported(rate)) {
      return const PlaybackActionResult.invalidArgument('Unsupported playback rate');
    }
    if (!_sessionControls!.supportsPlaybackRate) {
      return const PlaybackActionResult.unsupported('Playback rate not supported');
    }

    final result = await _sessionControls!.setPlaybackRate(rate);
    if (result.isSuccess) {
      _playbackRate = _readPlaybackRateFromControls(fallback: rate);
      _hasSessionRateOverride = true;
      notifyListeners();
    }
    return result;
  }

  Future<PlaybackActionResult> selectAudioTrack(String trackId) async {
    if (!isReady || _sessionControls == null) {
      return const PlaybackActionResult.invalidArgument('Playback not ready');
    }
    if (!_sessionControls!.supportsTrackSelection) {
      return const PlaybackActionResult.unsupported('Audio tracks not supported');
    }

    if (_selectedAudioTrackId == trackId) {
      return const PlaybackActionResult.success();
    }

    final result = await _sessionControls!.selectAudioTrack(trackId);
    if (result.isSuccess) {
      _syncCapabilityStateFromControls();
      notifyListeners();
    }
    return result;
  }

  Future<PlaybackActionResult> selectSubtitleTrack(String trackId) async {
    if (!isReady || _sessionControls == null) {
      return const PlaybackActionResult.invalidArgument('Playback not ready');
    }
    if (!_sessionControls!.supportsTrackSelection) {
      return const PlaybackActionResult.unsupported('Subtitles not supported');
    }

    if (_selectedSubtitleTrackId == trackId) {
      return const PlaybackActionResult.success();
    }

    final result = await _sessionControls!.selectSubtitleTrack(trackId);
    if (result.isSuccess) {
      _syncCapabilityStateFromControls();
      notifyListeners();
    }
    return result;
  }

  Future<PlaybackActionResult> disableSubtitles() async {
    if (!isReady || _sessionControls == null) {
      return const PlaybackActionResult.invalidArgument('Playback not ready');
    }
    if (!_sessionControls!.supportsTrackSelection) {
      return const PlaybackActionResult.unsupported('Subtitles not supported');
    }

    if (_selectedSubtitleTrackId == null) {
      return const PlaybackActionResult.success();
    }

    final result = await _sessionControls!.disableSubtitles();
    if (result.isSuccess) {
      _syncCapabilityStateFromControls();
      notifyListeners();
    }
    return result;
  }

  @visibleForTesting
  void simulateReadyForTest(MediaItem item) {
    _currentItem = item;
    _isInitializing = false;
    _forceReadyForTest = true;
    _forcePlayingForTest = true;
    if (_sessionControls != null) {
      _syncCapabilityStateFromControls();
    }
    notifyListeners();
  }

  @visibleForTesting
  void simulatePreparingForTest() {
    _isInitializing = true;
    _forceReadyForTest = false;
    _forcePlayingForTest = false;
    notifyListeners();
  }

  @visibleForTesting
  void simulatePlayingForTest({required bool playing, bool buffering = false}) {
    _forcePlayingForTest = playing;
    _forcedBufferingForTest = buffering;
    notifyListeners();
  }

  @visibleForTesting
  void simulatePlaybackMetricsForTest({
    Duration? duration,
    Duration? position,
    bool completed = false,
  }) {
    _forcedDurationForTest = duration;
    _forcedPositionForTest = position;
    _forcedCompletedForTest = completed;
  }

  @visibleForTesting
  void runPlaybackTickForTest() => _onPlaybackTick();

  @visibleForTesting
  void clearReadySimulationForTest() {
    _forceReadyForTest = false;
    _forcePlayingForTest = false;
    _forcedBufferingForTest = false;
    _forcedDurationForTest = null;
    _forcedPositionForTest = null;
    _forcedCompletedForTest = false;
  }

  @visibleForTesting
  void setPlaybackErrorForTest(PlaybackErrorKind kind, String message) {
    _playbackErrorKind = kind;
    _errorMessage = message;
    notifyListeners();
  }

  /// Test helper — persists resume state without starting playback.
  @visibleForTesting
  Future<void> persistResumeStateForTest(
    String itemId,
    Duration position, {
    Duration? duration,
    MediaItem? item,
  }) async {
    final eligible = item?.isContinueWatchingEligible ?? true;
    if (!eligible) return;
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

  Future<void> _initMediaKit(String mediaUri, int generation) async {
    if (_mediaKitInitOverride != null) {
      await _mediaKitInitOverride(this, mediaUri, generation);
      if (generation != _playGeneration) return;
      if (_sessionControls == null && _mediaKitPlayer != null) {
        _bindMediaKitSessionControls();
      }
      _syncCapabilityStateFromControls();
      return;
    }

    _mediaKitPlayer = Player();
    if (requiresVideoSurface) {
      _mediaKitVideoController = VideoController(_mediaKitPlayer!);
    } else {
      _mediaKitVideoController = null;
    }
    _bindMediaKitSessionControls();
    _attachMediaKitListeners(generation);

    final media = Media(mediaUriForPlayback(mediaUri));
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

    _syncCapabilityStateFromControls();
  }

  void _bindMediaKitSessionControls() {
    final player = _mediaKitPlayer;
    if (player == null) return;
    _sessionControls = MediaKitSessionControls(player);
  }

  Future<void> _initVideoPlayer(String mediaUri, int generation) async {
    _videoController = _buildVideoPlayerController(mediaUri);
    _sessionControls = const UnsupportedSessionControls();
    _syncCapabilityStateFromControls();
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
    if (_forceReadyForTest) {
      _forcedPositionForTest = position;
      if (position == Duration.zero) {
        _forcedCompletedForTest = false;
      }
      notifyListeners();
      return;
    }
    if (usesMediaKit) {
      await _mediaKitPlayer!.seek(position);
    } else {
      await _videoController?.seekTo(position);
    }
  }

  Future<void> startPlayback() async {
    if (_forceReadyForTest) return;
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
      if (requiresVideoSurface) ...[
        player.stream.width.listen((_) => onUpdate()),
        player.stream.height.listen((_) => onUpdate()),
      ],
      player.stream.tracks.listen((_) {
        if (generation != _playGeneration) return;
        _syncCapabilityStateFromControls();
        notifyListeners();
      }),
      player.stream.rate.listen((rate) {
        if (generation != _playGeneration) return;
        _playbackRate = rate;
        notifyListeners();
      }),
    ];
  }

  // ---------------------------------------------------------------------------
  // Position persistence
  // ---------------------------------------------------------------------------

  Future<void> _savePosition(String itemId, Duration position) async {
    if (_currentItem != null && !_currentItem!.isContinueWatchingEligible) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_posKeyPrefix$itemId', position.inSeconds);
    _markResumeDataChanged();
    notifyListeners();
  }

  Future<void> _saveDuration(String itemId, Duration duration) async {
    if (duration == Duration.zero) return;
    final item = _currentItem;
    if (item != null && item.id == itemId && !item.isContinueWatchingEligible) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_durKeyPrefix$itemId', duration.inSeconds);
  }

  Future<Duration> _savedPosition(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('$_posKeyPrefix$itemId') ?? 0;
    return Duration(seconds: seconds);
  }

  Future<void> _clearPosition(String itemId) async {
    final item = _currentItem;
    if (item != null && item.id == itemId && !item.isContinueWatchingEligible) {
      return;
    }
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

  static VideoPlayerController _buildVideoPlayerController(String mediaUri) {
    if (mediaUri.startsWith('http://') || mediaUri.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(mediaUri));
    }
    if (mediaUri.startsWith('file://')) {
      return VideoPlayerController.file(File.fromUri(Uri.parse(mediaUri)));
    }
    return VideoPlayerController.file(File(mediaUri));
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

    if (isCompleted) return;

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

    await _sessionControls?.dispose();
    _sessionControls = null;
    _resetCapabilityState(clearSessionOverride: true);

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

  void _setPlaybackError(PlaybackErrorMapping mapping) {
    _playbackErrorKind = mapping.kind;
    _errorMessage = mapping.userMessage;
    if (mapping.debugDetail != null) {
      debugPrint('[PlaybackService] ${mapping.kind.name}: ${mapping.debugDetail}');
    }
  }

  void _clearPlaybackError() {
    _playbackErrorKind = null;
    _errorMessage = null;
  }

  void _resetCapabilityState({bool clearSessionOverride = true}) {
    if (clearSessionOverride) {
      _hasSessionRateOverride = false;
    }
    _playbackRate = PlaybackRatePresets.defaultRate;
    _availableAudioTracks = const [];
    _availableSubtitleTracks = const [];
    _selectedAudioTrackId = null;
    _selectedSubtitleTrackId = null;
  }

  double _readPlaybackRateFromControls({required double fallback}) {
    final controls = _sessionControls;
    if (controls == null) return fallback;
    try {
      return controls.readSnapshot().playbackRate;
    } catch (e, stack) {
      debugPrint('[PlaybackService] rate read failed: $e\n$stack');
      return fallback;
    }
  }

  void _syncCapabilityStateFromControls() {
    final controls = _sessionControls;
    if (controls == null) return;
    try {
      final snapshot = controls.readSnapshot();
      _playbackRate = snapshot.playbackRate;
      _availableAudioTracks = snapshot.audioTracks;
      _availableSubtitleTracks = snapshot.subtitleTracks;

      var selectedAudio = snapshot.selectedAudioTrackId;
      if (selectedAudio != null &&
          !_availableAudioTracks.any((track) => track.id == selectedAudio)) {
        debugPrint(
          '[PlaybackService] stale audio track id ignored: $selectedAudio',
        );
        selectedAudio = null;
      }
      _selectedAudioTrackId = selectedAudio;

      var selectedSubtitle = snapshot.selectedSubtitleTrackId;
      if (selectedSubtitle != null &&
          !_availableSubtitleTracks
              .any((track) => track.id == selectedSubtitle)) {
        debugPrint(
          '[PlaybackService] stale subtitle track id ignored: $selectedSubtitle',
        );
        selectedSubtitle = null;
      }
      _selectedSubtitleTrackId = selectedSubtitle;
    } catch (e, stack) {
      debugPrint(
        '[PlaybackService] track/rate sync failed: $e\n$stack',
      );
    }
  }

  Future<void> _applyDefaultPlaybackRate() async {
    final controls = _sessionControls;
    if (controls == null || !controls.supportsPlaybackRate) {
      _playbackRate = PlaybackRatePresets.defaultRate;
      return;
    }

    final target = PlaybackRatePresets.normalize(_defaultPlaybackRateProvider());
    final result = await controls.setPlaybackRate(target);
    if (result.isSuccess) {
      _playbackRate = _readPlaybackRateFromControls(fallback: target);
      _hasSessionRateOverride = false;
    } else {
      _playbackRate = PlaybackRatePresets.defaultRate;
      debugPrint(
        '[PlaybackService] default rate apply failed: ${result.debugDetail}',
      );
    }
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
