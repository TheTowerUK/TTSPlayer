import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/constants/supported_extensions.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/models/unsupported_catalogue_version_exception.dart';
import 'package:ttsplayer/utils/media_kind_inference.dart';

import 'support/book_comic_catalog_fixtures.dart';

void main() {
  group('SupportedExtensions book/comic', () {
    test('includes required comic and book formats', () {
      expect(SupportedExtensions.book, containsAll(['pdf', 'epub']));
      expect(SupportedExtensions.comic, containsAll(['cbz', 'cbr']));
      expect(SupportedExtensions.all, containsAll(['pdf', 'epub', 'cbz', 'cbr']));
    });

    test('categoryFor classifies book and comic extensions', () {
      expect(
        SupportedExtensions.categoryFor('pdf'),
        MediaExtensionCategory.book,
      );
      expect(
        SupportedExtensions.categoryFor('cbz'),
        MediaExtensionCategory.comic,
      );
    });
  });

  group('MediaKind book/comic', () {
    test('fromString parses book and comic', () {
      expect(MediaKind.fromString('book'), MediaKind.book);
      expect(MediaKind.fromString('comic'), MediaKind.comic);
    });

    test('inference maps extensions when raw kind missing', () {
      expect(
        inferMediaKind(filePath: r'Y:\Media\Books\a.pdf', rawKind: null),
        MediaKind.book,
      );
      expect(
        inferMediaKind(filePath: r'Y:\Media\Comics\a.cbr', rawKind: null),
        MediaKind.comic,
      );
    });

    test('unknown raw kind stays unknown', () {
      expect(
        inferMediaKind(
          filePath: r'Y:\Media\Books\a.pdf',
          rawKind: 'future_kind',
        ),
        MediaKind.unknown,
      );
    });
  });

  group('MediaItem book/comic fields', () {
    test('parses author series page_count', () {
      final item = MediaItem.fromJson({
        'id': 'c1',
        'title': 'Night Watch',
        'file_path': r'Y:\Media\Comics\nw.cbz',
        'media_kind': 'comic',
        'author': 'Writer',
        'series': 'City Watch',
        'page_count': 22,
      });
      expect(item.isComic, isTrue);
      expect(item.canStartAvPlayback, isFalse);
      expect(item.isContinueWatchingEligible, isFalse);
      expect(item.author, 'Writer');
      expect(item.series, 'City Watch');
      expect(item.pageCount, 22);
    });

    test('book is not A/V playable', () {
      final item = MediaItem.fromJson({
        'id': 'b1',
        'title': 'Guide',
        'file_path': r'Y:\Media\Books\guide.pdf',
        'media_kind': 'book',
      });
      expect(item.isBook, isTrue);
      expect(item.canStartAvPlayback, isFalse);
    });
  });

  group('Catalogue v4 compatibility', () {
    test('parses mixed book/comic/video/audio catalogue', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
      );
      expect(catalog.catalogueInfo?.catalogueVersion, 4);
      expect(catalog.catalogueInfo?.scannerVersion, '0.5.0');
      final kinds = catalog.allItems.map((i) => i.mediaKind).toSet();
      expect(kinds, contains(MediaKind.book));
      expect(kinds, contains(MediaKind.comic));
      expect(kinds, contains(MediaKind.video));
      expect(kinds, contains(MediaKind.audio));
      expect(
        catalog.supportedExtensions,
        containsAll(['pdf', 'epub', 'cbz', 'cbr']),
      );
    });

    test('legacy v3 catalogues still load', () {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3StillCompatibleFixture) as Map<String, dynamic>,
      );
      expect(catalog.catalogueInfo?.catalogueVersion, 3);
      expect(catalog.allItems, isNotEmpty);
    });

    test('unsupported future catalogue_version fails predictably', () {
      expect(
        () => Catalog.fromJson(
          jsonDecode(kCatalogUnsupportedVersionFixture) as Map<String, dynamic>,
        ),
        throwsA(isA<UnsupportedCatalogueVersionException>()),
      );
    });

    test('malformed optional document fields do not crash', () {
      final item = MediaItem.fromJson({
        'id': 'x',
        'title': 'X',
        'file_path': r'Y:\Media\Books\x.epub',
        'media_kind': 'book',
        'page_count': 'nope',
        'author': null,
      });
      expect(item.pageCount, isNull);
      expect(item.mediaKind, MediaKind.book);
    });
  });
}
