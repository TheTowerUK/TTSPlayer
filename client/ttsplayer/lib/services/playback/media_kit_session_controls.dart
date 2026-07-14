import 'package:media_kit/media_kit.dart';

import '../../models/playback/playback_action_result.dart';
import '../../models/playback/playback_rate_presets.dart';
import 'playback_session_controls.dart';
import 'playback_track_mapper.dart';

/// media_kit-backed session controls for Windows desktop.
class MediaKitSessionControls implements PlaybackSessionControls {
  MediaKitSessionControls(this._player);

  final Player _player;

  @override
  bool get supportsPlaybackRate => true;

  @override
  bool get supportsTrackSelection => true;

  @override
  PlaybackSessionSnapshot readSnapshot() {
    final tracks = _player.state.tracks;
    final selected = _player.state.track;
    return PlaybackSessionSnapshot(
      playbackRate: _player.state.rate,
      audioTracks: PlaybackTrackMapper.mapAudioTracks(tracks.audio),
      subtitleTracks: PlaybackTrackMapper.mapSubtitleTracks(tracks.subtitle),
      selectedAudioTrackId:
          PlaybackTrackMapper.normalizeSelectedAudioId(selected.audio.id),
      selectedSubtitleTrackId: PlaybackTrackMapper.normalizeSelectedSubtitleId(
        selected.subtitle.id,
      ),
    );
  }

  @override
  Future<PlaybackActionResult> setPlaybackRate(double rate) async {
    if (!PlaybackRatePresets.isSupported(rate)) {
      return const PlaybackActionResult.invalidArgument('Unsupported rate');
    }
    try {
      await _player.setRate(rate);
      final actual = _player.state.rate;
      if ((actual - rate).abs() > 0.05) {
        return PlaybackActionResult.backendFailed(
          'Backend rate $actual != requested $rate',
        );
      }
      return const PlaybackActionResult.success();
    } catch (e) {
      return PlaybackActionResult.backendFailed(e.toString());
    }
  }

  @override
  Future<PlaybackActionResult> selectAudioTrack(String trackId) async {
    final available = readSnapshot().audioTracks;
    if (!available.any((track) => track.id == trackId)) {
      return PlaybackActionResult.invalidArgument('Unknown audio track: $trackId');
    }
    try {
      final target = _player.state.tracks.audio.firstWhere(
        (track) => track.id == trackId,
      );
      await _player.setAudioTrack(target);
      return const PlaybackActionResult.success();
    } catch (e) {
      return PlaybackActionResult.backendFailed(e.toString());
    }
  }

  @override
  Future<PlaybackActionResult> selectSubtitleTrack(String? trackId) async {
    if (trackId == null) {
      return disableSubtitles();
    }
    final available = readSnapshot().subtitleTracks;
    if (!available.any((track) => track.id == trackId)) {
      return PlaybackActionResult.invalidArgument(
        'Unknown subtitle track: $trackId',
      );
    }
    try {
      final target = _player.state.tracks.subtitle.firstWhere(
        (track) => track.id == trackId,
      );
      await _player.setSubtitleTrack(target);
      return const PlaybackActionResult.success();
    } catch (e) {
      return PlaybackActionResult.backendFailed(e.toString());
    }
  }

  @override
  Future<PlaybackActionResult> disableSubtitles() async {
    try {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return const PlaybackActionResult.success();
    } catch (e) {
      return PlaybackActionResult.backendFailed(e.toString());
    }
  }

  @override
  Future<void> dispose() async {}
}
