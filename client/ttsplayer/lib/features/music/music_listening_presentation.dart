import '../../models/media_item.dart';
import 'models/music_album.dart';
import 'models/music_library_projection.dart';
import 'models/music_listening_policy.dart';
import 'models/music_listening_record.dart';

/// Resolved listening-history row for UI rendering (M5.4 Step 5).
class MusicListeningListEntry {
  const MusicListeningListEntry({
    required this.record,
    required this.mediaItem,
  });

  final MusicListeningRecord record;
  final MediaItem? mediaItem;

  bool get isPlayable =>
      mediaItem != null && mediaItem!.isAudio && mediaItem!.status.isPlayable;

  String get displayTitle => mediaItem?.title ?? record.title;

  String get displayArtist => mediaItem?.artist ?? record.artist;

  String get displayAlbum => mediaItem?.album ?? record.album;
}

/// Maps [records] to catalogue-backed entries using strict [MediaItem.id] lookup.
List<MusicListeningListEntry> resolveListeningEntries(
  List<MusicListeningRecord> records,
  MusicLibraryProjection projection,
) {
  return records
      .map(
        (record) => MusicListeningListEntry(
          record: record,
          mediaItem: projection.findTrackById(record.trackId),
        ),
      )
      .toList(growable: false);
}

/// Playable entries only — stale records are omitted from interactive surfaces.
List<MusicListeningListEntry> resolvePlayableListeningEntries(
  List<MusicListeningRecord> records,
  MusicLibraryProjection projection,
) {
  return resolveListeningEntries(records, projection)
      .where((entry) => entry.isPlayable)
      .toList(growable: false);
}

/// Start position for history launches — encodes resume eligibility once.
Duration historyPlaybackStartPosition(MusicListeningRecord record) {
  if (record.completed) return Duration.zero;
  if (record.lastPosition < MusicListeningPolicy.minResumePosition) {
    return Duration.zero;
  }
  return record.lastPosition;
}

/// Progress fraction for incomplete records; null when unknown or completed.
double? listeningProgressFraction(MusicListeningRecord record) {
  if (record.completed) return null;

  final duration = record.duration;
  if (duration == null || duration <= Duration.zero) return null;

  final position = record.lastPosition;
  if (position <= Duration.zero) return null;

  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

String formatListeningDuration(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String listeningProgressLabel(MusicListeningRecord record) {
  if (record.completed) return 'Completed';

  final duration = record.duration;
  final position = record.lastPosition;
  if (duration != null && duration > Duration.zero) {
    return '${formatListeningDuration(position)} / '
        '${formatListeningDuration(duration)}';
  }
  if (position > Duration.zero) {
    return formatListeningDuration(position);
  }
  return 'Resume';
}

MusicAlbum? findAlbumContainingTrack(
  MusicLibraryProjection projection,
  String trackId,
) {
  for (final album in projection.albums) {
    for (final track in album.tracks) {
      if (track.id == trackId) return album;
    }
  }
  return null;
}
