import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../utils/media_kind_inference.dart';
import '../music_constants.dart';
import '../music_sorting.dart';
import 'music_album.dart';
import 'music_artist.dart';

/// Read-only derived music views over a unified catalogue (M5.2).
class MusicLibraryProjection {
  final String catalogueIdentity;
  final List<MediaItem> tracks;
  final List<MusicArtist> artists;
  final List<MusicAlbum> albums;

  const MusicLibraryProjection({
    required this.catalogueIdentity,
    required this.tracks,
    required this.artists,
    required this.albums,
  });

  bool get isEmpty => tracks.isEmpty;

  int get artistCount => artists.length;

  int get albumCount => albums.length;

  int get trackCount => tracks.length;

  MusicArtist? findArtistByGroupKey(String groupKey) {
    for (final artist in artists) {
      if (artist.groupKey == groupKey) return artist;
    }
    return null;
  }

  MusicAlbum? findAlbumByGroupKey(String groupKey) {
    for (final album in albums) {
      if (album.groupKey == groupKey) return album;
    }
    return null;
  }

  MediaItem? findTrackById(String itemId) {
    for (final track in tracks) {
      if (track.id == itemId) return track;
    }
    return null;
  }

  factory MusicLibraryProjection.build(Catalog catalog) {
    final audioItems = catalog.allItems.where((item) => item.isAudio).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final albumBuckets = <String, List<MediaItem>>{};
    final artistBuckets = <String, List<MediaItem>>{};

    for (final item in audioItems) {
      final albumKey = _effectiveAlbumGroupKey(item);
      albumBuckets.putIfAbsent(albumKey, () => []).add(item);

      final artistKey = _effectiveArtistGroupKey(item);
      artistBuckets.putIfAbsent(artistKey, () => []).add(item);
    }

    final albums = albumBuckets.entries.map((entry) {
      final items = List<MediaItem>.from(entry.value)
        ..sort(MusicSorting.compareTracksInAlbum);
      final title = _pickDisplayAlbum(items);
      final artist = _pickDisplayArtist(items);
      final year = _pickYear(items);
      final genre = _pickGenre(items);
      final discCount = _pickDiscCount(items);
      return MusicAlbum(
        groupKey: entry.key,
        displayTitle: title,
        displayArtist: artist,
        tracks: items,
        year: year,
        genre: genre,
        discCount: discCount,
      );
    }).toList()
      ..sort(MusicSorting.compareAlbumsBrowse);

    final albumsByArtist = <String, List<MusicAlbum>>{};
    for (final album in albums) {
      final artistKey = _artistKeyForAlbum(album);
      albumsByArtist.putIfAbsent(artistKey, () => []).add(album);
    }
    for (final list in albumsByArtist.values) {
      list.sort(MusicSorting.compareAlbumsWithinArtist);
    }

    final artists = artistBuckets.entries.map((entry) {
      final items = List<MediaItem>.from(entry.value)
        ..sort(MusicSorting.compareTracksBrowse);
      final name = _pickDisplayArtist(items);
      final artistAlbums = List<MusicAlbum>.from(
        albumsByArtist[entry.key] ?? const [],
      )..sort(MusicSorting.compareAlbumsWithinArtist);
      return MusicArtist(
        groupKey: entry.key,
        displayName: name,
        albums: artistAlbums,
        tracks: items,
      );
    }).toList()
      ..sort(MusicSorting.compareArtists);

    final sortedTracks = List<MediaItem>.from(audioItems)
      ..sort(MusicSorting.compareTracksBrowse);

    return MusicLibraryProjection(
      catalogueIdentity: catalog.catalogueIdentity,
      tracks: sortedTracks,
      artists: artists,
      albums: albums,
    );
  }

  static String _effectiveArtistGroupKey(MediaItem item) {
    final existing = item.artistGroupKey?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    return normalizeGroupKey(
      item.artist ?? item.albumArtist ?? MusicConstants.unknownArtist,
    );
  }

  static String _effectiveAlbumGroupKey(MediaItem item) {
    final existing = item.albumGroupKey?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final artist = item.albumArtist ?? item.artist ?? MusicConstants.unknownArtist;
    final album = item.album ?? MusicConstants.unknownAlbum;
    final parent = _parentFolderPath(item.filePath);
    return [
      normalizeGroupKey(artist),
      normalizeGroupKey(album),
      normalizeGroupKey(parent),
    ].join('|');
  }

  static String _artistKeyForAlbum(MusicAlbum album) {
    final first = album.tracks.first;
    return _effectiveArtistGroupKey(first);
  }

  static String _parentFolderPath(String filePath) {
    final normalized = filePath.replaceAll('/', '\\');
    final index = normalized.lastIndexOf('\\');
    if (index <= 0) return normalized;
    return normalized.substring(0, index);
  }

  static String _pickDisplayArtist(List<MediaItem> items) {
    final names = <String>{};
    for (final item in items) {
      final value = item.artist ?? item.albumArtist;
      if (value != null && value.trim().isNotEmpty) {
        names.add(value.trim());
      }
    }
    if (names.isEmpty) return MusicConstants.unknownArtist;
    final sorted = names.toList()..sort(_caseInsensitiveCompare);
    return sorted.first;
  }

  static String _pickDisplayAlbum(List<MediaItem> items) {
    final names = <String>{};
    for (final item in items) {
      final value = item.album;
      if (value != null && value.trim().isNotEmpty) {
        names.add(value.trim());
      }
    }
    if (names.isEmpty) return MusicConstants.unknownAlbum;
    final sorted = names.toList()..sort(_caseInsensitiveCompare);
    return sorted.first;
  }

  static int? _pickYear(List<MediaItem> items) {
    for (final item in items) {
      if (item.year != null) return item.year;
    }
    return null;
  }

  static String? _pickGenre(List<MediaItem> items) {
    for (final item in items) {
      final genre = item.genre?.trim();
      if (genre != null && genre.isNotEmpty) return genre;
    }
    return null;
  }

  static int _pickDiscCount(List<MediaItem> items) {
    var maxDisc = 1;
    for (final item in items) {
      final disc = item.discNumber;
      if (disc != null && disc > maxDisc) {
        maxDisc = disc;
      }
    }
    return maxDisc;
  }

  static int _caseInsensitiveCompare(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
