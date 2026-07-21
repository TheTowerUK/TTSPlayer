import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../models/playback/playback_queue.dart';
import '../../../services/playback_service.dart';
import '../models/music_album.dart';
import '../models/music_artist.dart';
import '../models/music_queue_source.dart';
import '../music_queue_seeding.dart';

/// App-scoped in-memory music queue coordinating with [PlaybackService].
class MusicPlaybackQueueController extends ChangeNotifier {
  MusicPlaybackQueueController({
    required PlaybackService playbackService,
    Future<void> Function()? pendingListeningWriteDrain,
  })  : _playback = playbackService,
        _pendingListeningWriteDrain = pendingListeningWriteDrain {
    _playback.addListener(_onPlaybackChanged);
  }

  /// Position above which [previous] restarts the current track instead of
  /// moving to the prior queue item.
  static const previousRestartThreshold = Duration(seconds: 4);

  final PlaybackService _playback;
  Future<void> Function()? _pendingListeningWriteDrain;

  /// Optional hook so natural completion can flush listening history before advance.
  set pendingListeningWriteDrain(Future<void> Function()? drain) {
    _pendingListeningWriteDrain = drain;
  }

  PlaybackQueue _queue = const PlaybackQueue.empty();
  MusicQueueSource? _queueSource;
  bool _playerRouteActive = false;
  bool _wasCompleted = false;
  int _completionAdvanceGeneration = 0;
  bool _advanceInFlight = false;

  PlaybackQueue get queue => _queue;

  MediaItem? get currentTrack => _queue.currentItem;

  MusicQueueSource? get queueSource => _queueSource;

  bool get isEmpty => _queue.isEmpty;

  bool get hasNext => _queue.hasNext;

  bool get canGoPrevious =>
      _queue.hasPrevious ||
      (_queue.hasCurrent && _playback.position > previousRestartThreshold);

  bool get playerRouteActive => _playerRouteActive;

  /// Replaces the queue with a single track and resets completion guards.
  void seedSingleTrack(MediaItem track) {
    if (!track.isAudio || !track.status.isPlayable) return;
    _queue = const PlaybackQueue.empty().replaceItems([track], startIndex: 0);
    _queueSource = const MusicQueueSource.singleTrack();
    _resetCompletionGuards();
    notifyListeners();
  }

  /// Replaces the queue with an album's canonical track order.
  ///
  /// Returns false when no playable audio tracks remain.
  bool seedAlbumQueue(
    MusicAlbum album, {
    MediaItem? startTrack,
    int? sourceIndex,
  }) {
    final ordered = MusicQueueSeeding.albumTracks(album);
    if (!MusicQueueSeeding.hasPlayableTracks(ordered)) return false;

    final start = sourceIndex != null
        ? MusicQueueSeeding.playableStartIndex(
            ordered,
            sourceIndex: sourceIndex,
          )
        : startTrack != null
            ? MusicQueueSeeding.playableStartIndexForTrack(ordered, startTrack)
            : 0;

    _queueSource = MusicQueueSource(
      kind: MusicQueueSourceKind.album,
      label: album.displayTitle,
      identityKey: album.groupKey,
    );
    replaceQueue(ordered, startIndex: start);
    return true;
  }

  /// Replaces the queue with an artist's album-ordered track flattening.
  ///
  /// Returns false when no playable audio tracks remain.
  bool seedArtistQueue(
    MusicArtist artist, {
    MediaItem? startTrack,
    int? sourceIndex,
  }) {
    final ordered = MusicQueueSeeding.artistTracks(artist);
    if (!MusicQueueSeeding.hasPlayableTracks(ordered)) return false;

    final start = sourceIndex != null
        ? MusicQueueSeeding.playableStartIndex(
            ordered,
            sourceIndex: sourceIndex,
          )
        : startTrack != null
            ? MusicQueueSeeding.playableStartIndexForTrack(ordered, startTrack)
            : 0;

    _queueSource = MusicQueueSource(
      kind: MusicQueueSourceKind.artist,
      label: artist.displayName,
      identityKey: artist.groupKey,
    );
    replaceQueue(ordered, startIndex: start);
    return true;
  }

  /// Replaces the entire queue.
  void replaceQueue(List<MediaItem> items, {int startIndex = 0}) {
    _queue =
        const PlaybackQueue.empty().replaceItems(items, startIndex: startIndex);
    _resetCompletionGuards();
    notifyListeners();
  }

