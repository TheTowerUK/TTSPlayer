import 'package:ttsplayer/models/media_item.dart';

/// Catalogue v3 mixed-media fixture for parser and service regression tests.
const String kCatalogV3MixedFixture = r'''
{
  "generated_at": "2026-07-19T12:00:00+00:00",
  "total_items": 4,
  "sources": [
    {
      "name": "NAS Media",
      "root_path": "Y:\\Media",
      "type": "smb",
      "accessible": true
    }
  ],
  "catalogue": {
    "id": "2026-07-19T12:00:00Z-MIXED1",
    "scanner_version": "0.4.0",
    "catalogue_version": 3,
    "supported_extensions": ["mp3", "mp4", "jpg"]
  },
  "folders": [
    {
      "id": "lib-videos",
      "name": "Videos",
      "path": "Y:\\Media\\Videos",
      "item_count": 1,
      "items": [
        {
          "id": "video-1",
          "title": "Sample Video",
          "file_path": "Y:\\Media\\Videos\\sample.mp4",
          "status": "available",
          "media_kind": "video"
        }
      ],
      "subfolders": []
    },
    {
      "id": "lib-music",
      "name": "Music",
      "path": "Y:\\Media\\Music",
      "item_count": 3,
      "items": [
        {
          "id": "audio-root",
          "title": "Root Track",
          "file_path": "Y:\\Media\\Music\\root_track.mp3",
          "status": "available",
          "media_kind": "audio",
          "artist": "Unknown Artist",
          "album": "Music",
          "album_artist": "Unknown Artist",
          "artist_group_key": "unknown artist",
          "album_group_key": "unknown artist|music|y:\\\\media\\\\music"
        }
      ],
      "subfolders": [
        {
          "id": "artist-beatles",
          "name": "The Beatles",
          "path": "Y:\\Media\\Music\\The Beatles",
          "item_count": 1,
          "items": [],
          "subfolders": [
            {
              "id": "album-abbey",
              "name": "Abbey Road",
              "path": "Y:\\Media\\Music\\The Beatles\\Abbey Road",
              "item_count": 2,
              "items": [
                {
                  "id": "track-complete",
                  "title": "Come Together",
                  "year": 1969,
                  "duration_seconds": 259,
                  "file_path": "Y:\\Media\\Music\\The Beatles\\Abbey Road\\01 - Come Together.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "The Beatles",
                  "album": "Abbey Road",
                  "album_artist": "The Beatles",
                  "track_number": 1,
                  "disc_number": 1,
                  "genre": "Rock",
                  "artist_group_key": "the beatles",
                  "album_group_key": "the beatles|abbey road|y:\\\\media\\\\music\\\\the beatles\\\\abbey road"
                },
                {
                  "id": "track-partial",
                  "title": "Untitled",
                  "file_path": "Y:\\Media\\Music\\The Beatles\\Abbey Road\\02 - Something.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Unknown Artist",
                  "album": "Abbey Road",
                  "album_artist": "Unknown Artist",
                  "artist_group_key": "unknown artist",
                  "album_group_key": "unknown artist|abbey road|y:\\\\media\\\\music\\\\the beatles\\\\abbey road"
                }
              ],
              "subfolders": []
            }
          ]
        }
      ]
    }
  ]
}
''';

/// Minimal v2 legacy catalogue (no media_kind).
const String kCatalogV2LegacyFixture = r'''
{
  "generated_at": "2026-06-30T19:00:02+00:00",
  "total_items": 2,
  "catalogue": {
    "id": "legacy-v2",
    "scanner_version": "0.3.3",
    "catalogue_version": 2,
    "supported_extensions": ["mp4", "jpg"]
  },
  "folders": [
    {
      "id": "f1",
      "name": "Videos",
      "path": "Y:\\Media\\Videos",
      "item_count": 1,
      "items": [
        {
          "id": "v1",
          "title": "Legacy Video",
          "file_path": "Y:\\Media\\Videos\\legacy.mp4",
          "status": "available"
        }
      ],
      "subfolders": []
    },
    {
      "id": "f2",
      "name": "Images",
      "path": "Y:\\Media\\Images",
      "item_count": 1,
      "items": [
        {
          "id": "i1",
          "title": "Legacy Image",
          "file_path": "Y:\\Media\\Images\\photo.jpg",
          "status": "available"
        }
      ],
      "subfolders": []
    }
  ]
}
''';

