import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';

/// Named Phase 5.6 large-library fixture profiles (Step 2).
///
/// Counts are exact once generated — record them in baseline reports.
enum Phase56CatalogProfile {
  /// 50 × 4 × 5 = 1,000 audio tracks.
  small,

  /// 100 × 10 × 10 = 10,000 audio tracks.
  medium,

  /// 200 × 20 × 10 = 40,000 audio tracks.
  large,

  /// Small audio profile plus video/image mixed-media entries.
  mixed,
}

/// Distinctive search sentinels embedded in every profile (stable IDs/titles).
abstract final class Phase56Sentinels {
  static const titleToken = 'PHASE56-SENTINEL-TITLE-ALPHA';
  static const artistToken = 'PHASE56-SENTINEL-ARTIST';
  static const albumToken = 'PHASE56-SENTINEL-ALBUM';
  static const absentToken = 'PHASE56-SENTINEL-ABSENT-ZZZ';

  static const titleTrackId = 'p56-sentinel-title';
  static const artistTrackId = 'p56-sentinel-artist';
  static const albumTrackId = 'p56-sentinel-album';
  static const compilationAlbumKey =
      'various artists|phase56 sentinel compilation|y:\\media\\music\\compilations\\phase56 sentinel compilation';
  static const compilationArtistKey = 'various artists';
}

class Phase56CatalogDimensions {
  const Phase56CatalogDimensions({
    required this.artistCount,
    required this.albumsPerArtist,
    required this.tracksPerAlbum,
  });

  final int artistCount;
  final int albumsPerArtist;
  final int tracksPerAlbum;

  int get audioTrackCount => artistCount * albumsPerArtist * tracksPerAlbum;
}

Phase56CatalogDimensions phase56DimensionsFor(Phase56CatalogProfile profile) {
  switch (profile) {
    case Phase56CatalogProfile.small:
    case Phase56CatalogProfile.mixed:
      return const Phase56CatalogDimensions(
        artistCount: 50,
        albumsPerArtist: 4,
        tracksPerAlbum: 5,
      );
    case Phase56CatalogProfile.medium:
      return const Phase56CatalogDimensions(
        artistCount: 100,
        albumsPerArtist: 10,
        tracksPerAlbum: 10,
      );
    case Phase56CatalogProfile.large:
      return const Phase56CatalogDimensions(
        artistCount: 200,
        albumsPerArtist: 20,
        tracksPerAlbum: 10,
      );
  }
}

String phase56CatalogueIdentity(Phase56CatalogProfile profile) {
  switch (profile) {
    case Phase56CatalogProfile.small:
      return 'PHASE56-SMALL-1K';
    case Phase56CatalogProfile.medium:
      return 'PHASE56-MEDIUM-10K';
    case Phase56CatalogProfile.large:
      return 'PHASE56-LARGE-40K';
    case Phase56CatalogProfile.mixed:
      return 'PHASE56-MIXED-1K';
  }
}

