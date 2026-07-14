import 'package:media_kit/media_kit.dart';

import '../../models/playback/playback_audio_track.dart';
import '../../models/playback/playback_subtitle_track.dart';

/// Maps media_kit track lists to application DTOs (ADR-010).
class PlaybackTrackMapper {
  PlaybackTrackMapper._();

  static const _sentinelIds = {'auto', 'no'};

  static List<PlaybackAudioTrack> mapAudioTracks(List<AudioTrack> tracks) {
    return tracks
        .where((track) => !_sentinelIds.contains(track.id))
        .map(
          (track) => PlaybackAudioTrack(
            id: track.id,
            title: track.title,
            language: track.language,
          ),
        )
        .toList(growable: false);
  }

  static List<PlaybackSubtitleTrack> mapSubtitleTracks(
    List<SubtitleTrack> tracks,
  ) {
    return tracks
        .where((track) => !_sentinelIds.contains(track.id))
        .map(
          (track) => PlaybackSubtitleTrack(
            id: track.id,
            title: track.title,
            language: track.language,
          ),
        )
        .toList(growable: false);
  }

  static String? normalizeSelectedAudioId(String? rawId) {
    if (rawId == null || _sentinelIds.contains(rawId)) return null;
    return rawId;
  }

  static String? normalizeSelectedSubtitleId(String? rawId) {
    if (rawId == null || rawId == 'no') return null;
    if (rawId == 'auto') return null;
    return rawId;
  }
}
