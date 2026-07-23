import 'package:flutter/foundation.dart';

import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../utils/media_kind_inference.dart';
import '../music_constants.dart';
import '../music_sorting.dart';
import 'music_album.dart';
import 'music_artist.dart';

/// Read-only derived music views over a unified catalogue (M5.2 / M5.6 Step 3).
///
/// Built once per catalogue identity via [MusicLibraryService]. Exposes ordered
/// collections and O(1) lookup indexes. Catalogue remains authoritative —
/// this object is immutable derived state and is never persisted.
class MusicLibraryProjection {
  MusicLibraryProjection({
    required this.catalogueIdentity,
    required List<MediaItem> tracks,
    required List<MusicArtist> artists,
    required List<MusicAlbum> albums,
    required Map<String, MediaItem> tracksById,
    required Map<String, MusicArtist> artistsByGroupKey,
    required Map<String, MusicAlbum> albumsByGroupKey,
  })  : tracks = List<MediaItem>.unmodifiable(tracks),
        artists = List<MusicArtist>.unmodifiable(artists),
        albums = List<MusicAlbum>.unmodifiable(albums),
        _tracksById = Map<String, MediaItem>.unmodifiable(tracksById),
        _artistsByGroupKey =
            Map<String, MusicArtist>.unmodifiable(artistsByGroupKey),
        _albumsByGroupKey =
            Map<String, MusicAlbum>.unmodifiable(albumsByGroupKey);

  final String catalogueIdentity;
  final List<MediaItem> tracks;
  final List<MusicArtist> artists;
  final List<MusicAlbum> albums;

  final Map<String, MediaItem> _tracksById;
  final Map<String, MusicArtist> _artistsByGroupKey;
  final Map<String, MusicAlbum> _albumsByGroupKey;

  bool get isEmpty => tracks.isEmpty;

  int get artistCount => artists.length;

  int get albumCount => albums.length;

  int get trackCount => tracks.length;

  /// Aggregate index sizes for informational diagnostics / baselines.
  int get trackIndexCount => _tracksById.length;

  int get artistIndexCount => _artistsByGroupKey.length;

  int get albumIndexCount => _albumsByGroupKey.length;

  MusicArtist? findArtistByGroupKey(String groupKey) =>
      _artistsByGroupKey[groupKey];

  MusicAlbum? findAlbumByGroupKey(String groupKey) =>
      _albumsByGroupKey[groupKey];

  /// Resolves a projected audio track by catalogue [itemId].
  ///
  /// Duplicate source IDs keep the **first** projected occurrence (matches the
  /// pre-index linear-scan policy). Video/image IDs are absent.
  MediaItem? findTrackById(String itemId) => _tracksById[itemId];

  /// Production artist grouping for tests and runtime fixtures.
  @visibleForTesting
  static String artistGroupKeyForItem(MediaItem item) =>
      _effectiveArtistGroupKey(item);

  /// Production album grouping for tests and runtime fixtures.
  @visibleForTesting
  static String albumGroupKeyForItem(MediaItem item) =>
      _effectiveAlbumGroupKey(item);

