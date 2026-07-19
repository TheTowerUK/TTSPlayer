import '../../../models/media_item.dart';
import 'music_album.dart';

/// Derived artist browse bucket — not a filesystem node.
class MusicArtist {
  final String groupKey;
  final String displayName;
  final List<MusicAlbum> albums;
  final List<MediaItem> tracks;

  const MusicArtist({
    required this.groupKey,
    required this.displayName,
    required this.albums,
    required this.tracks,
  });

  int get albumCount => albums.length;

  int get trackCount => tracks.length;

  /// Deterministic artwork source: first album's representative track.
  MediaItem? get representativeTrack {
    if (albums.isEmpty) {
      if (tracks.isEmpty) return null;
      final sorted = List<MediaItem>.from(tracks)
        ..sort((a, b) => a.filePath.compareTo(b.filePath));
      return sorted.first;
    }
    return albums.first.representativeTrack;
  }
}
