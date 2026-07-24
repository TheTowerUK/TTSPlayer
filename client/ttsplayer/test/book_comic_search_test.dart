import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'support/book_comic_catalog_fixtures.dart';

void main() {
  late SearchService searchService;
  late Catalog catalog;

  setUp(() {
    searchService = SearchService();
    catalog = Catalog.fromJson(
      jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
    );
    searchService.buildIndex(catalog);
  });

  tearDown(() {
    searchService.invalidateIndex();
  });

  test('title search finds books and comics', () {
    final bookHits = searchService.search('Embedded', const SearchFilters.empty());
    expect(bookHits.any((r) => r.item.mediaKind == MediaKind.book), isTrue);

    final comicHits = searchService.search('Night', const SearchFilters.empty());
    expect(comicHits.any((r) => r.item.mediaKind == MediaKind.comic), isTrue);
  });

  test('author and series enrich search blob', () {
    final byAuthor = searchService.search('Ada', const SearchFilters.empty());
    expect(byAuthor.any((r) => r.item.id == 'book-epub'), isTrue);

    final bySeries = searchService.search('City Watch', const SearchFilters.empty());
    expect(bySeries.any((r) => r.item.id == 'comic-cbz'), isTrue);
  });

  test('extension filter isolates comic archives', () {
    final cbz = searchService.search(
      'cbz',
      const SearchFilters(extension: 'cbz'),
    );
    expect(cbz, isNotEmpty);
    expect(cbz.every((r) => r.item.extension == 'cbz'), isTrue);

    final cbr = searchService.search(
      'cbr',
      const SearchFilters(extension: 'cbr'),
    );
    expect(cbr, isNotEmpty);
    expect(cbr.every((r) => r.item.extension == 'cbr'), isTrue);
  });

  test('mixed catalogue still finds video and audio', () {
    final video = searchService.search('Clip', const SearchFilters.empty());
    expect(video.any((r) => r.item.mediaKind == MediaKind.video), isTrue);

    final audio = searchService.search('Song', const SearchFilters.empty());
    expect(audio.any((r) => r.item.mediaKind == MediaKind.audio), isTrue);
  });

  test('extensions list includes book and comic formats', () {
    final extensions = searchService.extensionsFor(catalog);
    expect(extensions, containsAll(['pdf', 'epub', 'cbz', 'cbr', 'mp4', 'mp3']));
  });
}
