import '../../models/media_item.dart';
import '../../utils/media_kind_inference.dart';
import 'models/music_album.dart';
import 'models/music_artist.dart';
import 'music_constants.dart';

/// Locale-independent, deterministic music browse ordering (M5.2).
abstract final class MusicSorting {
  static int compareArtists(MusicArtist a, MusicArtist b) {
    final aUnknown = _isUnknownArtist(a.displayName);
    final bUnknown = _isUnknownArtist(b.displayName);
    if (aUnknown != bUnknown) {
      return aUnknown ? 1 : -1;
    }
    final byName = _caseInsensitiveCompare(a.displayName, b.displayName);
    if (byName != 0) return byName;
    return a.groupKey.compareTo(b.groupKey);
  }

  static int compareAlbumsBrowse(MusicAlbum a, MusicAlbum b) {
    final byArtist = _caseInsensitiveCompare(
      a.displayArtist,
      b.displayArtist,
    );
    if (byArtist != 0) return byArtist;

    final aYear = a.year;
    final bYear = b.year;
    if (aYear != null && bYear != null) {
      final byYear = aYear.compareTo(bYear);
      if (byYear != 0) return byYear;
    } else if (aYear != null) {
      return -1;
    } else if (bYear != null) {
      return 1;
    }

    final byTitle = _caseInsensitiveCompare(a.displayTitle, b.displayTitle);
    if (byTitle != 0) return byTitle;
    return a.groupKey.compareTo(b.groupKey);
  }

  static int compareAlbumsWithinArtist(MusicAlbum a, MusicAlbum b) {
    final aYear = a.year;
    final bYear = b.year;
    if (aYear != null && bYear != null) {
      final byYear = aYear.compareTo(bYear);
      if (byYear != 0) return byYear;
    } else if (aYear != null) {
      return -1;
    } else if (bYear != null) {
      return 1;
    }

    final byTitle = _caseInsensitiveCompare(a.displayTitle, b.displayTitle);
    if (byTitle != 0) return byTitle;
    return a.groupKey.compareTo(b.groupKey);
  }

  static int compareTracksInAlbum(MediaItem a, MediaItem b) {
    final aDisc = a.discNumber ?? 1;
    final bDisc = b.discNumber ?? 1;
    if (aDisc != bDisc) return aDisc.compareTo(bDisc);

    final aTrack = a.trackNumber;
    final bTrack = b.trackNumber;
    if (aTrack != null && bTrack != null) {
      final byTrack = aTrack.compareTo(bTrack);
      if (byTrack != 0) return byTrack;
    } else if (aTrack != null) {
      return -1;
    } else if (bTrack != null) {
      return 1;
    }

    final byTitle = _caseInsensitiveCompare(a.title, b.title);
    if (byTitle != 0) return byTitle;
    return a.id.compareTo(b.id);
  }

  static int compareTracksBrowse(MediaItem a, MediaItem b) {
    final byTitle = _caseInsensitiveCompare(a.title, b.title);
    if (byTitle != 0) return byTitle;

    final byArtist = _caseInsensitiveCompare(
      _trackArtistLabel(a),
      _trackArtistLabel(b),
    );
    if (byArtist != 0) return byArtist;

    final byAlbum = _caseInsensitiveCompare(
      a.album ?? MusicConstants.unknownAlbum,
      b.album ?? MusicConstants.unknownAlbum,
    );
    if (byAlbum != 0) return byAlbum;
    return a.id.compareTo(b.id);
  }

  static bool _isUnknownArtist(String name) {
    return normalizeGroupKey(name) == normalizeGroupKey(MusicConstants.unknownArtist);
  }

  static String _trackArtistLabel(MediaItem item) {
    return item.artist ?? item.albumArtist ?? MusicConstants.unknownArtist;
  }

  static int _caseInsensitiveCompare(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