  factory MusicLibraryProjection.build(Catalog catalog) {
    // Single audio filter + id-stable sort for deterministic bucketing.
    final audioItems = <MediaItem>[
      for (final item in catalog.allItems)
        if (item.isAudio) item,
    ]..sort((a, b) => a.id.compareTo(b.id));

    final albumBuckets = <String, List<MediaItem>>{};
    final artistBuckets = <String, List<MediaItem>>{};
    // Derive grouping keys once per item — reused for both buckets.
    final artistKeysByItem = <MediaItem, String>{};
    final albumKeysByItem = <MediaItem, String>{};

    for (final item in audioItems) {
      final albumKey = _effectiveAlbumGroupKey(item);
      final artistKey = _effectiveArtistGroupKey(item);
      albumKeysByItem[item] = albumKey;
      artistKeysByItem[item] = artistKey;
      albumBuckets.putIfAbsent(albumKey, () => <MediaItem>[]).add(item);
      artistBuckets.putIfAbsent(artistKey, () => <MediaItem>[]).add(item);
    }

    final albumsByGroupKey = <String, MusicAlbum>{};
    final albums = <MusicAlbum>[];
    for (final entry in albumBuckets.entries) {
      final items = List<MediaItem>.from(entry.value)
        ..sort(MusicSorting.compareTracksInAlbum);
      final album = MusicAlbum(
        groupKey: entry.key,
        displayTitle: _pickDisplayAlbum(items),
        displayArtist: _pickDisplayArtist(items),
        tracks: List<MediaItem>.unmodifiable(items),
        year: _pickYear(items),
        genre: _pickGenre(items),
        discCount: _pickDiscCount(items),
        representativeTrack: _pickRepresentativeTrack(items),
      );
      albumsByGroupKey[entry.key] = album;
      albums.add(album);
    }
    albums.sort(MusicSorting.compareAlbumsBrowse);

    final albumsByArtist = <String, List<MusicAlbum>>{};
    for (final album in albums) {
      final first = album.tracks.first;
      final artistKey =
          artistKeysByItem[first] ?? _effectiveArtistGroupKey(first);
      albumsByArtist.putIfAbsent(artistKey, () => <MusicAlbum>[]).add(album);
    }
    for (final list in albumsByArtist.values) {
      list.sort(MusicSorting.compareAlbumsWithinArtist);
    }

    final artistsByGroupKey = <String, MusicArtist>{};
    final artists = <MusicArtist>[];
    for (final entry in artistBuckets.entries) {
      final items = List<MediaItem>.from(entry.value)
        ..sort(MusicSorting.compareTracksBrowse);
      // Albums already sorted once above — reuse without re-sorting.
      final artistAlbums = List<MusicAlbum>.unmodifiable(
        albumsByArtist[entry.key] ?? const <MusicAlbum>[],
      );
      final artist = MusicArtist(
        groupKey: entry.key,
        displayName: _pickDisplayArtist(items),
        albums: artistAlbums,
        tracks: List<MediaItem>.unmodifiable(items),
        tracksInAlbumOrder: List<MediaItem>.unmodifiable([
          for (final album in artistAlbums) ...album.tracks,
        ]),
      );
      artistsByGroupKey[entry.key] = artist;
      artists.add(artist);
    }
    artists.sort(MusicSorting.compareArtists);

    final sortedTracks = List<MediaItem>.from(audioItems)
      ..sort(MusicSorting.compareTracksBrowse);

    // First-wins for duplicate IDs (matches former linear-scan behaviour).
    // LinkedHashMap preserves insertion order of first occurrence.
    final tracksById = <String, MediaItem>{};
    for (final track in sortedTracks) {
      tracksById.putIfAbsent(track.id, () => track);
    }

    return MusicLibraryProjection(
      catalogueIdentity: catalog.catalogueIdentity,
      tracks: sortedTracks,
      artists: artists,
      albums: albums,
      tracksById: tracksById,
      artistsByGroupKey: artistsByGroupKey,
      albumsByGroupKey: albumsByGroupKey,
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
    final artist =
        item.albumArtist ?? item.artist ?? MusicConstants.unknownArtist;
    final album = item.album ?? MusicConstants.unknownAlbum;
    final parent = _parentFolderPath(item.filePath);
    return [
      normalizeGroupKey(artist),
      normalizeGroupKey(album),
      normalizeGroupKey(parent),
    ].join('|');
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

  /// Deterministic artwork source: first track sorted by file path.
  static MediaItem _pickRepresentativeTrack(List<MediaItem> items) {
    if (items.length == 1) return items.first;
    final sorted = List<MediaItem>.from(items)
      ..sort((a, b) => a.filePath.compareTo(b.filePath));
    return sorted.first;
  }

  static int _caseInsensitiveCompare(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
