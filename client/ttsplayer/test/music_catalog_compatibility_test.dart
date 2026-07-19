import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'support/music_catalog_fixtures.dart';

void main() {
  group('MediaItem media_kind', () {
    test('legacy v2 video item infers video from extension', () {
      final item = legacyVideoItem();
      expect(item.mediaKind, MediaKind.video);
      expect(item.isVideo, isTrue);
      expect(item.isContinueWatchingEligible, isTrue);
    });

    test('v3 audio item parses explicit media_kind', () {
      final item = musicTrackComplete();
      expect(item.mediaKind, MediaKind.audio);
      expect(item.isAudio, isTrue);
      expect(item.isContinueWatchingEligible, isFalse);
    });

    test('unknown media_kind string is safe', () {
      final item = MediaItem.fromJson({
        'id': 'x',
        'title': 'X',
        'file_path': r'Y:\Media\Videos\x.mp4',
        'media_kind': 'future_kind',
      });
      expect(item.mediaKind, MediaKind.unknown);
    });

    test('invalid optional numeric values do not crash', () {
      final item = MediaItem.fromJson({
        'id': 'x',
        'title': 'X',
        'file_path': r'Y:\Media\Music\x.mp3',
        'media_kind': 'audio',
        'track_number': 'not-a-number',
        'disc_number': null,
      });
      expect(item.trackNumber, isNull);
      expect(item.mediaKind, MediaKind.audio);
    });
  });

  group('Catalogue compatibility', () {
    test('parses version 2 legacy catalogue', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV2LegacyFixture) as Map<String, dynamic>,
      );
      expect(catalog.catalogueInfo?.catalogueVersion, 2);
      expect(catalog.allItems.length, 2);
      expect(catalog.allItems.first.mediaKind, MediaKind.video);
      expect(catalog.allItems.last.mediaKind, MediaKind.image);
    });

    test('parses version 3 mixed-media catalogue', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
      expect(catalog.catalogueInfo?.catalogueVersion, 3);
      final kinds = catalog.allItems.map((i) => i.mediaKind).toSet();
      expect(kinds, contains(MediaKind.video));
      expect(kinds, contains(MediaKind.audio));
    });

    test('music metadata fields parse on v3 items', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
      final track = catalog.findItemById('track-complete');
      expect(track, isNotNull);
      expect(track!.artist, 'The Beatles');
      expect(track.album, 'Abbey Road');
      expect(track.trackNumber, 1);
      expect(track.artistGroupKey, 'the beatles');
    });
  });
}
