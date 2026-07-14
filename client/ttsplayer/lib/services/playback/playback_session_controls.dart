import '../../models/playback/playback_action_result.dart';
import '../../models/playback/playback_audio_track.dart';
import '../../models/playback/playback_subtitle_track.dart';

/// Snapshot of track and rate state from the active playback backend.
class PlaybackSessionSnapshot {
  final double playbackRate;
  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitleTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;

  const PlaybackSessionSnapshot({
    required this.playbackRate,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
  });

  static const empty = PlaybackSessionSnapshot(playbackRate: 1.0);
}

/// Narrow backend adapter for rate and embedded track controls (ADR-010).
abstract class PlaybackSessionControls {
  bool get supportsPlaybackRate;
  bool get supportsTrackSelection;

  PlaybackSessionSnapshot readSnapshot();

  Future<PlaybackActionResult> setPlaybackRate(double rate);

  Future<PlaybackActionResult> selectAudioTrack(String trackId);

  Future<PlaybackActionResult> selectSubtitleTrack(String? trackId);

  Future<PlaybackActionResult> disableSubtitles();

  Future<void> dispose();
}
