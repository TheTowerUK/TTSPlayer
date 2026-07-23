import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_constants.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/utils/media_kind_inference.dart';

import 'support/music_catalog_fixtures.dart';
import 'support/phase_56_large_music_catalog_fixture.dart';

/// Phase 5.6 Step 3 — projection indexes, immutability, and invalidation.
void main() {
  group('MusicLibraryProjection indexes', () {
    test('every projected track resolves by ID', () {
      final projection = MusicLibraryProjection.build(phase56SmallCatalog());
      for (final track in projection.tracks) {
        expect(projection.findTrackById(track.id), same(track));
      }
      expect(projection.trackIndexCount, projection.trackCount);
    });

    test('unknown track ID returns null', () {
      final projection = MusicLibraryProjection.build(phase56SmallCatalog());
      expect(projection.findTrackById('does-not-exist'), isNull);
    });

    test('video and image IDs are absent from track index', () {
      final projection = MusicLibraryProjection.build(phase56MixedCatalog());
      expect(projection.findTrackById('p56-video-00'), isNull);
      expect(projection.findTrackById('p56-image-00'), isNull);
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
    });

    test('duplicate source IDs keep first projected occurrence', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'DUP-IDS',
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
                'id': 'same-id',
                'title': 'First',
                'file_path': r'Y:\Music\a\first.mp3',
                'media_kind': 'audio',
                'artist': 'A',
                'album': 'Album',
                'artist_group_key': 'a',
                'album_group_key': 'a|album|scope',
              },
              {
                'id': 'same-id',
                'title': 'Second',
                'file_path': r'Y:\Music\a\second.mp3',
                'media_kind': 'audio',
                'artist': 'A',
                'album': 'Album',
                'artist_group_key': 'a',
                'album_group_key': 'a|album|scope',
              },
            ],
            'subfolders': [],
          },
        ],
      });
      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.trackCount, 2);
      expect(projection.findTrackById('same-id')!.title, 'First');
      expect(projection.trackIndexCount, 1);
    });

    test('artist and album indexes resolve expected groups', () {
      final projection = MusicLibraryProjection.build(phase56SmallCatalog());
      for (final artist in projection.artists) {
        expect(
          projection.findArtistByGroupKey(artist.groupKey),
          same(artist),
        );
      }
      for (final album in projection.albums) {
        expect(projection.findAlbumByGroupKey(album.groupKey), same(album));
      }
      expect(projection.artistIndexCount, projection.artistCount);
      expect(projection.albumIndexCount, projection.albumCount);
      expect(projection.findArtistByGroupKey('missing-artist'), isNull);
      expect(projection.findAlbumByGroupKey('missing-album'), isNull);
    });

    test('compilation album lookup remains correct', () {
      final catalog = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeCompilations: true,
        includeSentinels: false,
      );
      final projection = MusicLibraryProjection.build(catalog);
      final album = projection.findAlbumByGroupKey(
        Phase56Sentinels.compilationAlbumKey,
      );
      expect(album, isNotNull);
      expect(album!.tracks.length, 4);
      expect(
        projection.findArtistByGroupKey(Phase56Sentinels.compilationArtistKey),
        isNotNull,
      );
    });

    test('catalogue replacement removes stale indexes', () {
      final catalogA = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: true,
        catalogueIdentityOverride: 'IDX-A',
      );
      final catalogB = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: false,
        includeCompilations: false,
        catalogueIdentityOverride: 'IDX-B',
      );
      final projectionA = MusicLibraryProjection.build(catalogA);
      final projectionB = MusicLibraryProjection.build(catalogB);

      expect(
        projectionA.findTrackById(Phase56Sentinels.titleTrackId),
        isNotNull,
      );
      expect(
        projectionB.findTrackById(Phase56Sentinels.titleTrackId),
        isNull,
      );
      expect(
        projectionB.findAlbumByGroupKey(Phase56Sentinels.compilationAlbumKey),
        isNull,
      );
      expect(projectionA.catalogueIdentity, 'IDX-A');
      expect(projectionB.catalogueIdentity, 'IDX-B');
    });

    test('empty catalogue clears indexes', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 0,
        'catalogue': {
          'id': 'EMPTY',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [],
      });
      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.isEmpty, isTrue);
      expect(projection.trackIndexCount, 0);
      expect(projection.artistIndexCount, 0);
      expect(projection.albumIndexCount, 0);
      expect(projection.findTrackById('any'), isNull);
    });
  });

  group('MusicLibraryProjection immutability', () {
    test('getters return stable unmodifiable collections', () {
      final projection = MusicLibraryProjection.build(phase56SmallCatalog());
      expect(identical(projection.tracks, projection.tracks), isTrue);
      expect(identical(projection.artists, projection.artists), isTrue);
      expect(identical(projection.albums, projection.albums), isTrue);
      expect(
        () =>
            (projection.tracks as List<MediaItem>).add(projection.tracks.first),
        throwsUnsupportedError,
      );
      expect(
        () => (projection.artists as List).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => (projection.albums as List).removeAt(0),
        throwsUnsupportedError,
      );
      expect(
        () => (projection.albums.first.tracks as List).clear(),
        throwsUnsupportedError,
      );
    });

    test('index counts equal projected model counts', () {
      final projection = MusicLibraryProjection.build(phase56MediumCatalog());
      expect(projection.trackIndexCount, projection.trackCount);
      expect(projection.artistIndexCount, projection.artistCount);
      expect(projection.albumIndexCount, projection.albumCount);
    });
  });

  group('MusicLibraryService memoisation and invalidation', () {
    test('same catalogue identity reuses projection instance', () {
      final service = MusicLibraryService();
      final catalog = phase56SmallCatalog();
      final first = service.projectionFor(catalog);
      final second = service.projectionFor(catalog);
      expect(identical(first, second), isTrue);
    });

    test('new catalogue generation creates a new projection', () {
      final service = MusicLibraryService();
      final a = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'GEN-1',
      );
      final b = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'GEN-2',
      );
      final first = service.projectionFor(a);
      final second = service.projectionFor(b);
      expect(identical(first, second), isFalse);
      expect(second.catalogueIdentity, 'GEN-2');
    });

    test('metadata-only catalogue identity change invalidates', () {
      final service = MusicLibraryService();
      final base = phase56SmallCatalog();
      final first = service.projectionFor(base);
      final replaced = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'META-CHANGED',
      );
      final second = service.projectionFor(replaced);
      expect(identical(first, second), isFalse);
      expect(first.catalogueIdentity, isNot(second.catalogueIdentity));
    });

    test('item addition and removal invalidate via new identity', () {
      final service = MusicLibraryService();
      final withSentinels = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: true,
        catalogueIdentityOverride: 'WITH-ITEMS',
      );
      final without = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: false,
        includeCompilations: false,
        catalogueIdentityOverride: 'WITHOUT-ITEMS',
      );
      final first = service.projectionFor(withSentinels);
      expect(first.findTrackById(Phase56Sentinels.titleTrackId), isNotNull);
      final second = service.projectionFor(without);
      expect(identical(first, second), isFalse);
      expect(second.findTrackById(Phase56Sentinels.titleTrackId), isNull);
      // Old projection remains immutable and still holds its generation.
      expect(first.findTrackById(Phase56Sentinels.titleTrackId), isNotNull);
      expect(service.projectionFor(without), same(second));
    });

    test('empty replacement invalidates and clears indexes', () {
      final service = MusicLibraryService();
      final populated = phase56SmallCatalog();
      final empty = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 0,
        'catalogue': {
          'id': 'EMPTY-REPLACEMENT',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [],
      });
      final first = service.projectionFor(populated);
      expect(first.trackCount, greaterThan(0));
      final second = service.projectionFor(empty);
      expect(identical(first, second), isFalse);
      expect(second.isEmpty, isTrue);
      expect(second.trackIndexCount, 0);
    });

    test('repeated replacement does not accumulate state', () {
      final service = MusicLibraryService();
      MusicLibraryProjection? last;
      for (var i = 0; i < 5; i++) {
        final catalog = generatePhase56MusicCatalog(
          profile: Phase56CatalogProfile.small,
          catalogueIdentityOverride: 'LOOP-$i',
        );
        last = service.projectionFor(catalog);
        expect(service.hasCachedProjectionFor('LOOP-$i'), isTrue);
        expect(service.hasCachedProjectionFor('LOOP-${i - 1}'), isFalse);
      }
      expect(last!.catalogueIdentity, 'LOOP-4');
    });
  });

  group('Normalization and grouping keys', () {
    test('case and whitespace normalize equivalently', () {
      expect(normalizeGroupKey('  Artist Name  '), 'artist name');
      expect(normalizeGroupKey('ARTIST NAME'), 'artist name');
      expect(normalizeGroupKey('Artist   Name'), 'artist name');
    });

    test('missing artist and album fall back to unknowns', () {
      final item = MediaItem(
        id: 'm1',
        title: 'Mystery',
        filePath: r'Y:\Music\folder\mystery.mp3',
        mediaKindRaw: 'audio',
      );
      expect(
        MusicLibraryProjection.artistGroupKeyForItem(item),
        normalizeGroupKey(MusicConstants.unknownArtist),
      );
      final albumKey = MusicLibraryProjection.albumGroupKeyForItem(item);
      expect(albumKey.split('|')[0],
          normalizeGroupKey(MusicConstants.unknownArtist));
      expect(albumKey.split('|')[1],
          normalizeGroupKey(MusicConstants.unknownAlbum));
    });

    test('album-artist takes precedence for album grouping artist', () {
      final item = MediaItem(
        id: 'm2',
        title: 'Track',
        filePath: r'Y:\Music\Comp\Album\t.mp3',
        mediaKindRaw: 'audio',
        artist: 'Track Artist',
        albumArtist: 'Album Artist',
        album: 'Album',
      );
      final albumKey = MusicLibraryProjection.albumGroupKeyForItem(item);
      expect(albumKey.split('|')[0], normalizeGroupKey('Album Artist'));
      expect(
        MusicLibraryProjection.artistGroupKeyForItem(item),
        normalizeGroupKey('Track Artist'),
      );
    });

    test('unicode and diacritic display names still group by key', () {
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'UNICODE',
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
                'id': 'u1',
                'title': 'Café',
                'file_path': r'Y:\Music\Cafe\Album\a.mp3',
                'media_kind': 'audio',
                'artist': 'Café',
                'album': 'Été',
                'artist_group_key': 'cafe',
                'album_group_key': 'cafe|ete|scope',
              },
              {
                'id': 'u2',
                'title': 'Cafe',
                'file_path': r'Y:\Music\Cafe\Album\b.mp3',
                'media_kind': 'audio',
                'artist': 'Cafe',
                'album': 'Ete',
                'artist_group_key': 'cafe',
                'album_group_key': 'cafe|ete|scope',
              },
            ],
            'subfolders': [],
          },
        ],
      });
      final projection = MusicLibraryProjection.build(catalog);
      expect(projection.artists.length, 1);
      expect(projection.albums.length, 1);
      expect(projection.albums.first.trackCount, 2);
    });

    test('fixture profiles remain semantically stable', () {
      for (final profile in [
        Phase56CatalogProfile.small,
        Phase56CatalogProfile.medium,
      ]) {
        final catalog = generatePhase56MusicCatalog(
          profile: profile,
          includeSentinels: true,
          includeCompilations: true,
        );
        final a = MusicLibraryProjection.build(catalog);
        final b = MusicLibraryProjection.build(catalog);
        expect(a.tracks.map((t) => t.id), b.tracks.map((t) => t.id));
        expect(
            a.artists.map((x) => x.groupKey), b.artists.map((x) => x.groupKey));
        expect(
            a.albums.map((x) => x.groupKey), b.albums.map((x) => x.groupKey));
        for (final album in a.albums) {
          expect(
            album.tracks.map((t) => t.id).toList(),
            b
                .findAlbumByGroupKey(album.groupKey)!
                .tracks
                .map((t) => t.id)
                .toList(),
          );
        }
      }
    });

    test('mixed fixture excludes non-audio', () {
      final projection = MusicLibraryProjection.build(
        Catalog.fromJson(
            jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>),
      );
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
    });
  });
}