/// Deterministic in-memory music catalogues for Phase 5.6 baselines.
///
/// Does not write JSON files or media binaries. Compatible with production
/// [MusicLibraryProjection.build].
Catalog generatePhase56MusicCatalog({
  required Phase56CatalogProfile profile,
  int videoItemCount = 0,
  int imageItemCount = 0,
  bool includeMissingMetadata = true,
  bool includeCompilations = true,
  bool includeArtworkVariation = true,
  bool includeUnicodeNames = true,
  bool includeSentinels = true,
  String? catalogueIdentityOverride,
}) {
  final dims = phase56DimensionsFor(profile);
  final identity =
      catalogueIdentityOverride ?? phase56CatalogueIdentity(profile);

  final effectiveVideoCount = profile == Phase56CatalogProfile.mixed
      ? (videoItemCount > 0 ? videoItemCount : 25)
      : videoItemCount;
  final effectiveImageCount = profile == Phase56CatalogProfile.mixed
      ? (imageItemCount > 0 ? imageItemCount : 25)
      : imageItemCount;

  final artistFolders = <MediaFolder>[];
  var audioCount = 0;

  for (var a = 0; a < dims.artistCount; a++) {
    final artistName = _artistName(a, includeUnicodeNames: includeUnicodeNames);
    final artistKey = artistName.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    final albumFolders = <MediaFolder>[];

    for (var b = 0; b < dims.albumsPerArtist; b++) {
      final albumName = _albumName(a, b);
      final albumPath =
          r'Y:\Media\Music\' + artistName.trim() + r'\' + albumName;
      final albumKey =
          '$artistKey|${albumName.toLowerCase()}|${albumPath.toLowerCase()}';
      final tracks = <MediaItem>[];

      for (var t = 0; t < dims.tracksPerAlbum; t++) {
        final missing = includeMissingMetadata && a == 0 && b == 0 && t < 2;
        final withArtwork = includeArtworkVariation && ((a + b + t) % 3 != 0);
        final disc = (t ~/ 10) + 1;
        final trackNum = (t % 10) + 1;
        final id = 'p56-a${a.toString().padLeft(3, '0')}-'
            'b${b.toString().padLeft(2, '0')}-'
            't${t.toString().padLeft(2, '0')}';

        if (missing) {
          tracks.add(
            MediaItem(
              id: id,
              title: 'fallback-track-$t',
              filePath: '$albumPath\\fallback-track-$t.mp3',
              mediaKindRaw: 'audio',
              // Intentionally omit artist/album/albumArtist/track metadata.
              durationSeconds: 120 + t,
            ),
          );
        } else {
          tracks.add(
            MediaItem(
              id: id,
              title: '  Track ${t.toString().padLeft(2, '0')}  ',
              filePath: '$albumPath\\${disc.toString().padLeft(2, '0')} - '
                  '${trackNum.toString().padLeft(2, '0')} - '
                  'Track ${t.toString().padLeft(2, '0')}.mp3',
              mediaKindRaw: 'audio',
              artist: artistName,
              album: albumName,
              albumArtist: artistName,
              trackNumber: trackNum,
              discNumber: disc,
              year: 1990 + (b % 35),
              genre: 'Genre ${a % 7}',
              durationSeconds: 150 + (t * 3) + (b % 11),
              thumbnailPath: withArtwork ? '$albumPath\\cover.jpg' : null,
              artistGroupKey: artistKey,
              albumGroupKey: albumKey,
            ),
          );
        }
      }

      audioCount += tracks.length;
      albumFolders.add(
        MediaFolder(
          id: 'p56-album-a$a-b$b',
          name: albumName,
          path: albumPath,
          itemCount: tracks.length,
          items: tracks,
          subfolders: const [],
        ),
      );
    }

    artistFolders.add(
      MediaFolder(
        id: 'p56-artist-$a',
        name: artistName.trim(),
        path: r'Y:\Media\Music\' + artistName.trim(),
        itemCount: 0,
        items: const [],
        subfolders: albumFolders,
      ),
    );
  }

  final musicItems = <MediaItem>[];
  final musicSubfolders = List<MediaFolder>.from(artistFolders);

  if (includeCompilations) {
    final compilationTracks = <MediaItem>[
      for (var i = 0; i < 4; i++)
        MediaItem(
          id: 'p56-comp-$i',
          title: 'Compilation Track $i',
          filePath: r'Y:\Media\Music\Compilations\PHASE56 Sentinel Compilation\'
              '0${i + 1} - Compilation Track $i.mp3',
          mediaKindRaw: 'audio',
          artist: 'Guest Artist $i',
          album: 'PHASE56 Sentinel Compilation',
          albumArtist: 'Various Artists',
          trackNumber: i + 1,
          discNumber: 1,
          year: 2018,
          artistGroupKey: Phase56Sentinels.compilationArtistKey,
          albumGroupKey: Phase56Sentinels.compilationAlbumKey,
        ),
    ];
    // Also model "missing album artist" compilation sibling (fallback grouping).
    compilationTracks.add(
      MediaItem(
        id: 'p56-comp-missing-aa',
        title: 'Compilation Track Missing AA',
        filePath: r'Y:\Media\Music\Compilations\PHASE56 Sentinel Compilation\'
            '05 - Compilation Track Missing AA.mp3',
        mediaKindRaw: 'audio',
        artist: 'Guest Artist X',
        album: 'PHASE56 Sentinel Compilation',
        trackNumber: 5,
        discNumber: 1,
        year: 2018,
        artistGroupKey: 'guest artist x',
        albumGroupKey: 'guest artist x|phase56 sentinel compilation|'
            r'y:\media\music\compilations\phase56 sentinel compilation',
      ),
    );
    audioCount += compilationTracks.length;
    musicSubfolders.add(
      MediaFolder(
        id: 'p56-compilations',
        name: 'Compilations',
        path: r'Y:\Media\Music\Compilations',
        itemCount: 0,
        items: const [],
        subfolders: [
          MediaFolder(
            id: 'p56-comp-album',
            name: 'PHASE56 Sentinel Compilation',
            path: r'Y:\Media\Music\Compilations\PHASE56 Sentinel Compilation',
            itemCount: compilationTracks.length,
            items: compilationTracks,
            subfolders: const [],
          ),
        ],
      ),
    );
  }

  if (includeSentinels) {
    final sentinelTracks = <MediaItem>[
      MediaItem(
        id: Phase56Sentinels.titleTrackId,
        title: Phase56Sentinels.titleToken,
        filePath: r'Y:\Media\Music\Sentinels\PHASE56-SENTINEL-TITLE-ALPHA.mp3',
        mediaKindRaw: 'audio',
        artist: 'Ordinary Artist',
        album: 'Ordinary Album',
        albumArtist: 'Ordinary Artist',
        trackNumber: 1,
        discNumber: 1,
        year: 2024,
        durationSeconds: 200,
        artistGroupKey: 'ordinary artist',
        albumGroupKey: 'ordinary artist|ordinary album|'
            r'y:\media\music\sentinels',
      ),
      MediaItem(
        id: Phase56Sentinels.artistTrackId,
        title: 'Ordinary Title',
        filePath: r'Y:\Media\Music\Sentinels\artist-sentinel.mp3',
        mediaKindRaw: 'audio',
        artist: Phase56Sentinels.artistToken,
        album: 'Artist Sentinel Album',
        albumArtist: Phase56Sentinels.artistToken,
        trackNumber: 1,
        discNumber: 1,
        year: 2024,
        durationSeconds: 210,
        artistGroupKey: Phase56Sentinels.artistToken.toLowerCase(),
        albumGroupKey: '${Phase56Sentinels.artistToken.toLowerCase()}|'
            'artist sentinel album|'
            r'y:\media\music\sentinels',
      ),
      MediaItem(
        id: Phase56Sentinels.albumTrackId,
        title: 'Album Sentinel Track',
        filePath: r'Y:\Media\Music\Sentinels\album-sentinel.mp3',
        mediaKindRaw: 'audio',
        artist: 'Album Sentinel Artist',
        album: Phase56Sentinels.albumToken,
        albumArtist: 'Album Sentinel Artist',
        trackNumber: 1,
        discNumber: 1,
        year: 2024,
        durationSeconds: 220,
        artistGroupKey: 'album sentinel artist',
        albumGroupKey: 'album sentinel artist|'
            '${Phase56Sentinels.albumToken.toLowerCase()}|'
            r'y:\media\music\sentinels',
      ),
      // Duplicate title across artists (identity remains unique by ID).
      MediaItem(
        id: 'p56-dup-title-1',
        title: 'Duplicate Title',
        filePath: r'Y:\Media\Music\Sentinels\dup-1.mp3',
        mediaKindRaw: 'audio',
        artist: 'Dup Artist One',
        album: 'Dup Album',
        albumArtist: 'Dup Artist One',
        trackNumber: 1,
        artistGroupKey: 'dup artist one',
        albumGroupKey: 'dup artist one|dup album|y:\\media\\music\\sentinels',
      ),
      MediaItem(
        id: 'p56-dup-title-2',
        title: 'Duplicate Title',
        filePath: r'Y:\Media\Music\Sentinels\dup-2.mp3',
        mediaKindRaw: 'audio',
        artist: 'Dup Artist Two',
        album: 'Dup Album',
        albumArtist: 'Dup Artist Two',
        trackNumber: 1,
        artistGroupKey: 'dup artist two',
        albumGroupKey: 'dup artist two|dup album|y:\\media\\music\\sentinels',
      ),
    ];
    audioCount += sentinelTracks.length;
    musicItems.addAll(sentinelTracks);
  }

  final folders = <MediaFolder>[
    MediaFolder(
      id: 'p56-lib-music',
      name: 'Music',
      path: r'Y:\Media\Music',
      itemCount: musicItems.length,
      items: musicItems,
      subfolders: musicSubfolders,
    ),
  ];

  var totalItems = audioCount;

  if (effectiveVideoCount > 0) {
    final videos = <MediaItem>[
      for (var i = 0; i < effectiveVideoCount; i++)
        MediaItem(
          id: 'p56-video-$i',
          title: 'Phase56 Video $i',
          filePath: 'Y:\\Media\\Videos\\phase56_video_$i.mp4',
          mediaKindRaw: 'video',
          year: 2020 + (i % 5),
          durationSeconds: 600 + i,
        ),
    ];
    totalItems += videos.length;
    folders.add(
      MediaFolder(
        id: 'p56-lib-videos',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        itemCount: videos.length,
        items: videos,
        subfolders: const [],
      ),
    );
  }

  if (effectiveImageCount > 0) {
    final images = <MediaItem>[
      for (var i = 0; i < effectiveImageCount; i++)
        MediaItem(
          id: 'p56-image-$i',
          title: 'Phase56 Image $i',
          filePath: 'Y:\\Media\\Images\\phase56_image_$i.jpg',
          mediaKindRaw: 'image',
        ),
    ];
    totalItems += images.length;
    folders.add(
      MediaFolder(
        id: 'p56-lib-images',
        name: 'Images',
        path: r'Y:\Media\Images',
        itemCount: images.length,
        items: images,
        subfolders: const [],
      ),
    );
  }

  return Catalog.fromJson({
    'generated_at': '2026-07-23T09:00:00+00:00',
    'total_items': totalItems,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
      'supported_extensions': ['mp3', 'flac', 'mp4', 'jpg'],
    },
    'folders': folders.map((f) => f.toJson()).toList(),
  });
}

