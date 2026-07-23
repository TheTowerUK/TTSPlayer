import '../../../models/media_item.dart';

/// Derived album browse bucket — not a filesystem node.
class MusicAlbum {
  final String groupKey;
  final String displayTitle;
  final String displayArtist;
  final int? year;
  final String? genre;
  final int discCount;
  final List<MediaItem> tracks;

  /// Cached at projection build — avoids re-sorting on every artwork request.
  final MediaItem representativeTrack;

  const MusicAlbum({
    required this.groupKey,
    required this.displayTitle,
    required this.displayArtist,
    required this.tracks,
    required this.representativeTrack,
    this.year,
    this.genre,
    this.discCount = 1,
  });

  int get trackCount => tracks.length;
}