  void onPlayerRouteOpened() {
    _playerRouteActive = true;
  }

  /// Stops playback and clears queue when the dedicated player route closes.
  Future<void> onPlayerRouteClosed() async {
    _playerRouteActive = false;
    await clearQueueAndStop();
  }

  Future<void> playCurrent({Duration? startPosition}) async {
    final item = _queue.currentItem;
    if (item == null) return;
    _resetCompletionGuards();
    await _playback.play(item, startPosition: startPosition);
  }

  Future<void> retryCurrent({Duration? startPosition}) async {
    await playCurrent(startPosition: startPosition);
  }

  Future<void> next() async {
    if (!_queue.hasNext) return;
    _queue = _queue.advanceToNext();
    _resetCompletionGuards();
    notifyListeners();
    await playCurrent();
  }

  Future<void> previous() async {
    if (!_queue.hasCurrent) return;

    if (_playback.position > previousRestartThreshold) {
      await _playback.seekTo(Duration.zero);
      if (!_playback.isPlaying && _playback.isReady && !_playback.isCompleted) {
        await _playback.togglePlayPause();
      }
      notifyListeners();
      return;
    }

    if (_queue.hasPrevious) {
      _queue = _queue.retreatToPrevious();
      _resetCompletionGuards();
      notifyListeners();
      await playCurrent();
      return;
    }

    await _playback.seekTo(Duration.zero);
    notifyListeners();
  }

  Future<void> replayCurrent() async {
    _resetCompletionGuards();
    await _playback.seekTo(Duration.zero);
    if (_playback.isReady) {
      if (_playback.isCompleted || !_playback.isPlaying) {
        await _playback.togglePlayPause();
      }
    }
    notifyListeners();
  }

  Future<void> clearQueueAndStop() async {
    _queue = const PlaybackQueue.empty();
    _queueSource = null;
    _resetCompletionGuards();
    notifyListeners();
    await _playback.stop();
  }

  void clearQueueOnly() {
    _queue = const PlaybackQueue.empty();
    _queueSource = null;
    _resetCompletionGuards();
    notifyListeners();
  }

  /// Called from [CatalogCacheCoordinator] on successful catalogue replacement.
  Future<void> reconcileWithCatalog(Catalog catalog) async {
    if (_queue.isEmpty) return;

    final resolved = <String, MediaItem>{};
    for (final item in _queue.items) {
      final fresh = catalog.findItemById(item.id);
      if (fresh != null) {
        resolved[item.id] = fresh;
      }
    }

    final reconciled = _queue.reconcile(resolved);
    if (reconciled.isEmpty) {
      await clearQueueAndStop();
      return;
    }

    _queue = reconciled;
    _resetCompletionGuards();
    notifyListeners();

    final playbackId = _playback.currentItem?.id;
    if (_playerRouteActive &&
        playbackId != null &&
        reconciled.currentItem?.id != playbackId &&
        reconciled.hasCurrent) {
      await playCurrent();
    }
  }

  void _onPlaybackChanged() {
    final item = _playback.currentItem;
    if (item != null && !item.isAudio && !_queue.isEmpty) {
      clearQueueOnly();
      return;
    }

    if (_queue.isEmpty) {
      _wasCompleted = false;
      return;
    }

    final completed = _playback.isCompleted;
    if (completed && !_wasCompleted && !_advanceInFlight) {
      _wasCompleted = true;
      unawaited(_advanceOnCompletion());
    } else if (!completed) {
      _wasCompleted = false;
    }

    notifyListeners();
  }

  Future<void> _advanceOnCompletion() async {
    if (_advanceInFlight) return;
    final generation = ++_completionAdvanceGeneration;
    _advanceInFlight = true;
    try {
      final drain = _pendingListeningWriteDrain;
      if (drain != null) {
        await drain();
      }

      if (!_queue.hasNext) return;

      _queue = _queue.advanceToNext();
      _completionAdvanceGeneration++;
      notifyListeners();

      if (generation != _completionAdvanceGeneration) return;
      await playCurrent();
    } finally {
      _advanceInFlight = false;
    }
  }

  void _resetCompletionGuards() {
    _wasCompleted = false;
    _completionAdvanceGeneration++;
  }

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    super.dispose();
  }

  @visibleForTesting
  PlaybackService get playbackServiceForTest => _playback;

  @visibleForTesting
  void setQueueForTest(PlaybackQueue queue) {
    _queue = queue;
    _resetCompletionGuards();
    notifyListeners();
  }
}