/// Convenience wrappers for named profiles.
Catalog phase56SmallCatalog() =>
    generatePhase56MusicCatalog(profile: Phase56CatalogProfile.small);

Catalog phase56MediumCatalog() =>
    generatePhase56MusicCatalog(profile: Phase56CatalogProfile.medium);

Catalog phase56LargeCatalog() =>
    generatePhase56MusicCatalog(profile: Phase56CatalogProfile.large);

Catalog phase56MixedCatalog() =>
    generatePhase56MusicCatalog(profile: Phase56CatalogProfile.mixed);

/// Exact audio count for a generated profile (grid + optional extras).
int phase56ExpectedAudioCount({
  required Phase56CatalogProfile profile,
  bool includeCompilations = true,
  bool includeSentinels = true,
}) {
  final grid = phase56DimensionsFor(profile).audioTrackCount;
  final compilations = includeCompilations ? 5 : 0;
  final sentinels = includeSentinels ? 5 : 0;
  return grid + compilations + sentinels;
}

String _artistName(int index, {required bool includeUnicodeNames}) {
  if (includeUnicodeNames && index == 1) {
    return '  Café Münch  ';
  }
  if (includeUnicodeNames && index == 2) {
    return 'Björk Ensemble';
  }
  return 'Artist ${index.toString().padLeft(3, '0')}';
}

String _albumName(int artistIndex, int albumIndex) {
  if (artistIndex == 3 && albumIndex == 0) {
    return 'Études & Preludes';
  }
  return 'Album ${albumIndex.toString().padLeft(2, '0')}';
}
