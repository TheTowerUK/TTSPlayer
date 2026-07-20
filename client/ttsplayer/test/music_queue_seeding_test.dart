import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/music/models/music_album.dart';
import 'package:ttsplayer/features/music/models/music_artist.dart';
import 'package:ttsplayer/features/music/models/music_queue_source.dart';
import 'package:ttsplayer/features/music/music_queue_seeding.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';
import 'support/music_catalog_fixtures.dart';

MediaItem _track(
  String id, {
  String title = 'Track',
  int? discNumber,
  int? trackNumber,
  int? year,
  String album = 'Album',
  MediaItemStatus status = MediaItemStatus.available,
  String mediaKind = 'audio',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: mediaKind,
    status: status,
    discNumber: discNumber,
    trackNumber: trackNumber,
    year: year,
    album: album,
    artist: 'Artist',
    albumArtist: 'Artist',
  );
}

Catalog _catalogWithAudioIds(List<String> ids) {
  return Catalog.fromJson({
    'generated_at': '2026-07-20T12:00:00+00:00',
    'total_items': ids.length,
    'catalogue': {'id': 'test', 'catalogue_version': 3},
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': r'Y:\Music',
        'item_count': ids.length,
        'items': [
          for (final id in ids)
            {
              'id': id,
              'title': id,
              'file_path': r'Y:\Music\$id.mp3',
              'status': 'available',
              'media_kind': 'audio',
            },
        ],
        'subfolders': [],
      },
    ],
  });
}

MusicAlbum _album(
  List<MediaItem> tracks, {
  String groupKey = 'album-a',
  String title = 'Album A',
  int? year,
}) {
  return MusicAlbum(
    groupKey: groupKey,
    displayTitle: title,
    displayArtist: 'Artist',
    tracks: tracks,
    year: year,
  );
}

MusicArtist _artist({
  required List<MusicAlbum> albums,
  String groupKey = 'artist-a',
  String name = 'Artist',
}) {
  final flat = [for (final album in albums) ...album.tracks];
  return MusicArtist(
    groupKey: groupKey,
    displayName: name,
    albums: albums,
    tracks: flat,
  );
}

PlaybackService _stubPlayback() {
  return PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      final fake = FakePlaybackSessionControls();
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
    },
  );
}

