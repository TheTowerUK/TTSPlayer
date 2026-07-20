import '../../models/media_item.dart';
import '../../models/playback/playback_queue.dart';
import 'models/music_album.dart';
import 'models/music_artist.dart';

/// Resolves queue start indices without duplicating [MusicSorting] rules.
abstract final class MusicQueueSeeding {
  static bool hasPlayableTracks(List<MediaItem> orderedTracks) {
    return PlaybackQueue.audioOnlyItems(orderedTracks).isNotEmpty;
  }

  /// Index of [track] in [orderedTracks], preferring object identity for duplicates.
  static int indexInOrderedList(List<MediaItem> orderedTracks, MediaItem track) {
    final direct = orderedTracks.indexOf(track);
    if (direct >= 0) return direct;
    return orderedTracks.indexWhere((item) => item.id == track.id);
  }

  /// Maps a source-list index to the playable-only queue index after filtering.
  static int playableStartIndex(
    List<MediaItem> orderedTracks, {
    int sourceIndex = 0,
  }) {
    if (orderedTracks.isEmpty) return 0;

    var playableIndex = 0;
    for (var i = 0; i < orderedTracks.length; i++) {
      final item = orderedTracks[i];
      if (!item.isAudio || !item.status.isPlayable) continue;
      if (i == sourceIndex) return playableIndex;
      playableIndex++;
    }

    return 0;
  }

  static int playableStartIndexForTrack(
    List<MediaItem> orderedTracks,
    MediaItem track,
  ) {
    final sourceIndex = indexInOrderedList(orderedTracks, track);
    if (sourceIndex < 0) return 0;
    return playableStartIndex(orderedTracks, sourceIndex: sourceIndex);
  }

  static List<MediaItem> albumTracks(MusicAlbum album) => album.tracks;

  static List<MediaItem> artistTracks(MusicArtist artist) =>
      artist.tracksInAlbumOrder;
}
