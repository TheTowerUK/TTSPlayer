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
