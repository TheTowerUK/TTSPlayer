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

  const MusicAlbum({
    required this.groupKey,
    required this.displayTitle,
    required this.displayArtist,
    required this.tracks,
    this.year,
    this.genre,
    this.discCount = 1,
  });

  int get trackCount => tracks.length;

  /// Deterministic artwork source: first track sorted by file path.
  MediaItem get representativeTrack {
    final sorted = List<MediaItem>.from(tracks)
      ..sort((a, b) => a.filePath.compareTo(b.filePath));
    return sorted.first;
  }
}
