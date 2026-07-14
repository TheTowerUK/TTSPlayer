import '../../models/playback/playback_action_result.dart';
import 'playback_session_controls.dart';

/// No-op controls for backends without rate/track APIs (video_player).
class UnsupportedSessionControls implements PlaybackSessionControls {
  const UnsupportedSessionControls();

  @override
  bool get supportsPlaybackRate => false;

  @override
  bool get supportsTrackSelection => false;

  @override
  PlaybackSessionSnapshot readSnapshot() => PlaybackSessionSnapshot.empty;

  @override
  Future<PlaybackActionResult> setPlaybackRate(double rate) async {
    return const PlaybackActionResult.unsupported('Playback rate not supported');
  }

  @override
  Future<PlaybackActionResult> selectAudioTrack(String trackId) async {
    return const PlaybackActionResult.unsupported('Audio tracks not supported');
  }

  @override
  Future<PlaybackActionResult> selectSubtitleTrack(String? trackId) async {
    return const PlaybackActionResult.unsupported('Subtitles not supported');
  }

  @override
  Future<PlaybackActionResult> disableSubtitles() async {
    return const PlaybackActionResult.unsupported('Subtitles not supported');
  }

  @override
  Future<void> dispose() async {}
}
