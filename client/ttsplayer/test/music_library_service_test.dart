import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_constants.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/music_sorting.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';

import 'support/large_music_catalog_factory.dart';
import 'support/music_catalog_fixtures.dart';

void main() {
  group('MusicLibraryProjection', () {
    test('filters audio-only items from mixed catalogue', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
      final projection = MusicLibraryProjection.build(catalog);

      expect(projection.tracks.every((t) => t.isAudio), isTrue);
      expect(projection.trackCount, 3);
      expect(projection.artists.length, greaterThan(0));
      expect(projection.albums.length, greaterThan(0));
    });

    test('groups artists by artist_group_key', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-19T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'ARTIST-GROUP',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'music',
            'name': 'Music',
            'path': r'Y:\Music',
            'item_count': 2,
            'items': [
              {
                'id': 'a1',
                'title': 'Song A',
                'file_path': r'Y:\Music\Artist One\Album\a.mp3',
                'media_kind': 'audio',
                'artist': 'Artist One',
                'album': 'Album',
                'artist_group_key': 'artist one',
                'album_group_key': 'artist one|album|scope-a',
              },
              {
                'id': 'a2',
                'title': 'Song B',
                'file_path': r'Y:\Music\Artist One\Album\b.mp3',
                'media_kind': 'audio',
                'artist': 'Artist One',
                'album': 'Album',
                'artist_group_key': 'artist one',
                'album_group_key': 'artist one|album|scope-a',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.artists.length, 1);
      expect(projection.artists.first.trackCount, 2);
    });

    test('same album title under different artists does not collide', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-19T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'ALBUM-COLLISION',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'music',
            'name': 'Music',
            'path': r'Y:\Music',
            'item_count': 2,
            'items': [
              {
                'id': 'x',
                'title': 'Hit',
                'file_path': r'Y:\Music\Artist One\Greatest Hits\a.mp3',
                'media_kind': 'audio',
                'artist': 'Artist One',
                'album': 'Greatest Hits',
                'artist_group_key': 'artist one',
                'album_group_key': 'artist one|greatest hits|scope-1',
              },
              {
                'id': 'y',
                'title': 'Hit',
                'file_path': r'Y:\Music\Artist Two\Greatest Hits\b.mp3',
                'media_kind': 'audio',
                'artist': 'Artist Two',
                'album': 'Greatest Hits',
                'artist_group_key': 'artist two',
                'album_group_key': 'artist two|greatest hits|scope-2',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.albums.length, 2);
      expect(
        projection.albums.map((a) => a.groupKey).toSet().length,
        2,
      );
    });

    test('unknown artist is sorted last', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-19T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'UNKNOWN-ARTIST',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'music',
            'name': 'Music',
            'path': r'Y:\Music',
            'item_count': 2,
            'items': [
              {
                'id': 'u',
                'title': 'Mystery',
                'file_path': r'Y:\Music\mystery.mp3',
                'media_kind': 'audio',
                'artist': MusicConstants.unknownArtist,
                'artist_group_key': 'unknown artist',
              },
              {
                'id': 'z',
                'title': 'Alpha',
                'file_path': r'Y:\Music\Alpha\a.mp3',
                'media_kind': 'audio',
                'artist': 'Alpha',
                'artist_group_key': 'alpha',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.artists.last.displayName, MusicConstants.unknownArtist);
    });

    test('orders tracks within album by disc then track number', () {
      final items = [
        MediaItem(
          id: 't3',
          title: 'C',
          filePath: r'Y:\Music\A\Album\c.mp3',
          mediaKindRaw: 'audio',
          trackNumber: 2,
          discNumber: 2,
          artistGroupKey: 'a',
          albumGroupKey: 'a|album|scope',
        ),
        MediaItem(
          id: 't1',
          title: 'A',
          filePath: r'Y:\Music\A\Album\a.mp3',
          mediaKindRaw: 'audio',
          trackNumber: 1,
          discNumber: 1,
          artistGroupKey: 'a',
          albumGroupKey: 'a|album|scope',
        ),
        MediaItem(
          id: 't2',
          title: 'B',
          filePath: r'Y:\Music\A\Album\b.mp3',
          mediaKindRaw: 'audio',
          trackNumber: 2,
          discNumber: 1,
          artistGroupKey: 'a',
          albumGroupKey: 'a|album|scope',
        ),
      ]..sort(MusicSorting.compareTracksInAlbum);

      expect(items.map((i) => i.id).toList(), ['t1', 't2', 't3']);
    });

    test('representative track selection is deterministic', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
      final first = MusicLibraryProjection.build(catalog);
      final second = MusicLibraryProjection.build(catalog);

      expect(
        first.albums.first.representativeTrack.id,
        second.albums.first.representativeTrack.id,
      );
    });
  });

  group('MusicLibraryService', () {
    test('memoises projection by catalogue identity', () {
      final service = MusicLibraryService();
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );

      final first = service.projectionFor(catalog);
      final second = service.projectionFor(catalog);

      expect(identical(first, second), isTrue);
    });

    test('invalidate clears memoised projection', () {
      final service = MusicLibraryService();
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );

      final first = service.projectionFor(catalog);
      service.invalidate();
      final second = service.projectionFor(catalog);

      expect(identical(first, second), isFalse);
      expect(first.trackCount, second.trackCount);
    });

    test('large catalogue projection completes deterministically', () {
      final catalog = buildLargeMusicCatalog(
        artistCount: largeMusicArtistCount,
        albumsPerArtist: largeMusicAlbumsPerArtist,
        tracksPerAlbum: largeMusicTracksPerAlbum,
      );

      final first = MusicLibraryProjection.build(catalog);
      final second = MusicLibraryProjection.build(catalog);

      expect(first.artistCount, largeMusicArtistCount);
      expect(first.albumCount, largeMusicArtistCount * largeMusicAlbumsPerArtist);
      expect(
        first.trackCount,
        largeMusicArtistCount * largeMusicAlbumsPerArtist * largeMusicTracksPerAlbum,
      );
      expect(first.artists.map((a) => a.groupKey).toList(),
          second.artists.map((a) => a.groupKey).toList());
    });

    test('mixed catalogue excludes video from music projection', () {
      final catalog = buildLargeMusicCatalog(
        artistCount: 2,
        albumsPerArtist: 1,
        tracksPerAlbum: 2,
        includeVideoItems: true,
      );

      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
      expect(projection.trackCount, 4);
    });
  });
}
