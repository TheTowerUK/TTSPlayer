/// Fixtures for M6.1 book/comic catalogue compatibility tests.

const kCatalogV4BookComicFixture = r'''
{
  "generated_at": "2026-07-24T12:00:00Z",
  "catalogue": {
    "id": "2026-07-24T12:00:00Z-BOOK01",
    "scanner_version": "0.5.0",
    "catalogue_version": 4,
    "supported_extensions": [
      "aac", "avi", "bmp", "cbr", "cbz", "epub", "flac", "gif", "jpeg", "jpg",
      "m4a", "m4v", "mkv", "mov", "mp3", "mp4", "ogg", "opus", "pdf", "png",
      "tif", "tiff", "wav", "webp", "wma"
    ]
  },
  "sources": [
    {
      "name": "Media",
      "root_path": "Y:\\Media",
      "type": "local",
      "accessible": true
    }
  ],
  "total_items": 11,
  "folders": [
    {
      "id": "lib-media",
      "name": "Media",
      "path": "Y:\\Media",
      "item_count": 0,
      "items": [],
      "subfolders": [
        {
          "id": "books",
          "name": "Books",
          "path": "Y:\\Media\\Books",
          "item_count": 2,
          "items": [
            {
              "id": "book-pdf",
              "title": "Owner Manual",
              "file_path": "Y:\\Media\\Books\\Owner_Manual.pdf",
              "status": "available",
              "media_kind": "book"
            },
            {
              "id": "book-epub",
              "title": "Embedded Title",
              "file_path": "Y:\\Media\\Books\\novel.epub",
              "status": "available",
              "media_kind": "book",
              "author": "Ada Lovelace"
            }
          ],
          "subfolders": []
        },
        {
          "id": "comics",
          "name": "Comics",
          "path": "Y:\\Media\\Comics",
          "item_count": 2,
          "items": [
            {
              "id": "comic-cbz",
              "title": "Night Watch",
              "file_path": "Y:\\Media\\Comics\\nw.cbz",
              "status": "available",
              "media_kind": "comic",
              "author": "Writer",
              "series": "City Watch",
              "page_count": 22
            },
            {
              "id": "comic-cbr",
              "title": "Batman 01",
              "file_path": "Y:\\Media\\Comics\\Batman_01.cbr",
              "status": "available",
              "media_kind": "comic"
            }
          ],
          "subfolders": []
        },
        {
          "id": "mixed",
          "name": "Mixed",
          "path": "Y:\\Media\\Mixed",
          "item_count": 5,
          "items": [
            {
              "id": "mixed-vid",
              "title": "Mixed Clip",
              "file_path": "Y:\\Media\\Mixed\\clip.mp4",
              "status": "available",
              "media_kind": "video"
            },
            {
              "id": "mixed-aud",
              "title": "Mixed Song",
              "file_path": "Y:\\Media\\Mixed\\song.mp3",
              "status": "available",
              "media_kind": "audio",
              "artist": "Mixed Artist"
            },
            {
              "id": "mixed-img",
              "title": "Mixed Photo",
              "file_path": "Y:\\Media\\Mixed\\photo.jpg",
              "status": "available",
              "media_kind": "image"
            },
            {
              "id": "mixed-book",
              "title": "Mixed Manual",
              "file_path": "Y:\\Media\\Mixed\\manual.pdf",
              "status": "available",
              "media_kind": "book",
              "author": "Docs Team",
              "page_count": 12
            },
            {
              "id": "mixed-comic",
              "title": "Mixed Issue",
              "file_path": "Y:\\Media\\Mixed\\issue.cbz",
              "status": "available",
              "media_kind": "comic",
              "series": "Mixed Series",
              "page_count": 18
            }
          ],
          "subfolders": []
        },
        {
          "id": "videos",
          "name": "Videos",
          "path": "Y:\\Media\\Videos",
          "item_count": 1,
          "items": [
            {
              "id": "vid-1",
              "title": "Clip",
              "file_path": "Y:\\Media\\Videos\\clip.mp4",
              "status": "available",
              "media_kind": "video"
            }
          ],
          "subfolders": []
        },
        {
          "id": "music",
          "name": "Music",
          "path": "Y:\\Media\\Music",
          "item_count": 1,
          "items": [
            {
              "id": "aud-1",
              "title": "Song",
              "file_path": "Y:\\Media\\Music\\song.mp3",
              "status": "available",
              "media_kind": "audio",
              "artist": "Artist",
              "album": "Album"
            }
          ],
          "subfolders": []
        }
      ]
    }
  ]
}
''';

const kCatalogV3StillCompatibleFixture = r'''
{
  "generated_at": "2026-07-20T12:00:00Z",
  "catalogue": {
    "id": "2026-07-20T12:00:00Z-V3OK01",
    "scanner_version": "0.4.0",
    "catalogue_version": 3,
    "supported_extensions": ["mp3", "mp4", "jpg"]
  },
  "sources": [
    {
      "name": "Media",
      "root_path": "Y:\\Media",
      "type": "local",
      "accessible": true
    }
  ],
  "total_items": 1,
  "folders": [
    {
      "id": "v",
      "name": "Videos",
      "path": "Y:\\Media\\Videos",
      "item_count": 1,
      "items": [
        {
          "id": "v1",
          "title": "Clip",
          "file_path": "Y:\\Media\\Videos\\clip.mp4",
          "status": "available",
          "media_kind": "video"
        }
      ],
      "subfolders": []
    }
  ]
}
''';

const kCatalogUnsupportedVersionFixture = r'''
{
  "generated_at": "2026-07-24T12:00:00Z",
  "catalogue": {
    "id": "2026-07-24T12:00:00Z-FUTURE",
    "scanner_version": "9.0.0",
    "catalogue_version": 99,
    "supported_extensions": ["mp4"]
  },
  "sources": [],
  "total_items": 0,
  "folders": []
}
''';