MediaItem musicTrackComplete() {
  return MediaItem.fromJson({
    'id': 'track-complete',
    'title': 'Come Together',
    'file_path': r'Y:\Media\Music\The Beatles\Abbey Road\01 - Come Together.mp3',
    'status': 'available',
    'media_kind': 'audio',
    'artist': 'The Beatles',
    'album': 'Abbey Road',
    'album_artist': 'The Beatles',
    'track_number': 1,
    'disc_number': 1,
    'genre': 'Rock',
    'artist_group_key': 'the beatles',
    'album_group_key': r'the beatles|abbey road|y:\media\music\the beatles\abbey road',
  });
}

MediaItem legacyVideoItem() {
  return MediaItem.fromJson({
    'id': 'v1',
    'title': 'Legacy Video',
    'file_path': r'Y:\Media\Videos\legacy.mp4',
    'status': 'available',
  });
}

/// Three-track album + two-album artist for M5.3 queue seeding tests.
const String kCatalogV3QueueSeedingFixture = r'''
{
  "generated_at": "2026-07-20T12:00:00+00:00",
  "total_items": 5,
  "catalogue": {
    "id": "QUEUE-SEED",
    "catalogue_version": 3,
    "supported_extensions": ["mp3"]
  },
  "folders": [
    {
      "id": "music",
      "name": "Music",
      "path": "Y:\\Media\\Music",
      "item_count": 5,
      "items": [],
      "subfolders": [
        {
          "id": "artist-queue",
          "name": "Queue Artist",
          "path": "Y:\\Media\\Music\\Queue Artist",
          "item_count": 5,
          "items": [],
          "subfolders": [
            {
              "id": "album-a",
              "name": "First Album",
              "path": "Y:\\Media\\Music\\Queue Artist\\First Album",
              "item_count": 3,
              "items": [
                {
                  "id": "qa-t1",
                  "title": "First Track",
                  "file_path": "Y:\\Media\\Music\\Queue Artist\\First Album\\01.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Queue Artist",
                  "album": "First Album",
                  "album_artist": "Queue Artist",
                  "track_number": 1,
                  "disc_number": 1,
                  "year": 2020,
                  "artist_group_key": "queue artist",
                  "album_group_key": "queue artist|first album|y:\\\\media\\\\music\\\\queue artist\\\\first album"
                },
                {
                  "id": "qa-t2",
                  "title": "Second Track",
                  "file_path": "Y:\\Media\\Music\\Queue Artist\\First Album\\02.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Queue Artist",
                  "album": "First Album",
                  "album_artist": "Queue Artist",
                  "track_number": 2,
                  "disc_number": 1,
                  "year": 2020,
                  "artist_group_key": "queue artist",
                  "album_group_key": "queue artist|first album|y:\\\\media\\\\music\\\\queue artist\\\\first album"
                },
                {
                  "id": "qa-t3",
                  "title": "Third Track",
                  "file_path": "Y:\\Media\\Music\\Queue Artist\\First Album\\03.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Queue Artist",
                  "album": "First Album",
                  "album_artist": "Queue Artist",
                  "track_number": 3,
                  "disc_number": 2,
                  "year": 2020,
                  "artist_group_key": "queue artist",
                  "album_group_key": "queue artist|first album|y:\\\\media\\\\music\\\\queue artist\\\\first album"
                }
              ],
              "subfolders": []
            },
            {
              "id": "album-b",
              "name": "Second Album",
              "path": "Y:\\Media\\Music\\Queue Artist\\Second Album",
              "item_count": 2,
              "items": [
                {
                  "id": "qb-t1",
                  "title": "Later One",
                  "file_path": "Y:\\Media\\Music\\Queue Artist\\Second Album\\01.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Queue Artist",
                  "album": "Second Album",
                  "album_artist": "Queue Artist",
                  "track_number": 1,
                  "year": 2021,
                  "artist_group_key": "queue artist",
                  "album_group_key": "queue artist|second album|y:\\\\media\\\\music\\\\queue artist\\\\second album"
                },
                {
                  "id": "qb-t2",
                  "title": "Later Two",
                  "file_path": "Y:\\Media\\Music\\Queue Artist\\Second Album\\02.mp3",
                  "status": "available",
                  "media_kind": "audio",
                  "artist": "Queue Artist",
                  "album": "Second Album",
                  "album_artist": "Queue Artist",
                  "track_number": 2,
                  "year": 2021,
                  "artist_group_key": "queue artist",
                  "album_group_key": "queue artist|second album|y:\\\\media\\\\music\\\\queue artist\\\\second album"
                }
              ],
              "subfolders": []
            }
          ]
        }
      ]
    }
  ]
}
''';
