import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';

/// Standard fixture sizes for music projection and opt-in runtime tests.
const int smallMusicArtistCount = 5;
const int smallMusicAlbumsPerArtist = 2;
const int smallMusicTracksPerAlbum = 3;

const int largeMusicArtistCount = 100;
const int largeMusicAlbumsPerArtist = 10;
const int largeMusicTracksPerAlbum = 20;

/// Builds a deterministic mixed-media catalogue with nested music hierarchy.
///
/// Not shipped as app assets — constructed in test or opt-in runtime harness.
Catalog buildLargeMusicCatalog({
  int artistCount = largeMusicArtistCount,
  int albumsPerArtist = largeMusicAlbumsPerArtist,
  int tracksPerAlbum = largeMusicTracksPerAlbum,
  String catalogueIdentity = 'large-music-test-catalogue',
  bool includeVideoItems = true,
}) {
  assert(artistCount >= 0);
  assert(albumsPerArtist >= 0);
  assert(tracksPerAlbum >= 0);

  final musicSubfolders = <MediaFolder>[];
  var totalItems = 0;

  for (var a = 0; a < artistCount; a++) {
    final artistName = 'Artist ${a.toString().padLeft(3, '0')}';
    final artistKey = artistName.toLowerCase();
    final albumFolders = <MediaFolder>[];

    for (var b = 0; b < albumsPerArtist; b++) {
      final albumName = 'Album ${b.toString().padLeft(2, '0')}';
      final albumPath = r'Y:\Media\Music\' + artistName + r'\' + albumName;
      final albumKey = '$artistKey|$albumName|${albumPath.toLowerCase()}';
      final tracks = <MediaItem>[];

      for (var t = 0; t < tracksPerAlbum; t++) {
        final disc = (t ~/ 10) + 1;
        final trackNum = (t % 10) + 1;
        tracks.add(
          MediaItem(
            id: 'music-a$a-b$b-t$t',
            title: 'Track ${t.toString().padLeft(2, '0')}',
            filePath: '$albumPath\\${disc.toString().padLeft(2, '0')} - '
                '${trackNum.toString().padLeft(2, '0')} - '
                'Track ${t.toString().padLeft(2, '0')}.mp3',
            mediaKindRaw: 'audio',
            artist: artistName,
            album: albumName,
            albumArtist: artistName,
            trackNumber: trackNum,
            discNumber: disc,
            year: 2000 + (b % 25),
            genre: 'Genre ${a % 5}',
            artistGroupKey: artistKey,
            albumGroupKey: albumKey,
          ),
        );
      }

      totalItems += tracks.length;
      albumFolders.add(
        MediaFolder(
          id: 'album-a$a-b$b',
          name: albumName,
          path: albumPath,
          itemCount: tracks.length,
          items: tracks,
          subfolders: const [],
        ),
      );
    }

    musicSubfolders.add(
      MediaFolder(
        id: 'artist-$a',
        name: artistName,
        path: r'Y:\Media\Music\' + artistName,
        itemCount: 0,
        items: const [],
        subfolders: albumFolders,
      ),
    );
  }

  final folders = <MediaFolder>[
    MediaFolder(
      id: 'lib-music',
      name: 'Music',
      path: r'Y:\Media\Music',
      itemCount: 0,
      items: const [],
      subfolders: musicSubfolders,
    ),
  ];

  if (includeVideoItems) {
    folders.insert(
      0,
      MediaFolder(
        id: 'lib-videos',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        itemCount: 1,
        items: [
          MediaItem(
            id: 'video-sample',
            title: 'Sample Video',
            filePath: r'Y:\Media\Videos\sample.mp4',
            mediaKindRaw: 'video',
          ),
        ],
        subfolders: const [],
      ),
    );
    totalItems += 1;
  }

  return Catalog.fromJson({
    'generated_at': '2026-07-19T12:00:00+00:00',
    'total_items': totalItems,
    'catalogue': {
      'id': catalogueIdentity,
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
      'supported_extensions': ['mp3', 'mp4'],
    },
    'folders': folders.map((f) => f.toJson()).toList(),
  });
}