void main() {
  group('MusicQueueSeeding helpers', () {
    test('indexInOrderedList prefers object identity for duplicates', () {
      final first = _track('dup', title: 'First');
      final second = _track('dup', title: 'Second');
      final ordered = [first, second];

      expect(MusicQueueSeeding.indexInOrderedList(ordered, second), 1);
      expect(MusicQueueSeeding.indexInOrderedList(ordered, first), 0);
    });

    test('playableStartIndex skips non-audio and unplayable items', () {
      final ordered = [
        _track('video', mediaKind: 'video'),
        _track('missing', status: MediaItemStatus.missing),
        _track('playable'),
      ];
      expect(MusicQueueSeeding.playableStartIndex(ordered, sourceIndex: 2), 0);
      expect(MusicQueueSeeding.playableStartIndex(ordered, sourceIndex: 0), 0);
    });

    test('albumTracks returns canonical album order without re-sorting', () {
      final album = _album([
        _track('b', trackNumber: 2),
        _track('a', trackNumber: 1),
      ]);
      expect(
        MusicQueueSeeding.albumTracks(album).map((t) => t.id),
        ['b', 'a'],
      );
    });
  });

  group('MusicPlaybackQueueController album seeding', () {
    test('seedAlbumQueue replaces queue in album track order', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final album = _album([
        _track('t1', trackNumber: 1),
        _track('t2', trackNumber: 2),
        _track('t3', trackNumber: 3),
      ]);

      expect(controller.seedAlbumQueue(album), isTrue);
      expect(controller.queue.length, 3);
      expect(controller.queue.items.map((t) => t.id), ['t1', 't2', 't3']);
      expect(controller.queueSource?.kind, MusicQueueSourceKind.album);
      expect(controller.queueSource?.label, 'Album A');
    });

    test('seedAlbumQueue starts at first middle and final playable tracks', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final tracks = [
        _track('t1', trackNumber: 1),
        _track('t2', trackNumber: 2),
        _track('t3', trackNumber: 3),
      ];
      final album = _album(tracks);

      controller.seedAlbumQueue(album, sourceIndex: 0);
      expect(controller.currentTrack?.id, 't1');

      controller.seedAlbumQueue(album, sourceIndex: 1);
      expect(controller.currentTrack?.id, 't2');
      expect(controller.queue.hasPrevious, isTrue);
      expect(controller.queue.hasNext, isTrue);

      controller.seedAlbumQueue(album, sourceIndex: 2);
      expect(controller.currentTrack?.id, 't3');
      expect(controller.queue.hasNext, isFalse);
    });

    test('seedAlbumQueue preserves projection album track order', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      // Pre-sorted as MusicLibraryProjection would emit (disc, track, title, id).
      final album = _album([
        _track('d1t1', discNumber: 1, trackNumber: 1, title: 'Disc 1 A'),
        _track('d1t2', discNumber: 1, trackNumber: 2, title: 'Disc 1 B'),
        _track('d2t1', discNumber: 2, trackNumber: 1, title: 'Disc 2'),
      ]);

      controller.seedAlbumQueue(album);
      expect(controller.queue.items.map((t) => t.id), [
        'd1t1',
        'd1t2',
        'd2t1',
      ]);
    });

    test('seedAlbumQueue rejects empty or all-unplayable albums', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      expect(
        controller.seedAlbumQueue(_album([])),
        isFalse,
      );
      expect(controller.isEmpty, isTrue);

      expect(
        controller.seedAlbumQueue(_album([
          _track('v', mediaKind: 'video'),
          _track('m', status: MediaItemStatus.missing),
        ])),
        isFalse,
      );
    });

    test('album queue replacement replaces prior artist queue', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final artist = _artist(albums: [
        _album([_track('a1')], groupKey: 'al1', title: 'One'),
      ]);
      controller.seedArtistQueue(artist);
      final album = _album([_track('b1'), _track('b2')], title: 'Two');
      controller.seedAlbumQueue(album);

      expect(controller.queue.length, 2);
      expect(controller.queueSource?.kind, MusicQueueSourceKind.album);
      expect(controller.currentTrack?.id, 'b1');
    });

    test('reconcile refreshes album queue metadata by id', () async {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      controller.seedAlbumQueue(_album([
        _track('t1'),
        _track('t2'),
      ]));
      controller.onPlayerRouteOpened();

      final catalog = _catalogWithAudioIds(['t1', 't2']);
      await controller.reconcileWithCatalog(catalog);

      expect(controller.queue.length, 2);
      expect(controller.currentTrack?.id, 't1');
    });

    test('reconcile removes missing album queue items and keeps nearest index',
        () async {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      controller.seedAlbumQueue(_album([
        _track('t1', trackNumber: 1),
        _track('t2', trackNumber: 2),
        _track('t3', trackNumber: 3),
      ]), sourceIndex: 2);

      await controller.reconcileWithCatalog(_catalogWithAudioIds(['t1', 't3']));

      expect(controller.queue.length, 2);
      expect(controller.currentTrack?.id, 't3');
    });
  });

  group('MusicPlaybackQueueController artist seeding', () {
    test('seedArtistQueue flattens albums in album order within artist', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final albums = [
        _album(
          [
            _track('y1', trackNumber: 1, year: 1970),
            _track('y2', trackNumber: 2, year: 1970),
          ],
          groupKey: '1970',
          title: 'Seventies',
          year: 1970,
        ),
        _album(
          [_track('n1', trackNumber: 1), _track('n2', trackNumber: 2)],
          groupKey: 'unknown',
          title: 'No Year',
        ),
      ];
      final artist = _artist(albums: albums, name: 'Runtime Artist');

      expect(controller.seedArtistQueue(artist), isTrue);
      expect(controller.queue.items.map((t) => t.id), [
        'y1',
        'y2',
        'n1',
        'n2',
      ]);
      expect(controller.queueSource?.kind, MusicQueueSourceKind.artist);
    });

    test('seedArtistQueue starts at selected track in flattened order', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final albums = [
        _album([_track('a1'), _track('a2')], groupKey: 'a', title: 'A', year: 1969),
        _album([_track('b1')], groupKey: 'b', title: 'B', year: 1970),
      ];
      final artist = _artist(albums: albums);

      controller.seedArtistQueue(artist, sourceIndex: 2);
      expect(controller.currentTrack?.id, 'b1');
      expect(controller.queue.hasPrevious, isTrue);
    });

    test('same album title under different artists stays in artist album order',
        () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      final albums = [
        _album([_track('shared-title-a')], groupKey: 'artist-a|shared', title: 'Shared'),
        _album([_track('unique-b')], groupKey: 'artist-a|other', title: 'Other'),
      ];
      final artist = _artist(albums: albums);

      controller.seedArtistQueue(artist);
      expect(controller.queue.items.map((t) => t.id), [
        'shared-title-a',
        'unique-b',
      ]);
    });

    test('artist queue replacement replaces prior single-track queue', () {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      controller.seedSingleTrack(musicTrackComplete());
      final artist = _artist(albums: [
        _album([_track('x1'), _track('x2')]),
      ]);

      controller.seedArtistQueue(artist);
      expect(controller.queue.length, 2);
      expect(controller.queueSource?.kind, MusicQueueSourceKind.artist);
    });

    test('reconcile refreshes artist queue and stops when all items removed',
        () async {
      final controller =
          MusicPlaybackQueueController(playbackService: _stubPlayback());
      controller.seedArtistQueue(_artist(albums: [
        _album([_track('gone'), _track('stay')]),
      ]));
      await controller.playCurrent();

      await controller.reconcileWithCatalog(_catalogWithAudioIds(['stay']));

      expect(controller.queue.length, 1);
      expect(controller.currentTrack?.id, 'stay');

      await controller.reconcileWithCatalog(_catalogWithAudioIds([]));
      expect(controller.isEmpty, isTrue);
    });
  });
}
